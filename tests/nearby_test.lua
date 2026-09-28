local nearby = require("core.nearby")
local assert = require("tests.assert")

local T = {}

local OBJECTS = {
  { kind = "shadowDial", tileX = 100, tileZ = 100 },
  { kind = "shadowDial", tileX = 103, tileZ = 100 },
  { kind = "chest", tileX = 101, tileZ = 100 },
}

function T.nearest_of_a_kind_within_reach()
  assert.eq(nearby.nearest(OBJECTS, "shadowDial", 102, 100, 3).tileX, 103, "closest dial")
  assert.eq(nearby.nearest(OBJECTS, "shadowDial", 110, 100, 3), nil, "out of reach")
  assert.eq(nearby.nearest(OBJECTS, "safe", 100, 100, 3), nil, "no safes")
end

function T.teleport_is_a_long_single_step()
  assert.eq(nearby.teleported(100, 100, 101, 101), false, "walking")
  assert.eq(nearby.teleported(100, 100, 125, 127), true, "teleport")
  assert.eq(nearby.teleported(nil, nil, 125, 127), false, "first frame")
end

return T
