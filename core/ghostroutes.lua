local M = {}

M.TICK_MICROSECONDS = 600 * 1000
M.MERGE_TICKS = 0.5
M.FLOOR_TOLERANCE = 100
M.STALL_SLACK_TICKS = 1 / 6

function M.new()
  return { counts = {}, order = {}, ghosts = {}, floors = {}, legacy = {} }
end

function M.ticks(duration)
  return math.floor(duration / M.TICK_MICROSECONDS + 0.5)
end

function M.stallTicks(duration)
  return math.floor(duration / M.TICK_MICROSECONDS + M.STALL_SLACK_TICKS)
end

function M.floorOf(map, y)
  local best, bestGap = nil, M.FLOOR_TOLERANCE
  for _, floor in ipairs(map.floors) do
    local gap = math.abs(floor - y)
    if gap <= bestGap then best, bestGap = floor, gap end
  end
  if best then return best end
  best = math.floor(y + 0.5)
  map.floors[#map.floors + 1] = best
  return best
end

local note = function(map, key)
  if not map.counts[key] then
    map.counts[key] = 0
    map.order[#map.order + 1] = key
  end
  map.counts[key] = map.counts[key] + 1
  return true
end

local fields = function(line)
  local out = {}
  for f in line:gmatch("[^,]+") do out[#out + 1] = f end
  return out
end

function M.decode(text)
  local map = M.new()
  for line in (text or ""):gmatch("[^\n]+") do
    local f = fields(line)
    local current = (f[1] == "move" and #f == 9) or (f[1] == "stop" and #f == 6)
    if current then
      local key = line:match("^(.*),%d+$")
      map.counts[key] = tonumber(f[#f])
      map.order[#map.order + 1] = key
      M.floorOf(map, tonumber(f[2]))
      if f[1] == "move" then M.floorOf(map, tonumber(f[5])) end
    elseif f[1] == "move" or f[1] == "stop" then
      map.legacy[#map.legacy + 1] = line
    end
  end
  return map
end

function M.encode(map)
  local out = {}
  for _, key in ipairs(map.order) do out[#out + 1] = key .. "," .. map.counts[key] end
  return table.concat(out, "\n") .. "\n"
end

function M.observe(map, e)
  local g = map.ghosts[e.id]
  if e.kind == "appear" then
    map.ghosts[e.id] = { tileX = e.tileX, tileZ = e.tileZ, floor = M.floorOf(map, e.y), at = nil, stopSeen = false }
    return false
  end
  if not g then return false end
  if e.kind == "lost" then
    map.ghosts[e.id] = nil
    return false
  end
  if e.kind == "stop" then
    g.stopSeen, g.at = true, nil
    return false
  end
  if e.kind == "start" then
    local changed = false
    local ticks = M.stallTicks(e.still)
    if g.stopSeen and ticks > 0 then
      changed = note(map, string.format("stop,%d,%d,%d,%d", g.floor, g.tileX, g.tileZ, ticks))
    end
    g.at, g.fromStart = e.at, true
    return changed
  end
  if e.kind == "tile" then
    local floor = M.floorOf(map, e.y)
    if e.tileX == g.tileX and e.tileZ == g.tileZ and floor == g.floor then return false end
    if g.at and not g.fromStart and e.at - g.at < M.MERGE_TICKS * M.TICK_MICROSECONDS then return false end
    local ticks = (g.at and not g.fromStart) and tostring(M.ticks(e.at - g.at)) or "-"
    local changed = note(map, string.format("move,%d,%d,%d,%d,%d,%d,%s",
      g.floor, g.tileX, g.tileZ, floor, e.tileX, e.tileZ, ticks))
    g.tileX, g.tileZ, g.floor, g.at, g.fromStart = e.tileX, e.tileZ, floor, e.at, false
    return changed
  end
  return false
end

return M
