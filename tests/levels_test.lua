local levels = require("core.levels")
local assert = require("tests.assert")

local T = {}

function T.both_on_by_default()
  local l = levels.decode(nil)
  assert.eq(l.thieving, true, "thieving")
  assert.eq(l.agility, true, "agility")
end

function T.round_trip()
  local l = levels.new()
  assert.eq(levels.toggle(l, "agility"), true, "toggled")
  assert.eq(levels.toggle(l, "mining"), false, "unknown name")
  local restored = levels.decode(levels.encode(l))
  assert.eq(restored.thieving, true, "thieving kept")
  assert.eq(restored.agility, false, "agility off")
end

function T.what_each_level_gates()
  local l = levels.new()
  assert.eq(levels.canLoot(l, "safe", true), true, "both met")
  l.thieving = false
  assert.eq(levels.canLoot(l, "safe", false), false, "safe needs thieving")
  assert.eq(levels.canLoot(l, "chest", false), true, "chest does not")
  l.agility = false
  assert.eq(levels.canLoot(l, "chest", true), false, "crevice needs agility")
  assert.eq(levels.canLoot(l, "corpse", false), true, "open corpse")
end

return T
