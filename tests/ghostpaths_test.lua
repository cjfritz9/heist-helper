local ghostpaths = require("core.ghostpaths")
local assert = require("tests.assert")

local T = {}

local square = {
  loops = {
    { name = "square", steps = {
      { x = 0, z = 0 }, { x = 1, z = 0 }, { x = 2, z = 0, stall = 2 }, { x = 2, z = 1 },
      { x = 2, z = 2 }, { x = 1, z = 2 }, { x = 0, z = 2 }, { x = 0, z = 1 },
    } },
    { name = "line", steps = {
      { x = 10, z = 0 }, { x = 11, z = 0 }, { x = 12, z = 0 }, { x = 13, z = 0 }, { x = 12, z = 0 }, { x = 11, z = 0 },
    } },
  },
}

local tiles = function(text)
  local out = {}
  for x, z in text:gmatch("(%-?%d+),(%-?%d+)") do out[#out + 1] = { x = tonumber(x), z = tonumber(z) } end
  return out
end

function T.a_stall_adds_ticks_on_its_tile()
  local loops = ghostpaths.prepare(square)
  assert.eq(loops[1].time.length, 10, "8 steps + 2 stall ticks")
  local at = function(ticks) local s = ghostpaths.stepAt(loops[1], 2, ticks) return s.x .. "," .. s.z end
  assert.eq(at(0), "1,0", "arrived on 1,0")
  assert.eq(at(1), "2,0", "next tick")
  assert.eq(at(3), "2,0", "stalls two more ticks")
  assert.eq(at(4), "2,1", "then moves on")
  assert.eq(at(10), "1,0", "a lap later, back where it arrived")
end

function T.recent_tiles_find_the_loop_and_step()
  local loops = ghostpaths.prepare(square)
  local found = ghostpaths.locate(loops, tiles("2,1 2,2 1,2 0,2"))
  assert.eq(found and found.loop, 1, "the square")
  assert.eq(found and found.step, 7, "on its 7th step")
  local wrap = ghostpaths.locate(loops, tiles("0,2 0,1 0,0 1,0"))
  assert.eq(wrap and wrap.step, 2, "across the end of the lap")
end

function T.back_and_forth_tiles_are_told_apart_by_direction()
  local loops = ghostpaths.prepare(square)
  assert.eq(ghostpaths.locate(loops, tiles("10,0 11,0 12,0 13,0")).step, 4, "going out")
  assert.eq(ghostpaths.locate(loops, tiles("12,0 13,0 12,0 11,0")).step, 6, "coming back")
end

function T.two_tiles_are_enough_when_only_one_place_fits()
  local loops = ghostpaths.prepare(square)
  local found = ghostpaths.locate(loops, tiles("1,0 2,0"))
  assert.eq(found and found.step, 3, "the only step from 1,0 to 2,0")
  assert.eq(ghostpaths.locate(loops, tiles("12,0 11,0")).step, 6, "coming back along the line")
end

function T.too_few_or_unknown_tiles_find_nothing()
  local loops = ghostpaths.prepare(square)
  assert.eq(ghostpaths.locate(loops, tiles("1,0")), nil, "one tile is too few")
  assert.eq(ghostpaths.locate(loops, tiles("5,5 6,5 7,5 8,5")), nil, "not on any loop")
end

return T
