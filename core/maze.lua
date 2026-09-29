local M = {}

M.ORDER = { "west", "north", "east", "south" }
M.ROW_TILES = 5
M.RUN_TILES = 2
M.CLEAR_AFTER = 8

local key = function(dx, dz)
  return dx .. "," .. dz
end

function M.row(a, b)
  if not a or not b then return nil end
  local stepX = b.dx == a.dx and 0 or (b.dx > a.dx and 1 or -1)
  local stepZ = b.dz == a.dz and 0 or (b.dz > a.dz and 1 or -1)
  local length = math.max(math.abs(b.dx - a.dx), math.abs(b.dz - a.dz)) + 1
  if (stepX ~= 0 and stepZ ~= 0) or length ~= M.ROW_TILES then return nil end
  local tiles = {}
  for i = 0, length - 1 do
    tiles[#tiles + 1] = { dx = a.dx + stepX * i, dz = a.dz + stepZ * i }
  end
  return tiles
end

function M.nextBarrier(name)
  for i, n in ipairs(M.ORDER) do
    if n == name then return M.ORDER[i + 1] end
  end
  return nil
end

function M.nearestBarrier(rows, dx, dz)
  local best, bestDistance = nil, math.huge
  for name, tiles in pairs(rows) do
    for _, t in ipairs(tiles) do
      local d = math.max(math.abs(t.dx - dx), math.abs(t.dz - dz))
      if d < bestDistance then
        best, bestDistance = name, d
      end
    end
  end
  return best, bestDistance
end

function M.newSession()
  return { lit = {}, empty = 0 }
end

function M.observe(session, litTiles)
  if #litTiles == 0 then
    session.empty = session.empty + 1
    if session.empty >= M.CLEAR_AFTER then
      session.lit = {}
    end
    return
  end
  session.empty = 0
  for _, t in ipairs(litTiles) do
    session.lit[key(t.dx, t.dz)] = t
  end
end

function M.active(session)
  return next(session.lit) ~= nil
end

function M.isSafe(session, rows, names, dx, dz)
  if session.lit[key(dx, dz)] then return true end
  for _, name in ipairs(names) do
    for _, t in ipairs(rows[name] or {}) do
      if t.dx == dx and t.dz == dz then return true end
    end
  end
  return false
end

function M.bounds(rows)
  local b = nil
  for _, tiles in pairs(rows) do
    for _, t in ipairs(tiles) do
      b = b or { minX = t.dx, maxX = t.dx, minZ = t.dz, maxZ = t.dz }
      b.minX, b.maxX = math.min(b.minX, t.dx), math.max(b.maxX, t.dx)
      b.minZ, b.maxZ = math.min(b.minZ, t.dz), math.max(b.maxZ, t.dz)
    end
  end
  return b
end

local within = function(b, t)
  return not b or (t.dx >= b.minX and t.dx <= b.maxX and t.dz >= b.minZ and t.dz <= b.maxZ)
end

local NEIGHBOURS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

function M.safeTiles(session, rows, names)
  local b = M.bounds(rows)
  local rowTiles, lit, safe = {}, {}, {}
  for _, name in ipairs(names) do
    for _, t in ipairs(rows[name] or {}) do rowTiles[key(t.dx, t.dz)] = t end
  end
  for k, t in pairs(session.lit) do
    if within(b, t) then lit[k] = t end
  end
  for k, t in pairs(lit) do
    for _, n in ipairs(NEIGHBOURS) do
      local nk = key(t.dx + n[1], t.dz + n[2])
      if lit[nk] or rowTiles[nk] then
        safe[k] = t
        break
      end
    end
  end
  for k, t in pairs(rowTiles) do safe[k] = t end
  return safe
end

local sign = function(v)
  return v > 0 and 1 or (v < 0 and -1 or 0)
end

function M.route(session, rows, fromDx, fromDz, startName, endName)
  local safe = M.safeTiles(session, rows, { startName, endName })
  local finish = rows[endName] or {}
  local centre = finish[math.ceil(#finish / 2)]
  local distance, queue, head = {}, {}, 1
  for _, t in ipairs(finish) do
    distance[key(t.dx, t.dz)] = 0
    queue[#queue + 1] = t
  end
  while head <= #queue do
    local here = queue[head]
    head = head + 1
    local d = distance[key(here.dx, here.dz)]
    for ox = -M.RUN_TILES, M.RUN_TILES do
      for oz = -M.RUN_TILES, M.RUN_TILES do
        local k = key(here.dx + ox, here.dz + oz)
        if safe[k] and distance[k] == nil then
          distance[k] = d + 1
          queue[#queue + 1] = safe[k]
        end
      end
    end
  end
  local best = nil
  for ox = -M.RUN_TILES, M.RUN_TILES do
    for oz = -M.RUN_TILES, M.RUN_TILES do
      local d = distance[key(fromDx + ox, fromDz + oz)]
      if d and (not best or d < best) then best = d end
    end
  end
  if distance[key(fromDx, fromDz)] == 0 then return {} end
  if not best then return nil end
  local path, x, z, lastX, lastZ = {}, fromDx, fromDz, nil, nil
  local want = best
  while want >= 0 do
    local pick, pickScore = nil, nil
    for ox = -M.RUN_TILES, M.RUN_TILES do
      for oz = -M.RUN_TILES, M.RUN_TILES do
        local k = key(x + ox, z + oz)
        if (ox ~= 0 or oz ~= 0) and distance[k] == want then
          local turn = (lastX and (sign(ox) ~= lastX or sign(oz) ~= lastZ)) and 1 or 0
          local diagonal = (ox ~= 0 and oz ~= 0) and 1 or 0
          local short = (math.max(math.abs(ox), math.abs(oz)) < M.RUN_TILES) and 1 or 0
          local offCentre = (want == 0 and centre) and (math.abs(x + ox - centre.dx) + math.abs(z + oz - centre.dz)) or 0
          local score = offCentre * 1000 + turn * 100 + diagonal * 10 + short
          if not pickScore or score < pickScore then
            pick, pickScore = safe[k], score
          end
        end
      end
    end
    if not pick then return nil end
    lastX, lastZ = sign(pick.dx - x), sign(pick.dz - z)
    path[#path + 1] = pick
    x, z = pick.dx, pick.dz
    want = want - 1
  end
  return path
end

return M
