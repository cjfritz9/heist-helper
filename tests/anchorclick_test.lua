local anchorclick = require("core.anchorclick")
local assert = require("tests.assert")

local T = {}

local SECOND = 1000 * 1000
local OUTLINE = { { 100, 100 }, { 140, 100 }, { 140, 180 }, { 100, 180 } }

function T.click_inside_the_outline()
  assert.eq(anchorclick.contains(OUTLINE, 120, 150), true, "inside")
  assert.eq(anchorclick.contains(OUTLINE, 145, 150), true, "just outside, within margin")
  assert.eq(anchorclick.contains(OUTLINE, 300, 150), false, "elsewhere")
  assert.eq(anchorclick.contains({}, 120, 150), false, "no outline")
end

function T.ready_after_settling_next_to_it_without_batteries_in_view()
  local state = anchorclick.new()
  anchorclick.clicked(state, 5, -94, 0)
  assert.eq(anchorclick.ready(state, 1 * SECOND, 20, -94, false), nil, "still walking")
  assert.eq(anchorclick.ready(state, 5 * SECOND, 5, -95, false), nil, "just arrived")
  local dx, dz = anchorclick.ready(state, 9 * SECOND, 5, -95, false)
  assert.eq(dx, 5, "anchor dx")
  assert.eq(dz, -94, "anchor dz")
  assert.eq(anchorclick.ready(state, 10 * SECOND, 5, -95, false), nil, "used once")
end

function T.batteries_in_view_leave_it_to_the_battery_check()
  local state = anchorclick.new()
  anchorclick.clicked(state, 5, -94, 0)
  anchorclick.ready(state, 1 * SECOND, 5, -94, true)
  assert.eq(anchorclick.ready(state, 10 * SECOND, 5, -94, true), nil, "battery visible")
end

function T.old_clicks_expire()
  local state = anchorclick.new()
  anchorclick.clicked(state, 5, -94, 0)
  assert.eq(anchorclick.ready(state, 40 * SECOND, 5, -94, false), nil, "expired")
  assert.eq(state.click, nil, "cleared")
end

return T
