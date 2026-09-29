local digitfont = require("core.digitfont")

local M = {}

local SCALE = 2
local OFFSET_X, OFFSET_Y = 1, 1

local cached = { text = nil, surface = nil, w = 0, h = 0 }

local surfaceFor = function(bolt, text)
  if cached.text ~= text then
    local w, h, rgba = digitfont.render(text, SCALE)
    cached = { text = text, surface = bolt.createsurfacefromrgba(w, h, rgba), w = w, h = h }
  end
  return cached
end

function M.draw(bolt, icon, total)
  if not icon or not total then return end
  local s = surfaceFor(bolt, tostring(total))
  s.surface:drawtoscreen(0, 0, s.w, s.h, math.floor(icon.x + OFFSET_X), math.floor(icon.y + OFFSET_Y), s.w, s.h)
end

return M
