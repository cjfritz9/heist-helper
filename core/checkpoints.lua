local M = {}

M.REACH_TILES = 2
M.HEIGHT_TOLERANCE = 200
M.SIDES = {
  { name = "legionary1", section = 1 },
  { name = "legionary2", section = 2 },
  { name = "praetorian3", section = 3 },
  { name = "praetorian4", section = 4 },
}

local sectionOf = {}
for _, side in ipairs(M.SIDES) do
  sectionOf[side.name] = side.section
end

function M.new(seed)
  local set = { markers = {}, dials = {} }
  for _, m in ipairs(seed and seed.markers or {}) do
    M.put(set, m.name, m.dx, m.dz, m.y)
  end
  for _, d in ipairs(seed and seed.dials or {}) do
    set.dials[d.dx .. "," .. d.dz] = d.section
  end
  return set
end

function M.put(set, name, dx, dz, y)
  if not sectionOf[name] then return false end
  set.markers[name] = { name = name, dx = dx, dz = dz, y = math.floor(y + 0.5), section = sectionOf[name] }
  return true
end

function M.complete(set)
  for _, side in ipairs(M.SIDES) do
    if not set.markers[side.name] then return false end
  end
  return true
end

function M.at(set, dx, dz, y)
  local best, bestDistance = nil, M.REACH_TILES + 1
  for _, m in pairs(set.markers) do
    local distance = math.max(math.abs(m.dx - dx), math.abs(m.dz - dz))
    if distance < bestDistance and math.abs(m.y - y) <= M.HEIGHT_TOLERANCE then
      best, bestDistance = m, distance
    end
  end
  return best and best.section or nil
end

function M.afterDial(set, dx, dz)
  return set.dials[dx .. "," .. dz]
end

function M.encode(set)
  local out = {}
  for _, side in ipairs(M.SIDES) do
    local m = set.markers[side.name]
    if m then
      out[#out + 1] = string.format("%s,%d,%d,%d", m.name, m.dx, m.dz, m.y)
    end
  end
  return table.concat(out, "\n") .. "\n"
end

function M.merge(set, text)
  for line in (text or ""):gmatch("[^\r\n]+") do
    local name, dx, dz, y = line:match("^(%w+),(%-?%d+),(%-?%d+),(%-?%d+)$")
    if name then
      M.put(set, name, tonumber(dx), tonumber(dz), tonumber(y))
    end
  end
  return set
end

function M.list(set)
  local out = {}
  for _, side in ipairs(M.SIDES) do
    local m = set.markers[side.name]
    out[#out + 1] = { name = side.name, section = side.section, marked = m ~= nil,
      dx = m and m.dx or nil, dz = m and m.dz or nil }
  end
  return out
end

return M
