local checkpoints = require("core.checkpoints")
local assert = require("tests.assert")

local T = {}

local SEED = {
  markers = { { name = "legionary1", dx = 10, dz = -8, y = 4933 } },
  dials = { { dx = -3, dz = -33, section = 3 }, { dx = -28, dz = -6, section = 2 } },
}

function T.markers_set_the_section_nearby_on_their_floor()
  local set = checkpoints.new(SEED)
  checkpoints.put(set, "legionary2", 10, -12, 2949)
  assert.eq(checkpoints.at(set, 11, -9, 4930), 1, "section 1 side")
  assert.eq(checkpoints.at(set, 10, -13, 2950), 2, "section 2 side")
  assert.eq(checkpoints.at(set, 10, -8, 261), nil, "same spot, other floor")
  assert.eq(checkpoints.at(set, 30, -30, 4933), nil, "far away")
end

function T.nearest_marker_wins()
  local set = checkpoints.new()
  checkpoints.put(set, "praetorian3", 0, 0, 2179)
  checkpoints.put(set, "praetorian4", 0, -3, 2179)
  assert.eq(checkpoints.at(set, 0, -1, 2179), 3, "closer to section 3 side")
  assert.eq(checkpoints.at(set, 0, -2, 2179), 4, "closer to section 4 side")
end

function T.dials_go_both_ways()
  local set = checkpoints.new(SEED)
  assert.eq(checkpoints.afterDial(set, -3, -33), 3, "forward")
  assert.eq(checkpoints.afterDial(set, -28, -6), 2, "back")
  assert.eq(checkpoints.afterDial(set, 0, 0), nil, "not a dial")
end

function T.round_trip_and_completeness()
  local set = checkpoints.new(SEED)
  assert.eq(checkpoints.complete(set), false, "one of four")
  assert.eq(checkpoints.put(set, "nonsense", 0, 0, 0), false, "unknown side")
  checkpoints.put(set, "legionary2", 10, -12, 2949.4)
  checkpoints.put(set, "praetorian3", 0, -50, 2179)
  checkpoints.put(set, "praetorian4", 0, -53, 2179)
  assert.eq(checkpoints.complete(set), true, "all four")
  local restored = checkpoints.merge(checkpoints.new(), checkpoints.encode(set))
  assert.eq(checkpoints.complete(restored), true, "restored")
  assert.eq(restored.markers.legionary2.y, 2949, "rounded height")
  local listed = checkpoints.list(restored)
  assert.eq(#listed, 4, "listed")
  assert.eq(listed[2].section, 2, "in order")
end

return T
