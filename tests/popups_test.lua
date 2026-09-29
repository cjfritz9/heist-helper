local popups = require("core.popups")
local assert = require("tests.assert")

local T = {}

function T.boxes()
  assert.eq(popups.inside(popups.MOUSE_BOX, 100, 100, 390, 290), true, "tooltip beside the mouse")
  assert.eq(popups.inside(popups.PLAYER_BOX, 500, 450, 500, 560), false, "too far below the player")
  assert.eq(popups.inside(popups.PLAYER_BOX, 500, 450, 900, 400), true, "popup text to the right")
end

return T
