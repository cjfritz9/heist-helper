local lootpopups = require("core.lootpopups")
local assert = require("tests.assert")

local T = {}

local SECOND = 1000 * 1000
local FONT = { d1 = "1", d0 = "0", d2 = "2", L = "L", o = "o", t = "t", G = "G", a = "a", i = "i", n = "n", e = "e",
  d = "d", S = "S" }

local word = function(text, x, y)
  local glyphs = {}
  for i = 1, #text do
    glyphs[#glyphs + 1] = { x = x + i * 10, y = y, hash = text:sub(i, i) == "?" and "unknown" or text:sub(i, i) }
  end
  return glyphs
end

local popup = function(number, x, y)
  local glyphs = {}
  for _, h in ipairs(number) do
    glyphs[#glyphs + 1] = h
  end
  local out = {}
  local all = {}
  for _, h in ipairs(glyphs) do all[#all + 1] = h end
  for _, c in ipairs({ "L", "o", "o", "t", "G", "a", "i", "n", "e", "d" }) do all[#all + 1] = c end
  for i, h in ipairs(all) do
    out[i] = { x = x + i * 10, y = y + (i % 2), hash = h }
  end
  return out
end

local arriving = function(tracker, now, number, x, y)
  return lootpopups.update(tracker, now, lootpopups.lines(popup(number, x, y), FONT))
end

local join = function(...)
  local out = {}
  for _, list in ipairs({ ... }) do
    for _, g in ipairs(list) do out[#out + 1] = g end
  end
  return out
end

function T.reads_a_popup_line()
  local lines = lootpopups.lines(popup({ "d1", "d0" }, 100, 200), FONT)
  assert.eq(#lines, 1, "one line")
  assert.eq(lines[1].text, "10LootGained", "text")
  assert.eq(lootpopups.value(lines[1].text), 10, "value")
end

function T.unknown_digit_is_not_guessed()
  local lines = lootpopups.lines(popup({ "d1", "x7" }, 100, 200), FONT)
  assert.eq(lines[1].text, "1?LootGained", "marked")
  assert.eq(lines[1].unknown[1], "x7", "reported")
  assert.eq(lootpopups.value(lines[1].text), nil, "not counted")
  assert.eq(lootpopups.isLootLine(lines[1].text), true, "still a loot line")
end

function T.two_lines_at_once()
  local lines = lootpopups.lines(join(popup({ "d2" }, 100, 200), popup({ "d2" }, 100, 160)), FONT)
  assert.eq(#lines, 2, "two lines")
  assert.eq(lines[1].y < lines[2].y, true, "top first")
end

local values = function(ready)
  local out = {}
  for i, item in ipairs(ready) do out[i] = item.value end
  return table.concat(out, ",")
end

function T.each_popup_counted_once_as_it_rises()
  local tracker = lootpopups.newTracker()
  assert.eq(values(arriving(tracker, 0, { "d2" }, 100, 200)), "", "waits for its best reading")
  assert.eq(values(lootpopups.update(tracker, 0.1 * SECOND, lootpopups.lines(popup({ "d2" }, 100, 190), FONT))), "",
    "still settling")
  lootpopups.update(tracker, 0.2 * SECOND, {})
  local ready = lootpopups.update(tracker, 0.35 * SECOND, lootpopups.lines(popup({ "d2" }, 100, 185), FONT))
  assert.eq(values(ready), "2", "counted once settled, despite a missing frame")
  assert.eq(ready[1].at, 0, "timed from its first reading")
  lootpopups.update(tracker, 0.38 * SECOND, lootpopups.lines(join(popup({ "d2" }, 100, 181), popup({ "d2" }, 100, 200)), FONT))
  ready = lootpopups.update(tracker, 0.8 * SECOND,
    lootpopups.lines(join(popup({ "d2" }, 100, 170), popup({ "d2" }, 100, 190)), FONT))
  assert.eq(values(ready), "2", "second identical popup below the first")
end

function T.shortened_reading_is_replaced_by_the_full_number()
  local tracker = lootpopups.newTracker()
  arriving(tracker, 0, { "d2" }, 100, 200)
  lootpopups.update(tracker, 0.1 * SECOND, lootpopups.lines(popup({ "d1", "d2" }, 100, 195), FONT))
  local ready = lootpopups.update(tracker, 0.35 * SECOND, lootpopups.lines(popup({ "d1", "d2" }, 100, 190), FONT))
  assert.eq(values(ready), "12", "the longest reading wins")
end

function T.popup_gone_before_settling_still_counts()
  local tracker = lootpopups.newTracker()
  arriving(tracker, 0, { "d1", "d0" }, 100, 200)
  local ready = lootpopups.update(tracker, 2 * SECOND, {})
  assert.eq(values(ready), "10", "counted when it expires")
end

function T.popup_cut_off_on_the_right_is_the_same_popup()
  local tracker = lootpopups.newTracker()
  arriving(tracker, 0, { "d1", "d2" }, 100, 200)
  local cut = {}
  for i, g in ipairs(popup({ "d1", "d2" }, 100, 190)) do
    if i <= 6 then cut[#cut + 1] = g end
  end
  local lines = lootpopups.lines(cut, FONT)
  assert.eq(lines[1].text, "12Loot", "right side cut off")
  assert.eq(lootpopups.isLootLine(lines[1].text), true, "still a popup")
  local total = values(lootpopups.update(tracker, 0.5 * SECOND, lines))
  total = total .. values(lootpopups.update(tracker, 1.2 * SECOND, lootpopups.lines(popup({ "d1", "d2" }, 100, 180), FONT)))
  total = total .. values(lootpopups.update(tracker, 3 * SECOND, {}))
  assert.eq(total, "12", "counted once")
end

local amounts = function(counted)
  local out = {}
  for i, c in ipairs(counted) do out[i] = c.value end
  return table.concat(out, ",")
end

function T.each_popup_pairs_with_one_loot_action()
  local pairing = lootpopups.newPairing()
  lootpopups.popup(pairing, 0, 2)
  lootpopups.action(pairing, 0.3 * SECOND, "corpse")
  for i = 1, 10 do lootpopups.popup(pairing, (0.4 + i * 0.03) * SECOND, 2) end
  local counted = lootpopups.settle(pairing, 0.8 * SECOND)
  assert.eq(amounts(counted), "2", "one popup per action")
  local _, dropped = lootpopups.settle(pairing, 3 * SECOND)
  assert.eq(#dropped, 10, "readings of the same popup flying off are dropped")
end

function T.action_before_its_popup_still_pairs()
  local pairing = lootpopups.newPairing()
  lootpopups.action(pairing, 0, "safe", 3)
  assert.eq(#lootpopups.settle(pairing, 0.1 * SECOND), 0, "waiting for the popup")
  lootpopups.popup(pairing, 0.5 * SECOND, 30)
  local counted = lootpopups.settle(pairing, 0.6 * SECOND)
  assert.eq(amounts(counted), "30", "paired")
  assert.eq(counted[1].section, 3, "credited to the safe's section")
end

function T.leftover_chest_popup_cannot_take_a_rummage()
  local pairing = lootpopups.newPairing()
  lootpopups.popup(pairing, 0, 10)
  lootpopups.action(pairing, 0.1 * SECOND, "corpse")
  lootpopups.popup(pairing, 0.4 * SECOND, 2)
  local counted, dropped = lootpopups.settle(pairing, 2 * SECOND)
  assert.eq(amounts(counted), "2", "the rummage gets its own 2")
  assert.eq(table.concat(dropped, ","), "10", "the leftover 10 is dropped")
end

function T.doubled_rummage_and_shadow_chest_values_fit()
  local pairing = lootpopups.newPairing()
  lootpopups.action(pairing, 0, "corpse")
  lootpopups.popup(pairing, 0.1 * SECOND, 4)
  lootpopups.action(pairing, 1 * SECOND, "chest")
  lootpopups.popup(pairing, 1.1 * SECOND, 15)
  assert.eq(amounts(lootpopups.settle(pairing, 1.2 * SECOND)), "4,15", "both counted")
end

function T.popup_without_an_action_is_dropped_after_the_window()
  local pairing = lootpopups.newPairing()
  lootpopups.popup(pairing, 0, 10)
  lootpopups.action(pairing, 5 * SECOND, "chest")
  local counted, dropped = lootpopups.settle(pairing, 5 * SECOND)
  assert.eq(#counted, 0, "too far apart")
  assert.eq(dropped[1], 10, "dropped")
end

function T.partial_lines()
  assert.eq(lootpopups.isLootLine("Gained"), true, "number not drawn yet")
  assert.eq(lootpopups.isLootLine("15LootGa"), true, "right side cut")
  assert.eq(lootpopups.isLootLine("SpiritDisturbed|33%"), false, "other text")
  assert.eq(lootpopups.isLootLine("15"), false, "digits alone")
end

function T.other_text_is_ignored()
  local tracker = lootpopups.newTracker()
  local new = lootpopups.update(tracker, 0, lootpopups.lines(word("Spirit", 100, 200), FONT))
  assert.eq(#new, 0, "not a loot line")
end

return T
