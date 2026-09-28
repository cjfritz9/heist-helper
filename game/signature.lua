local picking = require("core.picking")

local M = {}

local FINGERPRINT_VERTICES = 16
local COLOUR_SAMPLES = 64
local TEXTURE_SAMPLES = 32
local PIXEL_BYTES = 32

function M.fingerprint(event, count)
  local shape = {}
  for i = 1, math.min(count, FINGERPRINT_VERTICES) do
    shape[i] = { event:vertexpoint(i):get() }
  end
  return picking.fingerprint(shape)
end

function M.colour(event, count)
  local colours = {}
  for i = 1, count, picking.stride(count, COLOUR_SAMPLES) do
    local r, g, b, a = event:vertexcolour(i)
    colours[#colours + 1] = { r * 255, g * 255, b * 255, a * 255 }
  end
  return picking.fingerprint(colours)
end

function M.texture(event, count)
  local seen, parts = {}, {}
  for i = 1, count, picking.stride(count, TEXTURE_SAMPLES) do
    local meta = event:vertexmeta(i)
    if not seen[meta] then
      seen[meta] = true
      local x, y, w, h = event:atlasxywh(meta)
      local part = { w, h }
      if w > 0 and h > 0 then
        local pixels = event:texturedata(x + math.floor(w / 2), y + math.floor(h / 2), PIXEL_BYTES)
        for b = 1, #pixels do
          part[#part + 1] = pixels:byte(b)
        end
      end
      parts[#parts + 1] = part
    end
  end
  return picking.fingerprint(parts)
end

function M.of(event, count)
  return {
    vertices = count,
    fingerprint = M.fingerprint(event, count),
    animated = event:animated(),
    colour = M.colour(event, count),
    textureHash = M.texture(event, count),
  }
end

return M
