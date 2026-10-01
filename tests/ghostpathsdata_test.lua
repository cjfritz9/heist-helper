local ghostpaths = require("core.ghostpaths")
local assert = require("tests.assert")

local T = {}

local loops = ghostpaths.prepare(require("data.ghostpaths"))

function T.four_patrols_with_their_measured_laps()
  local laps = {}
  for _, loop in ipairs(loops) do laps[loop.name] = loop.time.length end
  assert.eq(#loops, 4, "four patrols")
  assert.eq(laps["section 4"], 328, "section 4")
  assert.eq(laps["section 3 south"], 129, "section 3 south")
  assert.eq(laps["section 3 north"], 116, "section 3 north")
  assert.eq(laps["sections 1-2"], 155, "sections 1-2")
end

function T.every_step_is_one_tile_from_the_next()
  for _, loop in ipairs(loops) do
    local n = #loop.steps
    for i, s in ipairs(loop.steps) do
      local t = loop.steps[i % n + 1]
      local d = math.max(math.abs(s.x - t.x), math.abs(s.z - t.z))
      assert.eq(d, 1, string.format("%s step %d (%d,%d) to (%d,%d)", loop.name, i, s.x, s.z, t.x, t.z))
    end
  end
end

return T
