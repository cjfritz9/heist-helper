local coords = require("core.coords")
local markerdata = require("core.markerdata")
local lines = require("gfx.lines")

local M = {}

local DRAW_RADIUS_TILES = 48
local LINE_THICKNESS = 3
local OUTLINE_ALPHA = 230
local FILL_ALPHA = 55

local MARKER_COLOUR = { 255, 255, 255 }
local ARRIVAL_COLOUR = { 255, 210, 40 }

local withAlpha = function(rgb, alpha)
  return { rgb[1], rgb[2], rgb[3], alpha }
end

local markerColour = function(marker)
  if marker.arrival then
    return ARRIVAL_COLOUR
  end
  return MARKER_COLOUR
end

local visible = function(depth)
  return depth and depth > 0 and depth <= 1
end

local projectCorners = function(bolt, viewProj, marker)
  local size = coords.TILE_SIZE
  local x0, z0 = marker.tileX * size, marker.tileZ * size
  local corners = {
    { x0, z0 }, { x0 + size, z0 }, { x0 + size, z0 + size }, { x0, z0 + size },
  }
  local screen = {}
  for i, c in ipairs(corners) do
    local sx, sy, depth = bolt.point(c[1], marker.y, c[2]):transform(viewProj):togameview()
    if not visible(depth) then
      return nil
    end
    screen[i] = { sx, sy }
  end
  return screen
end

function M.draw(bolt, data, viewProj)
  if not viewProj then return end
  local position = bolt.playerposition()
  if not position then return end

  local px, _, pz = position:get()
  local player = coords.fromWorld(px, pz)
  local nearby = markerdata.nearby(data, player.tileX, player.tileZ, DRAW_RADIUS_TILES)
  if #nearby == 0 then return end

  local vx, vy, vw, vh = bolt.gameviewxywh()
  lines.setScreenDimensions(vw, vh)

  local quads, edges = {}, {}
  for _, marker in ipairs(nearby) do
    local s = projectCorners(bolt, viewProj, marker)
    if s then
      local rgb = markerColour(marker)
      quads[#quads + 1] = {
        s[1][1], s[1][2], s[2][1], s[2][2], s[3][1], s[3][2], s[4][1], s[4][2],
        colour = withAlpha(rgb, FILL_ALPHA),
      }
      local outline = withAlpha(rgb, OUTLINE_ALPHA)
      for i = 1, 4 do
        local a, b = s[i], s[i % 4 + 1]
        edges[#edges + 1] = { a[1], a[2], b[1], b[2], colour = outline }
      end
    end
  end

  lines.drawQuads(bolt, quads, vx, vy)
  lines.drawLines(bolt, edges, LINE_THICKNESS, vx, vy)
end

return M
