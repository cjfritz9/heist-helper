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
local levels = require("core.levels")
local checkpoints = require("core.checkpoints")
local links = require("core.links")
local linkwizard = require("core.linkwizard")
local compare = require("core.compare")
local nearby = require("core.nearby")
local stacklabels = require("core.stacklabels")
local rollinglog = require("core.rollinglog")
local anchorclick = require("core.anchorclick")
local defaultIcons = require("data.icons")
local picker = require("gfx.picker")
local markers = require("gfx.markers")
local objectDraw = require("gfx.objects")
local areaDraw = require("gfx.area")
local objectScan = require("game.objects")
local chatlog = require("game.chatlog")
local recorder = require("game.recorder")
local panel = require("game.panel")
local watch = require("game.watch")
local inventory = require("game.inventory")
local mazegrid = require("game.mazegrid")
local mazeroute = require("game.mazeroute")
local visionrings = require("game.visionrings")
local ticksync = require("game.ticksync")
local xpprobe = require("game.xpprobe")
local clickprobe = require("game.clickprobe")
local clicks = require("game.clicks")
local xpdrops = require("game.xpdrops")
local runlog = require("core.runlog")
local minimap = require("game.minimap")
local entrance = require("game.entrance")
local lootcounter = require("game.lootcounter")
local chatModule = require("modules.chat.chat")
local seedMarkers = require("data.markers")
local seedObjects = require("data.objects")
local seedLinks = require("data.links")
local seedCheckpoints = require("data.checkpoints")

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
local WATCH_LINES = 5000
local MAZE_CENTRE = { dx = -1, dz = -80, radius = 16 }
local LEVELS_FILE = "levels.csv"
local CREVICES_FILE = "crevices.csv"
local BATTERY_FILE = "battery.csv"
local CHECKPOINTS_FILE = "checkpoints.csv"
local LEARN_SECTION_TILES = 4
local INVENTORY_FILE = "inventory.log"
local LOG_LINES = 2000
local TAG_CANDIDATES_SHOWN = 3
local SHOW_TILE_MARKERS = false
local RECORD_UNLINKED_ANCHORS = false
local DIAL_REACH_TILES = 3
local LANDING_WINDOW_MICROSECONDS = 3 * 1000 * 1000
local ERROR_FILE = "error.log"
local TAG_ROWS_PER_CLICK = 8
local LEFT_BUTTON = 1
local MIDDLE_BUTTON = 3
local BATTERY_VISIBLE_SECONDS = 2
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
local pickTarget = nil
local lastIcons = {}
local mouse = nil
local batteryWasPresent = false
local batterySeenAt = -math.huge
local pendingAnchors = {}
local anchorClicks = anchorclick.new()
local batteryHoverAt = -math.huge
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

local chatLog = rollinglog.new(bolt.loadconfig(CHAT_FILE), LOG_LINES)
local chatReader = chatlog.new(chatModule)
local lastChatProblem = nil
local chatProblem = function()
  local problem = chatlog.problem(chatReader, bolt.time())
  if problem ~= lastChatProblem then
    lastChatProblem = problem
    lootcounter.append(problem and ("chat can't be read: " .. (problem == "scrolled" and "scrolled up" or "chat box not found"))
      or "chat readable again")
  end
  return problem
end

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

local inventoryLog = rollinglog.new(bolt.loadconfig(INVENTORY_FILE), LOG_LINES)
local inventoryDirty = false
local nextInventoryFlush = 0

local appendInventory = function(line)
  rollinglog.append(inventoryLog, string.format("[%9.3f] %s", bolt.time() / 1e6, line))
  inventoryDirty = true
end

local flushInventory = function(now)
  if not inventoryDirty or now < nextInventoryFlush then return end
  bolt.saveconfig(INVENTORY_FILE, rollinglog.text(inventoryLog))
  inventoryDirty = false
  nextInventoryFlush = now + RECORD_FLUSH_MICROSECONDS
end

local batterySignature = (bolt.loadconfig(BATTERY_FILE) or ""):match("^%s*(%S+)") or defaultIcons.battery
local knownLabels = {}
local batteryLearner = stacklabels.newLearner()

local watchLog = rollinglog.new(bolt.loadconfig(WATCH_FILE), WATCH_LINES)
local watchState = { dirty = false, nextFlush = 0 }
local shots = { count = 0, pending = false }

local flushWatchRaw = function(now)
  local text = watch.takeRaw()
  for line in text:gmatch("[^\n]+") do
    rollinglog.append(watchLog, line)
    watchState.dirty = true
  end
  if watchState.dirty and now >= watchState.nextFlush then
    bolt.saveconfig(WATCH_FILE, rollinglog.text(watchLog))
    watchState.dirty = false
    watchState.nextFlush = now + 5 * 1000 * 1000
  end
end

local saveWatchReport = function()
  for line in watch.report():gmatch("[^\n]+") do
    rollinglog.append(watchLog, line)
  end
  bolt.saveconfig(WATCH_FILE, rollinglog.text(watchLog))
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
objectmap.loadCrevices(objectMap, bolt.loadconfig(CREVICES_FILE))
local playerLevels = levels.decode(bolt.loadconfig(LEVELS_FILE))
local checkpointSet = checkpoints.merge(checkpoints.new(seedCheckpoints), bolt.loadconfig(CHECKPOINTS_FILE))

local learnSection = function(kind, dx, dz)
  if checkpoints.complete(checkpointSet) and run.section
    and objectmap.setSection(objectMap, kind, dx, dz, run.section) then
    bolt.saveconfig(OBJECTS_FILE, objectmap.encode(objectMap))
  end
end

local learnSectionFromKey = function(kind, k)
  local dx, dz = (k or ""):match("^(%-?%d+),(%-?%d+)$")
  if dx then
    learnSection(kind, tonumber(dx), tonumber(dz))
  end
end

local saveRun = function()
  bolt.saveconfig(RUN_FILE, runstate.encode(run))
end
lootcounter.init(bolt, run, saveRun)
mazeroute.init(bolt, lootcounter.append, ticksync.nextTick, ticksync.boundary)
ticksync.init(bolt)
xpprobe.init(bolt, ticksync.nextTick)
clickprobe.init(bolt, ticksync.nextTick)
entrance.init(bolt)
lootcounter.onPopupAppear(ticksync.popup)
visionrings.init(bolt, lootcounter.append, ticksync.ghostStart, ticksync.boundary)

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

local runFinished = false
local runHistory = { file = "runs.csv" }
runHistory.rows = runlog.decode(bolt.loadconfig(runHistory.file))
runHistory.sessionFrom = #runHistory.rows

local runStats = function()
  local stats = runlog.stats(runHistory.rows, runHistory.sessionFrom)
  return { session = stats.session, lifetime = stats.lifetime, last = stats.last,
    average = stats.average and runlog.clock(stats.average), best = stats.best and runlog.clock(stats.best) }
end

local MINIMAP_GHOST_PIXELS = 6
local MINIMAP_GHOST_COLOUR = { 255, 50, 50, 255 }
local MINIMAP_GHOST_ESTIMATE_COLOUR = { 255, 190, 60, 255 }
local drawMinimap = function()
  if not player or not run.anchor then return end
  local dots = {}
  for _, o in ipairs(status.remaining(run, objectMap, playerLevels)) do
    local rgb = objectDraw.COLOURS[o.kind]
    if rgb then dots[#dots + 1] = { dx = o.dx, dz = o.dz, y = o.y, colour = { rgb[1], rgb[2], rgb[3], 255 } } end
  end
  if playerLevels.ghosts then
    for _, g in ipairs(visionrings.minimapGhosts()) do
      dots[#dots + 1] = { dx = g.dx, dz = g.dz, y = g.y, size = MINIMAP_GHOST_PIXELS,
        colour = g.synced and MINIMAP_GHOST_COLOUR or MINIMAP_GHOST_ESTIMATE_COLOUR }
    end
  end
  minimap.draw(bolt, run.anchor, player.height, dots)
end

local inVault = function()
  return player ~= nil and anchor.inVault(run.anchor, player.tileX, player.tileZ)
end

local recordChat = function(message)
  local _, text = chatlines.split(message)
  if text == "WelcometoRuneScape." then lootcounter.loggedIn(bolt.time()) end
  if active then guarded("ticks", ticksync.chat, bolt.time()) end
  recorder.note(bolt.time(), message, appendRecord)
  local event = runstate.chatEvent(text)
  if event == "loot" and player then
    local k, count = runstate.recordLoot(run, objectsInView, player.tileX, player.tileZ)
    if k then
      guarded("rings", visionrings.noteRummage, bolt.time(), k)
      local corpse = objectMap.index["corpse," .. k]
      lootcounter.action(bolt.time(), "corpse", corpse and corpse.section)
      lootcounter.append(string.format("detected rummage %d/%d on corpse %s", count, runstate.RUMMAGES_PER_CORPSE, k))
      learnSectionFromKey("corpse", k)
      saveRun()
    end
  elseif event == "corpseLooted" and player then
    local k = runstate.markNearestCorpse(run, corpsesInView, player.tileX, player.tileZ)
    if k then
      learnSectionFromKey("corpse", k)
      saveRun()
    end
  elseif event == "caught" then
    local wrongStep = mazeroute.recentlyInMaze(bolt.time())
    lootcounter.caught(wrongStep)
    if not wrongStep then guarded("rings", visionrings.caught, run.anchor, player) end
  elseif event == "runComplete" then
    local seconds = runlog.parseTime(text)
    if seconds and not runFinished then
      runHistory.rows[#runHistory.rows + 1] = { seconds = seconds, loot = run.loot or 0 }
      bolt.saveconfig(runHistory.file, runlog.encode(runHistory.rows))
    end
    runFinished = true
    lootcounter.append("run complete: kept until you're teleported out")
  end
  if inVault() then
    lootcounter.append("chat: " .. text)
    rollinglog.append(chatLog, message)
    bolt.saveconfig(CHAT_FILE, rollinglog.text(chatLog))
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
    if runstate.setSection(run, checkpoints.afterDial(checkpointSet, used.tileX - run.anchor.x, used.tileZ - run.anchor.z)) then
      saveRun()
    end
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
  if arrival and anchor.sentBack(run.anchor, arrival, player and player.tileX, player and player.tileZ) then
    runstate.setSection(run, 1)
    saveRun()
    lootcounter.append("sent back to the arrival tile (caught): run kept")
  elseif arrival then
    runstate.resetRun(run)
    applyAnchor(arrival)
    saveRun()
  end
  player = { tileX = tile.tileX, tileZ = tile.tileZ, height = y, x = x, z = z }
  if run.anchor and runstate.setSection(run,
    checkpoints.at(checkpointSet, tile.tileX - run.anchor.x, tile.tileZ - run.anchor.z, y)) then
    saveRun()
  end
end

local isLootable = function(o)
  local behind = run.anchor ~= nil
    and objectmap.behindCrevice(objectMap, o.tileX - run.anchor.x, o.tileZ - run.anchor.z)
  return levels.canLoot(playerLevels, o.kind, behind)
end

local isHighlighted = function(o)
  if status.LOOT_KINDS[o.kind] and not isLootable(o) then
    return false
  end
  if o.kind == "shadowAnchor" then
    if not run.anchor then return false end
    return not runstate.isAnchorPowered(run, o.tileX - run.anchor.x, o.tileZ - run.anchor.z)
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

local learnBattery = function(link)
  if batterySignature then return end
  local learned, candidates = stacklabels.learn(batteryLearner, bolt.time(),
    run.anchor.x + link.anchorDx, run.anchor.z + link.anchorDz)
  if learned then
    batterySignature = learned
    bolt.saveconfig(BATTERY_FILE, learned .. "\n")
    appendInventory(string.format("learned battery %s from anchor %d,%d", learned, link.anchorDx, link.anchorDz))
  else
    appendInventory(string.format("anchor %d,%d powered by its link; %d stacks changed next to it, battery not learned",
      link.anchorDx, link.anchorDz, candidates))
  end
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
        learnBattery(link)
      end
    end
  end
  return changed
end

local processObjects = function(objects, watchedModels, selectedPoints)
  if not inVault() then
    for _, o in ipairs(objects) do
      local a = o.y and anchor.fromObject(o.kind, o.tileX, o.tileZ, o.y, objectMap.list)
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
      if objectmap.add(objectMap, o.kind, dx, dz, o.y) then
        mapChanged = true
      end
      if o.looted == true and runstate.markObjectLooted(run, o.kind, dx, dz) then
        runChanged = true
        lootcounter.append(string.format("detected %s %d,%d opened", o.kind, dx, dz))
        local mapped = objectMap.index[o.kind .. "," .. dx .. "," .. dz]
        lootcounter.action(bolt.time(), o.kind, mapped and mapped.section)
        if player and math.max(math.abs(o.tileX - player.tileX), math.abs(o.tileZ - player.tileZ)) <= LEARN_SECTION_TILES then
          learnSection(o.kind, dx, dz)
        end
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

local pickIcon = function(target, x, y)
  for _, icon in ipairs(lastIcons) do
    if x >= icon.x and x <= icon.x + icon.w and y >= icon.y and y <= icon.y + icon.h then
      if target == "battery" then
        batterySignature = icon.signature
        bolt.saveconfig(BATTERY_FILE, batterySignature .. "\n")
      else
        lootcounter.setBag(icon.signature)
      end
      appendInventory(target .. " picked: " .. icon.signature)
      showFlash("added")
      return
    end
  end
  showFlash("unknown")
end

local markPowered = function(dx, dz, reason)
  if runstate.setAnchorPowered(run, dx, dz) then
    saveRun()
    appendInventory(string.format("%s at anchor %d,%d: marked powered", reason, dx, dz))
  end
end

local notePendingAnchors = function()
  for _, o in ipairs(objectsInView) do
    if o.kind == "shadowAnchor"
      and math.max(math.abs(o.tileX - player.tileX), math.abs(o.tileZ - player.tileZ)) <= stacklabels.REACH_TILES then
      local dx, dz = o.tileX - run.anchor.x, o.tileZ - run.anchor.z
      if not runstate.isAnchorPowered(run, dx, dz) then
        pendingAnchors[dx .. "," .. dz] = { dx = dx, dz = dz }
      end
    end
  end
end

local pendingBattery = nil

local powerAnchorByBattery = function(now)
  local targets = {}
  local best = nearby.nearest(objectsInView, "shadowAnchor", player.tileX, player.tileZ, stacklabels.REACH_TILES)
  if best then
    targets[1] = { dx = best.tileX - run.anchor.x, dz = best.tileZ - run.anchor.z, reason = "battery used" }
  else
    for _, a in pairs(pendingAnchors) do
      targets[#targets + 1] = { dx = a.dx, dz = a.dz, reason = "battery went down while the inventory was hidden" }
    end
  end
  if #targets == 0 then
    appendInventory("battery changed, but no shadow anchor within reach")
    return
  end
  pendingBattery = { at = now, targets = targets }
end

local settleBattery = function(now)
  if not pendingBattery then return end
  if stacklabels.aroundLoot(pendingBattery.at, lootcounter.lastActionAt()) then
    appendInventory("battery change came with loot: no anchor marked")
    pendingBattery = nil
  elseif stacklabels.decided(now, pendingBattery.at) then
    for _, t in ipairs(pendingBattery.targets) do
      markPowered(t.dx, t.dz, t.reason)
    end
    pendingBattery = nil
  end
end

local checkAnchorClick = function()
  if not player or not run.anchor then return end
  local now = bolt.time()
  local batteryVisible = now - batterySeenAt <= BATTERY_VISIBLE_SECONDS * 1e6
  local dx, dz = anchorclick.ready(anchorClicks, now, player.tileX - run.anchor.x, player.tileZ - run.anchor.z,
    batteryVisible)
  if dx then
    markPowered(dx, dz, "clicked with no batteries in view")
  end
end

local CRYSTAL_NOTE_TILES = 8
local crystalClickedAt = nil
local CRYSTAL_HEIGHT_UNITS = 900
local CRYSTAL_MIN_HALF_PIXELS = 25
local crystalBox = function(o)
  if not viewProj or not o.y then return nil end
  local project = function(height)
    local sx, sy, depth = bolt.point((o.tileX + 0.5) * 512, o.y + height, (o.tileZ + 0.5) * 512):transform(viewProj):togameview()
    if not depth or depth <= 0 or depth > 1 then return nil end
    return sx, sy
  end
  local bx, by = project(0)
  local tx, ty = project(CRYSTAL_HEIGHT_UNITS)
  if not bx or not tx then return nil end
  local half = math.max(CRYSTAL_MIN_HALF_PIXELS, math.abs(by - ty) * 0.45)
  return { math.min(bx, tx) - half, math.min(by, ty) - half / 2, math.max(bx, tx) + half, math.max(by, ty) + half / 2 }
end
local noticeAnchorClick = function(x, y)
  if not run.anchor then return end
  local vx, vy = bolt.gameviewxywh()
  if playerLevels.maze then
    local near = {}
    for _, o in ipairs(objectsInView) do
      if o.kind == "shadowCrystal" then
        local box = crystalBox(o)
        local px, py = x - vx, y - vy
        local onBox = box and px >= box[1] and px <= box[3] and py >= box[2] and py <= box[4]
        if anchorclick.contains(o.points, px, py) or onBox then
          if not anchorclick.contains(o.points, px, py) then
            lootcounter.append("maze: crystal click caught by its position, not its outline")
          end
          if not (crystalClickedAt and bolt.time() - crystalClickedAt < 1500 * 1000) then
            crystalClickedAt = bolt.time()
            mazeroute.trigger(bolt.time(), o.tileX - run.anchor.x, o.tileZ - run.anchor.z)
          end
          return
        end
        if player and math.max(math.abs(o.tileX - player.tileX), math.abs(o.tileZ - player.tileZ)) <= CRYSTAL_NOTE_TILES then
          local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
          for _, p in ipairs(o.points or {}) do
            minX, maxX, minY, maxY = math.min(minX, p[1]), math.max(maxX, p[1]), math.min(minY, p[2]), math.max(maxY, p[2])
          end
          local box = crystalBox(o)
          near[#near + 1] = string.format("%d,%d (outline %s, position box %s)", o.tileX - run.anchor.x, o.tileZ - run.anchor.z,
            minX < math.huge and string.format("%d,%d-%d,%d", minX, minY, maxX, maxY) or "none",
            box and string.format("%d,%d-%d,%d", box[1], box[2], box[3], box[4]) or "none")
        end
      end
    end
    if #near > 0 then
      lootcounter.append(string.format("maze: left click at %d,%d (game view %d,%d) not on the crystal in view at %s", x, y,
        x - vx, y - vy, table.concat(near, " ")))
    end
  end
  for _, o in ipairs(objectsInView) do
    if o.kind == "shadowAnchor" and anchorclick.contains(o.points, x - vx, y - vy) then
      local dx, dz = o.tileX - run.anchor.x, o.tileZ - run.anchor.z
      if not runstate.isAnchorPowered(run, dx, dz) then
        anchorclick.clicked(anchorClicks, dx, dz, bolt.time())
        appendInventory(string.format("clicked anchor %d,%d", dx, dz))
      end
      return
    end
  end
end

local crystalSeen = function(result)
  if result.kind ~= "interact" or not run.anchor or not player or not playerLevels.maze then return end
  if crystalClickedAt and result.at - crystalClickedAt < 1500 * 1000 then return end
  local best, bestDistance = nil, nil
  for _, o in ipairs(objectsInView) do
    if o.kind == "shadowCrystal" then
      local d = math.max(math.abs(o.tileX - player.tileX), math.abs(o.tileZ - player.tileZ))
      local box = not result.name and crystalBox(o)
      local onBox = box and result.x - box[1] >= -60 and result.x - box[3] <= 60 and result.y - box[2] >= -60 and result.y - box[4] <= 60
      if (result.name == "shadowCrystal" or onBox) and d <= 15 and (not bestDistance or d < bestDistance) then best, bestDistance = o, d end
    end
  end
  if not best then return end
  crystalClickedAt = result.at
  lootcounter.append(string.format("maze: crystal click seen from the game's interaction cross%s",
    result.name and " and the mouseover text" or " next to the crystal (no mouseover text)"))
  mazeroute.trigger(result.at, best.tileX - run.anchor.x, best.tileZ - run.anchor.z)
end
clicks.init(crystalSeen)
lootcounter.alsoWantGlyph(clicks.wants)

local processInventory = function()
  local icons, glyphs, images = inventory.takeFrame()
  if #icons > 0 then
    lastIcons = icons
  end
  clicks.frame(glyphs, bolt.time())
  lootcounter.frame(icons, glyphs, images, lastIcons, player ~= nil and run.anchor ~= nil)
  if not player or not run.anchor then return end
  local now = bolt.time()
  settleBattery(now)
  if #icons == 0 then
    notePendingAnchors()
  end
  if batterySignature and stacklabels.present(icons, batterySignature) then
    batterySeenAt = now
  end
  for _, icon in ipairs(icons) do
    if icon.signature == batterySignature and mouse and stacklabels.near(icon, mouse.x, mouse.y) then
      batteryHoverAt = now
    end
  end
  local hovering = now - batteryHoverAt <= stacklabels.HOVER_SECONDS * 1e6
  local usedUp = batterySignature ~= nil and stacklabels.usedUp(batteryWasPresent, icons, batterySignature)
  if #icons > 0 then
    batteryWasPresent = batterySignature ~= nil and stacklabels.present(icons, batterySignature)
  end
  if usedUp then
    appendInventory(string.format("battery stack gone at %d,%d%s", player.tileX - run.anchor.x,
      player.tileZ - run.anchor.z, hovering and " (ignored: mouse over it)" or ""))
    if not hovering then
      powerAnchorByBattery(now)
    end
  end
  local changes = stacklabels.update(knownLabels, stacklabels.frame(icons, glyphs))
  if #changes == 0 then
    if #icons > 0 then pendingAnchors = {} end
    return
  end
  if not hovering then
    stacklabels.note(batteryLearner, now, changes, player.tileX, player.tileZ)
  end
  local batteryChanged = false
  for _, c in ipairs(changes) do
    local isBattery = c.signature == batterySignature
    local ignored = hovering and "mouse over it" or nil
    appendInventory(string.format("stack %s: '%s' -> '%s' at %d,%d%s", c.key, c.before, c.after,
      player.tileX - run.anchor.x, player.tileZ - run.anchor.z,
      isBattery and (ignored and (" (battery, ignored: " .. ignored .. ")") or " (battery)") or ""))
    batteryChanged = batteryChanged or (isBattery and not ignored)
  end
  if batteryChanged then
    powerAnchorByBattery(now)
  end
  if #icons > 0 then
    pendingAnchors = {}
  end
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
      saveWatchReport()
    end
  elseif action == "clear" then
    watch.clear()
  elseif action == "radius" then
    watch.resize(number == "-" and -1 or 1)
  elseif action == "maze" then
    if not run.anchor then
      showFlash("unknown")
      return
    end
    watch.start(run.anchor.x + MAZE_CENTRE.dx, run.anchor.z + MAZE_CENTRE.dz, MAZE_CENTRE.radius)
    showFlash("tagged")
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

local toggleCrevice = function(rank)
  local candidate = lastTagCandidates[tonumber(rank) or 0]
  local kind = candidate and catalog.classify(candidate.vertices, candidate.fingerprint, candidate.animated)
  if not run.anchor or not status.LOOT_KINDS[kind] then
    showFlash("unknown")
    return
  end
  local behind = objectmap.toggleCrevice(objectMap, candidate.tileX - run.anchor.x, candidate.tileZ - run.anchor.z)
  bolt.saveconfig(CREVICES_FILE, objectmap.encodeCrevices(objectMap))
  showFlash(behind and "added" or "removed")
end

local markCheckpoint = function(name)
  if not player or not run.anchor
    or not checkpoints.put(checkpointSet, name, player.tileX - run.anchor.x, player.tileZ - run.anchor.z, player.height) then
    showFlash("unknown")
    return
  end
  bolt.saveconfig(CHECKPOINTS_FILE, checkpoints.encode(checkpointSet))
  runstate.setSection(run, checkpointSet.markers[name].section)
  saveRun()
  showFlash("added")
end

local toggleLevel = function(name)
  if levels.toggle(playerLevels, name) then
    bolt.saveconfig(LEVELS_FILE, levels.encode(playerLevels))
  end
end

bolt.onmousemotion(function(event)
  if not active then return end
  local x, y = event:xy()
  mouse = { x = x, y = y }
  lootcounter.setMouse(x, y)
  clickprobe.mouseAt(x, y)
  clicks.mouseAt(x, y)
end)

bolt.onmousebutton(function(event)
  if active then clickprobe.clicked(event:button(), event:xy()) end
  if active and event:button() == LEFT_BUTTON then
    local cx, cy = event:xy()
    clicks.click(cx, cy, bolt.time())
  end
  if active and event:button() == LEFT_BUTTON then
    guarded("maze", mazeroute.click, bolt.time(), event:xy())
    guarded("inventory", noticeAnchorClick, event:xy())
    return
  end
  if event:button() ~= MIDDLE_BUTTON then
    return
  end
  if pickTarget == "entrancea" or pickTarget == "entranceb" then
    local x, y = event:xy()
    guarded("entrance", entrance.pick, pickTarget:sub(-1), viewProj, player, x, y)
    pickTarget = nil
    return
  end
  if not active then
    return
  end
  if pickTarget and not event:ctrl() and not event:shift() and not event:alt() then
    local target = pickTarget
    pickTarget = nil
    if target == "xpdrops" then
      local x, y = event:xy()
      guarded("xp", xpprobe.start, x, y, bolt.time())
    else
      pickIcon(target, event:xy())
    end
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
  battery = function() pickTarget = pickTarget ~= "battery" and "battery" or nil end,
  lootbag = function() pickTarget = pickTarget ~= "lootbag" and "lootbag" or nil end,
  xpdrops = function() pickTarget = pickTarget ~= "xpdrops" and "xpdrops" or nil end,
  clickprobe = function() guarded("probe", clickprobe.toggle, bolt.time()) end,
  entrance = function(argument)
    if argument == "a" or argument == "b" then
      local target = "entrance" .. argument
      pickTarget = pickTarget ~= target and target or nil
    else
      entrance.command(argument)
    end
  end,
  marktile = function()
    if SHOW_TILE_MARKERS then atPlayer(toggleMarker) end
  end,
  logtile = function() atPlayer(logPosition) end,
  add = addTaggedModel,
  crevice = toggleCrevice,
  capture = function()
    shots.pending = true
    if not panel.capture(true) then showFlash("unknown") end
  end,
  shot = function(image)
    shots.pending = false
    panel.capture(false)
    shots.count = shots.count + 1
    bolt.saveconfig(string.format("capture-%d.ppm", shots.count), image)
    if run.anchor and player and viewProj then
      bolt.saveconfig(string.format("capture-%d.csv", shots.count),
        mazegrid.corners(bolt, viewProj, run.anchor, MAZE_CENTRE, MAZE_CENTRE.radius, player.height))
    end
    showFlash("added")
  end,
  checkpoint = markCheckpoint,
  mazerow = function(name)
    if not player or not run.anchor then
      showFlash("unknown")
      return
    end
    local complete = mazeroute.markRow(name, player.tileX - run.anchor.x, player.tileZ - run.anchor.z)
    showFlash(complete and "added" or "tagged")
  end,
  level = toggleLevel,
  link = linkCommand,
  compare = compareCommand,
  select = selectCandidate,
  watch = watchCommand,
})

bolt.onrender3d(function(event)
  viewProj = event:viewprojmatrix()
  guarded("objects", objectScan.inspect, bolt, event, player and player.tileX, player and player.tileZ)
  if not active then return end
  guarded("rings", visionrings.inspect, event)
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
  guarded("inventory", inventory.inspect2d, event, lootcounter.want)
  if xpprobe.active() then guarded("xp", xpprobe.inspect2d, event) end
  if clickprobe.active() then guarded("probe", clickprobe.inspect2d, event) end
  guarded("xp", xpdrops.inspect2d, event)
end)

bolt.onminimapterrain(function(event)
  if active then guarded("minimap", minimap.terrain, event) end
end)

bolt.onrenderminimap(function(event)
  if active then guarded("minimap", minimap.render, event) end
end)

bolt.onrendericon(function(event)
  if not active then return end
  guarded("inventory", inventory.inspectIcon, event)
end)

bolt.onswapbuffers(function()
  guarded("player", updatePlayer)
  guarded("loot", lootcounter.updatePlayerScreen, viewProj)
  active = inVault()
  if runFinished and not active and player then
    runFinished = false
    runstate.resetRun(run)
    saveRun()
    lootcounter.append(string.format("teleported out after completing the run: run reset (landed on tile %d, %d)",
      player.tileX, player.tileZ))
  elseif not active and runstate.inProgress(run) and entrance.atEntrance(player) then
    runstate.resetRun(run)
    saveRun()
    lootcounter.append(string.format("left the vault before finishing: run reset (now on tile %d, %d)", player.tileX, player.tileZ))
  end
  if active then
    guarded("ticks", ticksync.frame, bolt.time(), player)
    guarded("xp", xpdrops.endFrame, bolt.time(), ticksync.xpDrop)
  end
  if xpprobe.active() or clickprobe.active() then
    guarded("xp", xpprobe.endFrame, bolt.time())
    guarded("probe", clickprobe.endFrame, bolt.time())
  end
  local inLobby = not active and entrance.showPanel(player)
  guarded("panel", panel.setVisible, active or inLobby, player and string.format("%s, you on tile %d, %d",
    active and "in the vault" or (inLobby and "near the entrance" or "away from both"), player.tileX, player.tileZ))
  local finished = picker.advance()
  if finished then
    saveTag(finished)
  end
  if active and SHOW_TILE_MARKERS then
    guarded("draw", markers.draw, bolt, markerData, viewProj)
  end
  if player then
    guarded("watch", watch.notePlayer, bolt.time(), player.tileX, player.tileZ)
  end
  guarded("watch", watch.endFrame, bolt.time())
  if active then
    guarded("inventory", processInventory)
    guarded("inventory", checkAnchorClick)
  end
  guarded("inventory", flushInventory, bolt.time())
  guarded("loot", lootcounter.flush, bolt.time())
  local seenObjects, watchedModels, selectedPoints = objectScan.takeFrame()
  guarded("highlight", processObjects, seenObjects, watchedModels, selectedPoints)
  if active then
    guarded("maze", mazeroute.notePlayer, run, player, bolt.time())
    guarded("maze", mazeroute.frame, run, player, viewProj, MAZE_CENTRE, playerLevels.maze, bolt.time())
    panel.capture(shots.pending)
    guarded("maze", mazeroute.draw, run, player, viewProj)
    guarded("rings", visionrings.endFrame, bolt.time(), run.anchor, player)
    guarded("minimap", drawMinimap)
    visionrings.showUnseen(playerLevels.ghostsUnseen)
    if playerLevels.ghosts then guarded("rings", visionrings.draw, viewProj) end
  else
    guarded("maze", mazeroute.stop)
  end
  if active and player and RECORD_UNLINKED_ANCHORS then
    guarded("record", recorder.update, bolt.time(), objectsInView, player.tileX, player.tileZ, run.anchor,
      function(dx, dz) return links.isLinked(linkSet, dx, dz) end, appendRecord)
  end
  if active then
    guarded("watch", flushWatchRaw, bolt.time())
  end
  guarded("record", flushRecord, bolt.time())
  if panel.devEnabled() and (active or inLobby) then guarded("entrance", entrance.draw, viewProj, player) end
  if inLobby then
    local lobbyStatus = status.build(run, objectMap, nil, playerLevels)
    lobbyStatus.lobby = true
    lobbyStatus.runs = runStats()
    lobbyStatus.entrance = entrance.status()
    lobbyStatus.pickTarget = pickTarget
    guarded("panel", panel.update, bolt.time(), lobbyStatus)
  end
  if not active then return end
  local panelStatus = status.build(run, objectMap, run.anchor and run.section, playerLevels)
  if panel.devEnabled() then
    panelStatus.mapping = status.mapping(objectMap)
    panelStatus.mapping.battery = batterySignature ~= nil
    panelStatus.mapping.lootBag = lootcounter.bagKnown()
    panelStatus.mapping.checkpoints = checkpoints.list(checkpointSet)
    panelStatus.mapping.mazeRows = mazeroute.rowStatus()
  end
  panelStatus.tagArmed = tagArmed
  panelStatus.pickTarget = pickTarget
  panelStatus.xpProbe = xpprobe.status(bolt.time())
  panelStatus.clickProbe = clickprobe.status(bolt.time())
  panelStatus.maze = mazeroute.status()
  panelStatus.loot = run.loot
  panelStatus.runs = runStats()
  panelStatus.entrance = entrance.status()
  panelStatus.lastTag = lastTag
  panelStatus.chat = chatProblem()
  panelStatus.link = linkwizard.status(wizard)
  panelStatus.linkCount = #linkSet.list
  panelStatus.compare = comparisonStatus()
  panelStatus.watch = watch.status()
  guarded("panel", panel.update, bolt.time(), panelStatus)
  guarded("loot", lootcounter.draw)
  if flash and bolt.time() < flashUntil then
    flash:drawtoscreen(0, 0, 1, 1, FLASH_MARGIN, FLASH_MARGIN, FLASH_SIZE, FLASH_SIZE)
  end
end)
