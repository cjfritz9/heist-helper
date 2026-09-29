local digitfont = require("core.digitfont")
local assert = require("tests.assert")

local T = {}

local pixel = function(rgba, w, x, y)
  local i = (y * w + x) * 4 + 1
  return rgba:sub(i, i + 3)
end

function T.size_includes_gaps_and_outline()
  local w, h, rgba = digitfont.render("10", 1)
  assert.eq(w, 3 + 1 + 3 + 2, "width")
  assert.eq(h, 5 + 2, "height")
  assert.eq(#rgba, w * h * 4, "bytes")
end

function T.digit_ink_is_white_and_outlined_in_black()
  local w, _, rgba = digitfont.render("1", 1)
  assert.eq(pixel(rgba, w, 2, 1), "\255\255\255\255", "top of the 1")
  assert.eq(pixel(rgba, w, 1, 0), "\0\0\0\255", "outline above-left")
  local w7, _, rgba7 = digitfont.render("7", 1)
  assert.eq(pixel(rgba7, w7, 0, 5), "\0\0\0\0", "clear away from the ink")
end

function T.scaling_repeats_pixels()
  local w1, h1 = digitfont.render("245", 1)
  local w3, h3, rgba = digitfont.render("245", 3)
  assert.eq(w3, w1 * 3, "width")
  assert.eq(h3, h1 * 3, "height")
  assert.eq(#rgba, w3 * h3 * 4, "bytes")
end

return T
