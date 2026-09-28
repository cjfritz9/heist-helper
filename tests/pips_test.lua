local pips = require("core.pips")
local assert = require("tests.assert")

local T = {}

local OUTLINE = { { 100, 200 }, { 200, 200 }, { 200, 300 }, { 100, 300 } }

function T.five_pips_centred_above_the_outline()
  local row = pips.layout(OUTLINE, 3, 5)
  assert.eq(#row, 5, "count")
  local width = 5 * pips.SIZE + 4 * pips.GAP
  assert.eq(row[1].x, 150 - width / 2, "centred")
  assert.eq(row[1].y, 200 - pips.LIFT - pips.SIZE, "above top edge")
end

function T.fills_the_first_n()
  local row = pips.layout(OUTLINE, 3, 5)
  assert.eq(row[3].filled, true, "third filled")
  assert.eq(row[4].filled, false, "fourth empty")
end

function T.no_outline_no_pips()
  assert.eq(#pips.layout({}, 2, 5), 0, "nothing")
end

return T
