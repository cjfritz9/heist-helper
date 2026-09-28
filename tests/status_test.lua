local status = require("core.status")
local runstate = require("core.runstate")
local assert = require("tests.assert")

local T = {}

local OBJECTS = {
  { kind = "chest", dx = 11, dz = -4 },
  { kind = "chest", dx = -22, dz = -11 },
  { kind = "safe", dx = -2, dz = -22 },
  { kind = "corpse", dx = 8, dz = 4 },
  { kind = "corpse", dx = -32, dz = -30 },
  { kind = "shadowAnchor", dx = -8, dz = -63 },
  { kind = "shadowDial", dx = -3, dz = -33 },
}

local anchored = function()
  local run = runstate.new()
  runstate.setAnchor(run, { x = 6499, z = 4395 })
  return run
end

function T.sections_from_height()
  assert.eq(status.section(4933), 1, "start")
  assert.eq(status.section(2949), 2, "section 2")
  assert.eq(status.section(261), 3, "section 3")
  assert.eq(status.section(2176), 4, "section 4")
  assert.eq(status.section(9000), nil, "unknown")
end

function T.counts_what_is_left()
  local run = anchored()
  runstate.markObjectLooted(run, "chest", 11, -4)
  run.lootedCorpses["8,4"] = true
  run.rummages["-32,-30"] = 3
  runstate.toggleAnchor(run, -8, -63)
  local s = status.build(run, OBJECTS, 261)
  assert.eq(s.anchored, true, "anchored")
  assert.eq(s.section, 3, "section")
  assert.eq(s.remaining.chest, 1, "chests")
  assert.eq(s.remaining.safe, 1, "safes")
  assert.eq(s.remaining.corpse, 1, "corpses")
  assert.eq(s.corpses[1].done, 3, "corpse in progress")
  assert.eq(s.anchors.powered, 1, "anchors powered")
  assert.eq(s.anchors.total, 1, "anchors total")
end

function T.nothing_counted_without_an_anchor()
  local s = status.build(runstate.new(), OBJECTS, nil)
  assert.eq(s.anchored, false, "not anchored")
  assert.eq(s.remaining.chest, 0, "no counts")
  assert.eq(s.section, nil, "no section")
end

return T
