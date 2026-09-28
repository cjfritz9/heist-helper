local coords = require("core.coords")
local assert = require("tests.assert")

local T = {}

function T.world_units_to_tiles()
  local tile = coords.fromWorld(512 * 3200 + 100, 512 * 3100 + 511)
  assert.eq(tile.tileX, 3200, "tileX")
  assert.eq(tile.tileZ, 3100, "tileZ")
end

function T.chunk_and_local_coordinates()
  local tile = coords.fromWorld(512 * 3205, 512 * 3139)
  assert.eq(tile.chunkX, 50, "chunkX")
  assert.eq(tile.chunkZ, 49, "chunkZ")
  assert.eq(tile.localX, 5, "localX")
  assert.eq(tile.localZ, 3, "localZ")
end

function T.al_kharid_lodestone_landing_tile()
  local tile = coords.fromWorld(1688320, 1630464)
  assert.eq(tile.tileX, 3297, "tileX")
  assert.eq(tile.tileZ, 3184, "tileZ")
end

return T
