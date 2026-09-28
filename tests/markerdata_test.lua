local markerdata = require("core.markerdata")
local assert = require("tests.assert")

local T = {}

local CSV = table.concat({
  "n,worldX,worldY,worldZ,tileX,tileZ,chunkX,chunkZ,localX,localZ",
  "0,5785344,4933,1660672,11299,3243,176,50,35,43",
  "4,5788928,4933,1662720,11306,3247,176,50,42,47",
  "32,5795584,2181,1624064,11319,3170,176,49,55,34",
  "33,5795584,2181,1624064,11319,3170,176,49,55,34",
  "3,1253120,8228,3897976,2447,7613,7,38,118,15,61",
}, "\n")

local SECTIONS = { [4933] = "1", [2181] = "4" }

function T.parse_skips_header_and_old_format_rows()
  local rows = markerdata.parseCsv(CSV)
  assert.eq(#rows, 4, "rows")
  assert.eq(rows[1].n, 0, "first row")
  assert.eq(rows[2].tileX, 11306, "tileX")
  assert.eq(rows[2].y, 4933, "height")
end

function T.build_uses_first_row_as_anchor()
  local data = markerdata.build(markerdata.parseCsv(CSV), SECTIONS)
  assert.eq(data.anchorX, 11299, "anchorX")
  assert.eq(data.anchorZ, 3243, "anchorZ")
  assert.eq(data.markers[1].arrival, true, "arrival flag")
  assert.eq(data.markers[2].dx, 7, "dx")
  assert.eq(data.markers[2].dz, 4, "dz")
  assert.eq(data.markers[2].section, "1", "section")
end

function T.build_drops_duplicate_tiles()
  local data = markerdata.build(markerdata.parseCsv(CSV), SECTIONS)
  assert.eq(#data.markers, 3, "32 and 33 merge")
end

function T.serialized_data_round_trips()
  local data = markerdata.build(markerdata.parseCsv(CSV), SECTIONS)
  local loaded = loadstring(markerdata.serialize(data))()
  assert.eq(loaded.anchorX, 11299, "anchorX")
  assert.eq(#loaded.markers, 3, "markers")
  assert.eq(loaded.markers[3].section, "4", "section")
  assert.eq(loaded.markers[3].arrival, false, "arrival")
end

function T.nearby_filters_by_radius()
  local data = markerdata.build(markerdata.parseCsv(CSV), SECTIONS)
  assert.eq(#markerdata.nearby(data, 11299, 3243, 10), 2, "start area")
  assert.eq(#markerdata.nearby(data, 11319, 3170, 5), 1, "south")
  assert.eq(#markerdata.nearby(data, 3297, 3184, 48), 0, "al kharid")
end

return T
