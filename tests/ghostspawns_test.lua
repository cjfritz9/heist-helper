local spawns = require("data.ghostspawns")
local assert = require("tests.assert")

local T = {}

function T.each_spawn_is_next_to_its_corpse()
  assert.eq(#spawns, 7, "seven known spawn tiles (corpse 11,-31's not seen yet)")
  for _, s in ipairs(spawns) do
    local d = math.max(math.abs(s.x - s.corpse.dx), math.abs(s.z - s.corpse.dz))
    assert.eq(d <= 4, true, string.format("spawn %d,%d within 4 tiles of corpse %d,%d", s.x, s.z, s.corpse.dx, s.corpse.dz))
  end
end

return T
