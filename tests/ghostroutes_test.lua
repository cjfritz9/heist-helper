local ghostroutes = require("core.ghostroutes")
local assert = require("tests.assert")

local T = {}

local MS = 1000

local ev = function(kind, at, tileX, tileZ, extra)
  local e = { kind = kind, id = 1, at = at * MS, tileX = tileX, tileZ = tileZ, y = 2176 }
  for k, v in pairs(extra or {}) do e[k] = v end
  return e
end

local feed = function(map, events)
  for _, e in ipairs(events) do ghostroutes.observe(map, e) end
  return ghostroutes.encode(map)
end

function T.walking_records_moves_with_ticks()
  local map = ghostroutes.new()
  local text = feed(map, {
    ev("appear", 0, 10, 20),
    ev("start", 100, 10, 20, { still = 100 * MS }),
    ev("tile", 400, 11, 20),
    ev("tile", 1000, 12, 20),
    ev("tile", 1610, 13, 20),
  })
  assert.eq(text, "move,2176,10,20,2176,11,20,-,1\nmove,2176,11,20,2176,12,20,1,1\nmove,2176,12,20,2176,13,20,1,1\n",
    "first step after a start has no tick count, the rest one tick each")
end

function T.stops_are_counted_only_when_seen_starting()
  local map = ghostroutes.new()
  local text = feed(map, {
    ev("appear", 0, 10, 20),
    ev("start", 2000, 10, 20, { still = 2000 * MS }),
    ev("tile", 2300, 11, 20),
    ev("stop", 2500, 11, 20, { moving = 200 * MS }),
    ev("start", 4300, 11, 20, { still = 1800 * MS }),
  })
  assert.eq(text, "move,2176,10,20,2176,11,20,-,1\nstop,2176,11,20,3,1\n", "the stop seen from its beginning: 3 ticks; the first one wasn't")
end

function T.corner_crossings_merge_into_one_diagonal_move()
  local map = ghostroutes.new()
  local text = feed(map, {
    ev("appear", 0, 10, 20),
    ev("start", 100, 10, 20, { still = 100 * MS }),
    ev("tile", 400, 11, 20),
    ev("tile", 1000, 12, 20),
    ev("tile", 1050, 12, 21),
    ev("tile", 1600, 13, 22),
  })
  assert.eq(text, "move,2176,10,20,2176,11,20,-,1\nmove,2176,11,20,2176,12,20,1,1\nmove,2176,12,20,2176,13,22,1,1\n",
    "the brief 12,21 crossing is folded into the diagonal")
end

function T.counts_add_up_and_survive_a_reload()
  local map = ghostroutes.new()
  local walk = { ev("appear", 0, 1, 1), ev("start", 10, 1, 1, { still = 10 * MS }), ev("tile", 300, 2, 1), ev("lost", 900, 2, 1) }
  feed(map, walk)
  local again = ghostroutes.decode(ghostroutes.encode(map))
  assert.eq(feed(again, walk), "move,2176,1,1,2176,2,1,-,2\n", "seen twice")
end

function T.stall_lengths_from_real_stops()
  local stall = function(seconds) return ghostroutes.stallTicks(seconds * 1000 * MS) end
  assert.eq(stall(0.43), 0, "a pause at a corner is no stall")
  assert.eq(stall(0.69), 1, "short end of a 1-tick stall")
  assert.eq(stall(1.02), 1, "long end of a 1-tick stall")
  assert.eq(stall(1.93), 3, "short end of a 3-tick stall")
  assert.eq(stall(2.21), 3, "long end of a 3-tick stall")
  assert.eq(stall(3.78), 6, "a 6-tick stall")
end

function T.a_corner_pause_is_not_recorded_as_a_stop()
  local map = ghostroutes.new()
  local text = feed(map, {
    ev("appear", 0, 10, 20),
    ev("start", 100, 10, 20, { still = 100 * MS }),
    ev("tile", 400, 11, 20),
    ev("stop", 700, 11, 20, { moving = 600 * MS }),
    ev("start", 1000, 11, 20, { still = 300 * MS }),
  })
  assert.eq(text, "move,2176,10,20,2176,11,20,-,1\n", "0.3 s at a turn: no stop line")
end

function T.floors_keep_stacked_routes_apart()
  local map = ghostroutes.new()
  assert.eq(ghostroutes.floorOf(map, 2176), 2176, "first floor")
  assert.eq(ghostroutes.floorOf(map, 2181.6), 2176, "a wobble stays on it")
  assert.eq(ghostroutes.floorOf(map, 2944), 2944, "a new floor")
  local upstairs = { kind = "appear", id = 2, at = 0, tileX = 1, tileZ = 1, y = 2944 }
  ghostroutes.observe(map, upstairs)
  ghostroutes.observe(map, { kind = "start", id = 2, at = 10 * MS, tileX = 1, tileZ = 1, y = 2944, still = 10 * MS })
  ghostroutes.observe(map, { kind = "tile", id = 2, at = 300 * MS, tileX = 2, tileZ = 1, y = 2944 })
  assert.eq(ghostroutes.encode(map), "move,2944,1,1,2944,2,1,-,1\n", "same x,z as a lower route, different floor")
end

function T.flicker_back_onto_the_same_tile_is_not_a_move()
  local map = ghostroutes.new()
  local text = feed(map, {
    ev("appear", 0, 10, 20),
    ev("start", 100, 10, 20, { still = 100 * MS }),
    ev("tile", 200, 10, 21),
    ev("tile", 900, 11, 21),
    ev("tile", 1000, 11, 21),
  })
  assert.eq(text, "move,2176,10,20,2176,10,21,-,1\nmove,2176,10,21,2176,11,21,1,1\n", "no self-move")
end

function T.old_lines_without_a_height_are_set_aside()
  local map = ghostroutes.decode("move,-25,-13,-25,-12,-,1\nstop,-25,-12,4,1\nmove,2176,1,1,2176,2,1,1,3\n")
  assert.eq(#map.legacy, 2, "two old lines kept aside")
  assert.eq(ghostroutes.encode(map), "move,2176,1,1,2176,2,1,1,3\n", "only the new format is kept")
end

return T
