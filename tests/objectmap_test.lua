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

function T.heights_fill_in_once()
  local map = objectmap.new({ { kind = "chest", dx = 11, dz = -4 } })
  assert.eq(objectmap.add(map, "chest", 11, -4, 4932.6), true, "height learned")
  assert.eq(map.list[1].y, 4933, "rounded")
  assert.eq(objectmap.add(map, "chest", 11, -4, 5000), false, "kept")
  local restored = objectmap.merge(objectmap.new(), objectmap.encode(map))
  assert.eq(restored.list[1].y, 4933, "height round trip")
end

function T.old_rows_without_height_still_load()
  local map = objectmap.merge(objectmap.new(), "safe,-2,-22\n")
  assert.eq(map.list[1].kind, "safe", "kind")
  assert.eq(map.list[1].y, nil, "no height")
end

function T.crevices_seeded_toggled_and_saved()
  local map = objectmap.new({ { kind = "chest", dx = -5, dz = -16, crevice = true } })
  assert.eq(objectmap.behindCrevice(map, -5, -16), true, "seeded")
  assert.eq(objectmap.toggleCrevice(map, 8, -63), true, "marked")
  assert.eq(objectmap.toggleCrevice(map, -5, -16), false, "unmarked")
  local saved = objectmap.encodeCrevices(map)
  local restored = objectmap.loadCrevices(objectmap.new({ { kind = "chest", dx = -5, dz = -16, crevice = true } }), saved)
  assert.eq(objectmap.behindCrevice(restored, 8, -63), true, "saved mark")
  assert.eq(objectmap.behindCrevice(restored, -5, -16), false, "saved file replaces the seed")
  assert.eq(objectmap.behindCrevice(objectmap.loadCrevices(map, nil), 8, -63), true, "no file keeps the seed")
end

function T.sections_are_set_once_and_saved()
  local map = objectmap.new({ { kind = "safe", dx = -2, dz = -22, section = 2 }, { kind = "chest", dx = 11, dz = -4 } })
  assert.eq(objectmap.setSection(map, "safe", -2, -22, 3), false, "seeded section kept")
  assert.eq(objectmap.setSection(map, "chest", 11, -4, 1), true, "learned")
  assert.eq(objectmap.setSection(map, "chest", 99, 99, 1), false, "unknown object")
  objectmap.add(map, "chest", 11, -4, 4928)
  local restored = objectmap.merge(objectmap.new(), objectmap.encode(map))
  assert.eq(restored.list[1].section, 2, "section without height")
  assert.eq(restored.list[1].y, nil, "no height")
  assert.eq(restored.list[2].section, 1, "section with height")
  assert.eq(restored.list[2].y, 4928, "height kept")
end

return T
