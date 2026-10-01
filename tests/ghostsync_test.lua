local ghostpaths = require("core.ghostpaths")
local ghostsync = require("core.ghostsync")
local assert = require("tests.assert")

local T = {}

local TICK = ghostsync.PERIOD
local LAG = 1.5

local steps = {
  { x = 0, z = 0 }, { x = 1, z = 0 }, { x = 2, z = 0 }, { x = 3, z = 0, stall = 2 },
  { x = 3, z = 1 }, { x = 3, z = 2 }, { x = 3, z = 3 }, { x = 2, z = 3 },
  { x = 1, z = 3 }, { x = 0, z = 3 }, { x = 0, z = 2 }, { x = 0, z = 1 },
}
for _, s in ipairs(steps) do s.h, s.lag = 100, LAG end
local loops = ghostpaths.prepare({ loops = { { name = "square", steps = steps } } })

local at = function(tile) return tile and (tile.x .. "," .. tile.z) or "none" end
local tileAt = function(state, id, tick) return at(ghostsync.tileFor(state, id, { x = 3, z = 1 }, 100, tick * TICK)) end
local toTick = function(t) return math.floor(t / TICK + 0.5) * TICK end

local walk = function(state, id, tiles, firstServerTick, noise)
  local message
  for i, t in ipairs(tiles) do
    local seen = (firstServerTick + i - 1 + LAG + (noise and noise[i] or 0)) * TICK
    message = ghostsync.observeTile(state, id, { x = t[1], z = t[2] }, seen, toTick) or message
  end
  return message
end

function T.two_tiles_walked_are_enough_to_sync()
  local state = ghostsync.new(loops)
  local message = walk(state, 7, { { 3, 1 }, { 3, 2 } }, 200, { 0.04, -0.05 })
  assert.eq(message, "synced to square from 2 tiles walked", "synced from the drawn ghost and each tile's known lag")
  assert.eq(tileAt(state, 7, 201), "3,2", "the server tile, not where it's drawn")
  assert.eq(tileAt(state, 7, 205), "0,3", "then counts on")
  assert.eq(tileAt(state, 7, 212), "3,0", "including the stall")
  assert.eq(tileAt(state, 7, 214), "3,1", "a lap after 3,1")
end

function T.tiles_that_disagree_start_the_estimate_over()
  local state = ghostsync.new(loops)
  assert.eq(walk(state, 7, { { 3, 1 }, { 3, 2 } }, 200, { 0, 0.6 }), nil, "0.6 ticks apart: not trusted")
  assert.eq(tileAt(state, 7, 201), "none", "nothing shown yet")
end

function T.a_set_off_is_a_checkpoint_that_tightens_the_sync()
  local state = ghostsync.new(loops)
  walk(state, 7, { { 3, 1 }, { 3, 2 } }, 201)
  for _, t in ipairs({ { 3, 3 }, { 2, 3 }, { 1, 3 }, { 0, 3 }, { 0, 2 }, { 0, 1 }, { 0, 0 }, { 1, 0 }, { 2, 0 }, { 3, 0 } }) do
    ghostsync.observeTile(state, 7, { x = t[1], z = t[2] }, nil)
  end
  assert.eq(ghostsync.observeStart(state, 7, 214 * TICK), "checkpoint on square: set-off was 1 tick before the sync, tightened",
    "the walked estimate was a tick late")
  assert.eq(tileAt(state, 7, 214), "3,1", "now exact")
  assert.eq(ghostsync.observeStart(state, 7, 228 * TICK), nil, "the next checkpoint agrees: nothing to say")
end

function T.after_a_checkpoint_a_little_walking_noise_does_not_move_it()
  local state = ghostsync.new(loops)
  for _, t in ipairs({ { 1, 0 }, { 2, 0 }, { 3, 0 } }) do ghostsync.observeTile(state, 7, { x = t[1], z = t[2] }, nil) end
  assert.eq(ghostsync.observeStart(state, 7, 300 * TICK), "synced to square at a set-off", "a set-off first")
  walk(state, 7, { { 3, 1 }, { 3, 2 }, { 3, 3 } }, 300, { 0.2, -0.25, 0.1 })
  assert.eq(tileAt(state, 7, 300), "3,1", "the exact sync stands")
end

local exactSync = function()
  local state = ghostsync.new(loops)
  for _, t in ipairs({ { 1, 0 }, { 2, 0 }, { 3, 0 } }) do ghostsync.observeTile(state, 7, { x = t[1], z = t[2] }, nil) end
  ghostsync.observeStart(state, 7, 200 * TICK)
  return state
end

function T.a_sync_a_tick_ahead_is_moved_back_after_three_tiles_agree()
  local state = exactSync()
  state.sync[1].at = state.sync[1].at - TICK
  assert.eq(tileAt(state, 7, 201), "3,3", "a tick ahead: shows 3,3 when the ghost is on 3,2")
  local message = walk(state, 7, { { 3, 1 }, { 3, 2 }, { 3, 3 } }, 200)
  assert.eq(message, "walked 3 tiles 1 tick behind the sync on square: moved it", "the ghost keeps arriving a tick after the sync says")
  assert.eq(tileAt(state, 7, 203), "2,3", "back on its true tile")
end

function T.two_tiles_off_by_a_tick_are_not_enough()
  local state = exactSync()
  state.sync[1].at = state.sync[1].at - TICK
  assert.eq(walk(state, 7, { { 3, 1 }, { 3, 2 } }, 200), nil, "not yet")
  assert.eq(walk(state, 7, { { 3, 3 } }, 202), "walked 3 tiles 1 tick behind the sync on square: moved it", "the third one does it")
end

function T.walking_into_view_on_a_synced_route_picks_it_up()
  local state = ghostsync.new(loops)
  walk(state, 7, { { 3, 1 }, { 3, 2 } }, 200)
  ghostsync.forget(state, 7)
  assert.eq(at(ghostsync.tileFor(state, 9, { x = 0, z = 3 }, 100, 205 * TICK)), "0,3", "picked up, shown where the lap has it")
  assert.eq(ghostsync.tileFor(state, 10, { x = 9, z = 9 }, 100, 205 * TICK), nil, "a ghost somewhere else isn't")
end

function T.the_shown_tile_never_steps_back_when_the_clock_wobbles()
  local state = ghostsync.new(loops)
  walk(state, 7, { { 3, 1 }, { 3, 2 } }, 200)
  assert.eq(tileAt(state, 7, 202), "3,3", "tick 202")
  assert.eq(tileAt(state, 7, 201), "3,3", "a wobble back: stays")
  assert.eq(tileAt(state, 7, 203), "2,3", "then on")
end

function T.the_outline_is_one_tile_ahead_of_the_drawn_ghost()
  local state = ghostsync.new(loops)
  walk(state, 7, { { 3, 1 }, { 3, 2 } }, 200)
  local shown = function(drawnX, drawnZ, tick)
    return at(ghostsync.tileFor(state, 7, { x = drawnX, z = drawnZ }, 100, tick * TICK, true))
  end
  assert.eq(shown(3, 2, 203.4), "3,3", "drawn on 3,2 while the server is already on 2,3: one tile ahead of the drawn ghost")
  assert.eq(shown(3, 3, 204.4), "2,3", "and on")
  assert.eq(shown(2, 0, 211.2), "3,0", "walking up to the stall tile")
  assert.eq(shown(3, 0, 212.5), "3,0", "standing on the stall tile with the server still there: the stall tile")
  assert.eq(shown(3, 0, 214.1), "3,1", "the server has left the stall: one tile on, where the drawn ghost is heading")
  assert.eq(shown(3, 0, 213.5), "3,1", "never steps back")
end

function T.re_anchoring_the_sync_while_walking_does_not_push_the_outline_ahead()
  local state = ghostsync.new(loops)
  walk(state, 7, { { 3, 1 }, { 3, 2 } }, 200)
  local shown = function(drawnX, drawnZ, tick)
    return at(ghostsync.tileFor(state, 7, { x = drawnX, z = drawnZ }, 100, tick * TICK, true))
  end
  assert.eq(shown(3, 2, 203.4), "3,3", "one ahead")
  local anchorBefore = state.sync[1].step
  walk(state, 7, { { 3, 3 } }, 202)
  assert.eq(state.sync[1].step ~= anchorBefore, true, "walking moved the sync's anchor on a tile")
  assert.eq(shown(3, 3, 204.4), "2,3", "still exactly one ahead, not held further on by the old anchor's count")
end

function T.a_synced_patrol_out_of_view_is_placed_where_it_would_be_drawn_one_ahead()
  local state = ghostsync.new(loops)
  walk(state, 7, { { 3, 1 }, { 3, 2 } }, 200)
  ghostsync.forget(state, 7)
  local list = ghostsync.unseen(state, 205.5 * TICK, {})
  assert.eq(#list, 1, "one synced loop, not in view")
  assert.eq(at(list[1].step), "0,3", "with a 1.5 tick lag the ghost would be drawn on 1,3, so one ahead: 0,3")
  assert.eq(at(ghostsync.unseen(state, 208.5 * TICK, {})[1].step), "0,0", "and it keeps moving along the route")
  assert.eq(#ghostsync.unseen(state, 205.5 * TICK, { [1] = true }), 0, "a loop whose ghost is in view isn't added")
end

function T.before_timing_is_known_the_route_says_where_it_is_heading()
  local state = ghostsync.new(loops)
  for _, t in ipairs({ { 3, 1 }, { 3, 2 }, { 3, 3 }, { 2, 3 } }) do ghostsync.observeTile(state, 7, { x = t[1], z = t[2] }, nil) end
  local ahead, on = ghostsync.routeAhead(state, 7)
  assert.eq(at(ahead) .. " " .. at(on), "1,3 2,3", "the next tile along the route")
end

return T
