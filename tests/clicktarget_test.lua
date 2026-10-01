local clicktarget = require("core.clicktarget")
local assert = require("tests.assert")

local T = {}

local MS = 1000
local known = {
  crossInteract = { red1 = true }, crossWalk = { yellow1 = true },
  names = { shadowCrystal = "S h a d o w" },
}

local hover = function(state, letters, x, y, now)
  for i, h in ipairs(letters) do clicktarget.glyph(state, h, x + i * 8, y + (h == "d" and 4 or 0), "00ffff") end
  clicktarget.endFrame(state, now)
end

function T.the_text_under_the_mouse_names_what_was_clicked()
  local state = clicktarget.new(known)
  state.mouse = { x = 700, y = 400 }
  hover(state, { "h", "S", "a", "w", "o", "d" }, 800, 460, 100 * MS)
  assert.eq(state.text, "h S a w o d", "letters in x order, the lower one (a descender) still on the same line")
  local state2 = clicktarget.new(known)
  state2.mouse = { x = 700, y = 400 }
  for i, h in ipairs({ "S", "h", "a", "d", "o", "w" }) do clicktarget.glyph(state2, h, 800 + i * 8, 460, "00ffff") end
  clicktarget.glyph(state2, "x", 700, 460, "ffffff")
  clicktarget.endFrame(state2, 100 * MS)
  clicktarget.click(state2, 700, 400, 150 * MS)
  local r = clicktarget.image(state2, "red1", 708, 408, 170 * MS)
  assert.eq(r and r.kind, "interact", "the red cross at the click")
  assert.eq(r and r.name, "shadowCrystal", "on a shadow crystal")
end

function T.a_walk_click_and_stale_text_are_told_apart()
  local state = clicktarget.new(known)
  state.mouse = { x = 700, y = 400 }
  for i, h in ipairs({ "S", "h", "a", "d", "o", "w" }) do clicktarget.glyph(state, h, 800 + i * 8, 460, "00ffff") end
  clicktarget.endFrame(state, 100 * MS)
  clicktarget.click(state, 300, 300, 600 * MS)
  local r = clicktarget.image(state, "yellow1", 308, 308, 620 * MS)
  assert.eq(r.kind, "walk", "the walk cross")
  assert.eq(r.name, nil, "text from half a second ago doesn't count")
  assert.eq(clicktarget.image(state, "red1", 600, 600, 630 * MS), nil, "a cross away from any click is ignored")
end

function T.clicks_without_a_cross_are_forgotten()
  local state = clicktarget.new(known)
  clicktarget.click(state, 300, 300, 0)
  clicktarget.endFrame(state, 500 * MS)
  assert.eq(#state.clicks, 0, "no cross within 400 ms")
end

return T
