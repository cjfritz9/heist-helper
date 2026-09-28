local extremes = require("core.extremes")
local assert = require("tests.assert")

local T = {}

local cube = function()
  local points = {}
  for x = 0, 1 do
    for y = 0, 1 do
      for z = 0, 1 do
        points[#points + 1] = { x * 100, y * 100, z * 100 }
      end
    end
  end
  points[#points + 1] = { 50, 50, 50 }
  points[#points + 1] = { 20, 80, 40 }
  return points
end

local contains = function(list, x, y, z)
  for _, p in ipairs(list) do
    if p[1] == x and p[2] == y and p[3] == z then
      return true
    end
  end
  return false
end

function T.twenty_six_directions()
  assert.eq(#extremes.DIRECTIONS, 26, "all but zero")
end

function T.cube_keeps_its_eight_corners_and_drops_interior_points()
  local chosen = extremes.select(cube())
  assert.eq(contains(chosen, 100, 100, 100), true, "top corner")
  assert.eq(contains(chosen, 0, 0, 0), true, "bottom corner")
  assert.eq(contains(chosen, 100, 0, 100), true, "side corner")
  assert.eq(contains(chosen, 50, 50, 50), false, "centre dropped")
  assert.eq(contains(chosen, 20, 80, 40), false, "interior dropped")
end

function T.no_duplicates()
  local chosen = extremes.select(cube())
  assert.eq(#chosen <= 26, true, "bounded")
  local seen = {}
  for _, p in ipairs(chosen) do
    local k = table.concat(p, ",")
    assert.eq(seen[k], nil, "duplicate " .. k)
    seen[k] = true
  end
end

return T
