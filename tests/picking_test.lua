local picking = require("core.picking")
local assert = require("tests.assert")

local T = {}

local boxOf = function(points)
  local box = picking.newBox()
  for _, p in ipairs(points) do
    picking.extend(box, p[1], p[2])
  end
  return box
end

function T.box_contains_points_inside_only()
  local box = boxOf({ { 10, 20 }, { 50, 80 } })
  assert.eq(picking.contains(box, 30, 40), true, "inside")
  assert.eq(picking.contains(box, 50, 80), true, "edge")
  assert.eq(picking.contains(box, 51, 40), false, "outside")
end

function T.empty_box_contains_nothing()
  local box = picking.newBox()
  assert.eq(picking.contains(box, 0, 0), false, "empty")
  assert.eq(picking.area(box), math.huge, "empty area")
end

function T.stride_caps_samples()
  assert.eq(picking.stride(100, 256), 1, "small model")
  assert.eq(picking.stride(1000, 256), 4, "large model")
end

function T.fingerprint_is_stable_and_shape_sensitive()
  local a = picking.fingerprint({ { 1, 2, 3 }, { 4, 5, 6 } })
  assert.eq(a, picking.fingerprint({ { 1, 2, 3 }, { 4, 5, 6 } }), "stable")
  assert.eq(a == picking.fingerprint({ { 1, 2, 3 }, { 4, 5, 7 } }), false, "differs")
  assert.eq(#a, 8, "8 hex chars")
end

function T.rank_puts_smallest_box_first()
  local ranked = picking.rank({
    { box = boxOf({ { 0, 0 }, { 500, 500 } }) },
    { box = boxOf({ { 10, 10 }, { 40, 60 } }) },
  })
  assert.eq(picking.area(ranked[1].box), 1500, "smallest first")
end

function T.last_tag_reads_highest_tag_number()
  assert.eq(picking.lastTag(picking.HEADER), 0, "empty log")
  assert.eq(picking.lastTag(picking.HEADER .. "1,1,x\n1,2,x\n2,1,x\n"), 2, "two tags")
end

function T.rows_are_relative_to_anchor_and_limited()
  local candidate = {
    vertices = 120, texture = 7, animated = false,
    tileX = 11310, tileZ = 3240, originY = 4933.4,
    box = boxOf({ { 100, 200 }, { 140, 260 } }),
    fingerprint = "0000abcd",
  }
  local text = picking.rows(3, { candidate, candidate }, 11299, 3243, 120, 230, 1)
  assert.eq(text, "3,1,120,7,0,11310,3240,11,-3,4933,40,60,0000abcd,120,230\n", "row")
end

return T
