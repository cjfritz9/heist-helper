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
local catalog = require("core.catalog")
local status = require("core.status")
local links = require("core.links")
local linkwizard = require("core.linkwizard")
local compare = require("core.compare")
local nearby = require("core.nearby")
local picker = require("gfx.picker")
local markers = require("gfx.markers")
local objectDraw = require("gfx.objects")
local areaDraw = require("gfx.area")
local objectScan = require("game.objects")
local chatlog = require("game.chatlog")
local recorder = require("game.recorder")
local panel = require("game.panel")
local watch = require("game.watch")
local chatModule = require("modules.chat.chat")
local seedMarkers = require("data.markers")
local seedObjects = require("data.objects")
local seedLinks = require("data.links")

local LOG_FILE = "positions.csv"
local MARKERS_FILE = "markers.csv"
local TAGS_FILE = "tags.csv"
local CHAT_FILE = "chat.log"
local RUN_FILE = "run.csv"
local OBJECTS_FILE = "objects.csv"
local RECORD_FILE = "record.log"
local CATALOG_FILE = "catalog.csv"
local LINKS_FILE = "links.csv"
local WATCH_FILE = "watch.log"
local ANCHOR_REACH_TILES = 3
local TAG_CANDIDATES_SHOWN = 3
local OUTLINE_UNLINKED_ANCHORS = false
local SHOW_TILE_MARKERS = false
local RECORD_UNLINKED_ANCHORS = false
local DIAL_REACH_TILES = 3
local LANDING_WINDOW_MICROSECONDS = 3 * 1000 * 1000
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
local tagArmed = false
local lastTag = nil
local lastTagCandidates = {}

local ADD_BUTTONS = {
  corpse = { kind = "corpse" },
  chestClosed = { kind = "chest", looted = false },
  chestOpen = { kind = "chest", looted = true },
  safe = { kind = "safe" },
  dial = { kind = "shadowDial" },
  anchor = { kind = "shadowAnchor" },
}

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

local recordText = bolt.loadconfig(RECORD_FILE) or ""
local recordDirty = false
local nextRecordFlush = 0
local RECORD_FLUSH_MICROSECONDS = 1000 * 1000

local appendRecord = function(text)
  if text == "" then return end
  recordText = recordText .. text
  recordDirty = true
end

local flushRecord = function(now)
  if not recordDirty or now < nextRecordFlush then return end
  bolt.saveconfig(RECORD_FILE, recordText)
  recordDirty = false
  nextRecordFlush = now + RECORD_FLUSH_MICROSECONDS
end

local watchHistory = bolt.loadconfig(WATCH_FILE) or ""
local lastWatchReport = ""

local nextWatchFlush = 0

local flushWatchRaw = function(now)
  local text = watch.takeRaw()
  if text ~= "" then
    watchHistory = watchHistory .. text
  end
  if now >= nextWatchFlush then
    bolt.saveconfig(WATCH_FILE, watchHistory)
    nextWatchFlush = now + 1000 * 1000
  end
end

local saveWatchReport = function(permanent)
  local report = watch.report()
  if report == lastWatchReport and not permanent then return end
  lastWatchReport = report
  if permanent then
    watchHistory = watchHistory .. report .. "\n"
    bolt.saveconfig(WATCH_FILE, watchHistory)
  else
    bolt.saveconfig(WATCH_FILE, watchHistory .. report)
  end
end

catalog.loadUser(bolt.loadconfig(CATALOG_FILE))

local savedLinks = links.decode(bolt.loadconfig(LINKS_FILE))
local linkSet = links.withSeed(seedLinks, bolt.loadconfig(LINKS_FILE))
local linkTracker = {}
local wizard = linkwizard.new()
local comparison = { before = nil, after = nil }
local landing = nil
local active = false
objectScan.setWatched(links.watchedVertexCounts(linkSet))

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
  recorder.note(bolt.time(), message, appendRecord)
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

local markDialUsed = function(dial)
  if dial and run.anchor
    and runstate.markObjectLooted(run, "shadowDial", dial.tileX - run.anchor.x, dial.tileZ - run.anchor.z) then
    saveRun()
  end
end

local noticeTeleport = function(fromX, fromZ, toX, toZ)
  if not nearby.teleported(fromX, fromZ, toX, toZ) or not anchor.inVault(run.anchor, fromX, fromZ) then
    return
  end
  local used = nearby.nearest(objectsInView, "shadowDial", fromX, fromZ, DIAL_REACH_TILES)
  if used then
    markDialUsed(used)
    landing = { tileX = toX, tileZ = toZ, untilTime = bolt.time() + LANDING_WINDOW_MICROSECONDS }
  end
end

local noticeLandingDial = function(objects)
  if not landing then return end
  if bolt.time() > landing.untilTime then
    landing = nil
    return
  end
  local partner = nearby.nearest(objects, "shadowDial", landing.tileX, landing.tileZ, DIAL_REACH_TILES)
  if partner then
    markDialUsed(partner)
    landing = nil
  end
end

local updatePlayer = function()
  local position = bolt.playerposition()
  if not position then return end
  local x, y, z = position:get()
  local tile = coords.fromWorld(x, z)
  if player then
    noticeTeleport(player.tileX, player.tileZ, tile.tileX, tile.tileZ)
  end
  local arrival = anchor.fromArrival(player and player.tileX, player and player.tileZ, tile.tileX, tile.tileZ, y)
  if arrival then
    runstate.resetRun(run)
    applyAnchor(arrival)
    saveRun()
  end
  player = { tileX = tile.tileX, tileZ = tile.tileZ, height = y }
end

local isHighlighted = function(o)
  if o.kind == "shadowAnchor" then
    if not run.anchor then return false end
    local dx, dz = o.tileX - run.anchor.x, o.tileZ - run.anchor.z
    if not OUTLINE_UNLINKED_ANCHORS and not links.isLinked(linkSet, dx, dz) then return false end
    return not runstate.isAnchorPowered(run, dx, dz)
  end
  if o.kind == "shadowDial" then
    return run.anchor == nil
      or not runstate.isObjectLooted(run, "shadowDial", o.tileX - run.anchor.x, o.tileZ - run.anchor.z)
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

local checkLinks = function(watchedModels)
  if not run.anchor or not player then return false end
  local changed = false
  for _, link in ipairs(linkSet.list) do
    if not runstate.isAnchorPowered(run, link.anchorDx, link.anchorDz) then
      local ox, oz = run.anchor.x + link.objectDx, run.anchor.z + link.objectDz
      local seen = {}
      for _, m in ipairs(watchedModels) do
        if m.tileX == ox and m.tileZ == oz then
          seen[m.signature] = true
        end
      end
      local near = math.max(math.abs(player.tileX - ox), math.abs(player.tileZ - oz)) <= links.WATCH_TILES
      if links.poweredNow(link, seen, near, linkTracker)
        and runstate.setAnchorPowered(run, link.anchorDx, link.anchorDz) then
        changed = true
      end
    end
  end
  return changed
end

local processObjects = function(objects, watchedModels, selectedPoints)
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
  noticeLandingDial(objects)
  local runChanged = checkLinks(watchedModels or {})
  local recording = inVault()
  for _, o in ipairs(objects) do
    if o.kind == "corpse" then
      corpses[#corpses + 1] = o
    end
    if recording then
      local dx, dz = o.tileX - run.anchor.x, o.tileZ - run.anchor.z
      if objectmap.add(objectMap, o.kind, dx, dz) then
        mapChanged = true
      end
      if o.looted == true and runstate.markObjectLooted(run, o.kind, dx, dz) then
        runChanged = true
      end
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
  if runChanged then
    saveRun()
  end
  if not inVault() then return end
  if panel.devEnabled() and player then
    areaDraw.draw(bolt, watch.area(), player.height, viewProj)
  end
  if selectedPoints and panel.devEnabled() then
    highlighted[#highlighted + 1] = { kind = "selected", points = selectedPoints }
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

  lastTagCandidates = finished.candidates
  objectScan.setTarget(finished.candidates[1])
  local shown = {}
  for rank = 1, math.min(TAG_CANDIDATES_SHOWN, #finished.candidates) do
    local c = finished.candidates[rank]
    shown[rank] = {
      rank = rank,
      vertices = c.vertices,
      fingerprint = c.fingerprint,
      animated = c.animated,
      w = math.floor(c.box.maxX - c.box.minX + 0.5),
      h = math.floor(c.box.maxY - c.box.minY + 0.5),
      kind = catalog.classify(c.vertices, c.fingerprint, c.animated),
    }
  end
  lastTag = { number = tagCount, candidates = shown }
end

local atPlayer = function(action)
  local position = bolt.playerposition()
  if not position then
    showFlash("unknown")
    return
  end
  action(position:get())
end

local addTaggedModel = function(argument)
  local button, rank = argument:match("^(%a+):(%d+)$")
  local spec = button and ADD_BUTTONS[button]
  local candidate = rank and lastTagCandidates[tonumber(rank)]
  if not spec or not candidate then
    showFlash("unknown")
    return
  end
  if catalog.add(candidate.vertices, candidate.fingerprint, spec.kind, spec.looted) then
    bolt.saveconfig(CATALOG_FILE, catalog.encodeUser())
  end
  lastTag.candidates[tonumber(rank)].kind = spec.kind
  showFlash("added")
end

local taggedCandidate = function(rank)
  local candidate = lastTagCandidates[tonumber(rank)]
  if not candidate or not run.anchor then
    showFlash("unknown")
    return nil
  end
  return candidate, candidate.tileX - run.anchor.x, candidate.tileZ - run.anchor.z
end

local LINK_STEPS = {
  start = function() linkwizard.start(wizard) end,
  cancel = function() linkwizard.cancel(wizard) end,
  skip = function() linkwizard.skipBefore(wizard) end,
  gone = function() linkwizard.markGone(wizard) end,
  anchor = function(rank)
    local c, dx, dz = taggedCandidate(rank)
    if c then
      linkwizard.useAnchor(wizard, dx, dz, catalog.classify(c.vertices, c.fingerprint, c.animated))
    end
  end,
  before = function(rank)
    local c, dx, dz = taggedCandidate(rank)
    if c then linkwizard.useBefore(wizard, c, dx, dz) end
  end,
  after = function(rank)
    local c, dx, dz = taggedCandidate(rank)
    if c then linkwizard.useAfter(wizard, c, dx, dz) end
  end,
  save = function()
    local result = linkwizard.result(wizard)
    if not result then
      showFlash("unknown")
      return
    end
    links.put(linkSet, result)
    links.put(savedLinks, result)
    bolt.saveconfig(LINKS_FILE, links.encode(savedLinks))
    objectScan.setWatched(links.watchedVertexCounts(linkSet))
    linkwizard.cancel(wizard)
    showFlash("added")
  end,
}

local linkCommand = function(argument)
  local step, rank = argument:match("^(%a+):?(%d*)$")
  local action = step and LINK_STEPS[step]
  if action then
    action(rank)
  end
end

local selectCandidate = function(argument)
  objectScan.setTarget(lastTagCandidates[tonumber(argument) or 0])
end

local watchCommand = function(argument)
  local action, number = argument:match("^(%a+):?([%d%+%-]*)$")
  if action == "close" then
    if watch.close() then
      saveWatchReport(true)
    end
  elseif action == "clear" then
    watch.clear()
  elseif action == "radius" then
    watch.resize(number == "-" and -1 or 1)
  elseif action == "here" then
    if not player then
      showFlash("unknown")
      return
    end
    watch.start(player.tileX, player.tileZ)
    showFlash("tagged")
  elseif action == "start" then
    local candidate = lastTagCandidates[tonumber(number) or 0]
    if not candidate then
      showFlash("unknown")
      return
    end
    watch.start(candidate.tileX, candidate.tileZ)
    showFlash("tagged")
  elseif action == "arm" then
    if watch.arm(bolt.time()) then
      showFlash("added")
    end
  elseif action == "use" then
    local afterSignature, tileX, tileZ = watch.linkTarget(tonumber(number) or 0)
    if not afterSignature or not run.anchor then
      showFlash("unknown")
      return
    end
    linkwizard.useAfterSignature(wizard, afterSignature, tileX - run.anchor.x, tileZ - run.anchor.z, true)
  end
end

local compareCommand = function(argument)
  local side, rank = argument:match("^(%a+):?(%d*)$")
  if side == "clear" then
    comparison.before, comparison.after = nil, nil
    return
  end
  local candidate = lastTagCandidates[tonumber(rank) or 0]
  if (side ~= "before" and side ~= "after") or not candidate then
    showFlash("unknown")
    return
  end
  comparison[side] = compare.snapshot(candidate, run.anchor and run.anchor.x, run.anchor and run.anchor.z)
  showFlash("tagged")
end

local comparisonStatus = function()
  if not comparison.before and not comparison.after then
    return nil
  end
  local rows = compare.diff(comparison.before, comparison.after)
  return { rows = rows, verdict = compare.verdict(comparison.before, comparison.after) }
end

local toggleNearestAnchor = function()
  if not player or not run.anchor then
    showFlash("unknown")
    return
  end
  local best = nearby.nearest(objectsInView, "shadowAnchor", player.tileX, player.tileZ, ANCHOR_REACH_TILES)
  if not best then
    showFlash("unknown")
    return
  end
  local powered = runstate.toggleAnchor(run, best.tileX - run.anchor.x, best.tileZ - run.anchor.z)
  saveRun()
  showFlash(powered and "added" or "removed")
end

bolt.onmousebutton(function(event)
  if not active or event:button() ~= MIDDLE_BUTTON then
    return
  end
  if event:ctrl() or (tagArmed and not event:shift() and not event:alt()) then
    tagArmed = false
    picker.request(event:xy())
    return
  end
  local action = (event:shift() and logPosition) or (SHOW_TILE_MARKERS and event:alt() and toggleMarker)
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

panel.init(bolt, {
  tag = function() tagArmed = not tagArmed end,
  marktile = function()
    if SHOW_TILE_MARKERS then atPlayer(toggleMarker) end
  end,
  logtile = function() atPlayer(logPosition) end,
  add = addTaggedModel,
  anchor = toggleNearestAnchor,
  link = linkCommand,
  compare = compareCommand,
  select = selectCandidate,
  watch = watchCommand,
})

bolt.onrender3d(function(event)
  viewProj = event:viewprojmatrix()
  guarded("objects", objectScan.inspect, bolt, event, player and player.tileX, player and player.tileZ)
  if not active then return end
  if picker.collecting() then
    guarded("tag", picker.inspect, bolt, event)
  end
  if recorder.sampling() then
    guarded("record", recorder.inspectModel, bolt, event)
  end
  if watch.active() then
    guarded("watch", watch.inspectModel, bolt, event)
  end
end)

bolt.onrenderparticles(function(event)
  if not active then return end
  if recorder.sampling() then
    guarded("record", recorder.inspectParticles, event)
  end
  if watch.active() then
    guarded("watch", watch.inspectParticles, event)
  end
end)

bolt.onrenderbillboard(function(event)
  if not active then return end
  if recorder.sampling() then
    guarded("record", recorder.inspectBillboard, bolt, event)
  end
  if watch.active() then
    guarded("watch", watch.inspectBillboard, bolt, event)
  end
end)

bolt.onrender2d(function(event)
  if not active then return end
  guarded("chat", chatlog.read, chatReader, bolt.time(), event, recordChat)
end)

bolt.onswapbuffers(function()
  guarded("player", updatePlayer)
  active = inVault()
  guarded("panel", panel.setVisible, active)
  local finished = picker.advance()
  if finished then
    saveTag(finished)
  end
  if active and SHOW_TILE_MARKERS then
    guarded("draw", markers.draw, bolt, markerData, viewProj)
  end
  guarded("watch", watch.endFrame, bolt.time())
  local seenObjects, watchedModels, selectedPoints = objectScan.takeFrame()
  guarded("highlight", processObjects, seenObjects, watchedModels, selectedPoints)
  if active and player and RECORD_UNLINKED_ANCHORS then
    guarded("record", recorder.update, bolt.time(), objectsInView, player.tileX, player.tileZ, run.anchor,
      function(dx, dz) return links.isLinked(linkSet, dx, dz) end, appendRecord)
  end
  if active then
    guarded("watch", flushWatchRaw, bolt.time())
  end
  guarded("record", flushRecord, bolt.time())
  if not active then return end
  local panelStatus = status.build(run, objectMap.list, player and player.height)
  panelStatus.tagArmed = tagArmed
  panelStatus.lastTag = lastTag
  panelStatus.link = linkwizard.status(wizard)
  panelStatus.linkCount = #linkSet.list
  panelStatus.compare = comparisonStatus()
  panelStatus.watch = watch.status()
  guarded("panel", panel.update, bolt.time(), panelStatus)
  if flash and bolt.time() < flashUntil then
    flash:drawtoscreen(0, 0, 1, 1, FLASH_MARGIN, FLASH_MARGIN, FLASH_SIZE, FLASH_SIZE)
  end
end)
