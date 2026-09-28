local probediff = require("core.probediff")
local assert = require("tests.assert")

local T = {}

function T.diff_reports_added_and_removed_sorted()
  local added, removed = probediff.diff({ a = true, c = true }, { b = true, c = true, d = true })
  assert.eq(table.concat(added, " "), "b d", "added")
  assert.eq(table.concat(removed, " "), "a", "removed")
end

function T.no_change_writes_nothing()
  local added, removed = probediff.diff({ a = true }, { a = true })
  assert.eq(probediff.lines(12.5, added, removed), "", "empty")
end

function T.lines_are_stamped_with_seconds()
  local text = probediff.lines(12.5, { "p:64x64@0,1" }, { "m:4506:17aa0a87:0@0,0" })
  assert.eq(text, "[    12.5] + p:64x64@0,1\n[    12.5] - m:4506:17aa0a87:0@0,0\n", "text")
end

function T.relative_position_within_radius_only()
  assert.eq(probediff.relative(100, 200, 101, 198, 3), "1,-2", "near")
  assert.eq(probediff.relative(100, 200, 105, 200, 3), nil, "far")
end

return T
