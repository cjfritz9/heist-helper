local watchdetail = require("core.watchdetail")
local assert = require("tests.assert")

local T = {}

local IDENTITY = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 100, 200, 300, 1 }

local crystal = function(overrides)
  local d = { x = 100.4, y = 2181, z = 300, scale = 1, matrix = IDENTITY, textureId = 73, colour = { 10, 20, 30, 255 } }
  for k, v in pairs(overrides or {}) do
    d[k] = v
  end
  return watchdetail.model(d)
end

function T.model_detail_changes_with_each_field()
  local base = crystal()
  assert.eq(base:match("^pos 100,2181,300 scale 1.000") ~= nil, true, "position and scale")
  assert.eq(crystal() == base, true, "stable")
  assert.eq(crystal({ scale = 1.05 }) ~= base, true, "scale")
  assert.eq(crystal({ colour = { 10, 20, 30, 200 } }) ~= base, true, "colour")
  assert.eq(crystal({ textureId = 74 }) ~= base, true, "texture id")
  local rotated = { 0.999, 0.04, 0, 0, -0.04, 0.999, 0, 0, 0, 0, 1, 0, 100, 200, 300, 1 }
  assert.eq(crystal({ matrix = rotated }) ~= base, true, "small rotation")
  assert.eq(crystal({ pose = { IDENTITY } }):find(" pose ") ~= nil, true, "pose when animated")
end

function T.second_draw_of_the_same_model_is_a_change()
  local one, two = {}, {}
  watchdetail.add(one, "m|crystal@0,0", "a")
  watchdetail.add(two, "m|crystal@0,0", "a")
  watchdetail.add(two, "m|crystal@0,0", "a")
  local changes = watchdetail.changes(watchdetail.finish(one), watchdetail.finish(two))
  assert.eq(#changes, 1, "one change")
  assert.eq(changes[1].detail, "x2 a | a", "drawn twice")
end

function T.appearing_keys_are_not_detail_changes()
  local previous = watchdetail.finish({})
  local current = {}
  watchdetail.add(current, "p|64x64@0,0", "255,255,255,255")
  assert.eq(#watchdetail.changes(previous, watchdetail.finish(current)), 0, "left to the set diff")
end

function T.baseline_variants_are_counted_and_capped()
  local variants = watchdetail.newVariants()
  for i = 1, watchdetail.MAX_VARIANTS + 10 do
    watchdetail.track(variants, { ["m|a"] = "x1 " .. i, ["m|b"] = "x1 same" })
  end
  assert.eq(watchdetail.variantCount(variants, "m|a"), watchdetail.MAX_VARIANTS, "capped")
  assert.eq(watchdetail.variantCount(variants, "m|b"), 1, "steady")
  assert.eq(watchdetail.variantCount(variants, "m|c"), 0, "unknown")
end

function T.colour_is_scaled_to_bytes()
  assert.eq(watchdetail.colour(1, 0.5, 0, 1), "255,128,0,255", "bytes")
end

return T
