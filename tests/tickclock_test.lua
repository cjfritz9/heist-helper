local tickclock = require("core.tickclock")
local assert = require("tests.assert")

local T = {}

local MS = 1000

function T.moving_off_after_standing_still_marks_a_tick()
  local clock = tickclock.new()
  assert.eq(tickclock.observe(clock, 0, false), false, "still")
  assert.eq(tickclock.observe(clock, 200 * MS, false), false, "still")
  assert.eq(tickclock.observe(clock, 216 * MS, true), true, "starts moving")
  assert.eq(clock.phase, 216 * MS, "tick phase")
  assert.eq(tickclock.observe(clock, 232 * MS, true), false, "still moving")
end

function T.a_brief_pause_is_not_a_tick()
  local clock = tickclock.new()
  tickclock.observe(clock, 0, false)
  tickclock.observe(clock, 200 * MS, true)
  tickclock.observe(clock, 216 * MS, false)
  assert.eq(tickclock.observe(clock, 300 * MS, true), false, "paused 84 ms")
end

function T.next_tick_follows_the_phase()
  local clock = tickclock.new()
  assert.eq(tickclock.nextTick(clock, 0), nil, "no phase yet")
  clock.phase = 1000 * MS
  assert.eq(tickclock.nextTick(clock, 1100 * MS), 1600 * MS, "later this tick")
  assert.eq(tickclock.nextTick(clock, 1600 * MS), 2200 * MS, "strictly after")
  assert.eq(tickclock.nextTick(clock, 3050 * MS), 3400 * MS, "a few ticks on")
end

return T
