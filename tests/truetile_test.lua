local truetile = require("core.truetile")
local assert = require("tests.assert")

local T = {}

local MS = 1000
local ticks = function(phase)
  return function(after) return after + (phase * MS - after) % truetile.TICK end
end
local noClock = function() return nil end
local tile = function(dx, dz) return { dx = dx, dz = dz } end
local at = function(state) return state.tile.dx .. "," .. state.tile.dz end
local names = function(events)
  local out = {}
  for _, e in ipairs(events) do
    if e.kind ~= "drawn" then out[#out + 1] = e.kind .. " " .. tostring(e.index) end
  end
  return table.concat(out, ", ")
end

function T.a_click_while_moving_counts_for_the_first_tick_it_reaches()
  local state, clock = truetile.new(), ticks(0)
  truetile.click(state, 300 * MS, { index = 1, tile = tile(2, 0) }, tile(0, 0), false, 50 * MS, clock)
  assert.eq(names(truetile.advance(state, 590 * MS, tile(0, 0), false, false, clock)), "", "before the tick: nothing yet")
  assert.eq(names(truetile.advance(state, 605 * MS, tile(0, 0), false, false, clock)), "reached 1", "on the tick")
  assert.eq(at(state), "2,0", "two tiles a tick")
end

function T.a_click_too_close_to_the_tick_waits_for_the_next()
  local state, clock = truetile.new(), ticks(0)
  truetile.click(state, 570 * MS, { index = 1, tile = tile(2, 0) }, tile(0, 0), false, 50 * MS, clock)
  assert.eq(names(truetile.advance(state, 610 * MS, tile(0, 0), false, false, clock)), "", "30 ms before the tick can't reach the server in time")
  assert.eq(names(truetile.advance(state, 1205 * MS, tile(0, 0), false, false, clock)), "reached 1", "the tick after")
end

function T.clicking_ahead_does_not_cancel_the_step_already_on_its_way()
  local state, clock = truetile.new(), ticks(0)
  truetile.click(state, 300 * MS, { index = 1, tile = tile(2, 0) }, tile(0, 0), false, 50 * MS, clock)
  truetile.click(state, 580 * MS, { index = 2, tile = tile(4, 0) }, tile(0, 0), false, 50 * MS, clock)
  assert.eq(names(truetile.advance(state, 605 * MS, tile(0, 0), false, false, clock)), "reached 1", "the first click still lands on its tick")
  assert.eq(names(truetile.advance(state, 1205 * MS, tile(1, 0), false, false, clock)), "reached 2", "the second a tick later")
end

function T.the_latest_click_that_reached_the_server_wins()
  local state, clock = truetile.new(), ticks(0)
  truetile.click(state, 100 * MS, { index = 1, tile = tile(2, 0) }, tile(0, 0), false, 50 * MS, clock)
  truetile.click(state, 300 * MS, { index = 2, tile = tile(0, 2) }, tile(0, 0), false, 50 * MS, clock)
  assert.eq(names(truetile.advance(state, 605 * MS, tile(0, 0), false, false, clock)), "reached 2", "changed your mind before the tick")
  assert.eq(at(state), "0,2", "went to the second")
end

function T.a_far_click_takes_several_ticks()
  local state, clock = truetile.new(), ticks(0)
  truetile.click(state, 100 * MS, { index = 3, tile = tile(4, 0) }, tile(0, 0), false, 50 * MS, clock)
  assert.eq(names(truetile.advance(state, 605 * MS, tile(0, 0), false, false, clock)), "toward 3", "halfway")
  assert.eq(at(state), "2,0", "two tiles in")
  assert.eq(names(truetile.advance(state, 1210 * MS, tile(1, 0), false, false, clock)), "reached 3", "there")
end

function T.a_click_while_standing_steps_on_the_tick_without_waiting_to_see_you_move()
  local state, clock = truetile.new(), ticks(0)
  truetile.click(state, 300 * MS, { index = 1, tile = tile(2, 0) }, tile(0, 0), true, 50 * MS, clock)
  assert.eq(names(truetile.advance(state, 605 * MS, tile(0, 0), true, false, clock)), "reached 1", "on the tick, drawn movement not needed")
  assert.eq(names(truetile.advance(state, 640 * MS, tile(0, 0), false, true, clock)), "", "seeing the start later changes nothing")
end

function T.a_standing_click_too_close_to_call_waits_to_see_you_move()
  local state, clock = truetile.new(), ticks(0)
  truetile.click(state, 560 * MS, { index = 1, tile = tile(2, 0) }, tile(0, 0), true, 50 * MS, clock)
  assert.eq(names(truetile.advance(state, 605 * MS, tile(0, 0), true, false, clock)), "", "10 ms either way: can't tell which tick")
  assert.eq(names(truetile.advance(state, 1240 * MS, tile(0, 0), false, true, clock)), "reached 1", "you set off a tick later: that was the one")
end

function T.without_any_clock_a_standing_click_steps_when_you_are_seen_to_move()
  local state = truetile.new()
  truetile.click(state, 300 * MS, { index = 1, tile = tile(2, 0) }, tile(0, 0), true, 50 * MS, noClock)
  assert.eq(names(truetile.advance(state, 500 * MS, tile(0, 0), true, false, noClock)), "", "standing")
  assert.eq(names(truetile.advance(state, 640 * MS, tile(0, 0), false, true, noClock)), "reached 1", "moved")
end

function T.with_nothing_clicked_the_true_tile_is_where_you_stand()
  local state = truetile.new()
  truetile.advance(state, 100 * MS, tile(3, 4), true, false, noClock)
  assert.eq(at(state), "3,4", "your drawn tile")
end

function T.while_you_run_on_the_true_tile_stays_ahead_of_your_drawn_character()
  local state, clock = truetile.new(), ticks(0)
  truetile.click(state, 300 * MS, { index = 1, tile = tile(2, 0) }, tile(0, 0), false, 50 * MS, clock)
  truetile.advance(state, 605 * MS, tile(0, 0), false, false, clock)
  truetile.advance(state, 700 * MS, tile(0, 0), false, false, clock)
  assert.eq(at(state), "2,0", "drawn character still on the old tile, no clicks pending: the true tile holds")
  truetile.click(state, 800 * MS, { index = 2, tile = tile(4, 0) }, tile(1, 0), false, 50 * MS, clock)
  assert.eq(names(truetile.advance(state, 1205 * MS, tile(1, 0), false, false, clock)), "reached 2", "so the next click is one tick away, not two")
end

function T.a_standing_click_keeps_its_step_while_your_character_is_slow_to_set_off()
  local state, clock = truetile.new(), ticks(0)
  truetile.click(state, 300 * MS, { index = 1, tile = tile(2, 0) }, tile(0, 0), true, 50 * MS, clock)
  truetile.advance(state, 605 * MS, tile(0, 0), true, false, clock)
  truetile.advance(state, 640 * MS, tile(0, 0), true, false, clock)
  assert.eq(at(state), "2,0", "drawn character not moving yet: the true tile has still moved")
end

function T.a_click_that_missed_its_tick_is_caught_when_you_stall_and_counts_next_tick()
  local state, clock = truetile.new(), ticks(0)
  state.tile, state.tileAt = tile(2, 0), 600 * MS
  truetile.click(state, 1100 * MS, { index = 3, tile = tile(4, 0) }, tile(1, 0), false, 50 * MS, clock)
  truetile.advance(state, 1205 * MS, tile(1, 0), false, false, clock)
  assert.eq(at(state), "4,0", "counted for the tick 100 ms after the click")
  truetile.advance(state, 1400 * MS, tile(2, 0), false, false, clock)
  local events = truetile.advance(state, 1520 * MS, tile(2, 0), true, false, clock)
  assert.eq(names(events), "missed 3", "you stood where it said you'd left: that click missed its tick")
  assert.eq(events[1].margin, 100 * MS, "by a click 100 ms before it")
  assert.eq(at(state), "2,0", "back where you really are")
  assert.eq(names(truetile.advance(state, 1805 * MS, tile(2, 0), true, false, clock)), "reached 3", "the server takes it on the next tick")
end

function T.a_missed_tick_is_caught_even_when_the_true_tile_was_already_off()
  local state, clock = truetile.new(), ticks(0)
  state.tile, state.tileAt = tile(1, 1), 600 * MS
  truetile.click(state, 1100 * MS, { index = 3, tile = tile(4, 0) }, tile(1, 0), false, 50 * MS, clock)
  truetile.advance(state, 1205 * MS, tile(1, 0), false, false, clock)
  local events = truetile.advance(state, 1520 * MS, tile(2, 0), true, false, clock)
  assert.eq(names(events), "missed 3", "standing somewhere the true tile isn't, just after a step")
  assert.eq(names(truetile.advance(state, 1805 * MS, tile(2, 0), true, false, clock)), "reached 3", "and the step comes on the next tick")
end

function T.standing_still_long_after_a_click_means_it_did_not_take()
  local state, clock = truetile.new(), ticks(0)
  state.tile, state.tileAt = tile(2, 0), 600 * MS
  truetile.click(state, 700 * MS, { index = 3, tile = tile(4, 0) }, tile(2, 0), false, 50 * MS, clock)
  truetile.advance(state, 1205 * MS, tile(2, 0), false, false, clock)
  local events = truetile.advance(state, 1520 * MS, tile(2, 0), true, false, clock)
  assert.eq(names(events), "ignored 3", "500 ms is far more than any round trip: the game didn't follow that click")
  assert.eq(names(truetile.advance(state, 1805 * MS, tile(2, 0), true, false, clock)), "", "so it isn't tried again")
  assert.eq(at(state), "2,0", "you're where you're drawn")
end

function T.your_drawn_character_is_checked_against_the_true_tile_path()
  local state, clock = truetile.new(), ticks(0)
  truetile.advance(state, 100 * MS, tile(0, 0), true, false, clock)
  truetile.click(state, 300 * MS, { index = 1, tile = tile(4, 0) }, tile(0, 0), false, 50 * MS, clock)
  truetile.advance(state, 605 * MS, tile(0, 0), false, false, clock)
  local events = truetile.advance(state, 900 * MS, tile(1, 0), false, false, clock)
  assert.eq(#events == 1 and events[1].kind, "drawn", "drawn on a tile the true tile passed")
  assert.eq(events[1].lag, 300 * MS, "300 ms after it")
  truetile.advance(state, 1205 * MS, tile(2, 0), false, false, clock)
  assert.eq(at(state), "4,0", "carries on")
end

function T.a_drawn_character_well_off_the_true_tile_path_resyncs_it()
  local state, clock = truetile.new(), ticks(0)
  truetile.advance(state, 100 * MS, tile(0, 0), true, false, clock)
  truetile.click(state, 300 * MS, { index = 1, tile = tile(4, 0) }, tile(0, 0), false, 50 * MS, clock)
  truetile.advance(state, 605 * MS, tile(0, 0), false, false, clock)
  truetile.advance(state, 800 * MS, tile(0, 1), false, false, clock)
  assert.eq(at(state), "2,0", "one tile to the side is within reach of the path: rounding, not a mistake")
  local events = truetile.advance(state, 900 * MS, tile(0, 2), false, false, clock)
  assert.eq(names(events), "offpath nil", "two tiles off the path")
  assert.eq(at(state), "0,2", "the true tile starts again from where you're drawn")
end

function T.a_click_anywhere_moves_the_true_tile_even_off_the_route()
  local state, clock = truetile.new(), ticks(0)
  truetile.click(state, 300 * MS, { tile = tile(0, 2) }, tile(0, 0), false, 50 * MS, clock)
  assert.eq(names(truetile.advance(state, 605 * MS, tile(0, 0), false, false, clock)), "reached nil", "no route step, still a destination")
  assert.eq(at(state), "0,2", "moved there")
end

function T.a_true_tile_that_has_run_away_from_your_character_is_pulled_back()
  local state, clock = truetile.new(), ticks(0)
  truetile.click(state, 300 * MS, { tile = tile(2, 0) }, tile(0, 0), false, 50 * MS, clock)
  truetile.advance(state, 605 * MS, tile(0, 0), false, false, clock)
  truetile.advance(state, 700 * MS, tile(9, 9), false, false, clock)
  assert.eq(at(state), "9,9", "more than 6 tiles from where you're drawn: the model was wrong")
end

function T.a_click_that_never_happens_is_dropped()
  local state, clock = truetile.new(), ticks(0)
  truetile.click(state, 560 * MS, { index = 1, tile = tile(2, 0) }, tile(0, 0), true, 50 * MS, clock)
  local events = truetile.advance(state, 560 * MS + 5 * truetile.TICK, tile(0, 0), true, false, clock)
  assert.eq(names(events), "lost 1", "never seen to move: forget it")
  assert.eq(state.tile, nil, "back to the drawn position")
end

return T
