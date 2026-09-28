local catalog = require("core.catalog")
local assert = require("tests.assert")

local T = {}

function T.only_known_vertex_counts_are_candidates()
  assert.eq(catalog.isCandidate(3444), true, "chest")
  assert.eq(catalog.isCandidate(21132), false, "player model")
end

function T.chest_states_come_from_the_model()
  local kind, looted = catalog.classify(3444, "9f69f595", false)
  assert.eq(kind, "chest", "kind")
  assert.eq(looted, false, "unopened")
  kind, looted = catalog.classify(3264, "8eaac06a", false)
  assert.eq(looted, true, "opened")
end

function T.safe_is_looted_once_it_stops_animating()
  assert.eq(select(2, catalog.classify(3456, "d77d3421", true)), false, "closed")
  assert.eq(select(2, catalog.classify(3456, "d77d3421", false)), true, "cracked")
end

function T.rare_chest_states()
  assert.eq(select(2, catalog.classify(3411, "6ea760dd", false)), false, "closed")
  assert.eq(select(2, catalog.classify(3231, "fca0baf0", false)), true, "opened")
end

function T.corpse_state_is_unknown_from_the_model()
  local kind, looted = catalog.classify(26187, "b940405f", false)
  assert.eq(kind, "corpse", "kind")
  assert.eq(looted, nil, "needs chat")
end

function T.second_corpse_pose_is_recognised()
  assert.eq(catalog.classify(15108, "0928e6ef", false), "corpse", "section 3 corpse")
end

function T.third_corpse_pose_is_recognised()
  assert.eq(catalog.classify(21867, "a99b1b05", false), "corpse", "section 4 corpse")
end

function T.fourth_corpse_pose_is_recognised()
  assert.eq(catalog.classify(25818, "ac0eb5ba", false), "corpse", "section 2 corpse")
end

function T.shadow_anchor_is_recognised_without_a_state()
  local kind, looted = catalog.classify(4506, "17aa0a87", false)
  assert.eq(kind, "shadowAnchor", "kind")
  assert.eq(looted, nil, "powered state unknown")
end

function T.matching_vertex_count_with_other_fingerprint_is_rejected()
  assert.eq(catalog.classify(3444, "00000000", false), nil, "wrong model")
end

return T
