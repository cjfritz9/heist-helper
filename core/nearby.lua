local M = {}

M.TELEPORT_TILES = 8

function M.distance(ax, az, bx, bz)
  return math.max(math.abs(ax - bx), math.abs(az - bz))
end

function M.nearest(objects, kind, x, z, reach)
  local best, bestDistance = nil, reach + 1
  for _, o in ipairs(objects) do
    if o.kind == kind then
      local d = M.distance(o.tileX, o.tileZ, x, z)
      if d < bestDistance then
        best, bestDistance = o, d
      end
    end
  end
  return best
end

function M.teleported(fromX, fromZ, toX, toZ)
  return fromX ~= nil and M.distance(fromX, fromZ, toX, toZ) > M.TELEPORT_TILES
end

return M
