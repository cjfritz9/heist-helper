local M = {}

M.TICK = 600 * 1000
M.RUN_TILES = 2
M.UNSURE = 40 * 1000
M.SPARE_TICKS = 3
M.STALE_TICKS = 2
M.MAX_LEAD_TILES = 6
M.SETTLE = 300 * 1000
M.MISS_MARGIN = 200 * 1000
M.PATH_KEEP = 3 * 600 * 1000
M.OFF_PATH_TILES = 2

function M.new()
  return { tile = nil, tileAt = nil, clicks = {}, nextTick = nil, path = {}, drawn = nil }
end

function M.reset(state)
  state.tile, state.tileAt, state.clicks, state.nextTick, state.last = nil, nil, {}, nil, nil
  state.path, state.drawn = {}, nil
end

local walk = function(from, to, tiles)
  local x, z, passed = from.dx, from.dz, {}
  for _ = 1, tiles do
    if x == to.dx and z == to.dz then break end
    x = x + (to.dx > x and 1 or (to.dx < x and -1 or 0))
    z = z + (to.dz > z and 1 or (to.dz < z and -1 or 0))
    passed[#passed + 1] = { dx = x, dz = z }
  end
  return { dx = x, dz = z }, passed
end

local stepToward = function(from, to)
  return (walk(from, to, M.RUN_TILES))
end

local distance = function(a, b)
  return math.max(math.abs(a.dx - b.dx), math.abs(a.dz - b.dz))
end

local checkDrawn = function(state, now, here, events)
  local nearest = nil
  for i = #state.path, 1, -1 do
    local p = state.path[i]
    if now - p.at > M.PATH_KEEP then break end
    if p.dx == here.dx and p.dz == here.dz then
      events[#events + 1] = { kind = "drawn", tile = here, lag = now - p.at, at = now }
      return
    end
    nearest = math.min(nearest or math.huge, distance(p, here))
  end
  if not nearest or not state.tile or distance(state.tile, here) < M.OFF_PATH_TILES or nearest < M.OFF_PATH_TILES then
    if nearest then events[#events + 1] = { kind = "drawn", tile = here, at = now } end
    return
  end
  events[#events + 1] = { kind = "offpath", tile = here, off = nearest, at = now }
  state.tile, state.tileAt, state.last, state.path = { dx = here.dx, dz = here.dz }, now, nil, {}
end

function M.click(state, now, target, here, standing, roundTrip, tickAfter)
  local from = state.tile or here
  local ticks = math.ceil(math.max(math.abs(target.tile.dx - from.dx), math.abs(target.tile.dz - from.dz)) / M.RUN_TILES)
  local click = { index = target.index, tile = target.tile, at = now, arrives = now + roundTrip,
    limit = (ticks + M.SPARE_TICKS) * M.TICK }
  local due = tickAfter(now)
  if standing and (not due or math.abs(due - click.arrives) <= M.UNSURE) then click.waitsForStart = true end
  if due then click.beforeTick = due - now end
  state.clicks[#state.clicks + 1] = click
  state.nextTick = state.nextTick or due
  return click
end

local process = function(state, at, here, events)
  local chosen = nil
  for i, c in ipairs(state.clicks) do
    if not c.waitsForStart and c.arrives <= at then chosen = i end
  end
  if not chosen then return end
  for _ = 1, chosen - 1 do table.remove(state.clicks, 1) end
  local click = state.clicks[1]
  local from = state.tile or here
  state.last = { from = { dx = from.dx, dz = from.dz }, click = click, at = at, margin = at - click.at }
  local passed
  state.tile, passed = walk(from, click.tile, M.RUN_TILES)
  state.tileAt = at
  for _, p in ipairs(passed) do
    state.path[#state.path + 1] = { dx = p.dx, dz = p.dz, at = at }
  end
  while #state.path > 0 and at - state.path[1].at > M.PATH_KEEP do table.remove(state.path, 1) end
  local reached = state.tile.dx == click.tile.dx and state.tile.dz == click.tile.dz
  if reached then table.remove(state.clicks, 1) end
  events[#events + 1] = { kind = reached and "reached" or "toward", index = click.index, click = click, at = at }
end

function M.advance(state, now, here, standing, started, tickAfter)
  local events = {}
  local lead = state.tile and math.max(math.abs(state.tile.dx - here.dx), math.abs(state.tile.dz - here.dz)) or 0
  if lead > M.MAX_LEAD_TILES then state.tile, state.tileAt, state.path = { dx = here.dx, dz = here.dz }, nil, {} end
  if state.drawn and (state.drawn.dx ~= here.dx or state.drawn.dz ~= here.dz) then checkDrawn(state, now, here, events) end
  state.drawn = { dx = here.dx, dz = here.dz }
  local last = state.last
  local settled = not state.tileAt or now - state.tileAt >= M.SETTLE
  if standing and last and settled and now - last.at < M.TICK
    and not (state.tile.dx == here.dx and state.tile.dz == here.dz) then
    local late = last.margin <= M.MISS_MARGIN
    events[#events + 1] = { kind = late and "missed" or "ignored", index = last.click.index, click = last.click, at = now,
      margin = last.margin }
    state.tile, state.tileAt, state.last, state.path = { dx = here.dx, dz = here.dz }, nil, nil, {}
    local kept = {}
    for _, c in ipairs(state.clicks) do
      if c ~= last.click then kept[#kept + 1] = c end
    end
    state.clicks = kept
    if late then
      table.insert(state.clicks, 1, last.click)
      last.click.arrives = math.min(last.click.arrives, now)
    end
    state.nextTick = tickAfter(now) or now + M.TICK
  end
  if #state.clicks == 0 then
    local stale = not state.tileAt or now - state.tileAt > M.STALE_TICKS * M.TICK
    if (standing and settled) or stale then state.tile = { dx = here.dx, dz = here.dz } end
    state.nextTick = nil
    return events
  end
  local resolved = false
  for _, c in ipairs(state.clicks) do
    if c.waitsForStart and started then
      c.waitsForStart, c.arrives, resolved = false, now, true
    end
  end
  if resolved then
    process(state, now, here, events)
    state.nextTick = tickAfter(now + M.TICK / 2) or now + M.TICK
  end
  while state.nextTick and now >= state.nextTick do
    local at = state.nextTick
    process(state, at, here, events)
    state.nextTick = tickAfter(at + M.TICK / 2) or at + M.TICK
  end
  local kept = {}
  for _, c in ipairs(state.clicks) do
    if now - c.at > c.limit then
      events[#events + 1] = { kind = "lost", index = c.index, click = c, at = now }
    else
      kept[#kept + 1] = c
    end
  end
  if #kept < #state.clicks then
    state.clicks = kept
    if #kept == 0 then state.tile, state.tileAt = nil, nil end
  end
  return events
end

return M
