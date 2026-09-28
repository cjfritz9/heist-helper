local recording = require("core.recording")
local assert = require("tests.assert")

local T = {}

local ANCHOR = { x = 9763, z = 747 }
local OBJECTS = {
  { kind = "shadowAnchor", tileX = 9768, tileZ = 653 },
  { kind = "shadowAnchor", tileX = 9768, tileZ = 722 },
  { kind = "chest", tileX = 9769, tileZ = 654 },
}

local linkedOnly = function(dx, dz) return dx == 5 and dz == -25 end
local noneLinked = function() return false end

function T.starts_next_to_an_unlinked_anchor()
  local target = recording.chooseTarget(OBJECTS, 9767, 654, ANCHOR, noneLinked)
  assert.eq(target.tileZ, 653, "anchor 6")
end

function T.ignores_linked_anchors()
  assert.eq(recording.chooseTarget(OBJECTS, 9768, 721, ANCHOR, linkedOnly), nil, "anchor 1 is linked")
end

function T.needs_to_be_close()
  assert.eq(recording.chooseTarget(OBJECTS, 9760, 653, ANCHOR, noneLinked), nil, "8 tiles away")
  assert.eq(recording.chooseTarget(OBJECTS, 9767, 654, nil, noneLinked), nil, "no run anchor")
end

function T.stops_when_walking_away()
  local target = OBJECTS[1]
  assert.eq(recording.shouldStop(target, 9768 - 15, 653), false, "at the edge")
  assert.eq(recording.shouldStop(target, 9768 - 16, 653), true, "beyond")
end

function T.snapshot_lines_are_sorted_and_stamped()
  local text = recording.snapshotLines(12.5, { ["m|b"] = true, ["m|a"] = true })
  assert.eq(text, "[   12.50] = m|a\n[   12.50] = m|b\n", "snapshot")
  assert.eq(recording.snapshotLines(1, {}), "", "empty")
end

return T
