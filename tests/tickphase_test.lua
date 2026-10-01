local tickphase = require("core.tickphase")
local assert = require("tests.assert")

local T = {}

local MS = 1000
local TRUSTED = { move = true }

local near = function(a, b, tolerance) return math.abs(a - b) <= tolerance end

function T.phase_from_samples_on_the_same_beat()
  local state = tickphase.new(TRUSTED)
  for _, at in ipairs({ 1250, 1850, 3050, 4855, 6045 }) do tickphase.add(state, at * MS, "move", at * MS) end
  assert.eq(near(state.phase, 50 * MS, 3 * MS), true, "phase about 50 ms into each 600 ms cycle: " .. state.phase)
  assert.eq(state.spread < 5 * MS, true, "tight: " .. state.spread)
end

function T.phase_wraps_around_the_cycle_edge()
  local state = tickphase.new(TRUSTED)
  for _, at in ipairs({ 1195, 1805, 2995, 3610 }) do tickphase.add(state, at * MS, "move", at * MS) end
  assert.eq(math.abs(tickphase.residual(state.phase, 1200 * MS)) < 6 * MS, true, "straddling 0 still averages to about 0")
end

function T.untrusted_sources_are_measured_but_not_used()
  local state = tickphase.new(TRUSTED)
  tickphase.add(state, 1250 * MS, "move", 1250 * MS)
  local r = tickphase.add(state, 1300 * MS, "chat", 1300 * MS)
  assert.eq(near(r.residual, 50 * MS, 10), true, "chat is 50 ms after the tick")
  assert.eq(#state.samples, 1, "not added to the clock")
end

function T.three_samples_off_the_beat_relock()
  local state = tickphase.new(TRUSTED)
  for _, at in ipairs({ 1250, 1850, 2450 }) do tickphase.add(state, at * MS, "move", at * MS) end
  tickphase.add(state, 3290 * MS, "move", 3290 * MS)
  tickphase.add(state, 3890 * MS, "move", 3890 * MS)
  local r = tickphase.add(state, 4490 * MS, "move", 4490 * MS)
  assert.eq(r.relocked, true, "three in a row 240 ms off: lock again")
  assert.eq(near(state.phase, 290 * MS, 3 * MS), true, "new phase from the fresh samples")
end

function T.one_stray_sample_does_not_move_the_clock()
  local state = tickphase.new(TRUSTED)
  for _, at in ipairs({ 1250, 1850, 2450 }) do tickphase.add(state, at * MS, "move", at * MS) end
  tickphase.add(state, 3290 * MS, "move", 3290 * MS)
  tickphase.add(state, 3650 * MS, "move", 3650 * MS)
  assert.eq(near(state.phase, 50 * MS, 3 * MS), true, "stray ignored, phase kept")
end

function T.slow_frames_count_for_less_and_next_tick_follows_the_phase()
  assert.eq(tickphase.weight(16 * MS), 1, "normal frame")
  assert.eq(tickphase.weight(67 * MS) < 0.31, true, "15 fps frame")
  local state = tickphase.new(TRUSTED)
  tickphase.add(state, 1250 * MS, "move", 1250 * MS)
  assert.eq(near(tickphase.nextTick(state, 1300 * MS), 1850 * MS, 10), true, "next boundary")
end

function T.tick_numbers_count_whole_ticks_from_the_phase()
  local state = tickphase.new(TRUSTED)
  assert.eq(tickphase.tickIndex(state, 1000 * MS), nil, "no phase yet")
  tickphase.add(state, 1250 * MS, "move", 1250 * MS)
  assert.eq(tickphase.tickIndex(state, 1300 * MS), 2, "tick 2 began at 1250 ms")
  assert.eq(tickphase.tickIndex(state, 1840 * MS), 2, "still tick 2")
  assert.eq(tickphase.tickIndex(state, 1840 * MS, true), 3, "nearest boundary is tick 3's")
  assert.eq(near(tickphase.boundary(state, 1840 * MS), 1250 * MS, 100), true, "the boundary it falls after")
  assert.eq(near(tickphase.boundary(state, 1840 * MS, true), 1850 * MS, 100), true, "the nearest boundary")
end

function T.the_tick_runs_a_little_slow_and_the_phase_follows_it()
  local state = tickphase.new(TRUSTED)
  tickphase.add(state, 1250 * MS, "move", 1250 * MS)
  local minute = 60 * 1000 * MS
  local later = tickphase.nextTick(state, 1250 * MS + 10 * minute)
  assert.eq(near((later - 1250 * MS) % tickphase.PERIOD, 55 * MS, 2 * MS), true, "55 ms later in the cycle after ten minutes")
  tickphase.add(state, 1250 * MS + minute + 5500, "move", 1250 * MS + minute + 5500)
  assert.eq(state.spread < 1 * MS, true, "a sample a minute on, 5.5 ms later in the cycle, agrees: " .. state.spread)
end

function T.a_primary_source_takes_over_and_the_rest_are_only_measured()
  local state = tickphase.new({ xp = 1, move = 1 }, { xp = true })
  for _, at in ipairs({ 1290, 1890, 2490 }) do tickphase.add(state, at * MS, "move", at * MS) end
  local first = tickphase.add(state, 3050 * MS, "xp", 3050 * MS)
  assert.eq(first.relocked, true, "the first XP drop replaces the movement-based clock")
  assert.eq(near(state.phase, 50 * MS, 1 * MS), true, "phase from the XP drop alone: " .. state.phase)
  local move = tickphase.add(state, 3700 * MS, "move", 3700 * MS)
  assert.eq(move.used, false, "movement is measured, not used, while XP drops hold the clock")
  assert.eq(near(move.residual, 50 * MS, 1 * MS), true, "measured 50 ms late")
  assert.eq(near(state.phase, 50 * MS, 1 * MS), true, "clock unmoved")
end

function T.the_clock_runs_on_its_own_between_primary_samples_then_falls_back()
  local state = tickphase.new({ xp = 1, move = 1 }, { xp = true })
  tickphase.add(state, 1250 * MS, "xp", 1250 * MS)
  local minute = 60 * 1000 * MS
  local at = 1250 * MS + 5 * minute + 80 * MS
  assert.eq(tickphase.add(state, at, "move", at).used, false, "five minutes on, still held by the XP drops")
  at = 1250 * MS + 11 * minute + 80 * MS
  assert.eq(tickphase.add(state, at, "move", at).used, true, "after ten minutes without one, movement is used again")
end

function T.five_agreeing_fallback_samples_overrule_a_stale_primary_clock()
  local state = tickphase.new({ xp = 1, move = 1 }, { xp = true })
  tickphase.add(state, 1250 * MS, "xp", 1250 * MS)
  local relocked = false
  for i, at in ipairs({ 2150, 2760, 3345, 3950, 4555 }) do
    local r = tickphase.add(state, at * MS, "move", at * MS)
    relocked = r.relocked or false
    if i < 5 then assert.eq(relocked, false, "not after " .. i) end
  end
  assert.eq(relocked, true, "a world hop: five movement starts agree on a new beat")
  assert.eq(near(state.phase, 350 * MS, 10 * MS), true, "new phase: " .. state.phase)
end

function T.off_beat_samples_that_disagree_with_each_other_do_not_relock()
  local state = tickphase.new(TRUSTED)
  for _, at in ipairs({ 1250, 1850, 2450 }) do tickphase.add(state, at * MS, "move", at * MS) end
  local relocked = false
  for _, at in ipairs({ 3200, 3990, 4400, 5150 }) do
    relocked = relocked or tickphase.add(state, at * MS, "move", at * MS).relocked or false
  end
  assert.eq(relocked, false, "scattered strays: keep the clock")
  assert.eq(near(state.phase, 50 * MS, 3 * MS), true, "phase kept")
end

function T.sources_can_count_for_less()
  local state = tickphase.new({ sharp = 1, rough = 0.25 })
  tickphase.add(state, 1200 * MS, "sharp", 1200 * MS)
  tickphase.add(state, 1850 * MS, "rough", 1850 * MS)
  assert.eq(near(state.phase, 10 * MS, 2 * MS), true, "a quarter of the pull: " .. state.phase)
end

return T
