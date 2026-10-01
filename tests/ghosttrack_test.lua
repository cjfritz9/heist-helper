local ghosttrack = require("core.ghosttrack")
local assert = require("tests.assert")

local T = {}

local MS = 1000

local kinds = function(events)
  local out = {}
  for i, e in ipairs(events) do out[i] = e.kind .. " g" .. e.id end
  return table.concat(out, ", ")
end

function T.a_new_ring_appears_once_and_keeps_its_id()
  local state = ghosttrack.new()
  assert.eq(kinds(ghosttrack.update(state, 0, { { x = 10.5, z = 20.5 } })), "appear g1", "first sighting")
  assert.eq(kinds(ghosttrack.update(state, 16 * MS, { { x = 10.5, z = 20.5 } })), "", "same ring, nothing new")
  assert.eq(kinds(ghosttrack.update(state, 32 * MS, { { x = 30.5, z = 20.5 } })), "appear g2", "far away: another ghost")
end

function T.moving_logs_start_centres_and_stop()
  local state = ghosttrack.new()
  ghosttrack.update(state, 0, { { x = 10.5, z = 20.5 } })
  local e = ghosttrack.update(state, 600 * MS, { { x = 10.7, z = 20.5 } })
  assert.eq(kinds(e), "start g1", "starts after standing")
  assert.eq(e[1].still, 600 * MS, "stood 600 ms")
  assert.eq(kinds(ghosttrack.update(state, 700 * MS, { { x = 11.1, z = 20.5 } })), "", "crossing the edge is not a tile any more")
  assert.eq(kinds(ghosttrack.update(state, 880 * MS, { { x = 11.45, z = 20.5 } })), "", "approaching the centre")
  assert.eq(kinds(ghosttrack.update(state, 900 * MS, { { x = 11.5, z = 20.5 } })), "", "at the centre")
  local tile = ghosttrack.update(state, 920 * MS, { { x = 11.55, z = 20.5 } })
  assert.eq(kinds(tile), "tile g1", "moving away from the centre: the tile is recorded")
  assert.eq(tile[1].at, 900 * MS, "at the moment it was closest")
  assert.eq(tile[1].tileX, 11, "tile 11")
end

function T.a_stop_on_a_centre_records_the_tile_and_the_stop()
  local state = ghosttrack.new()
  ghosttrack.update(state, 0, { { x = 10.5, z = 20.5 } })
  ghosttrack.update(state, 600 * MS, { { x = 10.9, z = 20.5 } })
  ghosttrack.update(state, 900 * MS, { { x = 11.5, z = 20.5 } })
  assert.eq(kinds(ghosttrack.update(state, 950 * MS, { { x = 11.5, z = 20.5 } })), "tile g1", "arrived and stayed")
  local stop = ghosttrack.update(state, 1100 * MS, { { x = 11.5, z = 20.5 } })
  assert.eq(kinds(stop), "stop g1", "stopped")
  assert.eq(stop[1].at, 900 * MS, "stopped when it last moved")
end

function T.a_diagonal_step_never_records_the_corner_tiles()
  local state = ghosttrack.new()
  ghosttrack.update(state, 0, { { x = 10.5, z = 20.5 } })
  local tiles = {}
  for i = 1, 30 do
    local t = i / 30
    for _, e in ipairs(ghosttrack.update(state, (600 + i * 20) * MS, { { x = 10.5 + t, z = 20.5 + t } })) do
      if e.kind == "tile" then tiles[#tiles + 1] = e.tileX .. "," .. e.tileZ end
    end
  end
  for i, x in ipairs({ 11.6, 11.7 }) do
    for _, e in ipairs(ghosttrack.update(state, (1300 + i * 20) * MS, { { x = x, z = x + 10 } })) do
      if e.kind == "tile" then tiles[#tiles + 1] = e.tileX .. "," .. e.tileZ end
    end
  end
  assert.eq(table.concat(tiles, " "), "11,21", "straight from 10,20 to 11,21")
end

function T.true_tile_is_the_centre_it_is_heading_to()
  local state = ghosttrack.new()
  ghosttrack.update(state, 0, { { x = 10.5, z = 20.5 } })
  ghosttrack.update(state, 600 * MS, { { x = 10.8, z = 20.5 } })
  local g = state.ghosts[1]
  assert.eq(table.concat({ ghosttrack.trueTile(g, 610 * MS) }, ","), "11,20", "sliding east: already on 11")
  ghosttrack.update(state, 900 * MS, { { x = 11.5, z = 20.5 } })
  ghosttrack.update(state, 1000 * MS, { { x = 11.5, z = 20.5 } })
  assert.eq(table.concat({ ghosttrack.trueTile(g, 1000 * MS) }, ","), "11,20", "standing: where it's drawn")
  ghosttrack.update(state, 1600 * MS, { { x = 11.3, z = 20.3 } })
  assert.eq(table.concat({ ghosttrack.trueTile(g, 1600 * MS) }, ","), "10,19", "sliding south-west")
end

function T.two_ghosts_passing_keep_their_ids()
  local state = ghosttrack.new()
  ghosttrack.update(state, 0, { { x = 10.5, z = 20.5 }, { x = 13.5, z = 20.5 } })
  ghosttrack.update(state, 100 * MS, { { x = 12.9, z = 20.5 }, { x = 11.1, z = 20.5 } })
  assert.eq(state.ghosts[1].x, 11.1, "g1 moved right")
  assert.eq(state.ghosts[2].x, 12.9, "g2 moved left")
end

function T.a_pinned_spawn_never_takes_over_a_passing_patrol()
  local state = ghosttrack.new()
  ghosttrack.update(state, 0, { { x = 10.5, z = 20.5 } })
  ghosttrack.pin(state, 1)
  ghosttrack.update(state, 100 * MS, { { x = 12.5, z = 20.5 } })
  local e = ghosttrack.update(state, 200 * MS, { { x = 11.5, z = 20.5 } })
  assert.eq(kinds(e), "start g2", "the patrol walking past the spawn's spot keeps its own id")
  assert.eq(state.ghosts[1].x, 10.5, "the spawn is still where it stood")
  assert.eq(state.ghosts[2].x, 11.5, "the patrol moved on")
end

function T.ghosts_that_never_moved_since_appearing()
  local state = ghosttrack.new()
  ghosttrack.update(state, 0, { { x = 10.5, z = 20.5 }, { x = 30.5, z = 20.5 } })
  ghosttrack.update(state, 3000 * MS, { { x = 10.5, z = 20.5 }, { x = 30.7, z = 20.5 } })
  assert.eq(#ghosttrack.idleSinceAppearing(state, 4000 * MS, 5), 0, "not long enough")
  local idle = ghosttrack.idleSinceAppearing(state, 5000 * MS, 5)
  assert.eq(#idle == 1 and idle[1].id, 1, "only the one that never moved")
  ghosttrack.pin(state, 1)
  assert.eq(#ghosttrack.idleSinceAppearing(state, 6000 * MS, 5), 0, "once pinned it's not reported again")
end

function T.a_ghost_out_of_view_is_lost_after_a_second()
  local state = ghosttrack.new()
  ghosttrack.update(state, 0, { { x = 10.5, z = 20.5 } })
  assert.eq(kinds(ghosttrack.update(state, 900 * MS, {})), "", "brief gap")
  local e = ghosttrack.update(state, 1100 * MS, {})
  assert.eq(kinds(e), "lost g1", "gone")
  assert.eq(ghosttrack.format(e[1]), "g1 lost from view on 10,20 (10.50,20.50) height 0", "log line")
end

return T
