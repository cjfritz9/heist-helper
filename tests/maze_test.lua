local maze = require("core.maze")
local assert = require("tests.assert")

local T = {}

local ROWS = {
  west = maze.row({ dx = 0, dz = 0 }, { dx = 0, dz = 4 }),
  north = maze.row({ dx = 10, dz = 10 }, { dx = 14, dz = 10 }),
}

local tiles = function(list)
  local out = {}
  for i, t in ipairs(list or {}) do out[i] = t.dx .. "," .. t.dz end
  return table.concat(out, " ")
end

function T.row_from_its_two_ends()
  assert.eq(tiles(maze.row({ dx = 3, dz = 7 }, { dx = 3, dz = 3 })), "3,7 3,6 3,5 3,4 3,3", "either direction")
  assert.eq(maze.row({ dx = 0, dz = 0 }, { dx = 3, dz = 0 }), nil, "not five tiles")
  assert.eq(maze.row({ dx = 0, dz = 0 }, { dx = 4, dz = 4 }), nil, "diagonal")
end

function T.legs_go_clockwise_and_start_from_the_nearest_row()
  assert.eq(maze.nextBarrier("west"), "north", "west to north")
  assert.eq(maze.nextBarrier("south"), nil, "south is the last")
  assert.eq(maze.nearestBarrier(ROWS, -1, 2), "west", "next to the west row")
end

function T.route_runs_two_tiles_a_tick_over_safe_tiles()
  local session = maze.newSession()
  local lit = {}
  for z = 4, 10 do lit[#lit + 1] = { dx = 2, dz = z } end
  for x = 3, 9 do lit[#lit + 1] = { dx = x, dz = 10 } end
  maze.observe(session, lit)
  local route = maze.route(session, ROWS, 0, 2, "west", "north")
  assert.eq(#route, 7, "seven ticks of two tiles")
  assert.eq(tiles({ route[#route] }), "10,10", "ends on the north row")
  for i = 2, #route do
    local a, b = route[i - 1], route[i]
    assert.eq(math.max(math.abs(a.dx - b.dx), math.abs(a.dz - b.dz)) <= 2, true, "each step is one tick")
  end
end

function T.end_row_lets_you_finish_early()
  local session = maze.newSession()
  local lit = {}
  for z = 4, 8 do lit[#lit + 1] = { dx = 1, dz = z } end
  for x = 2, 9 do lit[#lit + 1] = { dx = x, dz = 8 } end
  maze.observe(session, lit)
  local route = maze.route(session, ROWS, 0, 2, "west", "north")
  local last = route[#route]
  assert.eq(last.dz, 10, "ends on the north row")
  assert.eq(#route, 7, "shortest: two tiles a tick, then up to the row")
  local safe = maze.safeTiles(session, ROWS, { "west", "north" })
  for _, t in ipairs(route) do
    assert.eq(safe[t.dx .. "," .. t.dz] ~= nil, true, "every step on a safe tile")
  end
end

function T.lit_tiles_outside_the_maze_or_on_their_own_are_ignored()
  local session = maze.newSession()
  maze.observe(session, { { dx = 1, dz = 4 }, { dx = 1, dz = 5 }, { dx = 20, dz = 5 }, { dx = 6, dz = 6 } })
  local safe = maze.safeTiles(session, ROWS, { "west", "north" })
  assert.eq(safe["1,4"] ~= nil, true, "path tile next to the start row")
  assert.eq(safe["1,5"] ~= nil, true, "path tile next to another")
  assert.eq(safe["20,5"], nil, "outside the maze")
  assert.eq(safe["6,6"], nil, "isolated misread")
end

function T.straight_finish_at_the_middle_of_the_end_row()
  local rows = {
    west = maze.row({ dx = 0, dz = 0 }, { dx = 0, dz = 4 }),
    north = maze.row({ dx = 0, dz = 12 }, { dx = 4, dz = 12 }),
  }
  local session = maze.newSession()
  local lit = {}
  for x = 0, 4 do
    for z = 5, 11 do lit[#lit + 1] = { dx = x, dz = z } end
  end
  maze.observe(session, lit)
  local route = maze.route(session, rows, 2, 4, "west", "north")
  local last = route[#route]
  assert.eq(last.dx .. "," .. last.dz, "2,12", "the middle of the row, straight ahead")
  for _, t in ipairs(route) do
    assert.eq(t.dx, 2, "no veering to the side")
  end
end

function T.safe_tiles_are_lit_or_on_the_legs_rows()
  local session = maze.newSession()
  maze.observe(session, { { dx = 2, dz = 4 } })
  assert.eq(maze.isSafe(session, ROWS, { "west", "north" }, 2, 4), true, "lit")
  assert.eq(maze.isSafe(session, ROWS, { "west", "north" }, 0, 3), true, "start row")
  assert.eq(maze.isSafe(session, ROWS, { "west", "north" }, -1, 3), false, "outside the maze")
end

function T.no_route_through_unlit_tiles()
  local session = maze.newSession()
  maze.observe(session, { { dx = 2, dz = 4 } })
  assert.eq(maze.route(session, ROWS, 0, 2, "west", "north"), nil, "gap too wide")
end

function T.path_is_kept_while_shown_and_cleared_after()
  local session = maze.newSession()
  maze.observe(session, { { dx = 1, dz = 1 } })
  maze.observe(session, { { dx = 2, dz = 2 } })
  assert.eq(maze.active(session), true, "lit")
  for _ = 1, maze.CLEAR_AFTER - 1 do maze.observe(session, {}) end
  assert.eq(maze.active(session), true, "a few empty reads keep it")
  maze.observe(session, {})
  assert.eq(maze.active(session), false, "cleared once gone")
end

function T.final_crystal_is_by_the_south_row()
  local rows = {}
  for n, p in pairs(require("data.maze").rows) do rows[n] = maze.row(p[1], p[2]) end
  assert.eq(maze.nearestBarrier(rows, -6, -95), "south", "the shutdown crystal")
  assert.eq(maze.nextBarrier("south"), nil, "no leg starts there")
end

return T
