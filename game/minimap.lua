local lines = require("gfx.lines")
local minimapicons = require("core.minimapicons")

local M = {}

local TILE_UNITS = 512
local UNITS_PER_TERRAIN_PIXEL = 64
local DOT_PIXELS = 3
local EDGE_PIXELS = 4
local ANGLE_SIGN = 1
local EDGE_COLOUR = { 0, 0, 0, 230 }
local EDGE_EXTRA_PIXELS = 2
local ICON_SCALE = 2

local icons = {}
local STYLE_FILE = "minimap.csv"
local PNG_SETS = { native = true, digsite = true, spirit = true, mixed = true }
local STYLES = { "native", "pixel", "digsite", "spirit", "mixed" }
local style = STYLES[1]
local boltApi = nil

function M.init(bolt)
  boltApi = bolt
  local saved = (bolt.loadconfig(STYLE_FILE) or ""):match("style=(%a+)")
  for _, name in ipairs(STYLES) do
    if name == saved then style = saved end
  end
end

function M.style()
  return style
end

function M.cycleStyle()
  for i, name in ipairs(STYLES) do
    if name == style then
      style = STYLES[i % #STYLES + 1]
      break
    end
  end
  if boltApi then boltApi.saveconfig(STYLE_FILE, "style=" .. style .. "\n") end
end

local drawn = function(bolt, kind, rgb)
  if PNG_SETS[style] and bolt.createsurfacefrompng then
    local surface, w, h = bolt.createsurfacefrompng("icons." .. style .. "." .. kind)
    if surface then return { surface = surface, w = w, h = h } end
  end
  local w, h, rgba = minimapicons.render(kind == "ghostEstimate" and "ghost" or kind, rgb, ICON_SCALE)
  return w and { surface = bolt.createsurfacefromrgba(w, h, rgba), w = w, h = h } or false
end

local iconFor = function(bolt, kind, rgb)
  local key = style .. ":" .. kind .. ":" .. rgb[1] .. "," .. rgb[2] .. "," .. rgb[3]
  if icons[key] == nil then icons[key] = drawn(bolt, kind, rgb) end
  return icons[key]
end

local diamond = function(sx, sy, r, colour)
  return { sx, sy - r, sx + r, sy, sx, sy + r, sx - r, sy, colour = colour }
end

local terrain, target = nil, nil

function M.terrain(event)
  local x, y = event:position()
  terrain = { angle = event:angle(), scale = event:scale(), x = x, y = y }
end

function M.render(event)
  local tx, ty, tw, th = event:targetxywh()
  local _, _, sw = event:sourcexywh()
  target = { x = tx, y = ty, w = tw, h = th, sourceW = sw }
end

function M.project(worldX, worldZ)
  if not terrain or not target or not target.sourceW or target.sourceW == 0 then return nil end
  local perUnit = terrain.scale / UNITS_PER_TERRAIN_PIXEL * (target.w / target.sourceW)
  local dx, dz = worldX - terrain.x, worldZ - terrain.y
  local a = terrain.angle * ANGLE_SIGN
  local c, s = math.cos(a), math.sin(a)
  local rx, rz = dx * c - dz * s, dx * s + dz * c
  local cx, cy = target.x + target.w / 2, target.y + target.h / 2
  local sx, sy = cx + rx * perUnit, cy - rz * perUnit
  local radius = math.min(target.w, target.h) / 2 - EDGE_PIXELS
  if (sx - cx) ^ 2 + (sy - cy) ^ 2 > radius * radius then return nil end
  return sx, sy
end

function M.draw(bolt, anchor, dots)
  if not terrain or not target or not anchor then return end
  local quads, placed = {}, {}
  for _, d in ipairs(dots) do
    local sx, sy = M.project((anchor.x + d.dx + 0.5) * TILE_UNITS, (anchor.z + d.dz + 0.5) * TILE_UNITS)
    local icon = sx and d.icon and iconFor(bolt, d.icon, d.colour)
    if icon then
      placed[#placed + 1] = { icon = icon, x = sx, y = sy }
    elseif sx and d.size then
      quads[#quads + 1] = diamond(sx, sy, d.size + EDGE_EXTRA_PIXELS, EDGE_COLOUR)
      quads[#quads + 1] = diamond(sx, sy, d.size, d.colour)
    elseif sx then
      quads[#quads + 1] = { sx - DOT_PIXELS, sy - DOT_PIXELS, sx + DOT_PIXELS, sy - DOT_PIXELS,
        sx + DOT_PIXELS, sy + DOT_PIXELS, sx - DOT_PIXELS, sy + DOT_PIXELS, colour = d.colour }
    end
  end
  terrain, target = nil, nil
  if #quads > 0 then
    local w, h = bolt.gamewindowsize()
    lines.setScreenDimensions(w, h)
    lines.drawQuads(bolt, quads, 0, 0)
  end
  for _, p in ipairs(placed) do
    local i = p.icon
    i.surface:drawtoscreen(0, 0, i.w, i.h, math.floor(p.x - i.w / 2), math.floor(p.y - i.h / 2), i.w, i.h)
  end
end

return M
