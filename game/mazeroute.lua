local maze = require("core.maze")
local mazepatterns = require("core.mazepatterns")
local shapes = require("data.mazeshapes")
local json = require("core.json")
local mazegrid = require("game.mazegrid")
local tickclock = require("core.tickclock")
local latency = require("core.latency")
local truetile = require("core.truetile")
local lines = require("gfx.lines")
local seed = require("data.maze")

local M = {}

local FILE = "maze.csv"

local LINE_THICKNESS = 3
local NEXT_BORDER_THICKNESS = 5
local LATER_BORDER_THICKNESS = 2
local NEAR_TILES = 6
local CLICK_REACH_TILES = 12
local BURST_GAP_MICROSECONDS = 500 * 1000
local BURST_FRAMES = 16
local WAIT_MICROSECONDS = 3 * 1000 * 1000
local MOVED_PIXELS = 1
local KEEP_MICROSECONDS = 90 * 1000 * 1000
local ARRIVAL_TIMEOUT_MICROSECONDS = 20 * 1000 * 1000
local CRYSTAL_REACH_TILES = 2
local MOVED_UNITS = 1
local NEXT_FILL = { 60, 255, 120, 170 }
local NEXT_BORDER = { 220, 255, 225, 255 }
local LATER_FILL = { 70, 170, 255, 110 }
local LATER_BORDER = { 120, 200, 255, 230 }
local LINE_COLOUR = { 60, 255, 120, 170 }
local INSET = 0.12
local BARRIER_HEIGHT_UNITS = 700
local BORDER_INSET = 0.05

local bolt = nil
local ends = {}
local rows = {}
local session = maze.newSession()
local leg = nil
local route = nil
local grid = nil
local pulse = { waiting = false, since = 0, sent = nil }
local previousGrid = nil
local burst = nil
local triggeredAt = nil
local triggeredLeg = nil
local arrivedAt = nil
local frames = {}
local clock = tickclock.new()
local lastPosition = nil
local view = nil
local model = truetile.new()
local drawnLags = {}
local ping = latency.new()
local sharedNextTick = function() return nil end
local sharedBoundary = function() return nil end
local tickAfter = function(after)
  return sharedNextTick(after) or tickclock.nextTick(clock, after)
end
local clickedFromStillAt = nil
local START_SEEN_LATE_MICROSECONDS = 37 * 1000
local START_ON_TICK_MICROSECONDS = 100 * 1000
local lastInMazeAt = nil
local WRONG_STEP_WINDOW_MICROSECONDS = 2 * 1000 * 1000
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

function M.init(boltApi, logger, nextTick, boundary)
  bolt = boltApi
  log = logger or log
  sharedNextTick = nextTick or sharedNextTick
  sharedBoundary = boundary or sharedBoundary
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

function M.notePlayer(run, player, now)
  if not run.anchor or not player then return end
  if maze.inside(rows, player.tileX - run.anchor.x, player.tileZ - run.anchor.z) then lastInMazeAt = now end
end

function M.recentlyInMaze(now)
  return lastInMazeAt ~= nil and now - lastInMazeAt <= WRONG_STEP_WINDOW_MICROSECONDS
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
    if maze.gridShift(grid, pulse.sent) > MOVED_PIXELS then
      browser:sendmessage(json.encode({ grid = grid }))
      pulse.sent = grid
    end
    if now - pulse.since < WAIT_MICROSECONDS then return end
    browser:disablecapture()
    pulse.waiting = false
  end
  if not burst.at or now < burst.at then return end
  browser:sendmessage(json.encode({ start = true, grids = previousGrid and { previousGrid, grid } or { grid } }))
  browser:enablecapture()
  pulse.waiting, pulse.since, pulse.sent = true, now, grid
end

local reset = function()
  if #drawnLags > 0 then
    log("maze: drawn character on each tile, ms after the true tile got there: " .. table.concat(drawnLags, ", "))
    drawnLags = {}
  end
  session = maze.newSession()
  leg, route, burst, triggeredAt, triggeredLeg, lastReport, arrivedAt = nil, nil, nil, nil, nil, nil, nil
  frames = {}
  truetile.reset(model)
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
  burst = { left = BURST_FRAMES, crystal = { dx = crystalDx, dz = crystalDz } }
  log(string.format("maze: %s crystal clicked, capturing %d frames once you reach it", start, BURST_FRAMES))
  return true
end

local awaitCrystal = function(run, player, now)
  if not burst or burst.at then return end
  if player and run.anchor then
    local dx, dz = player.tileX - run.anchor.x - burst.crystal.dx, player.tileZ - run.anchor.z - burst.crystal.dz
    if math.max(math.abs(dx), math.abs(dz)) <= CRYSTAL_REACH_TILES then
      burst.at, arrivedAt = now, now
      log(string.format("maze: reached the crystal %.1f s after the click, capturing", (now - triggeredAt) / 1e6))
      return
    end
  end
  if now - triggeredAt > ARRIVAL_TIMEOUT_MICROSECONDS then
    log("maze: never reached the clicked crystal, capture cancelled")
    reset()
  end
end

function M.frame(run, player, viewProj, centre, enabled, now)
  previousGrid, grid = grid, nil
  awaitCrystal(run, player, now)
  if not M.wanted(run, player, enabled, centre) or not viewProj then
    if triggeredAt and not (burst and not burst.at) then reset() end
    closeBrowser()
    view = nil
    truetile.reset(model)
    return
  end
  if triggeredAt and not burst and now - triggeredAt > KEEP_MICROSECONDS then
    log("maze: route expired")
    reset()
  end
  grid = mazegrid.grid(bolt, viewProj, run.anchor, centre, centre.radius, player.height)
  capture(now)
  view = { run = run, player = player, viewProj = viewProj }
  local moved = lastPosition ~= nil and player.x ~= nil
    and math.abs(player.x - lastPosition.x) + math.abs(player.z - lastPosition.z) > MOVED_UNITS
  local started = tickclock.observe(clock, now, moved)
  if started and clickedFromStillAt then
    local tick = sharedBoundary(now - START_SEEN_LATE_MICROSECONDS, true)
    if tick and tick > clickedFromStillAt and math.abs(now - START_SEEN_LATE_MICROSECONDS - tick) <= START_ON_TICK_MICROSECONDS then
      latency.note(ping, tick - clickedFromStillAt)
      local low, high = latency.bounds(ping)
      log(string.format("maze: you set off on the tick %d ms after your click (seen %d ms after it): round trip between %d and %s ms",
        (tick - clickedFromStillAt) / 1000, (now - tick) / 1000, low / 1000, high and math.floor(high / 1000) or "?"))
    end
    clickedFromStillAt = nil
  end
  if player.x then lastPosition = { x = player.x, z = player.z } end
  local stepped = truetile.advance(model, now, { dx = player.tileX - run.anchor.x, dz = player.tileZ - run.anchor.z },
    tickclock.standing(clock, now), started, tickAfter)
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
      log("maze: frames after reaching the crystal: " .. mazepatterns.timeline(frames, leg.pattern.tiles, ignore))
      if burst then
        burst = nil
        log("maze: identified, capture stopped early")
      end
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
  local onStartRow = maze.isSafe({ lit = {} }, rows, { leg.start }, dx, dz)
  if plan and not onStartRow then plan.leftStart = true end
  if plan and plan.leftStart and onStartRow then
    log("maze: back on the start row, planning again")
    plan, leg.plan = nil, nil
    truetile.reset(model)
  end
  if not plan and inside and not burst then
    local steps = maze.route(tiles, rows, dx, dz, leg.start, leg.finish)
    if steps then
      plan = { origin = { dx = dx, dz = dz }, tiles = steps, progress = 0, finish = leg.finish }
      leg.plan = plan
    end
  end
  for _, e in ipairs(stepped) do
    if e.kind == "drawn" then
      drawnLags[#drawnLags + 1] = string.format("%d,%d %s", e.tile.dx, e.tile.dz,
        e.lag and string.format("%+d", e.lag / 1000) or "not passed yet")
    elseif e.kind == "offpath" then
      log(string.format("maze: drawn on %d,%d, %d tiles off the true tile's path: starting again from there", e.tile.dx,
        e.tile.dz, e.off))
    elseif e.kind == "missed" then
      latency.note(ping, e.margin + tickclock.TICK_MICROSECONDS)
      local low = latency.bounds(ping)
      log(string.format("maze: you stood still, so the click for %d,%d (%d ms before the tick) missed it: round trip at least %d ms",
        e.click.tile.dx, e.click.tile.dz, e.margin / 1000, low / 1000))
    elseif e.kind == "ignored" then
      log(string.format("maze: you stood still instead of heading for %d,%d, so that click didn't take; back to where you are",
        e.click.tile.dx, e.click.tile.dz))
    elseif e.kind == "lost" then
      log(string.format("maze: click on %d,%d never happened, back to your drawn position", e.click.tile.dx, e.click.tile.dz))
    elseif plan and e.kind == "toward" and e.index and e.index - 1 > plan.progress then
      plan.progress = e.index - 1
    end
    if plan and (e.kind == "missed" or e.kind == "ignored") then
      plan.progress = math.min(plan.progress, (e.index or plan.progress + 1) - 1)
    end
    if plan and (e.kind == "reached" or e.kind == "toward") and model.tile then
      for i = plan.progress + 1, #plan.tiles do
        local t = plan.tiles[i]
        if t.dx == model.tile.dx and t.dz == model.tile.dz then
          plan.progress = i
          log(string.format("maze: true tile on step %d, %d ms after the click for %d,%d", i, (e.at - e.click.at) / 1000,
            e.click.tile.dx, e.click.tile.dz))
        end
      end
    end
  end
  if plan then
    for i = plan.progress + 1, #plan.tiles do
      local t = plan.tiles[i]
      if t.dx == dx and t.dz == dz then
        plan.progress = i
        log(string.format("maze: your drawn character arrived on step %d before the true tile did", i))
      end
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
  if arrivedAt then
    frames[#frames + 1] = { seconds = (now - arrivedAt) / 1e6, tiles = tiles }
  end
  maze.observe(session, tiles)
end

function M.status()
  local lit = 0
  for _ in pairs(session.lit) do lit = lit + 1 end
  return { lit = lit, route = route and (#route.tiles - route.progress) or nil, leg = leg and (leg.start .. " → " .. tostring(leg.finish)) or nil,
    known = leg and leg.pattern ~= nil or nil, capturing = burst ~= nil or nil }
end

local project = function(run, player, viewProj, x, z, lift)
  local sx, sy, depth = bolt.point((run.anchor.x + x) * 512, player.height + (lift or 0), (run.anchor.z + z) * 512)
    :transform(viewProj):togameview()
  if not depth or depth <= 0 or depth > 1 then return nil end
  return { sx, sy }
end

local corners = function(run, player, viewProj, t, inset)
  local a = project(run, player, viewProj, t.dx + inset, t.dz + inset)
  local b = project(run, player, viewProj, t.dx + 1 - inset, t.dz + inset)
  local c = project(run, player, viewProj, t.dx + 1 - inset, t.dz + 1 - inset)
  local d = project(run, player, viewProj, t.dx + inset, t.dz + 1 - inset)
  if a and b and c and d then return { a, b, c, d } end
  return nil
end

local outline = function(edges, points, colour, thickness)
  local reach = thickness / 2
  for k = 1, 4 do
    local p, q = points[k], points[k % 4 + 1]
    local dx, dy = q[1] - p[1], q[2] - p[2]
    local len = math.max(0.001, math.sqrt(dx * dx + dy * dy))
    local ex, ey = dx / len * reach, dy / len * reach
    edges[#edges + 1] = { p[1] - ex, p[2] - ey, q[1] + ex, q[2] + ey, colour = colour }
  end
end

local barrier = function(run, player, viewProj, plan)
  local edge = plan.finish and maze.barrierEdge(rows, plan.finish)
  if not edge then return nil end
  local a = project(run, player, viewProj, edge[1][1], edge[1][2])
  local b = project(run, player, viewProj, edge[2][1], edge[2][2])
  local c = project(run, player, viewProj, edge[2][1], edge[2][2], BARRIER_HEIGHT_UNITS)
  local d = project(run, player, viewProj, edge[1][1], edge[1][2], BARRIER_HEIGHT_UNITS)
  if a and b and c and d then return { a, b, c, d }, edge end
  return nil
end

local towardsBarrier = function(run, player, viewProj, edge, t)
  local x, z = t.dx + 0.5, t.dz + 0.5
  if edge[1][1] == edge[2][1] then x = edge[1][1] else z = edge[1][2] end
  return project(run, player, viewProj, x, z)
end

local tileUnder = function(here, px, py)
  for dx = here.dx - CLICK_REACH_TILES, here.dx + CLICK_REACH_TILES do
    for dz = here.dz - CLICK_REACH_TILES, here.dz + CLICK_REACH_TILES do
      local quad = corners(view.run, view.player, view.viewProj, { dx = dx, dz = dz }, 0)
      if quad and maze.pointInQuad(quad, px, py) then return { dx = dx, dz = dz } end
    end
  end
  return nil
end

local logClick = function(now, here, tile, step)
  local highlighted = route.tiles[route.progress + 1]
  local verdict = (not step and "not on the route")
    or (step == route.progress + 1 and "the highlighted one")
    or (step <= route.progress and string.format("%d behind the highlighted one", route.progress + 1 - step))
    or string.format("%d ahead of the highlighted one", step - route.progress - 1)
  local due = tickAfter(now)
  log(string.format("maze: click on %s%s (%s); highlighted step %d at %d,%d; true tile %s; drawn at %d,%d, %s; %s",
    tile and (tile.dx .. "," .. tile.dz) or "no tile", step and (", step " .. step) or "", verdict,
    route.progress + 1, highlighted.dx, highlighted.dz,
    model.tile and (model.tile.dx .. "," .. model.tile.dz) or "unknown", here.dx, here.dz,
    tickclock.standing(clock, now) and "standing" or "moving",
    due and string.format("%d ms before a tick", (due - now) / 1000) or "no tick clock yet"))
end

function M.click(now, x, y)
  if not view then return false end
  local vx, vy = bolt.gameviewxywh()
  local px, py = x - vx, y - vy
  local here = { dx = view.player.tileX - view.run.anchor.x, dz = view.player.tileZ - view.run.anchor.z }
  local showing = route and route.progress < #route.tiles
  local wall = showing and barrier(view.run, view.player, view.viewProj, route)
  local onWall = wall and maze.pointInQuad(wall, px, py) or false
  local tile = onWall and route.tiles[#route.tiles] or tileUnder(here, px, py)
  local step = nil
  if tile and route then
    for i, t in ipairs(route.tiles) do
      if t.dx == tile.dx and t.dz == tile.dz then step = i end
    end
  end
  if showing then logClick(now, here, tile, step) end
  if not tile then return false end
  local standing = tickclock.standing(clock, now)
  local counted = showing and step ~= nil and step > route.progress
  if standing and counted and (not clickedFromStillAt or now - clickedFromStillAt > latency.MAX_MICROSECONDS) then
    clickedFromStillAt = now
  end
  local made = truetile.click(model, now, { index = step, tile = tile }, here, standing, latency.estimate(ping), tickAfter)
  if made.waitsForStart and showing then log("maze: that click is too close to the tick to call, waiting to see you move") end
  return counted
end

function M.draw(run, player, viewProj)
  if not route or not player or route.progress >= #route.tiles then return end
  local vx, vy, vw, vh = bolt.gameviewxywh()
  local quads, path, nextBorder, laterBorders = {}, {}, {}, {}
  local from = route.progress > 0 and route.tiles[route.progress] or route.origin
  local here = project(run, player, viewProj, from.dx + 0.5, from.dz + 0.5)
  if here then path[1] = here end
  local wall, edge = nil, nil
  if route.progress + 1 == #route.tiles then wall, edge = barrier(run, player, viewProj, route) end
  if wall then
    local t = route.tiles[#route.tiles]
    quads[1] = { wall[1][1], wall[1][2], wall[2][1], wall[2][2], wall[3][1], wall[3][2], wall[4][1], wall[4][2],
      colour = NEXT_FILL }
    outline(nextBorder, wall, NEXT_BORDER, NEXT_BORDER_THICKNESS)
    path[#path + 1] = towardsBarrier(run, player, viewProj, edge, t)
  end
  for i = route.progress + 1, wall and 0 or #route.tiles do
    local t = route.tiles[i]
    local isNext = i == route.progress + 1
    local fill = corners(run, player, viewProj, t, INSET)
    if fill then
      quads[#quads + 1] = { fill[1][1], fill[1][2], fill[2][1], fill[2][2], fill[3][1], fill[3][2], fill[4][1], fill[4][2],
        colour = isNext and NEXT_FILL or LATER_FILL }
    end
    local border = corners(run, player, viewProj, t, BORDER_INSET)
    if border then
      if isNext then
        outline(nextBorder, border, NEXT_BORDER, NEXT_BORDER_THICKNESS)
      else
        outline(laterBorders, border, LATER_BORDER, LATER_BORDER_THICKNESS)
      end
    end
    local centre = project(run, player, viewProj, t.dx + 0.5, t.dz + 0.5)
    if centre then path[#path + 1] = centre end
  end
  local edges = {}
  for i = 2, #path do
    edges[#edges + 1] = { path[i - 1][1], path[i - 1][2], path[i][1], path[i][2], colour = LINE_COLOUR }
  end
  lines.setScreenDimensions(vw, vh)
  if #edges > 0 then lines.drawLines(bolt, edges, LINE_THICKNESS, vx, vy) end
  lines.drawQuads(bolt, quads, vx, vy)
  if #laterBorders > 0 then lines.drawLines(bolt, laterBorders, LATER_BORDER_THICKNESS, vx, vy) end
  if #nextBorder > 0 then lines.drawLines(bolt, nextBorder, NEXT_BORDER_THICKNESS, vx, vy) end
end

return M
