local tooltip = require("core.tooltip")
local assert = require("tests.assert")

local T = {}

local FONT = { L = "L", o = "o", t = "t", S = "S", r = "r", e = "e", d = "d", [":"] = ":", ["2"] = "2", ["3"] = "3",
  ["5"] = "5", U = "U", s = "s" }

local line = function(text, x, y)
  local glyphs = {}
  for i = 1, #text do
    local c = text:sub(i, i)
    glyphs[#glyphs + 1] = { x = x + i * 7, y = y + ((c == "d" or c == "t") and -1 or 1), hash = c }
  end
  return glyphs
end

local join = function(...)
  local out = {}
  for _, list in ipairs({ ... }) do
    for _, g in ipairs(list) do out[#out + 1] = g end
  end
  return out
end

function T.reads_loot_stored_from_its_line()
  local glyphs = join(line("UseStolen", 10, 100), line("LootStored:235", 10, 122))
  assert.eq(tooltip.lootStored(glyphs, FONT), 235, "value")
end

function T.unknown_digit_reads_nothing()
  local glyphs = line("LootStored:2x5", 10, 100)
  assert.eq(tooltip.lootStored(glyphs, FONT), nil, "not guessed")
end

function T.glyphs_in_any_order_become_lines()
  local glyphs = join(line("LootStored:5", 10, 122), line("Use", 10, 100))
  local reversed = {}
  for i = #glyphs, 1, -1 do reversed[#reversed + 1] = glyphs[i] end
  local lines = tooltip.lines(reversed, FONT)
  assert.eq(lines[1], "Use", "top line")
  assert.eq(lines[2], "LootStored:5", "second line")
end

function T.a_value_counts_once_it_reads_the_same_twice()
  local r = tooltip.newReconciler()
  assert.eq(tooltip.confirm(r, 235), nil, "first read")
  assert.eq(tooltip.confirm(r, 235), 235, "confirmed")
  assert.eq(tooltip.confirm(r, nil), nil, "hover ended")
  assert.eq(tooltip.confirm(r, 237), nil, "new value needs confirming")
end

return T
