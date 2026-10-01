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

function M.stepToward(from, to, tiles)
  local x, z = from.dx, from.dz
  for _ = 1, tiles or M.RUN_TILES do
    if x == to.dx and z == to.dz then break end
    x = x + (to.dx > x and 1 or (to.dx < x and -1 or 0))
    z = z + (to.dz > z and 1 or (to.dz < z and -1 or 0))
  end
  return { dx = x, dz = z }
end

function M.barrierEdge(rows, name)
  local row, b = rows[name], M.bounds(rows)
  if not row or not b then return nil end
  local first, last = row[1], row[#row]
  if first.dx == last.dx then
    local outward = first.dx > (b.minX + b.maxX) / 2 and 1 or 0
    local x = first.dx + outward
    local z1, z2 = math.min(first.dz, last.dz), math.max(first.dz, last.dz) + 1
    return { { x, z1 }, { x, z2 } }
  end
  local outward = first.dz > (b.minZ + b.maxZ) / 2 and 1 or 0
  local z = first.dz + outward
  local x1, x2 = math.min(first.dx, last.dx), math.max(first.dx, last.dx) + 1
  return { { x1, z }, { x2, z } }
end

function M.inside(rows, dx, dz)
  local b = M.bounds(rows)
  return b ~= nil and dx > b.minX and dx < b.maxX and dz > b.minZ and dz < b.maxZ
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

function M.pointInQuad(quad, x, y)
  local sign = nil
  for k = 1, 4 do
    local a, b = quad[k], quad[k % 4 + 1]
    local cross = (b[1] - a[1]) * (y - a[2]) - (b[2] - a[2]) * (x - a[1])
    if cross ~= 0 then
      local s = cross > 0
      if sign == nil then sign = s elseif sign ~= s then return false end
    end
  end
  return true
end

function M.gridShift(a, b)
  if not a or not b or a.n ~= b.n or a.dx0 ~= b.dx0 or a.dz0 ~= b.dz0 then return math.huge end
  local shift = 0
  for i = 1, #a.pts do
    local p, q = a.pts[i], b.pts[i]
    if (p < 0) ~= (q < 0) then return math.huge end
    if p >= 0 then shift = math.max(shift, math.abs(p - q)) end
  end
  return shift
end

local COST = { tick = 1e9, walk = 1e7, offPathMiddle = 1e3, turn = 1e2, distance = 10, diagonal = 1 }

local moveCost = function(ox, oz, lastX, lastZ, last, middleSafe)
  local cost = COST.tick
  if not middleSafe then cost = cost + COST.offPathMiddle end
  if not last and math.max(math.abs(ox), math.abs(oz)) < M.RUN_TILES then cost = cost + COST.walk end
  if lastX and (sign(ox) ~= lastX or sign(oz) ~= lastZ) then cost = cost + COST.turn end
  if ox ~= 0 and oz ~= 0 then cost = cost + COST.diagonal end
  return cost + COST.distance * math.sqrt(ox * ox + oz * oz)
end

function M.route(session, rows, fromDx, fromDz, startName, endName)
  local safe = M.safeTiles(session, rows, { startName, endName })
  local finish = rows[endName] or {}
  local goal = {}
  for _, t in ipairs(finish) do goal[key(t.dx, t.dz)] = true end
  if goal[key(fromDx, fromDz)] then return {} end
  local start = { dx = fromDx, dz = fromDz }
  local states = { { tile = start, cost = 0 } }
  local best, open, seen = nil, { states[1] }, {}
  while #open > 0 do
    local at = 1
    for i = 2, #open do
      if open[i].cost < open[at].cost then at = i end
    end
    local here = table.remove(open, at)
    local stateKey = key(here.tile.dx, here.tile.dz) .. ":" .. tostring(here.dirX) .. tostring(here.dirZ)
    if best and here.cost >= best.cost then break end
    if not seen[stateKey] then
      seen[stateKey] = true
      if here.parent and goal[key(here.tile.dx, here.tile.dz)] then
        best = here
      else
        for ox = -M.RUN_TILES, M.RUN_TILES do
          for oz = -M.RUN_TILES, M.RUN_TILES do
            local k = key(here.tile.dx + ox, here.tile.dz + oz)
            local tile = safe[k]
            if tile and (ox ~= 0 or oz ~= 0) then
              local last = goal[k] or false
              local middle = math.max(math.abs(ox), math.abs(oz)) < M.RUN_TILES
                or safe[key(here.tile.dx + sign(ox), here.tile.dz + sign(oz))] ~= nil
              local cost = here.cost + moveCost(ox, oz, here.dirX, here.dirZ, last, middle)
              open[#open + 1] = { tile = tile, cost = cost, parent = here, dirX = sign(ox), dirZ = sign(oz) }
            end
          end
        end
      end
    end
  end
  if not best then return nil end
  local path = {}
  local node = best
  while node.parent do
    table.insert(path, 1, node.tile)
    node = node.parent
  end
  return path
end

return M
