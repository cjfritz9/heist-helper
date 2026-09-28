local hull = require("core.hull")
local assert = require("tests.assert")

local T = {}

function T.square_with_interior_point()
  local result = hull.convex({ { 0, 0 }, { 10, 0 }, { 10, 10 }, { 0, 10 }, { 5, 5 } })
  assert.eq(#result, 4, "corners only")
end

function T.collinear_points_are_dropped()
  local result = hull.convex({ { 0, 0 }, { 5, 0 }, { 10, 0 }, { 10, 10 }, { 0, 10 } })
  assert.eq(#result, 4, "no midpoint")
end

function T.too_few_points_give_nothing()
  assert.eq(#hull.convex({ { 0, 0 }, { 1, 1 } }), 0, "two points")
end

return T
