local spawntimer = require("core.spawntimer")
local assert = require("tests.assert")

local T = {}

local MS = 1000

function T.counts_down_the_twelve_ticks_from_the_tick_it_appeared()
  assert.eq(spawntimer.remaining(1000 * MS, 1010 * MS), 12, "just appeared")
  assert.eq(spawntimer.remaining(1000 * MS, 1599 * MS), 12, "still the first tick")
  assert.eq(spawntimer.remaining(1000 * MS, 1600 * MS), 11, "one tick gone")
  assert.eq(spawntimer.remaining(1000 * MS, 1000 * MS + 11 * 600 * MS), 1, "last tick")
end

function T.nothing_once_it_should_have_gone()
  assert.eq(spawntimer.remaining(1000 * MS, 1000 * MS + 12 * 600 * MS), nil, "a leftover from leaving the instance: no timer")
  assert.eq(spawntimer.remaining(nil, 1000 * MS), nil, "appearance unknown")
end

function T.a_bar_of_twelve_cells_with_the_ticks_left_filled()
  local colours = { back = "back", full = "full", empty = "empty" }
  local quads = spawntimer.bar(5, 100, 50, 60, 8, colours)
  assert.eq(#quads, 13, "background and twelve cells")
  assert.eq(quads[1].colour, "back", "background first, underneath")
  assert.eq(quads[6].colour, "full", "fifth cell filled")
  assert.eq(quads[7].colour, "empty", "sixth empty")
  assert.eq(quads[2][1], 70, "starts at the left end, centred on the ghost")
  assert.eq(quads[13][3], 130, "ends at the right end")
  assert.eq(quads[2][6], 50, "sits on the given bottom")
end

return T
