local M = {}

local TILE_UNITS = 512

function M.corners(bolt, viewProj, anchor, centre, radius, height)
  local vx, vy, vw, vh = bolt.gameviewxywh()
  local out = { string.format("gameview,%d,%d,%d,%d", vx, vy, vw, vh), "dx,dz,x,y,depth" }
  for dz = centre.dz - radius, centre.dz + radius + 1 do
    for dx = centre.dx - radius, centre.dx + radius + 1 do
      local wx, wz = (anchor.x + dx) * TILE_UNITS, (anchor.z + dz) * TILE_UNITS
      local sx, sy, depth = bolt.point(wx, height, wz):transform(viewProj):togameview()
      out[#out + 1] = string.format("%d,%d,%.1f,%.1f,%.4f", dx, dz, sx + vx, sy + vy, depth)
    end
  end
  return table.concat(out, "\n") .. "\n"
end

function M.grid(bolt, viewProj, anchor, centre, radius, height)
  local vx, vy, vw, vh = bolt.gameviewxywh()
  local dx0, dz0 = centre.dx - radius, centre.dz - radius
  local n = radius * 2 + 2
  local pts = {}
  for j = 0, n - 1 do
    for i = 0, n - 1 do
      local wx, wz = (anchor.x + dx0 + i) * TILE_UNITS, (anchor.z + dz0 + j) * TILE_UNITS
      local sx, sy, depth = bolt.point(wx, height, wz):transform(viewProj):togameview()
      local ok = depth and depth > 0 and depth < 1
      pts[#pts + 1] = ok and math.floor(sx + vx + 0.5) or -1
      pts[#pts + 1] = ok and math.floor(sy + vy + 0.5) or -1
    end
  end
  return { dx0 = dx0, dz0 = dz0, n = n, gv = { vx, vy, vw, vh }, pts = pts }
end

return M
