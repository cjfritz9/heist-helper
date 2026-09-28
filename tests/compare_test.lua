local compare = require("core.compare")
local assert = require("tests.assert")

local T = {}

local candidate = function(overrides)
  local c = {
    vertices = 3444, fingerprint = "9f69f595", animated = false, shape = "23d533a3", uv = "5c0fe0b6",
    colour = "11111111", textureHash = "aaaaaaaa", tileX = 7262, tileZ = 4955,
    box = { minX = 100, maxX = 148, minY = 200, maxY = 289 },
  }
  for k, v in pairs(overrides or {}) do c[k] = v end
  return c
end

function T.snapshot_is_relative_to_anchor()
  local s = compare.snapshot(candidate(), 7267, 4971)
  assert.eq(s.tile, "-5,-16", "tile")
  assert.eq(s.size, "48x89", "size")
  assert.eq(s.animated, "no", "animated")
end

function T.identical_objects()
  local a, b = compare.snapshot(candidate()), compare.snapshot(candidate({ box = { minX = 0, maxX = 10, minY = 0, maxY = 10 } }))
  assert.eq(compare.verdict(a, b), "Identical in everything Bolt can see", "size alone doesn't count")
end

function T.texture_only_difference()
  local a, b = compare.snapshot(candidate()), compare.snapshot(candidate({ textureHash = "bbbbbbbb" }))
  assert.eq(compare.verdict(a, b), "Differs in: Texture", "texture")
  local rows = compare.diff(a, b)
  local textureRow
  for _, r in ipairs(rows) do if r.label == "Texture" then textureRow = r end end
  assert.eq(textureRow.same, false, "row marked different")
end

function T.several_differences_listed_in_order()
  local a = compare.snapshot(candidate())
  local b = compare.snapshot(candidate({ vertices = 3264, fingerprint = "8eaac06a", animated = true }))
  assert.eq(compare.verdict(a, b), "Differs in: Vertices, Model, Animated", "list")
end

function T.half_done_comparison_has_no_verdict()
  local rows = compare.diff(compare.snapshot(candidate()), nil)
  assert.eq(compare.verdict(compare.snapshot(candidate()), nil), nil, "no verdict")
  assert.eq(rows[1].after, "", "empty after")
end

return T
