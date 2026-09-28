local M = {}

M.TILE_SIZE = 512
M.CHUNK_TILES = 64

function M.fromWorld(x, z)
  local tileX = math.floor(x / M.TILE_SIZE)
  local tileZ = math.floor(z / M.TILE_SIZE)
  return {
    tileX = tileX,
    tileZ = tileZ,
    chunkX = math.floor(tileX / M.CHUNK_TILES),
    chunkZ = math.floor(tileZ / M.CHUNK_TILES),
    localX = tileX % M.CHUNK_TILES,
    localZ = tileZ % M.CHUNK_TILES,
  }
end

return M
