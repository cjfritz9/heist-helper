local coords = require("core.coords")
local lines = require("gfx.lines")

local M = {}

local COLOUR = { 60, 255, 90, 200 }
local THICKNESS = 2

local visible = function(depth)
  return depth and depth > 0 and depth <= 1
end

function M.draw(bolt, area, height, viewProj)
  if not area or not viewProj then return end
  local size = coords.TILE_SIZE
  local x0, z0 = (area.tileX - area.radius) * size, (area.tileZ - area.radius) * size
  local x1, z1 = (area.tileX + area.radius + 1) * size, (area.tileZ + area.radius + 1) * size
  local corners = { { x0, z0 }, { x1, z0 }, { x1, z1 }, { x0, z1 } }
  local screen = {}
  for i, c in ipairs(corners) do
    local sx, sy, depth = bolt.point(c[1], height, c[2]):transform(viewProj):togameview()
    if not visible(depth) then return end
    screen[i] = { sx, sy }
  end
  local edges = {}
  for i = 1, 4 do
    local a, b = screen[i], screen[i % 4 + 1]
    edges[i] = { a[1], a[2], b[1], b[2], colour = COLOUR }
  end
  local vx, vy, vw, vh = bolt.gameviewxywh()
  lines.setScreenDimensions(vw, vh)
  lines.drawLines(bolt, edges, THICKNESS, vx, vy)
end

return M
