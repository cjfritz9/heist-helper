local ghostpaths = require("core.ghostpaths")

local M = {}

M.PERIOD = 600 * 1000
M.RECENT_TILES = 8
M.PICK_UP_TILES = 2
M.PICK_UP_HEIGHT = 300
M.QUICK_TILES = 2
M.AGREE_TICKS = 0.2
M.CHECK_TILES = 3
M.CHECK_SLACK = 0.3
M.LEAD_TICKS = 1
M.DRAWN_BEHIND_TICKS = 6

function M.new(loops)
  return { loops = loops, sync = {}, estimates = {}, ghostLoop = {}, recent = {}, shown = {}, off = {} }
end

function M.forget(state, id)
  state.ghostLoop[id], state.recent[id] = nil, nil
end

function M.ticksSince(from, at)
  return math.floor((at - from) / M.PERIOD + 0.5)
end

function M.predicted(state, li, at)
  local s = state.sync[li]
  if not s or not at then return nil end
  return ghostpaths.stepAt(state.loops[li], s.step, M.ticksSince(s.at, at))
end

local origin = function(loop, step, serverAt)
  return (serverAt / M.PERIOD - loop.time.firstTick[step]) % loop.time.length
end

local circularMean = function(values, L)
  local sx, sy = 0, 0
  for _, v in ipairs(values) do
    sx, sy = sx + math.cos(v / L * 2 * math.pi), sy + math.sin(v / L * 2 * math.pi)
  end
  return (math.atan2(sy, sx) / (2 * math.pi) * L) % L
end

local spread = function(values, centre, L)
  local worst = 0
  for _, v in ipairs(values) do
    worst = math.max(worst, math.abs((v - centre + L / 2) % L - L / 2))
  end
  return worst
end

local check = function(state, li, k, serverAt)
  local s, loop = state.sync[li], state.loops[li]
  local L = loop.time.length
  local expected = (loop.time.firstTick[k] - loop.time.firstTick[s.step]) % L
  local r = ((serverAt - s.at) / M.PERIOD - expected + L / 2) % L - L / 2
  local whole = math.floor(r + 0.5)
  local off = state.off[li]
  if whole == 0 or math.abs(r - whole) > M.CHECK_SLACK then
    state.off[li] = nil
    return nil
  end
  off = (off and off.ticks == whole) and { ticks = whole, count = off.count + 1 } or { ticks = whole, count = 1 }
  state.off[li] = off
  if off.count < M.CHECK_TILES then return nil end
  state.sync[li] = { step = s.step, at = s.at + whole * M.PERIOD, exact = s.exact }
  state.off[li], state.shown[li] = nil, nil
  local n = math.abs(whole)
  return string.format("walked %d tiles %d tick%s %s the sync on %s: moved it", M.CHECK_TILES, n, n == 1 and "" or "s",
    whole > 0 and "behind" or "ahead of", loop.name)
end

function M.observeTile(state, id, tile, centreAt, toTick)
  local recent = state.recent[id] or {}
  recent[#recent + 1] = { x = tile.x, z = tile.z, at = centreAt }
  if #recent > M.RECENT_TILES then table.remove(recent, 1) end
  state.recent[id] = recent
  local found = ghostpaths.locate(state.loops, recent)
  if not found then return nil end
  local li = found.loop
  local loop = state.loops[li]
  local first = state.ghostLoop[id] ~= li
  state.ghostLoop[id] = li
  local s = state.sync[li]
  local step = loop.steps[found.step]
  if s and centreAt and step.lag then
    local message = check(state, li, found.step, centreAt - step.lag * M.PERIOD)
    if message or s.exact then return message end
  end
  if not centreAt or not step.lag or (s and s.exact) then
    if first and s then return "on its synced route (" .. loop.name .. ")" end
    return nil
  end
  local list = state.estimates[li] or {}
  local n = #loop.steps
  for j = math.max(1, #recent - 1), #recent do
    local r = recent[j]
    local k = (found.step - 1 - (#recent - j)) % n + 1
    local st = loop.steps[k]
    if r.at and not r.used and st.lag and st.x == r.x and st.z == r.z then
      list[#list + 1] = origin(loop, k, r.at - st.lag * M.PERIOD)
      r.used = true
    end
  end
  while #list > 6 do table.remove(list, 1) end
  state.estimates[li] = list
  if #list < M.QUICK_TILES then return nil end
  local L = loop.time.length
  local centre = circularMean(list, L)
  if spread(list, centre, L) > M.AGREE_TICKS then
    state.estimates[li] = { list[#list] }
    return nil
  end
  local serverAt = (centre + loop.time.firstTick[found.step]) * M.PERIOD
  local at = (toTick and toTick(serverAt)) or serverAt
  local before = s and M.predicted(state, li, at)
  state.sync[li] = { step = found.step, at = at, exact = false }
  if not s then
    state.shown[li] = nil
    return string.format("synced to %s from %d tiles walked", loop.name, #list)
  end
  if before and (before.x ~= step.x or before.z ~= step.z) then
    state.shown[li] = nil
    return string.format("refined %s from %d tiles walked: had it on %d,%d, now %d,%d", loop.name, #list, before.x, before.z, step.x, step.z)
  end
  return nil
end

function M.observeStart(state, id, startBoundary)
  if not startBoundary then return nil end
  local found = ghostpaths.locate(state.loops, state.recent[id] or {})
  if not found then return nil end
  local li = found.loop
  local loop = state.loops[li]
  local nextStep = found.step % #loop.steps + 1
  local target = loop.steps[nextStep]
  state.ghostLoop[id] = li
  local s = state.sync[li]
  local p = s and M.predicted(state, li, startBoundary)
  local agreed = p and p.x == target.x and p.z == target.z
  if agreed then
    local wasExact = s.exact
    state.sync[li] = { step = s.step, at = s.at, exact = true }
    if wasExact then return nil end
    return string.format("checkpoint on %s: set-off agrees with the sync", loop.name)
  end
  local message = string.format("synced to %s at a set-off", loop.name)
  if s then
    message = string.format("checkpoint on %s: set-off far from the sync (%d,%d), tightened", loop.name, p.x, p.z)
    for d = 6, 1, -1 do
      for _, sign in ipairs({ -1, 1 }) do
        local q = M.predicted(state, li, startBoundary + sign * d * M.PERIOD)
        if q and q.x == target.x and q.z == target.z then
          message = string.format("checkpoint on %s: set-off was %d tick%s %s the sync, tightened", loop.name, d, d == 1 and "" or "s",
            sign > 0 and "before" or "after")
        end
      end
    end
  end
  state.sync[li] = { step = nextStep, at = startBoundary, exact = true }
  state.shown[li] = nil
  return message
end

function M.routeAhead(state, id)
  local found = ghostpaths.locate(state.loops, state.recent[id] or {})
  if not found then return nil end
  local loop = state.loops[found.loop]
  return loop.steps[found.step % #loop.steps + 1], loop.steps[found.step]
end

local aheadOfDrawn = function(state, li, ghostTile, at)
  local s, loop = state.sync[li], state.loops[li]
  local time = loop.time
  local L = time.length
  local server = math.floor((at - s.at) / M.PERIOD)
  local indexAt = function(k) return time.ticks[(time.firstTick[s.step] + k) % L + 1] end
  for k = server, server - M.DRAWN_BEHIND_TICKS, -1 do
    local j = indexAt(k)
    local step = loop.steps[j]
    if step.x == ghostTile.x and step.z == ghostTile.z then
      local last = k
      while indexAt(last + 1) == j and last - k <= L do last = last + 1 end
      return math.min(server, last + M.LEAD_TICKS)
    end
  end
  return server - M.LEAD_TICKS
end

function M.unseen(state, at, seen)
  local out = {}
  for li in pairs(state.sync) do
    if not seen[li] then
      local server = M.predicted(state, li, at)
      local behind = server and server.lag and math.max(0, server.lag - M.LEAD_TICKS) or 0
      local step = M.predicted(state, li, at - behind * M.PERIOD)
      if step then out[#out + 1] = { loop = li, step = step } end
    end
  end
  return out
end

function M.tileFor(state, id, ghostTile, ghostHeight, at, oneAhead)
  local li = state.ghostLoop[id]
  if not li or not state.sync[li] then
    li = nil
    for n in pairs(state.sync) do
      local p = M.predicted(state, n, at)
      if p and math.max(math.abs(p.x - ghostTile.x), math.abs(p.z - ghostTile.z)) <= M.PICK_UP_TILES
        and math.abs((p.h or ghostHeight) - ghostHeight) <= M.PICK_UP_HEIGHT then
        state.ghostLoop[id] = n
        li = n
        break
      end
    end
  end
  if not li or not at then return nil end
  local s = state.sync[li]
  local ticks = oneAhead and aheadOfDrawn(state, li, ghostTile, at) or M.ticksSince(s.at, at)
  local base = math.floor(s.at / M.PERIOD + 0.5)
  local absolute = base + ticks
  local last = state.shown[li]
  if last and absolute < last and absolute >= last - 2 then absolute = last end
  state.shown[li] = absolute
  ticks = absolute - base
  return ghostpaths.stepAt(state.loops[li], s.step, ticks), li
end

return M
