local picking = require("core.picking")

local M = {}

local MAX_BITMAP_WIDTH, MAX_BITMAP_HEIGHT = 400, 64
local INK_LEVEL = 128

local bitmapped = {}

local pixelHash = function(event, x, y, w, h)
  if w <= 0 or h <= 0 then return "-" end
  local rows = {}
  for _, row in ipairs({ 0, math.floor(h / 2), h - 1 }) do
    local data = event:texturedata(x, y + row, w * 4)
    local bytes = {}
    for b = 1, #data do
      bytes[b] = data:byte(b)
    end
    rows[#rows + 1] = bytes
  end
  return picking.fingerprint(rows)
end

M.pixelHash = pixelHash

local colourHex = function(r, g, b)
  return string.format("%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

M.colourHex = colourHex

function M.bitmap(event, hash, x, y, w, h)
  if bitmapped[hash] or w > MAX_BITMAP_WIDTH or h > MAX_BITMAP_HEIGHT then return nil end
  bitmapped[hash] = true
  local rows = {}
  for row = 0, h - 1 do
    local data = event:texturedata(x, y + row, w * 4)
    local bits = {}
    for px = 0, w - 1 do
      local r, g, b, a = data:byte(px * 4 + 1, px * 4 + 4)
      bits[#bits + 1] = ((a or 0) >= INK_LEVEL and ((r or 0) + (g or 0) + (b or 0)) >= INK_LEVEL * 3) and "#" or "."
    end
    rows[#rows + 1] = table.concat(bits)
  end
  return table.concat(rows, "/")
end

return M
