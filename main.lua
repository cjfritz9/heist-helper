local bolt = require("bolt")
bolt.checkversion(1, 0)

local coords = require("core.coords")
local poslog = require("core.poslog")
local markerstore = require("core.markerstore")
local picking = require("core.picking")
local chatlines = require("core.chatlines")
local anchor = require("core.anchor")
local runstate = require("core.runstate")
local objectmap = require("core.objectmap")
local picker = require("gfx.picker")
local markers = require("gfx.markers")
local objectDraw = require("gfx.objects")
local objectScan = require("game.objects")
local chatlog = require("game.chatlog")
local probe = require("game.probe")
local chatModule = require("modules.chat.chat")
local seedMarkers = require("data.markers")
local seedObjects = require("data.objects")

local LOG_FILE = "positions.csv"
local MARKERS_FILE = "markers.csv"
local TAGS_FILE = "tags.csv"
local CHAT_FILE = "chat.log"
local RUN_FILE = "run.csv"
local OBJECTS_FILE = "objects.csv"
local PROBE_FILE = "probe.log"
local ERROR_FILE = "error.log"
local TAG_ROWS_PER_CLICK = 8
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
local player = nil
local corpsesInView = {}
local objectsInView = {}

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

local guarded = function(source, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then
    reportError(source, err)
  end
end

local log = bolt.loadconfig(LOG_FILE) or poslog.HEADER
local count = poslog.countRows(log)

local tags = picking.startLog(bolt.loadconfig(TAGS_FILE))
local tagCount = picking.lastTag(tags)

local savedMarkers = bolt.loadconfig(MARKERS_FILE)
local markerData = (savedMarkers and markerstore.decode(savedMarkers)) or markerstore.copy(seedMarkers)

local chatText = bolt.loadconfig(CHAT_FILE) or ""
local chatReader = chatlog.new(chatModule)

local probeText = bolt.loadconfig(PROBE_FILE) or ""

local appendProbe = function(text)
  if text == "" then return end
  probeText = probeText .. text
  bolt.saveconfig(PROBE_FILE, probeText)
end

local run = runstate.decode(bolt.loadconfig(RUN_FILE))
local objectMap = objectmap.merge(objectmap.new(seedObjects), bolt.loadconfig(OBJECTS_FILE))

local saveRun = function()
  bolt.saveconfig(RUN_FILE, runstate.encode(run))
end

local syncMarkersToAnchor = function()
  if run.anchor then
    markerData.anchorX, markerData.anchorZ = run.anchor.x, run.anchor.z
  end
end
syncMarkersToAnchor()

local applyAnchor = function(a)
  if runstate.setAnchor(run, a) then
    syncMarkersToAnchor()
    saveRun()
  end
end

local inVault = function()
  return player ~= nil and anchor.inVault(run.anchor, player.tileX, player.tileZ)
end

local recordChat = function(message)
  local _, text = chatlines.split(message)
  local event = runstate.chatEvent(text)
  if event == "loot" and player then
    if runstate.recordLoot(run, objectsInView, player.tileX, player.tileZ) then
      saveRun()
    end
  elseif event == "corpseLooted" and player then
    if runstate.markNearestCorpse(run, corpsesInView, player.tileX, player.tileZ) then
      saveRun()
    end
  elseif event == "runComplete" then
    runstate.resetRun(run)
    saveRun()
  end
  if inVault() then
    chatText = chatText .. message .. "\n"
    bolt.saveconfig(CHAT_FILE, chatText)
  end
end

local updatePlayer = function()
  local position = bolt.playerposition()
  if not position then return end
  local x, y, z = position:get()
  local tile = coords.fromWorld(x, z)
  local arrival = anchor.fromArrival(player and player.tileX, player and player.tileZ, tile.tileX, tile.tileZ, y)
  if arrival then
    runstate.resetRun(run)
    applyAnchor(arrival)
    saveRun()
  end
  player = { tileX = tile.tileX, tileZ = tile.tileZ }
end

local isHighlighted = function(o)
  if o.kind == "shadowAnchor" then
    return false
  end
  if o.kind == "corpse" then
    return run.anchor ~= nil and not runstate.isCorpseLooted(run, o.tileX - run.anchor.x, o.tileZ - run.anchor.z)
  end
  return o.looted == false
end

local corpseProgress = function(o)
  local done = runstate.rummageCount(run, o.tileX - run.anchor.x, o.tileZ - run.anchor.z)
  return { done = done, total = runstate.RUMMAGES_PER_CORPSE }
end

local processObjects = function(objects)
  if not inVault() then
    for _, o in ipairs(objects) do
      local a = anchor.fromObject(o.kind, o.tileX, o.tileZ, objectMap.list)
      if a then
        applyAnchor(a)
        break
      end
    end
  end

  local corpses, highlighted, mapChanged = {}, {}, false
  local recording = inVault()
  for _, o in ipairs(objects) do
    if o.kind == "corpse" then
      corpses[#corpses + 1] = o
    end
    if recording and objectmap.add(objectMap, o.kind, o.tileX - run.anchor.x, o.tileZ - run.anchor.z) then
      mapChanged = true
    end
    if isHighlighted(o) then
      if o.kind == "corpse" then
        o.progress = corpseProgress(o)
      end
      highlighted[#highlighted + 1] = o
    end
  end
  corpsesInView = corpses
  objectsInView = objects
  if mapChanged then
    bolt.saveconfig(OBJECTS_FILE, objectmap.encode(objectMap))
  end
  objectDraw.draw(bolt, highlighted)
end

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
  local lastChat = chatReader.mostRecent and chatlines.split(chatReader.mostRecent)
  tags = tags .. picking.rows(tagCount, finished.candidates, markerData.anchorX, markerData.anchorZ,
    finished.x, finished.y, lastChat, TAG_ROWS_PER_CLICK)
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
  guarded("objects", objectScan.inspect, bolt, event, player and player.tileX, player and player.tileZ)
  if picker.collecting() then
    guarded("tag", picker.inspect, bolt, event)
  end
  if probe.active() then
    guarded("probe", probe.inspectModel, bolt, event)
  end
end)

bolt.onrenderparticles(function(event)
  if probe.active() then
    guarded("probe", probe.inspectParticles, event)
  end
end)

bolt.onrenderbillboard(function(event)
  if probe.active() then
    guarded("probe", probe.inspectBillboard, bolt, event)
  end
end)

bolt.onrender2d(function(event)
  guarded("chat", chatlog.read, chatReader, bolt.time(), event, recordChat)
end)

bolt.onswapbuffers(function()
  guarded("player", updatePlayer)
  local finished = picker.advance()
  if finished then
    saveTag(finished)
  end
  guarded("draw", markers.draw, bolt, markerData, viewProj)
  guarded("highlight", processObjects, objectScan.takeFrame())
  if player then
    guarded("probe", probe.update, bolt.time(), objectsInView, player.tileX, player.tileZ, appendProbe)
  end
  if flash and bolt.time() < flashUntil then
    flash:drawtoscreen(0, 0, 1, 1, FLASH_MARGIN, FLASH_MARGIN, FLASH_SIZE, FLASH_SIZE)
  end
end)
