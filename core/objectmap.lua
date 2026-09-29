local M = {}

local key = function(kind, dx, dz)
  return kind .. "," .. dx .. "," .. dz
end

local tileKey = function(dx, dz)
  return dx .. "," .. dz
end

local round = function(y)
  return math.floor(y + 0.5)
end

function M.new(seed)
  local map = { list = {}, index = {}, crevices = {} }
  for _, o in ipairs(seed or {}) do
    M.add(map, o.kind, o.dx, o.dz, o.y)
    M.setSection(map, o.kind, o.dx, o.dz, o.section)
    map.index[key(o.kind, o.dx, o.dz)].shadow = o.shadow
    if o.crevice then
      map.crevices[tileKey(o.dx, o.dz)] = true
    end
  end
  return map
end

function M.add(map, kind, dx, dz, y)
  local k = key(kind, dx, dz)
  local existing = map.index[k]
  if existing then
    if y and not existing.y then
      existing.y = round(y)
      return true
    end
    return false
  end
  local entry = { kind = kind, dx = dx, dz = dz, y = y and round(y) or nil }
  map.index[k] = entry
  map.list[#map.list + 1] = entry
  return true
end

function M.setSection(map, kind, dx, dz, section)
  local entry = map.index[key(kind, dx, dz)]
  if not entry or not section or entry.section then
    return false
  end
  entry.section = section
  return true
end

function M.encode(map)
  local out = {}
  for _, o in ipairs(map.list) do
    local row = key(o.kind, o.dx, o.dz)
    if o.y or o.section then
      row = row .. "," .. (o.y or "")
    end
    if o.section then
      row = row .. "," .. o.section
    end
    out[#out + 1] = row
  end
  return table.concat(out, "\n") .. "\n"
end

function M.merge(map, text)
  for line in (text or ""):gmatch("[^\r\n]+") do
    local kind, dx, dz, y, section = line:match("^(%a+),(%-?%d+),(%-?%d+),?(%-?%d*),?(%d*)$")
    if kind then
      M.add(map, kind, tonumber(dx), tonumber(dz), tonumber(y))
      M.setSection(map, kind, tonumber(dx), tonumber(dz), tonumber(section))
    end
  end
  return map
end

function M.behindCrevice(map, dx, dz)
  return map.crevices[tileKey(dx, dz)] == true
end

function M.toggleCrevice(map, dx, dz)
  local k = tileKey(dx, dz)
  map.crevices[k] = not map.crevices[k] or nil
  return map.crevices[k] == true
end

function M.encodeCrevices(map)
  local out = {}
  for k in pairs(map.crevices) do
    out[#out + 1] = k
  end
  table.sort(out)
  return table.concat(out, "\n") .. "\n"
end

function M.loadCrevices(map, text)
  if not text then return map end
  map.crevices = {}
  for line in text:gmatch("[^\r\n]+") do
    local dx, dz = line:match("^(%-?%d+),(%-?%d+)$")
    if dx then
      map.crevices[tileKey(tonumber(dx), tonumber(dz))] = true
    end
  end
  return map
end

return M
