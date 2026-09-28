local wizard = require("core.linkwizard")
local links = require("core.links")
local assert = require("tests.assert")

local T = {}

local closed = { vertices = 3444, fingerprint = "9f69f595", animated = false, colour = "11111111", textureHash = "aaaaaaaa" }
local open = { vertices = 3264, fingerprint = "8eaac06a", animated = false, colour = "22222222", textureHash = "bbbbbbbb" }

function T.full_change_flow()
  local w = wizard.new()
  wizard.start(w)
  assert.eq(wizard.useAnchor(w, -8, -63, "shadowAnchor"), true, "anchor")
  assert.eq(wizard.useBefore(w, closed, -3, -60), true, "before")
  assert.eq(wizard.useAfter(w, open, -3, -60), true, "after")
  local result = wizard.result(w)
  assert.eq(result.anchorDx, -8, "anchor dx")
  assert.eq(result.objectDz, -60, "object dz")
  assert.eq(links.mode(result), "change", "mode")
  assert.eq(wizard.status(w).mode, "change", "status mode")
end

function T.steps_must_happen_in_order()
  local w = wizard.new()
  wizard.start(w)
  assert.eq(wizard.useBefore(w, closed, 0, 0), false, "before needs anchor first")
  assert.eq(wizard.useAfter(w, open, 0, 0), false, "after needs before first")
  assert.eq(wizard.result(w), nil, "no result yet")
end

function T.after_must_be_the_same_tile()
  local w = wizard.new()
  wizard.start(w)
  wizard.useAnchor(w, -8, -63, "shadowAnchor")
  wizard.useBefore(w, closed, -3, -60)
  assert.eq(wizard.useAfter(w, open, -4, -60), false, "other tile rejected")
  assert.eq(wizard.status(w).step, "after", "still waiting")
end

function T.appear_flow_takes_position_from_after()
  local w = wizard.new()
  wizard.start(w)
  wizard.useAnchor(w, -8, -63, "shadowAnchor")
  assert.eq(wizard.skipBefore(w), true, "not visible yet")
  wizard.useAfter(w, open, 2, -58)
  local result = wizard.result(w)
  assert.eq(result.objectDx, 2, "position from after")
  assert.eq(links.mode(result), "appear", "mode")
end

function T.disappear_flow()
  local w = wizard.new()
  wizard.start(w)
  wizard.useAnchor(w, -8, -63, "shadowAnchor")
  wizard.useBefore(w, closed, -3, -60)
  assert.eq(wizard.markGone(w), true, "gone")
  assert.eq(links.mode(wizard.result(w)), "disappear", "mode")
end

function T.warns_when_nothing_changed_or_not_an_anchor()
  local w = wizard.new()
  wizard.start(w)
  wizard.useAnchor(w, 1, 1, "chest")
  assert.eq(wizard.status(w).message ~= nil, true, "not an anchor warning")
  wizard.useBefore(w, closed, 0, 0)
  wizard.useAfter(w, closed, 0, 0)
  assert.eq(links.mode(wizard.result(w)), "none", "identical")
  assert.eq(wizard.status(w).message ~= nil, true, "identical warning")
end

function T.watched_flicker_can_be_the_after_state()
  local w = wizard.new()
  wizard.start(w)
  wizard.useAnchor(w, 5, -94, "shadowAnchor")
  wizard.useBefore(w, { vertices = 2004, fingerprint = "a55442d9", animated = false, colour = "5ab4337c", textureHash = "96ff7ead" }, -6, -95)
  assert.eq(wizard.useAfterSignature(w, "2004:a55442d9:1:5ab4337c:96ff7ead", -6, -95), true, "flicker")
  assert.eq(links.mode(wizard.result(w)), "change", "change")
end

function T.watched_flicker_on_a_neighbouring_tile_moves_the_link()
  local w = wizard.new()
  wizard.start(w)
  wizard.useAnchor(w, 5, -94, "shadowAnchor")
  wizard.useBefore(w, { vertices = 2004, fingerprint = "a55442d9", animated = false, colour = "5ab4337c", textureHash = "96ff7ead" }, -6, -95)
  assert.eq(wizard.useAfterSignature(w, "300:12345678:1:00000000:00000000", -5, -95, true), true, "accepted")
  assert.eq(wizard.result(w).objectDx, -5, "link follows the flicker")
end

function T.cancel_resets()
  local w = wizard.new()
  wizard.start(w)
  wizard.useAnchor(w, -8, -63, "shadowAnchor")
  wizard.cancel(w)
  assert.eq(wizard.status(w).step, "idle", "idle")
end

return T
