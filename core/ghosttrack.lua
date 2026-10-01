local M = {}

M.MATCH_TILES = 2
M.STILL_MICROSECONDS = 150 * 1000
M.LOST_MICROSECONDS = 1000 * 1000
M.MOVED_TILES = 0.002
M.PINNED_MATCH_TILES = 0.25
M.CENTRE_TILES = 0.3
M.HEADING_MICROSECONDS = 50 * 1000
M.AT_CENTRE_TILES = 0.02

function M.new()
  return { ghosts = {}, nextId = 1 }
end

local distance = function(a, b)
  return math.max(math.abs(a.x - b.x), math.abs(a.z - b.z))
end

local sign = function(v)
  if v > 0.001 then return 1 elseif v < -0.001 then return -1 end
  return 0
end

local centreOffset = function(x, z)
  local tx, tz = math.floor(x), math.floor(z)
  return tx, tz, math.max(math.abs(x - tx - 0.5), math.abs(z - tz - 0.5))
end

local match = function(state, rings)
  local pairs_, taken = {}, {}
  for ri, ring in ipairs(rings) do
    for gi, ghost in ipairs(state.ghosts) do
      local d = distance(ring, ghost)
      local limit = ghost.pinned and M.PINNED_MATCH_TILES or M.MATCH_TILES
      if d <= limit then pairs_[#pairs_ + 1] = { ri = ri, gi = gi, d = d } end
    end
  end
  table.sort(pairs_, function(a, b) return a.d < b.d end)
  local ringTo = {}
  for _, p in ipairs(pairs_) do
    if not ringTo[p.ri] and not taken[p.gi] then
      ringTo[p.ri], taken[p.gi] = p.gi, true
    end
  end
  return ringTo
end

function M.update(state, now, rings)
  local events = {}
  local emit = function(kind, ghost, extra)
    local e = { kind = kind, id = ghost.id, at = now, x = ghost.x, z = ghost.z, y = ghost.y,
      tileX = math.floor(ghost.x), tileZ = math.floor(ghost.z) }
    for k, v in pairs(extra or {}) do e[k] = v end
    events[#events + 1] = e
  end
  local ringTo = match(state, rings)
  for ri, ring in ipairs(rings) do
    local ghost = ringTo[ri] and state.ghosts[ringTo[ri]]
    if not ghost then
      ghost = { id = state.nextId, x = ring.x, z = ring.z, y = ring.y, seenAt = now, appearedAt = now,
        movedAt = nil, stillSince = now, moving = false, everMoved = false, dirX = 0, dirZ = 0,
        lastTileX = math.floor(ring.x), lastTileZ = math.floor(ring.z) }
      state.nextId = state.nextId + 1
      state.ghosts[#state.ghosts + 1] = ghost
      emit("appear", ghost)
    else
      local moved = distance(ring, ghost) > M.MOVED_TILES
      if moved then ghost.dirX, ghost.dirZ = sign(ring.x - ghost.x), sign(ring.z - ghost.z) end
      ghost.x, ghost.z, ghost.y, ghost.seenAt = ring.x, ring.z, ring.y, now
      if moved then
        ghost.everMoved = true
        if not ghost.moving then
          emit("start", ghost, { still = now - ghost.stillSince })
          ghost.moving, ghost.movingSince = true, now
        end
        ghost.movedAt = now
      elseif ghost.moving and now - ghost.movedAt >= M.STILL_MICROSECONDS then
        ghost.moving, ghost.stillSince = false, ghost.movedAt
        emit("stop", ghost, { at = ghost.movedAt, moving = ghost.movedAt - ghost.movingSince })
      end
      local tx, tz, d = centreOffset(ghost.x, ghost.z)
      local c = ghost.centre
      local settle = function(centre)
        centre.done = true
        if centre.tileX == ghost.lastTileX and centre.tileZ == ghost.lastTileZ then return end
        ghost.lastTileX, ghost.lastTileZ = centre.tileX, centre.tileZ
        events[#events + 1] = { kind = "tile", id = ghost.id, at = centre.at, x = centre.x, z = centre.z, y = centre.y,
          tileX = centre.tileX, tileZ = centre.tileZ }
      end
      if c and (d > M.CENTRE_TILES or c.tileX ~= tx or c.tileZ ~= tz) then
        if not c.done then settle(c) end
        ghost.centre, c = nil, nil
      end
      if d <= M.CENTRE_TILES then
        if not c then
          ghost.centre = { tileX = tx, tileZ = tz, d = d, at = now, x = ghost.x, z = ghost.z, y = ghost.y }
        elseif d < c.d then
          c.d, c.at, c.x, c.z, c.y = d, now, ghost.x, ghost.z, ghost.y
        elseif not c.done then
          settle(c)
        end
      end
    end
  end
  local kept = {}
  for _, ghost in ipairs(state.ghosts) do
    if now - ghost.seenAt > M.LOST_MICROSECONDS then
      emit("lost", ghost, { at = ghost.seenAt })
    else
      kept[#kept + 1] = ghost
    end
  end
  state.ghosts = kept
  return events
end

function M.moving(ghost, now)
  return not ghost.pinned and ghost.movedAt ~= nil and now - ghost.movedAt <= M.HEADING_MICROSECONDS
end

function M.trueTile(ghost, now)
  local heading = M.moving(ghost, now)
  local ahead = function(v, dir)
    if not heading or dir == 0 then return math.floor(v) end
    if dir > 0 then return math.ceil(v - 0.5 + M.AT_CENTRE_TILES) end
    return math.floor(v - 0.5 - M.AT_CENTRE_TILES)
  end
  return ahead(ghost.x, ghost.dirX), ahead(ghost.z, ghost.dirZ)
end

function M.idleSinceAppearing(state, now, seconds)
  local idle = {}
  for _, ghost in ipairs(state.ghosts) do
    if not ghost.everMoved and not ghost.pinned and now - ghost.appearedAt >= seconds * 1e6 then idle[#idle + 1] = ghost end
  end
  return idle
end

function M.pin(state, id)
  for _, ghost in ipairs(state.ghosts) do
    if ghost.id == id then ghost.pinned = true end
  end
end

function M.format(e)
  local where = string.format("%d,%d (%.2f,%.2f) height %d", e.tileX, e.tileZ, e.x, e.z, math.floor((e.y or 0) + 0.5))
  if e.kind == "appear" then return string.format("g%d appears on %s", e.id, where) end
  if e.kind == "tile" then return string.format("g%d onto %s", e.id, where) end
  if e.kind == "start" then return string.format("g%d starts moving from %s after standing %.2f s", e.id, where, e.still / 1e6) end
  if e.kind == "stop" then return string.format("g%d stops on %s after moving %.2f s", e.id, where, e.moving / 1e6) end
  return string.format("g%d lost from view on %s", e.id, where)
end

return M
