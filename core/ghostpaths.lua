local M = {}

M.MATCH_TILES = 4
M.MIN_MATCH_TILES = 2

function M.timeline(loop)
  local ticks, firstTick = {}, {}
  for i, step in ipairs(loop.steps) do
    firstTick[i] = #ticks
    for _ = 0, step.stall or 0 do ticks[#ticks + 1] = i end
  end
  return { ticks = ticks, firstTick = firstTick, length = #ticks }
end

function M.prepare(data)
  local loops = {}
  for n, loop in ipairs(data.loops) do
    loops[n] = { name = loop.name, steps = loop.steps, time = M.timeline(loop) }
  end
  return loops
end

local same = function(step, tile)
  return step.x == tile.x and step.z == tile.z
end

local match = function(loops, recent, count)
  local found = nil
  for li, loop in ipairs(loops) do
    local steps, n = loop.steps, #loop.steps
    for start = 1, n do
      local ok = true
      for k = 1, count do
        if not same(steps[(start + k - 2) % n + 1], recent[#recent - count + k]) then ok = false break end
      end
      if ok then
        if found then return nil, "ambiguous" end
        found = { loop = li, step = (start + count - 2) % n + 1 }
      end
    end
  end
  return found
end

function M.locate(loops, recent)
  for count = math.min(#recent, M.MATCH_TILES), M.MIN_MATCH_TILES, -1 do
    local found = match(loops, recent, count)
    if found then return found end
  end
  return nil
end

function M.stepAt(loop, arrivalStep, ticksSinceArrival)
  local time = loop.time
  local tick = (time.firstTick[arrivalStep] + ticksSinceArrival) % time.length
  return loop.steps[time.ticks[tick + 1]]
end

return M
