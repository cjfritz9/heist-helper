local markerstore = require("core.markerstore")
local assert = require("tests.assert")

local T = {}

local seed = function()
  return {
    anchorX = 11299,
    anchorZ = 3243,
    markers = {
      { n = 0, dx = 0, dz = 0, y = 4933, section = "1", arrival = true },
      { n = 4, dx = 7, dz = 4, y = 4933, section = "1", arrival = false },
    },
  }
end

function T.copy_is_independent_of_seed()
  local original = seed()
  local copy = markerstore.copy(original)
  markerstore.toggle(copy, 11306, 3247, 4933)
  assert.eq(#original.markers, 2, "seed untouched")
  assert.eq(#copy.markers, 1, "copy changed")
end

function T.encode_decode_round_trip()
  local decoded = markerstore.decode(markerstore.encode(seed()))
  assert.eq(decoded.anchorX, 11299, "anchorX")
  assert.eq(decoded.anchorZ, 3243, "anchorZ")
  assert.eq(#decoded.markers, 2, "markers")
  assert.eq(decoded.markers[1].arrival, true, "arrival")
  assert.eq(decoded.markers[2].dx, 7, "dx")
  assert.eq(decoded.markers[2].section, "1", "section")
end

function T.decode_rejects_text_without_anchor()
  assert.eq(markerstore.decode("marker,1,2,3,1,0\n"), nil, "no anchor")
  assert.eq(markerstore.decode(""), nil, "empty")
end

function T.toggle_removes_existing_marker()
  local data = seed()
  assert.eq(markerstore.toggle(data, 11306, 3247, 4933), "removed", "result")
  assert.eq(#data.markers, 1, "count")
end

function T.toggle_adds_marker_relative_to_anchor()
  local data = seed()
  assert.eq(markerstore.toggle(data, 11300, 3240, 4932.6), "added", "result")
  local added = data.markers[3]
  assert.eq(added.dx, 1, "dx")
  assert.eq(added.dz, -3, "dz")
  assert.eq(added.y, 4933, "rounded height")
  assert.eq(added.arrival, false, "not arrival")
end

function T.toggle_twice_restores_state()
  local data = seed()
  markerstore.toggle(data, 11300, 3240, 4933)
  markerstore.toggle(data, 11300, 3240, 4933)
  assert.eq(#data.markers, 2, "count")
end

return T
