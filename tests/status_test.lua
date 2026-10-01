local status = require("core.status")
local runstate = require("core.runstate")
local objectmap = require("core.objectmap")
local levels = require("core.levels")
local assert = require("tests.assert")

local T = {}

local OBJECTS = {
  { kind = "chest", dx = 11, dz = -4, section = 1 },
  { kind = "chest", dx = -22, dz = -11, section = 1 },
  { kind = "safe", dx = -2, dz = -22, section = 2 },
  { kind = "chest", dx = -5, dz = -16, section = 2, crevice = true },
  { kind = "corpse", dx = 8, dz = 4, section = 1 },
  { kind = "corpse", dx = -32, dz = -30, section = 3 },
  { kind = "shadowAnchor", dx = -8, dz = -63, section = 4 },
  { kind = "shadowDial", dx = -3, dz = -33 },
  { kind = "rareChest", dx = 18, dz = -88 },
}

local anchored = function()
  local run = runstate.new()
  runstate.setAnchor(run, { x = 6499, z = 4395 })
  return run
end

function T.counts_what_is_left_in_the_vault_and_the_section()
  local run = anchored()
  runstate.markObjectLooted(run, "chest", 11, -4)
  run.lootedCorpses["8,4"] = true
  run.rummages["-32,-30"] = 3
  local s = status.build(run, objectmap.new(OBJECTS), 1, levels.new())
  assert.eq(s.anchored, true, "anchored")
  assert.eq(s.section, 1, "section")
  assert.eq(s.total.chest, 2, "chests")
  assert.eq(s.total.safe, 1, "safes")
  assert.eq(s.total.corpse, 1, "corpses")
  assert.eq(s.total.rareChest, 1, "rare chest without a section")
  assert.eq(s.current.chest, 1, "section 1 chest")
  assert.eq(s.current.corpse, 0, "section 1 corpse looted")
  assert.eq(s.current.rareChest, 0, "no section, not counted in one")
end

function T.levels_remove_what_you_cannot_loot()
  local low = levels.new()
  levels.toggle(low, "thieving")
  levels.toggle(low, "agility")
  local s = status.build(anchored(), objectmap.new(OBJECTS), 2, low)
  assert.eq(s.total.safe, 0, "no safes")
  assert.eq(s.total.chest, 2, "crevice chest removed")
  assert.eq(s.current.chest, 0, "section 2 crevice chest removed")
  assert.eq(s.current.safe, 0, "section 2 safe removed")
end

function T.no_section_yet()
  local s = status.build(anchored(), objectmap.new(OBJECTS), nil, levels.new())
  assert.eq(s.current, nil, "no section counts")
  assert.eq(s.total.chest, 3, "vault counts")
end

function T.nothing_counted_without_an_anchor()
  local s = status.build(runstate.new(), objectmap.new(OBJECTS), 2, levels.new())
  assert.eq(s.anchored, false, "not anchored")
  assert.eq(s.total.chest, 0, "no counts")
  assert.eq(s.current, nil, "no section counts")
end

function T.mapping_progress()
  local m = status.mapping(objectmap.new(OBJECTS))
  assert.eq(m.withSection, 6, "loot with a section")
  assert.eq(m.loot, 7, "loot objects")
  assert.eq(#m.crevices, 1, "crevice objects")
  assert.eq(m.crevices[1].dz, -16, "crevice object")
end

function T.potential_and_gained_per_section()
  local run = anchored()
  local objects = {
    { kind = "chest", dx = 1, dz = 1, section = 2, shadow = true },
    { kind = "safe", dx = 2, dz = 2, section = 2 },
    { kind = "corpse", dx = 3, dz = 3, section = 2 },
    { kind = "chest", dx = 4, dz = 4, section = 2, crevice = true },
    { kind = "rareChest", dx = 5, dz = 5, section = 4 },
  }
  runstate.addLoot(run, 25, 2)
  local s = status.build(run, objectmap.new(objects), 2, levels.new())
  assert.eq(s.splits[2].potential, 15 + 30 + 10 + 10, "shadow chest, safe, corpse, crevice chest")
  assert.eq(s.splits[2].gained, 25, "gained")
  assert.eq(s.splits[4].potential, 50, "rare chest")
  assert.eq(s.splits[1].potential, 0, "nothing in section 1")
  local low = levels.new()
  levels.toggle(low, "thieving")
  levels.toggle(low, "agility")
  assert.eq(status.build(run, objectmap.new(objects), 2, low).splits[2].potential, 25, "no safe, no crevice")
end

function T.remaining_lists_what_is_left_to_loot()
  local map = objectmap.new()
  objectmap.add(map, "chest", 1, 1, 256)
  objectmap.add(map, "safe", 2, 2, 256)
  objectmap.add(map, "shadowAnchor", 3, 3, 256)
  local run = runstate.new()
  run.anchor = { x = 100, z = 100 }
  runstate.markObjectLooted(run, "chest", 1, 1)
  local left = status.remaining(run, map, levels.new())
  assert.eq(#left, 1, "only the safe")
  assert.eq(left[1].kind, "safe", "the safe")
end

return T
