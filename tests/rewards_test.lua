local rewards = require("core.rewards")
local assert = require("tests.assert")

local T = {}

function T.bag_caps_at_500()
  assert.eq(rewards.capBag(535), 500, "over cap")
  assert.eq(rewards.capBag(-5), 0, "below zero")
end

function T.leaving_without_rare_chest_halves_points()
  assert.eq(rewards.finalPoints(300, false), 150, "halved")
  assert.eq(rewards.finalPoints(535, false), 250, "capped then halved")
  assert.eq(rewards.finalPoints(535, true), 500, "capped")
end

function T.xp_is_400_per_point_plus_instant()
  assert.eq(rewards.xp(270, 66440), 174440, "270 point run")
end

function T.remainder_is_chance_of_extra_roll()
  local rolls, chance = rewards.commonRolls(270)
  assert.eq(rolls, 10, "guaranteed rolls")
  assert.near(chance, 0.8, 1e-9, "extra roll chance")
end

function T.common_rolls_cap_at_20()
  local rolls, chance = rewards.commonRolls(500)
  assert.eq(rolls, 20, "rolls at cap")
  assert.eq(chance, 0, "no extra at cap")
end

function T.rare_rate_matches_anchors()
  assert.eq(rewards.rareRate(0), 0, "zero points")
  assert.near(1 / rewards.rareRate(100), 234, 1e-6, "100 points")
  assert.near(1 / rewards.rareRate(500), 36, 1e-6, "500 points")
end

function T.rare_rate_matches_wiki_157_point_example()
  assert.near(1 / rewards.rareRate(157), 172.5, 0.1, "157 points")
end

function T.specific_item_is_a_third_of_rare_rate()
  assert.near(1 / rewards.specificItemRate(300), 270, 1e-6, "300 points")
end

function T.luck_multiplies_rare_rate()
  assert.near(rewards.rareRate(500, 4), (1 / 36) * 1.03, 1e-12, "luck tier 4")
end

function T.rare_chest_overflow()
  assert.eq(rewards.rareChestOverflow(450), 0, "exactly fits")
  assert.eq(rewards.rareChestOverflow(480), 30, "30 wasted")
end

function T.project_summarises_a_run()
  local projection = rewards.project({ bagPoints = 270, openedRareChest = true, instantXp = 66440 })
  assert.eq(projection.points, 270, "points")
  assert.eq(projection.xp, 174440, "xp")
  assert.eq(projection.commonRolls, 10, "rolls")
  assert.eq(projection.pointsToCap, 230, "points to cap")
end

return T
