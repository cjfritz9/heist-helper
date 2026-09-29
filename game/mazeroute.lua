local maze = require("core.maze")
local mazepatterns = require("core.mazepatterns")
local shapes = require("data.mazeshapes")
local json = require("core.json")
local mazegrid = require("game.mazegrid")
local lines = require("gfx.lines")
local seed = require("data.maze")

local M = {}

local FILE = "maze.csv"

local THICKNESS = 4
local NEAR_TILES = 6
local BURST_DELAY_MICROSECONDS = 1200 * 1000
local BURST_GAP_MICROSECONDS = 600 * 1000
local BURST_FRAMES = 4
local WAIT_MICROSECONDS = 3 * 1000 * 1000
local KEEP_MICROSECONDS = 90 * 1000 * 1000
local NEXT_FILL = { 60, 255, 120, 150 }
local LATER_FILL = { 70, 170, 255, 90 }
local LINE_COLOUR = { 60, 255, 120, 230 }
local INSET = 0.12

local bolt = nil
local ends = {}
local rows = {}
local session = maze.newSession()
local leg = nil
local route = nil
local grid = nil
local pulse = { waiting = false, since = 0 }
local burst = nil
local triggeredAt = nil
local triggeredLeg = nil
local browser = nil
local browserReady = false
local library = {}
local log = function() end
local lastReport = nil

local rebuildRows = function()
  rows = {}
  for _, name in ipairs(maze.ORDER) do
    local e = ends[name]
    local row = e and maze.row(e[1], e[2])
    if row then rows[name] = row end
  end
end

local save = function()
  local out = {}
  for _, name in ipairs(maze.ORDER) do
    for i, t in ipairs(ends[name] or {}) do
      out[#out + 1] = string.format("%s,%d,%d,%d", name, i, t.dx, t.dz)
    end
  end
  bolt.saveconfig(FILE, table.concat(out, "\n") .. "\n")
end

function M.init(boltApi, logger)
  bolt = boltApi
  log = logger or log
  library = mazepatterns.fromShapes(shapes)
  for name, pair in pairs(seed.rows) do
    ends[name] = { pair[1], pair[2] }
  end
  for line in (bolt.loadconfig(FILE) or ""):gmatch("[^\n]+") do
    local name, i, dx, dz = line:match("^(%a+),(%d),(%-?%d+),(%-?%d+)$")
    if name then
      ends[name] = ends[name] or {}
      ends[name][tonumber(i)] = { dx = tonumber(dx), dz = tonumber(dz) }
    end
  end
  rebuildRows()
end

function M.markRow(name, dx, dz)
  local e = ends[name]
  if not e or #e >= 2 then
    e = {}
    ends[name] = e
  end
  e[#e + 1] = { dx = dx, dz = dz }
  rebuildRows()
  save()
  return #e == 2 and rows[name] ~= nil
end

function M.rowStatus()
  local out = {}
  for _, name in ipairs(maze.ORDER) do
    out[#out + 1] = { name = name, ends = ends[name] and #ends[name] or 0, ok = rows[name] ~= nil }
  end
  return out
end

function M.wanted(run, player, enabled, centre)
  if not enabled or not run.anchor or run.section ~= 4 or not player then return false end
  local dx, dz = player.tileX - run.anchor.x - centre.dx, player.tileZ - run.anchor.z - centre.dz
  return math.max(math.abs(dx), math.abs(dz)) <= centre.radius + NEAR_TILES
end

local closeBrowser = function()
  if browser then
    browser:close()
    log("maze: capture window closed")
  end
  browser = nil
  browserReady = false
  pulse.waiting = false
end

local CAPTURE_SIZE = 8

local openBrowser = function()
  browser = bolt.createembeddedbrowser(0, 0, CAPTURE_SIZE, CAPTURE_SIZE, "plugin://ui/capture.html")
  browserReady = false
  log("maze: capture window opened")
  browser:onmessage(function(message)
    local text = message:match("^mazelit:(.*)$")
    if text then
      M.lit(text, bolt.time())
      return
    end
    local info = message:match("^mazeinfo:(.*)$")
    if info == "ready" then browserReady = true end
    if info then log("maze capture: " .. info) end
  end)
end

function M.stop()
  closeBrowser()
  grid, route = nil, nil
end

local capture = function(now)
  if not burst or not grid then
    if browser and not burst then closeBrowser() end
    return
  end
  if not browser then openBrowser() end
  if not browserReady then return end
  if pulse.waiting then
    if now - pulse.since < WAIT_MICROSECONDS then return end
    browser:disablecapture()
    pulse.waiting = false
  end
  if now < burst.at then return end
  browser:sendmessage(json.encode(grid))
  browser:enablecapture()
  pulse.waiting, pulse.since = true, now
end

local reset = function()
  session = maze.newSession()
  leg, route, burst, triggeredAt, triggeredLeg, lastReport = nil, nil, nil, nil, nil, nil
end

function M.legForCrystal(dx, dz)
  local start = maze.nearestBarrier(rows, dx, dz)
  local finish = start and maze.nextBarrier(start)
  if not finish then return nil end
  return start
end

function M.trigger(now, crystalDx, crystalDz)
  local start = M.legForCrystal(crystalDx, crystalDz)
  if not start then
    log(string.format("maze: crystal at %d,%d shuts the mazes down, ignored", crystalDx, crystalDz))
    return false
  end
  if leg and leg.pattern and leg.start == start then
    log(string.format("maze: %s crystal clicked again, keeping the identified maze", start))
    return false
  end
  reset()
  triggeredAt, triggeredLeg = now, start
  burst = { at = now + BURST_DELAY_MICROSECONDS, left = BURST_FRAMES }
  log(string.format("maze: %s crystal clicked, capturing %d frames", start, BURST_FRAMES))
  return true
end

function M.frame(run, player, viewProj, centre, enabled, now)
  grid = nil
  if not M.wanted(run, player, enabled, centre) or not viewProj then
    if triggeredAt then reset() end
    closeBrowser()
    return
  end
  if triggeredAt and not burst and now - triggeredAt > KEEP_MICROSECONDS then
    log("maze: route expired")
    reset()
  end
  grid = mazegrid.grid(bolt, viewProj, run.anchor, centre, centre.radius, player.height)
  capture(now)
  local dx, dz = player.tileX - run.anchor.x, player.tileZ - run.anchor.z
  if not maze.active(session) then
    route = nil
    return
  end
  if not leg then
    local start = triggeredLeg or maze.nearestBarrier(rows, dx, dz)
    leg = start and { start = start, finish = maze.nextBarrier(start) } or nil
    if leg then
      leg.key = leg.finish and mazepatterns.legKey(leg.start, leg.finish) or nil
      log(string.format("maze: path lit, leg %s → %s", leg.start, tostring(leg.finish)))
    end
  end
  if not leg or not leg.finish then
    route = nil
    return
  end
  if not leg.pattern then
    local ignore = {}
    for _, name in ipairs({ leg.start, leg.finish }) do
      for _, t in ipairs(rows[name] or {}) do ignore[t.dx .. "," .. t.dz] = true end
    end
    local best, why = mazepatterns.match(library[leg.key], session.lit, ignore)
    if best then
      leg.pattern = library[leg.key][best]
      log("maze: identified " .. leg.key .. " " .. why)
    elseif why ~= leg.why then
      leg.why = why
      log("maze: not identified yet (" .. why .. ")")
    end
  end
  if leg.finish and maze.isSafe({ lit = {} }, rows, { leg.finish }, dx, dz) and triggeredAt and not burst then
    log("maze: reached the " .. leg.finish .. " row, route done")
    reset()
    return
  end
  local tiles = leg.pattern and { lit = leg.pattern.tiles } or session
  local inside = maze.isSafe(tiles, rows, { leg.start, leg.finish }, dx, dz)
  local plan = leg.plan
  if plan and plan.progress > 0 and maze.isSafe({ lit = {} }, rows, { leg.start }, dx, dz) then
    log("maze: back on the start row, planning again")
    plan, leg.plan = nil, nil
  end
  if not plan and inside and not burst then
    local steps = maze.route(tiles, rows, dx, dz, leg.start, leg.finish)
    if steps then
      plan = { origin = { dx = dx, dz = dz }, tiles = steps, progress = 0 }
      leg.plan = plan
    end
  end
  if plan then
    for i = plan.progress + 1, #plan.tiles do
      local t = plan.tiles[i]
      if t.dx == dx and t.dz == dz then plan.progress = i end
    end
  end
  route = plan
  local litList = {}
  for k in pairs(session.lit) do litList[#litList + 1] = k end
  table.sort(litList)
  local litText = table.concat(litList, " ")
  if litText ~= leg.litText then
    leg.litText = litText
    log("maze: lit tiles " .. litText)
  end
  if plan and plan ~= leg.loggedPlan then
    leg.loggedPlan = plan
    local steps = {}
    for i, t in ipairs(plan.tiles) do steps[i] = t.dx .. "," .. t.dz end
    log(string.format("maze: planned from %d,%d: %s", plan.origin.dx, plan.origin.dz, table.concat(steps, " ")))
  end
  local report = plan and ("route " .. #plan.tiles .. " ticks, step " .. plan.progress)
    or (inside and "no route" or "not on a safe tile")
  if report ~= lastReport then
    lastReport = report
    log("maze: " .. report)
  end
end

function M.grid()
  return grid
end

function M.lit(text, now)
  if browser then browser:disablecapture() end
  pulse.waiting = false
  if burst then
    burst.left = burst.left - 1
    burst.at = now + BURST_GAP_MICROSECONDS
    if burst.left <= 0 then burst = nil end
  end
  local tiles = {}
  for dx, dz in text:gmatch("(%-?%d+),(%-?%d+)") do
    tiles[#tiles + 1] = { dx = tonumber(dx), dz = tonumber(dz) }
  end
  maze.observe(session, tiles)
end

function M.status()
  local lit = 0
  for _ in pairs(session.lit) do lit = lit + 1 end
  return { lit = lit, route = route and (#route.tiles - route.progress) or nil, leg = leg and (leg.start .. " → " .. tostring(leg.finish)) or nil,
    known = leg and leg.pattern ~= nil or nil, capturing = burst ~= nil or nil }
end

local project = function(run, player, viewProj, x, z)
  local sx, sy, depth = bolt.point((run.anchor.x + x) * 512, player.height, (run.anchor.z + z) * 512)
    :transform(viewProj):togameview()
  if not depth or depth <= 0 or depth > 1 then return nil end
  return { sx, sy }
end

function M.draw(run, player, viewProj)
  if not route or not player or route.progress >= #route.tiles then return end
  local vx, vy, vw, vh = bolt.gameviewxywh()
  local quads, path = {}, {}
  local from = route.progress > 0 and route.tiles[route.progress] or route.origin
  local here = project(run, player, viewProj, from.dx + 0.5, from.dz + 0.5)
  if here then path[1] = here end
  for i = route.progress + 1, #route.tiles do
    local t = route.tiles[i]
    local a = project(run, player, viewProj, t.dx + INSET, t.dz + INSET)
    local b = project(run, player, viewProj, t.dx + 1 - INSET, t.dz + INSET)
    local c = project(run, player, viewProj, t.dx + 1 - INSET, t.dz + 1 - INSET)
    local d = project(run, player, viewProj, t.dx + INSET, t.dz + 1 - INSET)
    if a and b and c and d then
      quads[#quads + 1] = { a[1], a[2], b[1], b[2], c[1], c[2], d[1], d[2],
        colour = i == route.progress + 1 and NEXT_FILL or LATER_FILL }
    end
    local centre = project(run, player, viewProj, t.dx + 0.5, t.dz + 0.5)
    if centre then path[#path + 1] = centre end
  end
  local edges = {}
  for i = 2, #path do
    edges[#edges + 1] = { path[i - 1][1], path[i - 1][2], path[i][1], path[i][2], colour = LINE_COLOUR }
  end
  lines.setScreenDimensions(vw, vh)
  lines.drawQuads(bolt, quads, vx, vy)
  if #edges > 0 then
    lines.drawLines(bolt, edges, THICKNESS, vx, vy)
  end
end

return M
