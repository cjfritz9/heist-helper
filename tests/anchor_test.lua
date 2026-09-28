local anchor = require("core.anchor")
local objectmap = require("core.objectmap")
local assert = require("tests.assert")

local T = {}

local OBJECTS = objectmap.new(require("data.objects")).list

function T.arrival_after_teleport_sets_anchor()
  local a = anchor.fromArrival(3367, 3189, 11875, 4203, 4933)
  assert.eq(a.x, 11875, "x")
  assert.eq(a.z, 4203, "z")
end

function T.arrival_on_first_frame_sets_anchor()
  assert.eq(anchor.fromArrival(nil, nil, 11299, 3243, 4930).x, 11299, "no previous tile")
end

function T.walking_back_over_arrival_tile_is_ignored()
  assert.eq(anchor.fromArrival(11300, 3243, 11299, 3243, 4933), nil, "walked")
end

function T.arrival_needs_grid_and_height()
  assert.eq(anchor.fromArrival(nil, nil, 11300, 3243, 4933), nil, "off grid")
  assert.eq(anchor.fromArrival(nil, nil, 11299, 3243, 2181), nil, "wrong height")
end

function T.corpse_in_second_instance_finds_its_anchor()
  local a = anchor.fromObject("corpse", 11883, 4207, OBJECTS)
  assert.eq(a.x, 11875, "x")
  assert.eq(a.z, 4203, "z")
end

function T.corpse_in_third_instance_finds_its_anchor()
  local a = anchor.fromObject("corpse", 6507, 4399, OBJECTS)
  assert.eq(a.x, 6499, "x")
  assert.eq(a.z, 4395, "z")
end

function T.each_mapped_chest_resolves_to_one_anchor()
  local a = anchor.fromObject("chest", 11299 + 15 + 640, 3243 - 73 - 64, OBJECTS)
  assert.eq(a.x, 11299 + 640, "x")
  assert.eq(a.z, 3243 - 64, "z")
end

function T.shadow_anchor_finds_its_anchor()
  local a = anchor.fromObject("shadowAnchor", 6491, 4332, OBJECTS)
  assert.eq(a.x, 6499, "x")
  assert.eq(a.z, 4395, "z")
end

function T.object_map_covers_all_thirty_loot_sources()
  local counts = {}
  for _, o in ipairs(OBJECTS) do
    counts[o.kind] = (counts[o.kind] or 0) + 1
  end
  assert.eq(counts.chest, 13, "chests and shadow chests")
  assert.eq(counts.safe, 8, "safes")
  assert.eq(counts.rareChest, 1, "rare chest")
  assert.eq(counts.corpse, 8, "corpses")
end

function T.every_mapped_object_resolves_to_a_unique_anchor()
  for _, o in ipairs(OBJECTS) do
    local a = anchor.fromObject(o.kind, 6499 + o.dx, 4395 + o.dz, OBJECTS)
    assert.eq(a and a.x, 6499, o.kind .. " " .. o.dx .. "," .. o.dz)
  end
end

function T.unmapped_object_gives_no_anchor()
  assert.eq(anchor.fromObject("chest", 11300, 3200, OBJECTS), nil, "unmapped")
  assert.eq(anchor.fromObject("corpse", 11300, 3200, {}), nil, "empty map")
end

function T.in_vault_uses_bounds_around_anchor()
  local a = { x = 6499, z = 4395 }
  assert.eq(anchor.inVault(a, 6499 + 18, 4395 - 88), true, "rare chest")
  assert.eq(anchor.inVault(a, 6499 + 200, 4395), false, "outside")
  assert.eq(anchor.inVault(nil, 0, 0), false, "no anchor")
end

return T
