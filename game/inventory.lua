local picking = require("core.picking")
local lootprobe = require("game.lootprobe")

local M = {}

local SIGNATURE_POINTS = 8
local MAX_GLYPH_PIXELS = 24

local icons, glyphs, images = {}, {}, {}

function M.inspectIcon(event)
  local x, y, w, h = event:xywh()
  local models = event:modelcount()
  local counts, points = {}, {}
  for m = 1, models do
    counts[m] = event:modelvertexcount(m)
  end
  if models > 0 then
    for i = 1, math.min(counts[1], SIGNATURE_POINTS) do
      points[i] = { event:modelvertexpoint(1, i):get() }
    end
  end
  icons[#icons + 1] = {
    signature = models .. ":" .. table.concat(counts, ",") .. ":" .. picking.fingerprint(points),
    x = x, y = y, w = w, h = h,
  }
end

local MIN_POPUP_PIXELS, MAX_POPUP_PIXELS = 20, 48
local MAX_CACHED = 4000

local hashCache, cached = {}, 0

local cachedHash = function(event, ax, ay, aw, ah)
  local key = ax .. "," .. ay .. "," .. aw .. "," .. ah
  local hash = hashCache[key]
  if not hash then
    if cached >= MAX_CACHED then
      hashCache, cached = {}, 0
    end
    hash = lootprobe.pixelHash(event, ax, ay, aw, ah)
    hashCache[key] = hash
    cached = cached + 1
  end
  return hash
end

local unknownBitmap = function(event, hash, known, ax, ay, aw, ah)
  if known(hash) then return nil end
  return lootprobe.bitmap(event, hash, ax, ay, aw, ah)
end

function M.inspect2d(event, want)
  local perImage = event:verticesperimage()
  for i = 1, event:vertexcount(), perImage do
    local ax, ay, aw, ah = event:vertexatlasdetails(i)
    local small = aw <= MAX_GLYPH_PIXELS and ah <= MAX_GLYPH_PIXELS
    if aw > 0 and ah >= MIN_POPUP_PIXELS and ah <= MAX_POPUP_PIXELS and not small then
      local vx, vy = event:vertexscaledxy(i)
      if want.image(vx, vy) then
        local hash = cachedHash(event, ax, ay, aw, ah)
        images[#images + 1] = { x = vx, y = vy, hash = hash, w = aw, h = ah,
          bitmap = unknownBitmap(event, hash, want.known, ax, ay, aw, ah) }
      end
    elseif aw > 0 and ah > 0 and small then
      local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
      for v = i, i + 2 do
        local vx, vy = event:vertexscaledxy(v)
        minX, maxX = math.min(minX, vx), math.max(maxX, vx)
        minY, maxY = math.min(minY, vy), math.max(maxY, vy)
      end
      local r, g, b = event:vertexcolour(i)
      local cx, cy = (minX + maxX) / 2, (minY + maxY) / 2
      local colour = lootprobe.colourHex(r, g, b)
      local pixels = want.glyph(cx, cy, colour) and cachedHash(event, ax, ay, aw, ah) or nil
      glyphs[#glyphs + 1] = {
        x = cx, y = cy, id = ax .. "," .. ay .. "#" .. colour, colour = colour,
        pixels = pixels, w = aw, h = ah,
        bitmap = pixels and unknownBitmap(event, pixels, want.known, ax, ay, aw, ah) or nil,
      }
    end
  end
end

function M.takeFrame()
  local frameIcons, frameGlyphs, frameImages = icons, glyphs, images
  icons, glyphs, images = {}, {}, {}
  return frameIcons, frameGlyphs, frameImages
end

return M
