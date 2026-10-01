local mazepatterns = require("core.mazepatterns")
local assert = require("tests.assert")

local T = {}

local library = mazepatterns.fromShapes(require("data.mazeshapes"))

local tiles = function(text)
  local list = {}
  for dx, dz in text:gmatch("(%-?%d+),(%-?%d+)") do list[#list + 1] = { dx = tonumber(dx), dz = tonumber(dz) } end
  return (mazepatterns.set(list))
end

local CAPTURED = "-12,-73 -12,-74 -12,-75 -12,-76 -12,-77 -11,-77 -10,-77 -9,-77 -8,-77 -8,-76 -8,-75 -8,-74 -8,-73 "
  .. "-8,-72 -8,-71 -8,-70 -7,-70 -6,-70 -5,-70 -4,-70 -3,-70 -2,-70 -1,-70"
local WEST_ROW = tiles("-12,-73 -12,-74 -12,-75 -12,-76 -12,-77")

function T.three_shapes_on_every_leg()
  for _, leg in ipairs({ "west-north", "north-east", "east-south" }) do
    assert.eq(#library[leg], 3, leg)
  end
end

function T.captured_west_path_is_shape_A()
  local best, why = mazepatterns.match(library["west-north"], tiles(CAPTURED), WEST_ROW)
  assert.eq(best and library["west-north"][best].name, "A", why)
end

function T.part_of_the_path_is_enough()
  local best, why = mazepatterns.match(library["west-north"], tiles("-11,-77 -10,-77 -9,-77 -8,-77 -8,-76 -8,-75 -8,-74"), WEST_ROW)
  assert.eq(best and library["west-north"][best].name, "A", why)
end

function T.pylon_glare_does_not_stop_a_match()
  local glare = " -1,-82 1,-82 1,-83 -1,-85 -2,-80 -4,-82 12,-82"
  local best, why = mazepatterns.match(library["west-north"], tiles(CAPTURED .. glare), WEST_ROW)
  assert.eq(best and library["west-north"][best].name, "A", why)
end

function T.four_tiles_of_one_shape_are_enough()
  local best, why = mazepatterns.match(library["west-north"], tiles("-11,-77 -10,-77 -9,-77 -8,-77 0,-79 1,-81"), WEST_ROW)
  assert.eq(best and library["west-north"][best].name, "A", why)
  best = mazepatterns.match(library["west-north"], tiles("-11,-77 -10,-77 -9,-77 0,-79"), WEST_ROW)
  assert.eq(best, nil, "three is not")
end

function T.too_little_seen()
  local best, why = mazepatterns.match(library["west-north"], tiles("-11,-77 -10,-77"), WEST_ROW)
  assert.eq(best, nil, "two tiles")
  assert.eq(why, "only 2 path tiles on any known shape", "reason")
end

function T.every_shape_starts_next_to_its_start_row_and_ends_on_its_end_row()
  local maze = require("core.maze")
  local rowsData = require("data.maze").rows
  local rows = {}
  for n, p in pairs(rowsData) do rows[n] = maze.row(p[1], p[2]) end
  for leg, patterns in pairs(library) do
    local start, finish = leg:match("^(%a+)%-(%a+)$")
    for _, p in ipairs(patterns) do
      local route = maze.route({ lit = p.tiles }, rows, rows[start][3].dx, rows[start][3].dz, start, finish)
      assert.eq(route ~= nil, true, leg .. " shape " .. p.name .. " has a route")
    end
  end
end

function T.corners_keep_the_in_between_tile_on_the_path()
  local maze = require("core.maze")
  local rows = {}
  for n, p in pairs(require("data.maze").rows) do rows[n] = maze.row(p[1], p[2]) end
  local route = maze.route({ lit = library["west-north"][1].tiles }, rows, -12, -73, "west", "north")
  local out = {}
  for i, t in ipairs(route) do out[i] = t.dx .. "," .. t.dz end
  assert.eq(table.concat(out, " "), "-12,-75 -10,-77 -8,-75 -8,-73 -8,-71 -6,-70 -4,-70 -3,-70",
    "diagonal round the first corner, the 2-and-1 move where its in-between tile is on the path, and out at the nearest end-row tile")
end

function T.timeline_counts_shape_tiles_per_frame()
  local pattern = tiles("1,1 1,2 1,3")
  local frames = {
    { seconds = 1.04, tiles = { { dx = 9, dz = 9 } } },
    { seconds = 1.6, tiles = { { dx = 1, dz = 1 }, { dx = 1, dz = 2 }, { dx = 0, dz = 0 } } },
    { seconds = 2.1, tiles = { { dx = 1, dz = 2 }, { dx = 1, dz = 3 } } },
  }
  assert.eq(mazepatterns.timeline(frames, pattern, tiles("1,3")), "1.04s 0 (+0), 1.60s 2 (+2), 2.10s 1 (+0)", "timeline")
end

function T.east_south_shape_C_runs_two_tiles_until_the_last_step()
  local maze = require("core.maze")
  local rows = {}
  for n, p in pairs(require("data.maze").rows) do rows[n] = maze.row(p[1], p[2]) end
  local shape
  for _, p in ipairs(library["east-south"]) do
    if p.name == "C" then shape = p end
  end
  local route = maze.route({ lit = shape.tiles }, rows, 10, -79, "east", "south")
  local x, z = 10, -79
  for i, t in ipairs(route) do
    local step = math.max(math.abs(t.dx - x), math.abs(t.dz - z))
    if i < #route then assert.eq(step, 2, "run step " .. i .. " to " .. t.dx .. "," .. t.dz) end
    x, z = t.dx, t.dz
  end
  assert.eq(#route, 10, "no slower than before")
end

return T
