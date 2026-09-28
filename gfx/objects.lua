local hull = require("core.hull")
local pips = require("core.pips")
local lines = require("gfx.lines")

local M = {}

local THICKNESS = 2
local ALPHA = 235
local PIP_EMPTY_ALPHA = 90

local COLOURS = {
  chest = { 255, 215, 0 },
  safe = { 0, 200, 255 },
  rareChest = { 255, 60, 220 },
  corpse = { 255, 140, 0 },
}

local pipQuads = function(quads, outline, progress, rgb)
  for _, p in ipairs(pips.layout(outline, progress.done, progress.total)) do
    quads[#quads + 1] = {
      p.x, p.y, p.x + p.w, p.y, p.x + p.w, p.y + p.h, p.x, p.y + p.h,
      colour = { rgb[1], rgb[2], rgb[3], p.filled and ALPHA or PIP_EMPTY_ALPHA },
    }
  end
end

function M.draw(bolt, objects)
  local edges, quads = {}, {}
  for _, o in ipairs(objects) do
    local outline = hull.convex(o.points or {})
    local rgb = COLOURS[o.kind]
    local colour = { rgb[1], rgb[2], rgb[3], ALPHA }
    for i = 1, #outline do
      local a, b = outline[i], outline[i % #outline + 1]
      edges[#edges + 1] = { a[1], a[2], b[1], b[2], colour = colour }
    end
    if o.progress then
      pipQuads(quads, outline, o.progress, rgb)
    end
  end
  if #edges == 0 then return end
  local vx, vy, vw, vh = bolt.gameviewxywh()
  lines.setScreenDimensions(vw, vh)
  lines.drawLines(bolt, edges, THICKNESS, vx, vy)
  lines.drawQuads(bolt, quads, vx, vy)
end

return M
