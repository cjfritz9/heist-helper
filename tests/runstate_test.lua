local runstate = require("core.runstate")
local assert = require("tests.assert")

local T = {}

local anchored = function()
  local state = runstate.new()
  runstate.setAnchor(state, { x = 6499, z = 4395 })
  return state
end

function T.new_anchor_starts_a_new_run()
  local state = anchored()
  state.lootedCorpses["8,4"] = true
  assert.eq(runstate.setAnchor(state, { x = 6499, z = 4395 }), false, "same anchor")
  assert.eq(runstate.isCorpseLooted(state, 8, 4), true, "kept")
  assert.eq(runstate.setAnchor(state, { x = 11875, z = 4203 }), true, "moved")
  assert.eq(runstate.isCorpseLooted(state, 8, 4), false, "cleared")
end

function T.marks_nearest_corpse_within_reach()
  local state = anchored()
  local corpses = {
    { tileX = 6507, tileZ = 4399 },
    { tileX = 6520, tileZ = 4399 },
  }
  assert.eq(runstate.markNearestCorpse(state, corpses, 6506, 4401), "8,4", "key")
  assert.eq(runstate.isCorpseLooted(state, 8, 4), true, "looted")
  assert.eq(runstate.isCorpseLooted(state, 21, 4), false, "other corpse untouched")
end

function T.ignores_corpses_out_of_reach()
  local state = anchored()
  assert.eq(runstate.markNearestCorpse(state, { { tileX = 6507, tileZ = 4399 } }, 6515, 4399), nil, "too far")
end

function T.chat_events()
  assert.eq(runstate.chatEvent("You'vetakeneverythingyoucanfromthattarget."), "corpseLooted", "corpse")
  assert.eq(runstate.chatEvent("CompletionTime:19:25.2"), "runComplete", "run end")
  assert.eq(runstate.chatEvent("Youlootangoldaureuscoin."), "loot", "loot")
  assert.eq(runstate.chatEvent("Looted."), nil, "already looted chest")
  assert.eq(runstate.chatEvent("Youcrackopenthesafe!"), nil, "other")
end

function T.encode_decode_round_trip()
  local state = anchored()
  state.lootedCorpses["8,4"] = true
  state.lootedCorpses["-3,-20"] = true
  local decoded = runstate.decode(runstate.encode(state))
  assert.eq(decoded.anchor.x, 6499, "anchor x")
  assert.eq(decoded.anchor.z, 4395, "anchor z")
  assert.eq(runstate.isCorpseLooted(decoded, -3, -20), true, "negative offsets")
end

function T.decode_of_nothing_is_empty()
  local state = runstate.decode(nil)
  assert.eq(state.anchor, nil, "no anchor")
end

local CORPSE = { kind = "corpse", tileX = 6507, tileZ = 4399 }

function T.five_loots_at_a_corpse_finish_it()
  local state = anchored()
  for i = 1, 4 do
    local k, count = runstate.recordLoot(state, { CORPSE }, 6506, 4401)
    assert.eq(k, "8,4", "key")
    assert.eq(count, i, "count")
  end
  assert.eq(runstate.isCorpseLooted(state, 8, 4), false, "four is not enough")
  runstate.recordLoot(state, { CORPSE }, 6506, 4401)
  assert.eq(runstate.isCorpseLooted(state, 8, 4), true, "five finishes it")
  assert.eq(runstate.rummageCount(state, 8, 4), 5, "count")
end

function T.loot_at_a_nearer_chest_is_not_counted()
  local state = anchored()
  local chest = { kind = "chest", looted = true, tileX = 6505, tileZ = 4401 }
  assert.eq(runstate.recordLoot(state, { CORPSE, chest }, 6505, 4400), nil, "chest nearer")
  assert.eq(runstate.rummageCount(state, 8, 4), 0, "untouched")
end

function T.equally_near_objects_are_not_guessed()
  local state = anchored()
  local chest = { kind = "chest", looted = false, tileX = 6505, tileZ = 4399 }
  assert.eq(runstate.recordLoot(state, { CORPSE, chest }, 6506, 4399), nil, "tie")
end

function T.loot_far_from_anything_is_ignored()
  local state = anchored()
  assert.eq(runstate.recordLoot(state, { CORPSE }, 6520, 4399), nil, "out of reach")
end

function T.finished_corpse_does_not_absorb_more_loot()
  local state = anchored()
  state.lootedCorpses["8,4"] = true
  local chest = { kind = "chest", looted = false, tileX = 6509, tileZ = 4399 }
  assert.eq(runstate.recordLoot(state, { CORPSE, chest }, 6507, 4399), nil, "chest wins")
end

function T.rummage_counts_survive_a_restart_and_reset_with_the_run()
  local state = anchored()
  runstate.recordLoot(state, { CORPSE }, 6507, 4399)
  runstate.recordLoot(state, { CORPSE }, 6507, 4399)
  local decoded = runstate.decode(runstate.encode(state))
  assert.eq(runstate.rummageCount(decoded, 8, 4), 2, "restored")
  runstate.resetRun(decoded)
  assert.eq(runstate.rummageCount(decoded, 8, 4), 0, "reset")
end

function T.looted_objects_and_powered_anchors_persist()
  local state = anchored()
  assert.eq(runstate.markObjectLooted(state, "chest", 11, -4), true, "new")
  assert.eq(runstate.markObjectLooted(state, "chest", 11, -4), false, "already")
  assert.eq(runstate.toggleAnchor(state, -8, -63), true, "powered")
  local decoded = runstate.decode(runstate.encode(state))
  assert.eq(runstate.isObjectLooted(decoded, "chest", 11, -4), true, "chest restored")
  assert.eq(runstate.isAnchorPowered(decoded, -8, -63), true, "anchor restored")
  assert.eq(runstate.toggleAnchor(decoded, -8, -63), false, "toggled off")
  runstate.resetRun(state)
  assert.eq(runstate.isObjectLooted(state, "chest", 11, -4), false, "reset")
end

function T.set_anchor_powered_only_once()
  local state = anchored()
  assert.eq(runstate.setAnchorPowered(state, -8, -63), true, "first")
  assert.eq(runstate.setAnchorPowered(state, -8, -63), false, "already")
  assert.eq(runstate.isAnchorPowered(state, -8, -63), true, "powered")
end

return T
