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

return T
