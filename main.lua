local bolt = require("bolt")
bolt.checkversion(1, 0)

local coords = require("core.coords")
local poslog = require("core.poslog")
local markerstore = require("core.markerstore")
local picking = require("core.picking")
local picker = require("gfx.picker")
local markers = require("gfx.markers")
local seedMarkers = require("data.markers")

local LOG_FILE = "positions.csv"
local MARKERS_FILE = "markers.csv"
local TAGS_FILE = "tags.csv"
local TAG_ROWS_PER_CLICK = 8
local ERROR_FILE = "error.log"
local MIDDLE_BUTTON = 3
local FLASH_MICROSECONDS = 400 * 1000
local FLASH_SIZE = 32
local FLASH_MARGIN = 16

local createFlashSurface = function(r, g, b)
  local surface = bolt.createsurface(1, 1)
  surface:clear(r, g, b, 0.9)
  return surface
end

local flashes = {
  logged = createFlashSurface(0.1, 0.9, 0.2),
  added = createFlashSurface(1.0, 1.0, 1.0),
  removed = createFlashSurface(1.0, 0.55, 0.0),
  unknown = createFlashSurface(0.9, 0.1, 0.1),
  tagged = createFlashSurface(0.1, 0.85, 0.95),
}

local flash = nil
local flashUntil = 0
local viewProj = nil
local reportedErrors = {}

local showFlash = function(name)
  flash = flashes[name]
  flashUntil = bolt.time() + FLASH_MICROSECONDS
end

local reportError = function(source, err)
  if reportedErrors[source] then return end
  reportedErrors[source] = tostring(err)
  local lines = {}
  for name, message in pairs(reportedErrors) do
    lines[#lines + 1] = name .. ": " .. message
  end
  bolt.saveconfig(ERROR_FILE, table.concat(lines, "\n") .. "\n")
end

local log = bolt.loadconfig(LOG_FILE) or poslog.HEADER
local count = poslog.countRows(log)

local tags = bolt.loadconfig(TAGS_FILE) or picking.HEADER
local tagCount = picking.lastTag(tags)

local savedMarkers = bolt.loadconfig(MARKERS_FILE)
local markerData = (savedMarkers and markerstore.decode(savedMarkers)) or markerstore.copy(seedMarkers)

local logPosition = function(x, y, z)
  count = count + 1
  log = log .. poslog.row(count, x, y, z)
  bolt.saveconfig(LOG_FILE, log)
  showFlash("logged")
end

local toggleMarker = function(x, y, z)
  local tile = coords.fromWorld(x, z)
  showFlash(markerstore.toggle(markerData, tile.tileX, tile.tileZ, y))
  bolt.saveconfig(MARKERS_FILE, markerstore.encode(markerData))
end

local saveTag = function(finished)
  if #finished.candidates == 0 then
    showFlash("unknown")
    return
  end
  tagCount = tagCount + 1
  tags = tags .. picking.rows(tagCount, finished.candidates, markerData.anchorX, markerData.anchorZ,
    finished.x, finished.y, TAG_ROWS_PER_CLICK)
  bolt.saveconfig(TAGS_FILE, tags)
  showFlash("tagged")
end

bolt.onmousebutton(function(event)
  if event:button() ~= MIDDLE_BUTTON then
    return
  end
  if event:ctrl() then
    picker.request(event:xy())
    return
  end
  local action = (event:shift() and logPosition) or (event:alt() and toggleMarker)
  if not action then
    return
  end
  local position = bolt.playerposition()
  if not position then
    showFlash("unknown")
    return
  end
  action(position:get())
end)

bolt.onrender3d(function(event)
  viewProj = event:viewprojmatrix()
  if picker.collecting() then
    local ok, err = pcall(picker.inspect, bolt, event)
    if not ok then
      reportError("tag", err)
    end
  end
end)

bolt.onswapbuffers(function()
  local finished = picker.advance()
  if finished then
    saveTag(finished)
  end
  local ok, err = pcall(markers.draw, bolt, markerData, viewProj)
  if not ok then
    reportError("draw", err)
  end
  if flash and bolt.time() < flashUntil then
    flash:drawtoscreen(0, 0, 1, 1, FLASH_MARGIN, FLASH_MARGIN, FLASH_SIZE, FLASH_SIZE)
  end
end)
