package.path = "./?.lua;" .. package.path

local markerdata = require("core.markerdata")

local SECTION_BY_HEIGHT = {
  [4933] = "1",
  [2949] = "2",
  [261] = "3",
  [2181] = "4",
  [1221] = "4",
}

local input = arg[1]
if not input then
  io.stderr:write("usage: luajit tools/build_markers.lua mapping/run1.csv > data/markers.lua\n")
  os.exit(2)
end

local file = assert(io.open(input, "r"))
local rows = markerdata.parseCsv(file:read("*a"))
file:close()

io.write(markerdata.serialize(markerdata.build(rows, SECTION_BY_HEIGHT)))
