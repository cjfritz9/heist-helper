local minimapicons = require("core.minimapicons")
local assert = require("tests.assert")

local T = {}

function T.every_shape_is_a_square_grid_of_known_pixels()
  for kind, shape in pairs(minimapicons.SHAPES) do
    for y, row in ipairs(shape) do
      assert.eq(#row, #shape[1], kind .. " row " .. y .. " width")
      assert.eq(row:find("[^%.kwcld]") == nil, true, kind .. " row " .. y .. " uses only palette letters")
    end
  end
end

function T.icons_render_to_rgba_in_the_kind_colour()
  local w, h, rgba = minimapicons.render("chest", { 255, 215, 0 })
  assert.eq(w .. "x" .. h, "11x11", "size")
  assert.eq(#rgba, w * h * 4, "four bytes a pixel")
  local at = function(x, y) local i = ((y - 1) * w + (x - 1)) * 4; return { rgba:byte(i + 1, i + 4) } end
  assert.eq(at(1, 1)[4], 0, "corner transparent")
  assert.eq(table.concat(at(2, 4), ","), "255,215,0,255", "body in the chest colour")
  assert.eq(at(1, 3)[1], 0, "black outline")
  assert.eq(minimapicons.render("nonsense", { 1, 2, 3 }), nil, "unknown kind")
  local w2, h2, big = minimapicons.render("chest", { 255, 215, 0 }, 2)
  assert.eq(w2 .. "x" .. h2 .. " " .. #big, "22x22 1936", "pixel-doubled")
  local i = ((8 - 1) * w2 + (4 - 1)) * 4
  assert.eq(table.concat({ big:byte(i + 1, i + 4) }, ","), "255,215,0,255", "each pixel doubled both ways")
end

return T
