local objectmap = require("core.objectmap")
local assert = require("tests.assert")

local T = {}

function T.seed_and_add_without_duplicates()
  local map = objectmap.new({ { kind = "chest", dx = 11, dz = -4 } })
  assert.eq(objectmap.add(map, "chest", 11, -4), false, "duplicate")
  assert.eq(objectmap.add(map, "safe", -2, -22), true, "new")
  assert.eq(#map.list, 2, "count")
end

function T.encode_merge_round_trip()
  local map = objectmap.new({ { kind = "corpse", dx = 8, dz = 4 } })
  objectmap.add(map, "rareChest", 18, -88)
  local restored = objectmap.merge(objectmap.new(), objectmap.encode(map))
  assert.eq(#restored.list, 2, "count")
  assert.eq(restored.list[2].kind, "rareChest", "kind")
  assert.eq(restored.list[2].dz, -88, "negative offset")
end

return T
