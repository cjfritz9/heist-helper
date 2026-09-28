local coords = require("core.coords")

local M = {}

M.HEADER = "n,worldX,worldY,worldZ,tileX,tileZ,chunkX,chunkZ,localX,localZ\n"

function M.countRows(text)
  local lines = select(2, text:gsub("\n", ""))
  return math.max(0, lines - 1)
end

function M.row(n, x, y, z)
  local tile = coords.fromWorld(x, z)
  return string.format("%d,%.0f,%.0f,%.0f,%d,%d,%d,%d,%d,%d\n",
    n, x, y, z,
    tile.tileX, tile.tileZ,
    tile.chunkX, tile.chunkZ, tile.localX, tile.localZ)
end

return M
