local routeassembly = require("core.routeassembly")
local assert = require("tests.assert")

local T = {}

local S = 1000 * 1000

local path = function(text)
  local out = {}
  for k in text:gmatch("%S+") do out[#out + 1] = k end
  return out
end

local walk = function(text, step)
  local out, at = {}, 0
  for x, z in text:gmatch("(%-?%d+),(%-?%d+)") do
    out[#out + 1] = { x = tonumber(x), z = tonumber(z), at = at }
    at = at + (step or 0.6) * S
  end
  return out
end

function T.clean_drops_repeats_and_corner_detours()
  local tiles = walk("0,0 1,0 1,0 2,0")
  assert.eq(table.concat(routeassembly.clean(tiles), " "), "0,0 1,0 2,0", "repeat dropped")
  local corner = { { x = 0, z = 0, at = 0 }, { x = 1, z = 0, at = 0.3 * S }, { x = 1, z = 1, at = 0.35 * S }, { x = 2, z = 2, at = 0.95 * S } }
  assert.eq(table.concat(routeassembly.clean(corner), " "), "0,0 1,1 2,2", "1,0 was only clipped on a diagonal")
  local turn = walk("0,0 1,0 1,1")
  assert.eq(table.concat(routeassembly.clean(turn), " "), "0,0 1,0 1,1", "a real L-turn a tick apart stays")
end

function T.a_missed_centre_between_two_tiles_is_filled_in()
  assert.eq(table.concat(routeassembly.clean(walk("-25,-18 -25,-16 -25,-15")), " "), "-25,-18 -25,-17 -25,-16 -25,-15", "straight")
  assert.eq(table.concat(routeassembly.clean(walk("0,0 2,2")), " "), "0,0 1,1 2,2", "two diagonal steps")
  assert.eq(table.concat(routeassembly.clean(walk("0,0 2,1")), " "), "0,0 2,1", "ambiguous: left alone")
end

function T.a_cut_corner_is_put_back_when_other_sightings_show_the_turn()
  local reads = { path("3,-56 3,-55 3,-54 4,-54 5,-54"), path("3,-56 3,-55 3,-54 4,-54"), path("3,-57 3,-56 3,-55 4,-54 5,-54") }
  routeassembly.fixCutCorners(reads)
  assert.eq(table.concat(reads[3], " "), "3,-57 3,-56 3,-55 3,-54 4,-54 5,-54", "the lone diagonal becomes the turn the others saw")
  local real = { path("0,0 1,1 2,2"), path("0,0 1,1") }
  routeassembly.fixCutCorners(real)
  assert.eq(table.concat(real[1], " "), "0,0 1,1 2,2", "a diagonal nobody saw as a turn stays")
end

function T.overlapping_sightings_join_into_one_route()
  local a = path("1 2 3 4 5 6 7 8 9 10")
  local b = path("5 6 7 8 9 10 11 12 13 14")
  local contigs = routeassembly.assemble({ a, b }, 4)
  assert.eq(#contigs, 1, "one route")
  assert.eq(table.concat(contigs[1], " "), "1 2 3 4 5 6 7 8 9 10 11 12 13 14", "joined on the overlap")
end

function T.separate_patrols_stay_apart()
  local contigs = routeassembly.assemble({ path("1 2 3 4 5 6"), path("a b c d e f"), path("3 4 5 6 7 8") }, 4)
  assert.eq(#contigs, 2, "two routes")
end

function T.a_sighting_inside_another_adds_nothing()
  local contigs = routeassembly.assemble({ path("1 2 3 4 5 6 7 8"), path("3 4 5 6") }, 4)
  assert.eq(#contigs, 1, "contained")
end

function T.a_lap_closes_on_a_short_wrap()
  local contig = path("13 14 15 16 15 14 13 12 11 10 9 8 7 6 7 8 9 10 11 12 13 14 15 16")
  local loop = routeassembly.loop(contig)
  assert.eq(loop and #loop, 20, "wraps round after 20 steps, overlapping 4")
end

function T.a_back_and_forth_patrol_closes_into_a_loop()
  local out = path("1 2 3 4 5 6 5 4 3 2")
  local sightings = { path("1 2 3 4 5 6 5 4"), path("5 6 5 4 3 2 1 2 3 4") }
  local contigs = routeassembly.assemble(sightings, 4)
  local loop = routeassembly.loop(contigs[1], 4)
  assert.eq(loop and #loop, #out, "ten steps out and back")
end

return T
