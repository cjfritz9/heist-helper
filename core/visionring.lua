local M = {}

M.VERTICES = 6144
M.FINGERPRINT = "7552c143"
M.RADIUS_TILES = 4.52

local key = function(x, z)
  return x .. "," .. z
end

function M.mask(radiusTiles)
  local tiles, reach = {}, math.max(0, radiusTiles - 0.5)
  for ox = -math.floor(reach), math.floor(reach) do
    for oz = -math.floor(reach), math.floor(reach) do
      if ox * ox + oz * oz <= reach * reach then tiles[key(ox, oz)] = true end
    end
  end
  return tiles
end

function M.outline(mask)
  local edges = {}
  for k in pairs(mask) do
    local x, z = k:match("(-?%d+),(-?%d+)")
    x, z = tonumber(x), tonumber(z)
    if not mask[key(x - 1, z)] then edges[#edges + 1] = { x, z, x, z + 1 } end
    if not mask[key(x + 1, z)] then edges[#edges + 1] = { x + 1, z, x + 1, z + 1 } end
    if not mask[key(x, z - 1)] then edges[#edges + 1] = { x, z, x + 1, z } end
    if not mask[key(x, z + 1)] then edges[#edges + 1] = { x, z + 1, x + 1, z + 1 } end
  end
  return edges
end

function M.covers(mask, ringTileX, ringTileZ, tileX, tileZ)
  return mask[key(tileX - ringTileX, tileZ - ringTileZ)] == true
end

return M
