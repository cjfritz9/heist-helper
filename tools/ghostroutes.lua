package.path = "./?.lua;" .. package.path

local routeassembly = require("core.routeassembly")
local ghostpaths = require("core.ghostpaths")

local TICK_SECONDS = 0.6
local STALL_SLACK_TICKS = 1 / 6
local OUTPUT = "data/ghostpaths.lua"

local logPaths, write = {}, false
for _, a in ipairs(arg) do
  if a == "--write" then write = true
  elseif not a:match("%.csv$") then logPaths[#logPaths + 1] = a end
end
if #logPaths == 0 then
  print("usage: luajit tools/ghostroutes.lua <ghosts-run-*.log ...> [--write]")
  os.exit(1)
end

local reads, sightings, stops, heights = {}, {}, {}, {}
local knownSpawnTile = {}
for _, sp in ipairs(require("data.ghostspawns")) do knownSpawnTile[sp.x .. "," .. sp.z] = true end

for fileIndex, path in ipairs(logPaths) do
  local open, spawn, session = {}, {}, 0
  local finish = function(k)
    local s = open[k]
    open[k] = nil
    if s and not spawn[k] then
      reads[#reads + 1] = routeassembly.clean(s.tiles)
      sightings[#sightings + 1] = { file = fileIndex, events = s.tiles, setoffs = s.setoffs or {} }
    end
  end
  for line in io.lines(path) do
    local at = tonumber(line:match("^%[%s*([%d.]+)%]"))
    if line:find("] run: ") then
      for k in pairs(open) do finish(k) end
      session = session + 1
    else
      local spawned = line:match("%] g(%d+) treated as a spawn")
      if spawned then spawn[session .. ":" .. spawned] = true end
      local id, verb, x, z, h = line:match("%] g(%d+) (%a+)[^%d%-]*(%-?%d+),(%-?%d+) %([^)]*%) height (%d+)")
      if id and at then
        local k = session .. ":" .. id
        x, z, h = tonumber(x), tonumber(z), tonumber(h)
        if line:find("spawned by corpse") then spawn[k] = true end
        if verb == "appears" and knownSpawnTile[x .. "," .. z] then spawn[k] = true end
        local tile = { x = x, z = z, at = at * 1e6 }
        local s = open[k]
        if verb == "appears" then
          finish(k)
          open[k] = { tiles = { tile } }
        elseif s and (verb == "onto" or verb == "lost") then
          local last = s.tiles[#s.tiles]
          if last.x ~= x or last.z ~= z then
            s.from = last
            s.tiles[#s.tiles + 1] = tile
          end
          if verb == "lost" then finish(k) end
        elseif s and verb == "stops" then
          s.stopped = { x = x, z = z, from = s.tiles[#s.tiles - 1] }
        elseif s and verb == "starts" and s.stopped then
          local seconds = tonumber(line:match("after standing ([%d.]+) s"))
          local ticks = seconds and math.floor(seconds / TICK_SECONDS + STALL_SLACK_TICKS) or 0
          if ticks > 0 and s.stopped.from then
            local tile, from = s.stopped.x .. "," .. s.stopped.z, s.stopped.from.x .. "," .. s.stopped.from.z
            stops[#stops + 1] = { tile = tile, from = from, ticks = ticks }
            s.setoffs = s.setoffs or {}
            s.setoffs[#s.setoffs + 1] = { at = at * 1e6, tile = tile, from = from }
          end
          s.stopped = nil
        end
        local hk = x .. "," .. z
        heights[hk] = heights[hk] or {}
        heights[hk][h] = (heights[hk][h] or 0) + 1
      end
    end
  end
  for k in pairs(open) do finish(k) end
end

local heightOf = function(k)
  local best, n = 0, 0
  for h, c in pairs(heights[k] or {}) do
    if c > n then best, n = h, c end
  end
  return best
end

local stallFor = function(tile, from)
  local votes = {}
  for _, s in ipairs(stops) do
    if s.tile == tile and s.from == from then votes[s.ticks] = (votes[s.ticks] or 0) + 1 end
  end
  local best, n, total = nil, 0, 0
  for ticks, c in pairs(votes) do
    total = total + c
    if c > n then best, n = ticks, c end
  end
  return best, n, total
end

local nameOf = function(steps)
  local minZ, maxZ, maxH = math.huge, -math.huge, 0
  for _, s in ipairs(steps) do
    minZ, maxZ, maxH = math.min(minZ, s.z), math.max(maxZ, s.z), math.max(maxH, s.h)
  end
  if maxH > 2600 then return "sections 1-2" end
  if maxH > 2000 then return "section 4" end
  if minZ >= -31 then return "section 3 north" end
  return "section 3 south"
end

routeassembly.fixCutCorners(reads)
local contigs = routeassembly.assemble(reads)
print(string.format("%d sightings, %d routes after stitching, %d stops", #reads, #contigs, #stops))

local median = function(values)
  table.sort(values)
  local n = #values
  if n == 0 then return nil end
  if n % 2 == 1 then return values[(n + 1) / 2] end
  return (values[n / 2] + values[n / 2 + 1]) / 2
end

local passesOf = function(loop)
  local stepOf, passes = {}, {}
  for n, k in ipairs(loop) do
    stepOf[loop[(n - 2) % #loop + 1] .. ">" .. k] = n
  end
  for _, sighting in ipairs(sightings) do
    for e = 2, #sighting.events do
      local a, b = sighting.events[e - 1], sighting.events[e]
      local n = stepOf[a.x .. "," .. a.z .. ">" .. b.x .. "," .. b.z]
      if n then
        passes[n] = passes[n] or {}
        passes[n][#passes[n] + 1] = { file = sighting.file, at = b.at }
      end
    end
  end
  return passes
end

local lapTicks = function(loop, passes)
  local gaps = {}
  for _, list in pairs(passes) do
    local byFile = {}
    for _, p in ipairs(list) do
      byFile[p.file] = byFile[p.file] or {}
      table.insert(byFile[p.file], p.at)
    end
    for _, times in pairs(byFile) do
      table.sort(times)
      for t = 2, #times do
        local ticks = (times[t] - times[t - 1]) / (TICK_SECONDS * 1e6)
        if ticks > #loop * 0.8 and ticks < #loop * 1.6 then gaps[#gaps + 1] = ticks end
      end
    end
  end
  local lap = median(gaps)
  return lap and math.floor(lap + 0.5), #gaps
end

local arrivals = function(loop, passes, lap)
  local starts = {}
  for _, p in ipairs(passes[1] or {}) do
    starts[p.file] = starts[p.file] or {}
    table.insert(starts[p.file], p.at)
  end
  for _, times in pairs(starts) do table.sort(times) end
  local offset = {}
  for n = 1, #loop do
    local values = {}
    for _, p in ipairs(passes[n] or {}) do
      local best = nil
      for _, t in ipairs(starts[p.file] or {}) do
        if t <= p.at then best = t end
      end
      if best then
        local ticks = ((p.at - best) / (TICK_SECONDS * 1e6)) % lap
        values[#values + 1] = ticks
      end
    end
    offset[n] = median(values)
  end
  offset[1] = 0
  local round = function(values)
    local tick, last = {}, 0
    local base = values[1] or 0
    for n = 1, #loop do
      local v = values[n] and ((values[n] - base) % lap) or nil
      local guess = v and math.floor(v + 0.5) or (last + 1)
      if n == 1 then guess = 0 elseif guess <= last then guess = last + 1 end
      tick[n], last = guess, guess
    end
    return tick
  end
  local circular = function(values)
    local sx, sy = 0, 0
    for _, v in ipairs(values) do
      sx, sy = sx + math.cos(v / lap * 2 * math.pi), sy + math.sin(v / lap * 2 * math.pi)
    end
    if sx == 0 and sy == 0 then return nil end
    return (math.atan2(sy, sx) / (2 * math.pi) * lap) % lap
  end
  local tick = round(offset)
  for _ = 1, 4 do
    local fileOffset = {}
    local byFile = {}
    for n = 1, #loop do
      for _, p in ipairs(passes[n] or {}) do
        byFile[p.file] = byFile[p.file] or {}
        table.insert(byFile[p.file], (p.at / (TICK_SECONDS * 1e6) - tick[n]) % lap)
      end
    end
    for file, values in pairs(byFile) do fileOffset[file] = circular(values) end
    local refined = {}
    for n = 1, #loop do
      local values = {}
      for _, p in ipairs(passes[n] or {}) do
        values[#values + 1] = (p.at / (TICK_SECONDS * 1e6) - fileOffset[p.file]) % lap
      end
      refined[n] = circular(values)
    end
    tick = round(refined)
  end
  return tick
end

local segmentWaits = function(loop, lap)
  local n = #loop
  local stepOf = {}
  for k, key in ipairs(loop) do stepOf[loop[(k - 2) % n + 1] .. ">" .. key] = k end
  local xz = function(key) local x, z = key:match("(%-?%d+),(%-?%d+)") return tonumber(x), tonumber(z) end
  local isKey = {}
  for k = 1, n do
    local px, pz = xz(loop[(k - 2) % n + 1])
    local x, z = xz(loop[k])
    local nx, nz = xz(loop[k % n + 1])
    if x - px ~= nx - x or z - pz ~= nz - z then isKey[k] = true end
    if stallFor(loop[k], loop[(k - 2) % n + 1]) then isKey[k] = true end
  end
  local keys = {}
  for k = 1, n do if isKey[k] then keys[#keys + 1] = k end end
  local nextKey = {}
  for i, k in ipairs(keys) do nextKey[k] = keys[i % #keys + 1] end
  local samples = {}
  for _, sighting in ipairs(sightings) do
    local seen = {}
    for e = 2, #sighting.events do
      local a, b = sighting.events[e - 1], sighting.events[e]
      local k = stepOf[a.x .. "," .. a.z .. ">" .. b.x .. "," .. b.z]
      if k then
        seen[#seen + 1] = { step = k, at = b.at }
      else
        seen[#seen + 1] = { step = nil }
      end
    end
    for i = 1, #seen do
      local from = seen[i]
      if from.step and isKey[from.step] then
        local target = nextKey[from.step]
        local between = (target - from.step) % n
        if between == 0 then between = n end
        for j = i + 1, math.min(#seen, i + between) do
          if not seen[j].step then break end
          if seen[j].step == target and j - i == between then
            samples[from.step] = samples[from.step] or {}
            table.insert(samples[from.step], (seen[j].at - from.at) / (TICK_SECONDS * 1e6) - between)
          end
        end
      end
    end
  end
  local exact = {}
  for _, sighting in ipairs(sightings) do
    local offs = sighting.setoffs
    for i = 2, #offs do
      local a = stepOf[offs[i - 1].from .. ">" .. offs[i - 1].tile]
      local b = stepOf[offs[i].from .. ">" .. offs[i].tile]
      if a and b then
        local between = (b - a) % n
        if between == 0 then between = n end
        local ticks = math.floor((offs[i].at - offs[i - 1].at) / (TICK_SECONDS * 1e6) + 0.5)
        if ticks >= between and ticks < between + lap - n + 1 then
          local k = a .. ">" .. b
          exact[k] = exact[k] or { a = a, b = b, between = between, values = {} }
          table.insert(exact[k].values, ticks - between)
        end
      end
    end
  end
  local raw, total = {}, 0
  for _, k in ipairs(keys) do
    local m = samples[k] and median(samples[k]) or 0
    raw[k] = math.max(0, m)
    total = total + raw[k]
  end
  local want = lap - n
  local waits, used, order = {}, 0, {}
  for _, k in ipairs(keys) do
    waits[k] = math.floor(raw[k])
    used = used + waits[k]
    order[#order + 1] = k
  end
  table.sort(order, function(x, y) return (raw[x] - math.floor(raw[x])) > (raw[y] - math.floor(raw[y])) end)
  local i = 1
  while used < want and #order > 0 do
    waits[order[i]] = waits[order[i]] + 1
    used = used + 1
    i = i % #order + 1
  end
  i = #order
  while used > want and #order > 0 do
    if waits[order[i]] > 0 then waits[order[i]] = waits[order[i]] - 1 used = used - 1 end
    i = (i - 2) % #order + 1
  end
  local fixed, pinned = {}, {}
  for _, e in pairs(exact) do
    local want = median(e.values)
    want = math.floor(want + 0.5)
    local inside, have = {}, 0
    for d = 1, e.between do
      local k = (e.a + d - 1) % n + 1
      if waits[k] then
        inside[#inside + 1] = k
        have = have + waits[k]
      end
    end
    local byRemainder = function(x, y) return (raw[x] - math.floor(raw[x])) > (raw[y] - math.floor(raw[y])) end
    table.sort(inside, byRemainder)
    local j = 1
    while have < want and #inside > 0 do
      waits[inside[j]] = waits[inside[j]] + 1
      have = have + 1
      j = j % #inside + 1
    end
    j = #inside
    local guard = 0
    while have > want and #inside > 0 and guard < 1000 do
      if waits[inside[j]] > 0 then waits[inside[j]] = waits[inside[j]] - 1 have = have - 1 end
      j = (j - 2) % #inside + 1
      guard = guard + 1
    end
    fixed[#fixed + 1] = string.format("%s>%s %d ticks (seen %d)", loop[e.a], loop[e.b], e.between + want, #e.values)
    for _, k in ipairs(inside) do pinned[k] = true end
  end
  local total, free = 0, {}
  for _, k in ipairs(keys) do
    total = total + waits[k]
    if not pinned[k] then free[#free + 1] = k end
  end
  table.sort(free, function(x, y) return (raw[x] - math.floor(raw[x])) > (raw[y] - math.floor(raw[y])) end)
  local j = 1
  while total < want and #free > 0 do
    waits[free[j]] = waits[free[j]] + 1
    total = total + 1
    j = j % #free + 1
  end
  j = #free
  local guard = 0
  while total > want and #free > 0 and guard < 1000 do
    if waits[free[j]] > 0 then waits[free[j]] = waits[free[j]] - 1 total = total - 1 end
    j = (j - 2) % #free + 1
    guard = guard + 1
  end
  return waits, raw, samples, #keys, fixed
end

local loops = {}
for i, contig in ipairs(contigs) do
  local loop = routeassembly.loop(contig)
  if not loop then
    print(string.format("\nroute %d: open, %d steps: %s", i, #contig, table.concat(contig, " ")))
  else
    local passes = passesOf(loop)
    local lap, gaps = lapTicks(loop, passes)
    local waits, raw, samples, keyCount, fixed = nil, nil, nil, 0, {}
    if lap then waits, raw, samples, keyCount, fixed = segmentWaits(loop, lap) end
    local steps, stallTicks, notes = {}, 0, {}
    for n, k in ipairs(loop) do
      local x, z = k:match("(%-?%d+),(%-?%d+)")
      local from = loop[(n - 2) % #loop + 1]
      local stall = waits and waits[n] or stallFor(k, from)
      if stall and stall <= 0 then stall = nil end
      steps[n] = { x = tonumber(x), z = tonumber(z), h = heightOf(k), stall = stall }
      if stall then
        stallTicks = stallTicks + stall
        notes[#notes + 1] = string.format("%s from %s: %d (measured %.2f over %d)", k, from, stall,
          raw and raw[n] or 0, samples and samples[n] and #samples[n] or 0)
      end
    end
    if lap then notes[#notes + 1] = string.format("lap measured from %d one-lap gaps: %d ticks; %d turn or stall tiles", gaps, lap, keyCount) end
    for _, f in ipairs(fixed) do notes[#notes + 1] = "exact between set-offs: " .. f end
    local entry = { name = nameOf(steps), steps = steps }
    loops[#loops + 1] = entry
    print(string.format("\n%s: %d steps + %d stall ticks = %d ticks a lap", entry.name, #steps, stallTicks, #steps + stallTicks))
    for _, note in ipairs(notes) do print("  " .. note) end
  end
end

local prepared = ghostpaths.prepare({ loops = loops })
print("\nlap check: each tile time against the model, after lining up each log once; ticks off")
for li, loop in ipairs(prepared) do
  local stepOf = {}
  for n, st in ipairs(loop.steps) do
    local prev = loop.steps[(n - 2) % #loop.steps + 1]
    stepOf[prev.x .. "," .. prev.z .. ">" .. st.x .. "," .. st.z] = n
  end
  local L = loop.time.length
  local byFile = {}
  for _, sighting in ipairs(sightings) do
    for e = 2, #sighting.events do
      local a, b = sighting.events[e - 1], sighting.events[e]
      local n = stepOf[a.x .. "," .. a.z .. ">" .. b.x .. "," .. b.z]
      if n then
        byFile[sighting.file] = byFile[sighting.file] or {}
        table.insert(byFile[sighting.file], (b.at / (TICK_SECONDS * 1e6) - loop.time.firstTick[n]) % L)
      end
    end
  end
  local off, count, worst = {}, 0, 0
  for _, values in pairs(byFile) do
    local sx, sy = 0, 0
    for _, v in ipairs(values) do
      sx, sy = sx + math.cos(v / L * 2 * math.pi), sy + math.sin(v / L * 2 * math.pi)
    end
    local centre = (math.atan2(sy, sx) / (2 * math.pi) * L) % L
    for _, v in ipairs(values) do
      local miss = (v - centre + L / 2) % L - L / 2
      local bucket = math.floor(miss + 0.5)
      off[bucket] = (off[bucket] or 0) + 1
      worst, count = math.max(worst, math.abs(miss)), count + 1
    end
  end
  local spread = {}
  for bucket, c in pairs(off) do spread[#spread + 1] = { b = bucket, c = c } end
  table.sort(spread, function(x, y) return x.b < y.b end)
  local parts = {}
  for _, x in ipairs(spread) do parts[#parts + 1] = string.format("%+d:%d", x.b, x.c) end
  print(string.format("  %s (%d ticks): %d tiles, worst %.2f ticks off, by whole ticks %s", loop.name, L, count, worst, table.concat(parts, " ")))
end

print("\nclient lag: how far behind its server tile the drawn ghost reaches each tile's centre, in ticks")
for li, loop in ipairs(prepared) do
  local n, L = #loop.steps, loop.time.length
  local stepOf = {}
  for k, st in ipairs(loop.steps) do
    local p = loop.steps[(k - 2) % n + 1]
    stepOf[p.x .. "," .. p.z .. ">" .. st.x .. "," .. st.z] = k
  end
  local offsets = {}
  for _, sighting in ipairs(sightings) do
    for _, off in ipairs(sighting.setoffs) do
      local k = stepOf[off.from .. ">" .. off.tile]
      if k then
        local nextStep = k % n + 1
        offsets[sighting.file] = offsets[sighting.file] or {}
        table.insert(offsets[sighting.file], (off.at / (TICK_SECONDS * 1e6) - loop.time.firstTick[nextStep]) % L)
      end
    end
  end
  local fileOffset = {}
  for file, values in pairs(offsets) do
    local sx, sy = 0, 0
    for _, v in ipairs(values) do sx, sy = sx + math.cos(v / L * 2 * math.pi), sy + math.sin(v / L * 2 * math.pi) end
    fileOffset[file] = (math.atan2(sy, sx) / (2 * math.pi) * L) % L
  end
  local perStep = {}
  for _, sighting in ipairs(sightings) do
    local offset = fileOffset[sighting.file]
    if offset then
      for e = 2, #sighting.events do
        local a, b = sighting.events[e - 1], sighting.events[e]
        local k = stepOf[a.x .. "," .. a.z .. ">" .. b.x .. "," .. b.z]
        if k then
          local v = ((b.at / (TICK_SECONDS * 1e6) - loop.time.firstTick[k]) - offset + L / 2) % L - L / 2
          perStep[k] = perStep[k] or {}
          table.insert(perStep[k], v)
        end
      end
    end
  end
  local known = {}
  for k = 1, n do
    if perStep[k] and #perStep[k] >= 2 then known[k] = median(perStep[k]) end
  end
  local measured = 0
  for k = 1, n do if known[k] then measured = measured + 1 end end
  for k = 1, n do
    local lag = known[k]
    if not lag and measured > 0 then
      local back, fwd = nil, nil
      for d = 1, n do
        if not back and known[(k - 1 - d) % n + 1] then back = { d = d, v = known[(k - 1 - d) % n + 1] } end
        if not fwd and known[(k - 1 + d) % n + 1] then fwd = { d = d, v = known[(k - 1 + d) % n + 1] } end
        if back and fwd then break end
      end
      lag = back.v + (fwd.v - back.v) * back.d / (back.d + fwd.d)
    end
    loops[li].steps[k].lag = lag
  end
  print(string.format("  %s: measured on %d of %d tiles, the rest in between", loop.name, measured, n))
end

if write then
  local out = { "return {", "  loops = {" }
  for _, loop in ipairs(loops) do
    out[#out + 1] = string.format("    { name = %q, steps = {", loop.name)
    for _, s in ipairs(loop.steps) do
      out[#out + 1] = string.format("      { x = %d, z = %d, h = %d%s%s },", s.x, s.z, s.h, s.stall and (", stall = " .. s.stall) or "",
        s.lag and string.format(", lag = %.2f", s.lag) or "")
    end
    out[#out + 1] = "    } },"
  end
  out[#out + 1] = "  },"
  out[#out + 1] = "}"
  local f = assert(io.open(OUTPUT, "w"))
  f:write(table.concat(out, "\n") .. "\n")
  f:close()
  print("\nwrote " .. OUTPUT)
end
