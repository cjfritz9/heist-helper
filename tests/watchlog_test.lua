local watchlog = require("core.watchlog")
local assert = require("tests.assert")

local T = {}

local SECOND = 1000 * 1000
local CRYSTAL = "m|2004:a55442d9:0:5ab4337c:96ff7ead@0,0"
local FLICKER = "m|2004:a55442d9:1:5ab4337c:11111111@0,0"
local PIECE = "m|24:f9b9e5f4:0:9bd3bf8d:b2bfa8a5@0,0"
local AMBIENT = "p|64x64@1,0"

local baseline = function(frames, extra)
  local log = watchlog.new()
  for i = 1, frames do
    local seen = { [CRYSTAL] = true, [PIECE] = true }
    if extra and extra(i) then seen[AMBIENT] = true end
    watchlog.observe(log, i * 16000, seen)
  end
  return log
end

function T.nothing_is_reported_until_armed()
  local log = baseline(100)
  assert.eq(watchlog.inBaseline(log), true, "still baseline")
  watchlog.observe(log, 5 * SECOND, { [FLICKER] = true })
  assert.eq(#watchlog.items(log), 0, "flicker during baseline is background")
end

function T.flicker_after_arming_is_reported()
  local log = baseline(100)
  watchlog.arm(log, 10 * SECOND)
  watchlog.observe(log, 11 * SECOND, { [FLICKER] = true, [PIECE] = true })
  watchlog.observe(log, 11.02 * SECOND, { [FLICKER] = true, [PIECE] = true })
  watchlog.observe(log, 11.5 * SECOND, { [CRYSTAL] = true, [PIECE] = true })
  local items = watchlog.items(log)
  assert.eq(#items, 2, "flicker appeared, steady crystal briefly gone")
  local appeared
  for _, item in ipairs(items) do
    if item.change == "+" then appeared = item end
  end
  assert.eq(appeared.signature, FLICKER, "flicker")
  assert.eq(appeared.frames, 2, "two frames")
  assert.eq(appeared.first, 1, "one second after arming")
end

function T.looping_background_effects_are_ignored()
  local log = baseline(100, function(i) return i % 10 < 3 end)
  watchlog.arm(log, 10 * SECOND)
  watchlog.observe(log, 11 * SECOND, { [CRYSTAL] = true, [PIECE] = true })
  watchlog.observe(log, 12 * SECOND, { [CRYSTAL] = true, [PIECE] = true, [AMBIENT] = true })
  assert.eq(#watchlog.items(log), 0, "ambient neither appears nor disappears")
end

function T.closing_the_window_stops_recording()
  local log = baseline(10)
  assert.eq(watchlog.close(log), false, "can't close before opening")
  watchlog.arm(log, 1 * SECOND)
  watchlog.observe(log, 2 * SECOND, { [FLICKER] = true, [CRYSTAL] = true, [PIECE] = true })
  assert.eq(watchlog.close(log), true, "closed")
  watchlog.observe(log, 3 * SECOND, { ["p|late"] = true, [CRYSTAL] = true, [PIECE] = true })
  assert.eq(#watchlog.items(log), 1, "only the change inside the window")
end

function T.arming_twice_keeps_first_time()
  local log = baseline(10)
  assert.eq(watchlog.arm(log, 1 * SECOND), true, "armed")
  assert.eq(watchlog.arm(log, 2 * SECOND), false, "already armed")
  assert.eq(log.armedAt, 1 * SECOND, "first time kept")
end

function T.baseline_size_counts_background_things()
  assert.eq(watchlog.baselineSize(baseline(10, function() return true end)), 3, "crystal, piece, ambient")
end

function T.items_are_capped()
  local log = baseline(5)
  watchlog.arm(log, 0)
  local seen = {}
  for i = 1, 20 do seen["p|" .. i] = true end
  watchlog.observe(log, 2 * SECOND, seen)
  assert.eq(#watchlog.items(log), watchlog.MAX_ITEMS, "capped")
end

function T.describe_models_and_others()
  local label, linkSignature, dx, dz = watchlog.describe("m|2004:a55442d9:1:5ab4337c:11111111@1,-1")
  assert.eq(label, "model 2004v a55442d9 animated col 5ab4337c tex 11111111 @1,-1", "model label")
  assert.eq(linkSignature, "2004:a55442d9:1:5ab4337c:11111111", "usable for links")
  assert.eq(dx, 1, "offset x")
  assert.eq(dz, -1, "offset z")
  local particleLabel, particleSignature = watchlog.describe("p|64x64@0,0")
  assert.eq(particleLabel, "particles 64x64@0,0", "particle label")
  assert.eq(particleSignature, nil, "particles can't be linked yet")
end

return T
