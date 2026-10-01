local visionring = require("core.visionring")
local assert = require("tests.assert")

local T = {}

local count = function(set)
  local n = 0
  for _ in pairs(set) do n = n + 1 end
  return n
end

function T.mask_takes_tiles_whose_centre_is_within_half_a_tile_less_than_the_radius()
  local mask = visionring.mask(1.6)
  assert.eq(count(mask), 5, "a plus of 5 tiles at radius 1.6")
  assert.eq(mask["1,0"], true, "next to the centre")
  assert.eq(mask["1,1"], nil, "diagonal is too far")
  assert.eq(count(visionring.mask(2)), 9, "radius 2 takes the diagonals too")
  local ring = visionring.mask(visionring.RADIUS_TILES)
  assert.eq(count(ring), 49, "the measured ring: 49 tiles")
  assert.eq(ring["4,0"] and ring["0,-4"] and true, true, "one tile out from the middle of each flat side")
  assert.eq(ring["4,1"], nil, "but not either side of it")
end

function T.outline_is_only_the_edges_against_uncovered_tiles()
  assert.eq(#visionring.outline(visionring.mask(1)), 4, "one tile, four sides")
  local plus = visionring.mask(1.6)
  assert.eq(count(plus), 5, "a plus")
  assert.eq(#visionring.outline(plus), 12, "a plus has twelve outside edges")
end

function T.covers_is_relative_to_the_ring_tile()
  local mask = visionring.mask(1.6)
  assert.eq(visionring.covers(mask, 10, 20, 11, 20), true, "next to it")
  assert.eq(visionring.covers(mask, 10, 20, 11, 21), false, "diagonal at radius 1.6")
end

return T
