local coords = require("core.coords")
local visionring = require("core.visionring")
local ghosttrack = require("core.ghosttrack")
local ghostroutes = require("core.ghostroutes")
local ghostpaths = require("core.ghostpaths")
local ghostsync = require("core.ghostsync")
local rollinglog = require("core.rollinglog")
local signature = require("game.signature")
local lines = require("gfx.lines")
local spawntimer = require("core.spawntimer")

local M = {}

local COLOUR = { 255, 70, 70, 230 }
local FALLBACK_COLOUR = { 255, 190, 60, 200 }
local THICKNESS = 6
local FILL_COLOUR = { 255, 40, 40, 70 }
local TIMER_COLOURS = { back = { 0, 0, 0, 170 }, full = { 255, 255, 255, 235 }, empty = { 90, 90, 90, 150 } }
local TIMER_WIDTH_PIXELS = 60
local TIMER_HEIGHT_PIXELS = 7
local TIMER_LIFT_UNITS = 1100
local APPEAR_SEEN_LATE_MICROSECONDS = 53 * 1000
local CATCH_LOG_TILES = 20
local TRACK_FILE = "ghosts.log"
local TRACK_LINES = 6000
local TRACK_FLUSH_MICROSECONDS = 2 * 1000 * 1000
local ROUTES_FILE = "ghostroutes.csv"
local RUN_COUNT_FILE = "ghostruns.csv"
local RUN_FLUSH_MICROSECONDS = 10 * 1000 * 1000
local LEGACY_ROUTES_FILE = "ghostroutes-noheight.csv"
local ROUTES_FLUSH_MICROSECONDS = 5 * 1000 * 1000

local bolt = nil
local log = function() end
local onStart = function() end
local boundary = function() return nil end
local loops = ghostpaths.prepare(require("data.ghostpaths"))
local KNOWN_SPAWNS = require("data.ghostspawns")
local SPAWN_MATCH_TILES = 0.25
local SPAWN_MATCH_HEIGHT = 300
local sync = ghostsync.new(loops)
local mask = visionring.mask(visionring.RADIUS_TILES)
local edges = visionring.outline(mask)
local maskTiles = {}
for k in pairs(mask) do
  local x, z = k:match("(-?%d+),(-?%d+)")
  maskTiles[#maskTiles + 1] = { tonumber(x), tonumber(z) }
end
local frame, current = {}, {}
local tracker = ghosttrack.new()
local trackLog = nil
local trackDirty, nextTrackFlush = false, 0
local trackedAnchor = nil
local trackedAt = nil
local runLines, runFile, runDirty, nextRunFlush = {}, nil, false, 0
local routes = nil
local SPAWN_TILES = 4
local SPAWN_MICROSECONDS = 6 * 1000 * 1000
local LATE_RUMMAGE_MICROSECONDS = 1000 * 1000
local SPAWN_IDLE_SECONDS = 5
local STALL_START_MICROSECONDS = 150 * 1000
local DRAW_GRACE_MICROSECONDS = 250 * 1000
local CANDIDATE_OFFSETS = { 0, -0.5, -1 }
local TEST_REACH_TILES = 8
local TELEPORT_TILES = 3
local HISTORY_MICROSECONDS = 2 * 1000 * 1000
local playerHistory = {}
local lastTestTick = nil
local rummages = {}
local spawns = {}
local spawnTicks = {}
local routesDirty, nextRoutesFlush = false, 0

function M.init(boltApi, logger, ghostStarted, tickBoundary)
  bolt = boltApi
  log = logger or log
  onStart = ghostStarted or onStart
  boundary = tickBoundary or boundary
  trackLog = rollinglog.new(bolt.loadconfig(TRACK_FILE), TRACK_LINES)
  routes = ghostroutes.decode(bolt.loadconfig(ROUTES_FILE))
  if #routes.legacy > 0 then
    local kept = bolt.loadconfig(LEGACY_ROUTES_FILE) or ""
    bolt.saveconfig(LEGACY_ROUTES_FILE, kept .. table.concat(routes.legacy, "\n") .. "\n")
    bolt.saveconfig(ROUTES_FILE, ghostroutes.encode(routes))
    routes.legacy = {}
  end
end

local track = function(at, line)
  local text = string.format("[%9.3f] %s", at / 1e6, line)
  rollinglog.append(trackLog, text)
  trackDirty = true
  if runFile then
    runLines[#runLines + 1] = text
    runDirty = true
  end
end

local startRunFile = function()
  local n = (tonumber((bolt.loadconfig(RUN_COUNT_FILE) or ""):match("%d+")) or 0) + 1
  bolt.saveconfig(RUN_COUNT_FILE, tostring(n) .. "\n")
  runFile, runLines, runDirty = string.format("ghosts-run-%d.log", n), {}, false
end

local spawnedBy = function(e, list)
  for _, r in ipairs(list or rummages) do
    if e.at - r.at <= SPAWN_MICROSECONDS and math.max(math.abs(e.x - r.dx - 0.5), math.abs(e.z - r.dz - 0.5)) <= SPAWN_TILES then
      return r.key
    end
  end
  return nil
end

local noteAppearance = function(id, at)
  spawnTicks[id] = boundary(at - APPEAR_SEEN_LATE_MICROSECONDS, true) or at
end

local markSpawn = function(now, ghost, why)
  spawns[ghost.id] = true
  noteAppearance(ghost.id, ghost.appearedAt)
  ghosttrack.pin(tracker, ghost.id)
  routes.ghosts[ghost.id] = nil
  track(now, string.format("g%d treated as a spawn: %s", ghost.id, why))
end

function M.noteRummage(now, corpseKey)
  local dx, dz = corpseKey:match("^(%-?%d+),(%-?%d+)$")
  if not dx then return end
  local rummage = { at = now, key = corpseKey, dx = tonumber(dx), dz = tonumber(dz) }
  for _, ghost in ipairs(tracker.ghosts) do
    if not spawns[ghost.id] and not ghost.everMoved and now - ghost.appearedAt <= LATE_RUMMAGE_MICROSECONDS
      and spawnedBy({ at = now, x = ghost.x, z = ghost.z }, { rummage }) then
      markSpawn(now, ghost, "appeared just before the rummage of corpse " .. corpseKey)
    end
  end
  local kept = { rummage }
  for _, r in ipairs(rummages) do
    if now - r.at <= SPAWN_MICROSECONDS then kept[#kept + 1] = r end
  end
  rummages = kept
end

local knownSpawn = function(e)
  for _, s in ipairs(KNOWN_SPAWNS) do
    if math.abs(e.x - s.x - 0.5) <= SPAWN_MATCH_TILES and math.abs(e.z - s.z - 0.5) <= SPAWN_MATCH_TILES
      and math.abs((e.y or s.h) - s.h) <= SPAWN_MATCH_HEIGHT then
      return s.corpse.dx .. "," .. s.corpse.dz
    end
  end
  return nil
end

local recordRoutes = function(now, anchor)
  if not anchor then return end
  if not trackedAnchor or trackedAnchor.x ~= anchor.x or trackedAnchor.z ~= anchor.z then
    trackedAnchor = { x = anchor.x, z = anchor.z }
    if runFile and runDirty then bolt.saveconfig(runFile, table.concat(runLines, "\n") .. "\n") end
    startRunFile()
    tracker = ghosttrack.new()
    routes.ghosts = {}
    rummages, spawns, spawnTicks = {}, {}, {}
    sync = ghostsync.new(loops)
    track(now, string.format("run: arrival at %d,%d, tiles below are relative to it", anchor.x, anchor.z))
  end
  trackedAt = now
  local rings = {}
  for i, ring in ipairs(current) do
    rings[i] = { x = ring.x / coords.TILE_SIZE - anchor.x, z = ring.z / coords.TILE_SIZE - anchor.z, y = ring.y }
  end
  for _, e in ipairs(ghosttrack.update(tracker, now, rings)) do
    local corpse = e.kind == "appear" and (knownSpawn(e) or spawnedBy(e))
    if corpse then
      spawns[e.id] = corpse
      noteAppearance(e.id, e.at)
      ghosttrack.pin(tracker, e.id)
    end
    track(e.at, ghosttrack.format(e) .. (corpse and string.format(" (spawned by corpse %s)", corpse) or ""))
    if not spawns[e.id] then
      if e.kind == "start" then onStart(e) end
      if ghostroutes.observe(routes, e) then routesDirty = true end
      local message = nil
      if e.kind == "tile" then
        message = ghostsync.observeTile(sync, e.id, { x = e.tileX, z = e.tileZ }, e.at, function(t) return boundary(t, true) end)
      elseif e.kind == "start" and e.still >= STALL_START_MICROSECONDS then
        message = ghostsync.observeStart(sync, e.id, boundary(e.at, true))
      end
      if message then track(e.at, string.format("g%d %s", e.id, message)) end
    end
    if e.kind == "lost" then ghostsync.forget(sync, e.id) end
    if e.kind == "lost" then spawns[e.id], spawnTicks[e.id] = nil, nil end
  end
  for _, ghost in ipairs(ghosttrack.idleSinceAppearing(tracker, now, SPAWN_IDLE_SECONDS)) do
    if not spawns[ghost.id] then markSpawn(now, ghost, "hasn't moved since appearing " .. SPAWN_IDLE_SECONDS .. " s ago") end
  end
  if routesDirty and now >= nextRoutesFlush then
    bolt.saveconfig(ROUTES_FILE, ghostroutes.encode(routes))
    routesDirty, nextRoutesFlush = false, now + ROUTES_FLUSH_MICROSECONDS
  end
  if runDirty and now >= nextRunFlush then
    bolt.saveconfig(runFile, table.concat(runLines, "\n") .. "\n")
    runDirty, nextRunFlush = false, now + RUN_FLUSH_MICROSECONDS
  end
  if trackDirty and now >= nextTrackFlush then
    bolt.saveconfig(TRACK_FILE, rollinglog.text(trackLog))
    trackDirty, nextTrackFlush = false, now + TRACK_FLUSH_MICROSECONDS
  end
end

function M.inspect(event)
  local count = event:vertexcount()
  if count ~= visionring.VERTICES or event:animated() then return end
  if signature.fingerprint(event, count) ~= visionring.FINGERPRINT then return end
  local x, y, z = bolt.point(0, 0, 0):transform(event:modelmatrix()):get()
  local tile = coords.fromWorld(x, z)
  local k = tile.tileX .. "," .. tile.tileZ
  if not frame[k] then
    frame[k] = { x = x, y = y, z = z, tileX = tile.tileX, tileZ = tile.tileZ }
  end
end

local playerBeforeJump = function(now)
  local newest = playerHistory[#playerHistory]
  for i = #playerHistory, 2, -1 do
    local a, b = playerHistory[i - 1], playerHistory[i]
    if math.max(math.abs(a.x - b.x), math.abs(a.z - b.z)) > TELEPORT_TILES then return a end
  end
  return newest
end

local offsetsSeeing = function(me)
  local lines = {}
  for id, li in pairs(sync.ghostLoop) do
    if sync.sync[li] and not spawns[id] then
      local parts, any, near = {}, false, false
      for _, offset in ipairs(CANDIDATE_OFFSETS) do
        local t = boundary(trackedAt + offset * ghostsync.PERIOD)
        local p = t and ghostsync.predicted(sync, li, t)
        if p then
          near = near or math.max(math.abs(p.x - me.x), math.abs(p.z - me.z)) <= TEST_REACH_TILES
          local inside = visionring.covers(mask, p.x, p.z, me.x, me.z)
          any = any or inside
          parts[#parts + 1] = string.format("%+g %s", offset, inside and "yes" or "no")
        end
      end
      if near then lines[#lines + 1] = { any = any, text = string.format("g%d (%s): %s", id, loops[li].name, table.concat(parts, ", ")) } end
    end
  end
  return lines
end

local testTick = function(now)
  local tick = boundary(now)
  if not tick or tick == lastTestTick then return end
  lastTestTick = tick
  local me = playerHistory[#playerHistory]
  if not me then return end
  for _, l in ipairs(offsetsSeeing(me)) do
    if l.any then track(now, string.format("tick: you on %d,%d; inside by offset: %s", me.x, me.z, l.text)) end
  end
end

function M.endFrame(now, anchor, player)
  current = {}
  for _, ring in pairs(frame) do current[#current + 1] = ring end
  frame = {}
  recordRoutes(now, anchor)
  if anchor and player then
    playerHistory[#playerHistory + 1] = { at = now, x = player.tileX - anchor.x, z = player.tileZ - anchor.z }
    while #playerHistory > 1 and now - playerHistory[1].at > HISTORY_MICROSECONDS do table.remove(playerHistory, 1) end
    testTick(now)
  end
end

function M.rings()
  return current
end

local showUnseen = false

function M.showUnseen(show)
  showUnseen = show
end

local drawnTiles = function()
  if not trackedAnchor or not trackedAt then return current end
  local out, seenLoops = {}, {}
  local clocked = boundary(trackedAt) ~= nil
  for _, ghost in ipairs(tracker.ghosts) do
    if trackedAt - ghost.seenAt <= DRAW_GRACE_MICROSECONDS then
      local step = nil
      if spawns[ghost.id] then
        out[#out + 1] = { tileX = math.floor(ghost.x) + trackedAnchor.x, tileZ = math.floor(ghost.z) + trackedAnchor.z, y = ghost.y, synced = true,
          countdown = spawntimer.remaining(spawnTicks[ghost.id], trackedAt) }
      elseif clocked then
        local li
        step, li = ghostsync.tileFor(sync, ghost.id, { x = math.floor(ghost.x), z = math.floor(ghost.z) }, ghost.y, trackedAt, true)
        if li then seenLoops[li] = true end
      end
      if spawns[ghost.id] then
      elseif step then
        out[#out + 1] = { tileX = step.x + trackedAnchor.x, tileZ = step.z + trackedAnchor.z, y = step.h or ghost.y, synced = true }
      else
        local ahead, on = nil, nil
        if not spawns[ghost.id] then ahead, on = ghostsync.routeAhead(sync, ghost.id) end
        if ahead then
          local tile = ghosttrack.moving(ghost, trackedAt) and ahead or on
          out[#out + 1] = { tileX = tile.x + trackedAnchor.x, tileZ = tile.z + trackedAnchor.z, y = tile.h or ghost.y }
        else
          local tx, tz = ghosttrack.trueTile(ghost, trackedAt)
          out[#out + 1] = { tileX = tx + trackedAnchor.x, tileZ = tz + trackedAnchor.z, y = ghost.y }
        end
      end
    end
  end
  if showUnseen and boundary(trackedAt) then
    for _, u in ipairs(ghostsync.unseen(sync, trackedAt, seenLoops)) do
      out[#out + 1] = { tileX = u.step.x + trackedAnchor.x, tileZ = u.step.z + trackedAnchor.z, y = u.step.h or 0, synced = true }
    end
  end
  return out
end

function M.minimapGhosts()
  if not trackedAnchor then return {} end
  local out = {}
  for _, ring in ipairs(drawnTiles()) do
    out[#out + 1] = { dx = ring.tileX - trackedAnchor.x, dz = ring.tileZ - trackedAnchor.z, y = ring.y, synced = ring.synced }
  end
  return out
end

function M.draw(viewProj)
  if not viewProj then return end
  local rings = drawnTiles()
  local vx, vy, vw, vh = bolt.gameviewxywh()
  local out = {}
  local project = function(ring, ex, ez)
    local sx, sy, depth = bolt.point((ring.tileX + ex) * coords.TILE_SIZE, ring.y, (ring.tileZ + ez) * coords.TILE_SIZE)
      :transform(viewProj):togameview()
    if not depth or depth <= 0 or depth > 1 then return nil end
    return sx, sy
  end
  local bars, fills = {}, {}
  for _, ring in ipairs(rings) do
    if ring.synced then
      local corner = {}
      local at = function(x, z)
        local k = x .. "," .. z
        if corner[k] == nil then
          local sx, sy = project(ring, x, z)
          corner[k] = sx and { sx, sy } or false
        end
        return corner[k]
      end
      for _, t in ipairs(maskTiles) do
        local a, b, c, d = at(t[1], t[2]), at(t[1] + 1, t[2]), at(t[1] + 1, t[2] + 1), at(t[1], t[2] + 1)
        if a and b and c and d then
          fills[#fills + 1] = { a[1], a[2], b[1], b[2], c[1], c[2], d[1], d[2], colour = FILL_COLOUR }
        end
      end
    end
    for _, e in ipairs(edges) do
      local ax, ay = project(ring, e[1], e[2])
      local bx, by = project(ring, e[3], e[4])
      if ax and bx then out[#out + 1] = { ax, ay, bx, by, colour = ring.synced and COLOUR or FALLBACK_COLOUR } end
    end
    if ring.countdown then
      local cx, cy = project({ tileX = ring.tileX, tileZ = ring.tileZ, y = ring.y + TIMER_LIFT_UNITS }, 0.5, 0.5)
      if cx then
        for _, q in ipairs(spawntimer.bar(ring.countdown, cx, cy, TIMER_WIDTH_PIXELS, TIMER_HEIGHT_PIXELS, TIMER_COLOURS)) do
          bars[#bars + 1] = q
        end
      end
    end
  end
  if #out == 0 then return end
  lines.setScreenDimensions(vw, vh)
  lines.drawQuads(bolt, fills, vx, vy)
  lines.drawLines(bolt, out, THICKNESS, vx, vy)
  lines.drawQuads(bolt, bars, vx, vy)
end

function M.caught(anchor, player)
  if not anchor or not player then return end
  local me = playerBeforeJump(trackedAt or 0) or { x = player.tileX - anchor.x, z = player.tileZ - anchor.z }
  local lines = offsetsSeeing(me)
  for _, l in ipairs(lines) do
    local text = string.format("caught: you on %d,%d; inside by offset: %s", me.x, me.z, l.text)
    log(text)
    track(trackedAt or 0, text)
  end
  if #lines == 0 then
    local near = 0
    for _, ring in ipairs(current) do
      local dx, dz = ring.tileX - anchor.x, ring.tileZ - anchor.z
      if math.max(math.abs(dx - me.x), math.abs(dz - me.z)) <= CATCH_LOG_TILES then
        near = near + 1
        log(string.format("caught: ring drawn on %d,%d, you on %d,%d, no synced route for it", dx, dz, me.x, me.z))
      end
    end
    if near == 0 then log(string.format("caught: no vision ring in view, you on %d,%d", me.x, me.z)) end
  end
end

return M
