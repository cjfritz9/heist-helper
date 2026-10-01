local lobby = require("core.lobby")
local assert = require("tests.assert")

local T = {}

function T.without_a_marked_area_it_is_the_bundled_entrance_rectangle()
  assert.eq(lobby.near(2490, 7580), true, "inside the bundled area")
  assert.eq(lobby.near(2487, 7584), true, "its corner counts")
  assert.eq(lobby.near(2496, 7580), false, "one tile outside")
  assert.eq(lobby.near(3297, 3184), false, "the first guess, which was Al Kharid")
  assert.eq(lobby.near(11299, 3243), false, "inside a vault instance")
  assert.eq(lobby.near(nil, nil), false, "position unknown")
end

function T.two_marked_corners_make_the_area()
  local area = lobby.new()
  area.a = { tileX = 3350, tileZ = 3200 }
  assert.eq(lobby.near(2490, 7580, area), true, "one corner isn't an area yet: still the bundled one")
  area.b = { tileX = 3340, tileZ = 3215 }
  assert.eq(lobby.near(3345, 3207, area), true, "inside, whichever way round the corners are")
  assert.eq(lobby.near(3350, 3215, area), true, "the edge counts")
  assert.eq(lobby.near(3351, 3207, area), false, "one tile outside")
  assert.eq(lobby.near(2490, 7580, area), false, "the bundled area no longer counts")
end

function T.the_area_survives_a_save_and_load()
  local area = lobby.new()
  area.a, area.b, area.always = { tileX = 3350, tileZ = 3200 }, { tileX = 3340, tileZ = 3215 }, true
  local again = lobby.decode(lobby.encode(area))
  assert.eq(again.a.tileX .. "," .. again.b.tileZ, "3350,3215", "corners kept")
  assert.eq(again.always, true, "keep-open switch kept")
  assert.eq(lobby.decode(nil).a, nil, "nothing saved yet")
end

return T
