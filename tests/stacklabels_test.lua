local stacklabels = require("core.stacklabels")
local assert = require("tests.assert")

local T = {}

local SECOND = 1000 * 1000
local BATTERY = { signature = "1:120:aaaa", x = 100, y = 200, w = 32, h = 32 }
local COINS = { signature = "1:80:bbbb", x = 140, y = 200, w = 32, h = 32 }

local digit = function(x, y, id)
  return { x = x, y = y, id = id }
end

function T.label_reads_glyphs_over_the_icon_left_to_right()
  local glyphs = { digit(106, 204, "d2"), digit(101, 204, "d1"), digit(300, 300, "far"), digit(104, 226, "low") }
  assert.eq(stacklabels.label(BATTERY, glyphs), "d1 d2", "top digits in order; far and lower-half glyphs ignored")
  assert.eq(stacklabels.label(COINS, glyphs), "", "no glyphs over coins")
end

function T.changes_only_for_icons_seen_before()
  local known = {}
  local first = stacklabels.update(known, stacklabels.frame({ BATTERY }, { digit(101, 204, "d3") }))
  assert.eq(#first, 0, "first sight is not a change")
  local same = stacklabels.update(known, stacklabels.frame({ BATTERY }, { digit(101, 204, "d3") }))
  assert.eq(#same, 0, "unchanged")
  local closed = stacklabels.update(known, stacklabels.frame({}, {}))
  assert.eq(#closed, 0, "inventory hidden")
  local changed = stacklabels.update(known, stacklabels.frame({ BATTERY }, { digit(101, 204, "d2") }))
  assert.eq(#changed, 1, "count changed")
  assert.eq(changed[1].signature, BATTERY.signature, "battery")
  assert.eq(changed[1].before, "d3", "before")
  assert.eq(changed[1].after, "d2", "after")
end

function T.stack_used_up_only_while_the_inventory_is_drawn()
  assert.eq(stacklabels.usedUp(true, { COINS }, BATTERY.signature), true, "battery gone, coins still drawn")
  assert.eq(stacklabels.usedUp(true, {}, BATTERY.signature), false, "inventory hidden")
  assert.eq(stacklabels.usedUp(true, { BATTERY, COINS }, BATTERY.signature), false, "still there")
  assert.eq(stacklabels.usedUp(false, { COINS }, BATTERY.signature), false, "wasn't there before")
end

function T.battery_change_near_a_loot_action_is_from_the_loot()
  assert.eq(stacklabels.aroundLoot(10 * SECOND, 8.5 * SECOND), true, "just after a chest")
  assert.eq(stacklabels.aroundLoot(10 * SECOND, 10.1 * SECOND), true, "just before the chest was seen opening")
  assert.eq(stacklabels.aroundLoot(20 * SECOND, 8 * SECOND), false, "long after")
  assert.eq(stacklabels.aroundLoot(20 * SECOND, nil), false, "nothing looted yet")
  assert.eq(stacklabels.decided(11 * SECOND, 10 * SECOND), false, "still waiting")
  assert.eq(stacklabels.decided(12.5 * SECOND, 10 * SECOND), true, "decided")
end

function T.mouse_near_an_icon()
  assert.eq(stacklabels.near(BATTERY, 116, 216), true, "over it")
  assert.eq(stacklabels.near(BATTERY, 100 + 32 + 40, 200), true, "just beside it")
  assert.eq(stacklabels.near(BATTERY, 600, 600), false, "far away")
end

function T.learns_the_one_stack_that_changed_at_the_anchor()
  local learner = stacklabels.newLearner()
  stacklabels.note(learner, 1 * SECOND, { { signature = COINS.signature } }, 50, 50)
  stacklabels.note(learner, 5 * SECOND, { { signature = BATTERY.signature } }, 10, 10)
  local learned, count = stacklabels.learn(learner, 8 * SECOND, 11, 9)
  assert.eq(learned, BATTERY.signature, "battery learned")
  assert.eq(count, 1, "one candidate")
end

function T.two_stacks_changing_at_the_anchor_is_ambiguous()
  local learner = stacklabels.newLearner()
  stacklabels.note(learner, 1 * SECOND, { { signature = COINS.signature }, { signature = BATTERY.signature } }, 10, 10)
  local learned, count = stacklabels.learn(learner, 2 * SECOND, 10, 10)
  assert.eq(learned, nil, "not learned")
  assert.eq(count, 2, "two candidates")
end

function T.old_changes_are_forgotten()
  local learner = stacklabels.newLearner()
  stacklabels.note(learner, 1 * SECOND, { { signature = BATTERY.signature } }, 10, 10)
  stacklabels.note(learner, 60 * SECOND, {}, 10, 10)
  assert.eq(stacklabels.learn(learner, 60 * SECOND, 10, 10), nil, "too old")
end

return T
