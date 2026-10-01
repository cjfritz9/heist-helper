local latency = require("core.latency")
local assert = require("tests.assert")

local T = {}

local MS = 1000

function T.nothing_measured_is_a_typical_round_trip()
  assert.eq(latency.estimate(latency.new()), latency.DEFAULT, "50 ms until something says otherwise")
end

function T.samples_that_contradict_each_other_are_not_averaged()
  local state = latency.new()
  latency.note(state, 4 * MS)
  assert.eq(#state.gaps, 0, "setting off 4 ms after a click: that click didn't do it")
  latency.note(state, 746 * MS)
  latency.note(state, 40 * MS)
  assert.eq(latency.estimate(state), latency.DEFAULT, "at least 131 and at most 55 can't both be true")
end

function T.a_click_far_from_a_tick_says_nothing_new()
  local state = latency.new()
  latency.note(state, 430 * MS)
  assert.eq(latency.estimate(state), 50 * MS, "moved 430 ms later: the round trip is under 445, so still the typical one")
end

function T.a_click_that_only_just_made_its_tick_caps_it()
  local state = latency.new()
  latency.note(state, 20 * MS)
  assert.eq(latency.estimate(state), 17.5 * MS, "moved on a tick 20 ms after the click: between 0 and 35")
end

function T.a_click_that_just_missed_a_tick_raises_it()
  local state = latency.new()
  latency.note(state, 680 * MS)
  assert.eq(latency.estimate(state), 65 * MS, "missed a tick 80 ms after the click: at least 65")
  latency.note(state, 90 * MS)
  assert.eq(latency.estimate(state), 85 * MS, "and made one 90 ms after: between 65 and 105")
end

function T.nonsense_gaps_are_ignored_and_old_ones_roll_off()
  local state = latency.new()
  latency.note(state, -5 * MS)
  latency.note(state, 5000 * MS)
  assert.eq(#state.gaps, 0, "negative and five-second gaps ignored")
  latency.note(state, 1000 * MS)
  assert.eq(latency.estimate(state), 50 * MS, "missing a tick by 400 ms isn't the round trip: something else held you up")
  for _ = 1, 30 do latency.note(state, 200 * MS) end
  assert.eq(#state.gaps, latency.SAMPLES, "only the last twenty kept")
end

return T
