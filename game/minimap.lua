local lines = require("gfx.lines")

local M = {}

local TILE_UNITS = 512
local UNITS_PER_TERRAIN_PIXEL = 64
local DOT_PIXELS = 3
local EDGE_PIXELS = 4
local ANGLE_SIGN = 1
local SAME_FLOOR_HEIGHT = 400
local EDGE_COLOUR = { 0, 0, 0, 230 }
local EDGE_EXTRA_PIXELS = 2

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

function M.draw(bolt, anchor, height, dots)
  if not terrain or not target or not anchor then return end
  local quads = {}
  for _, d in ipairs(dots) do
    if not d.y or not height or math.abs(d.y - height) <= SAME_FLOOR_HEIGHT then
      local sx, sy = M.project((anchor.x + d.dx + 0.5) * TILE_UNITS, (anchor.z + d.dz + 0.5) * TILE_UNITS)
      if sx and d.size then
        quads[#quads + 1] = diamond(sx, sy, d.size + EDGE_EXTRA_PIXELS, EDGE_COLOUR)
        quads[#quads + 1] = diamond(sx, sy, d.size, d.colour)
      elseif sx then
        quads[#quads + 1] = { sx - DOT_PIXELS, sy - DOT_PIXELS, sx + DOT_PIXELS, sy - DOT_PIXELS,
          sx + DOT_PIXELS, sy + DOT_PIXELS, sx - DOT_PIXELS, sy + DOT_PIXELS, colour = d.colour }
      end
    end
  end
  terrain, target = nil, nil
  if #quads == 0 then return end
  local w, h = bolt.gamewindowsize()
  lines.setScreenDimensions(w, h)
  lines.drawQuads(bolt, quads, 0, 0)
end

return M
