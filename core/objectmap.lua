local M = {}

local key = function(kind, dx, dz)
  return kind .. "," .. dx .. "," .. dz
end

function M.new(seed)
  local map = { list = {}, index = {} }
  for _, o in ipairs(seed or {}) do
    M.add(map, o.kind, o.dx, o.dz)
  end
  return map
end

function M.add(map, kind, dx, dz)
  local k = key(kind, dx, dz)
  if map.index[k] then
    return false
  end
  map.index[k] = true
  map.list[#map.list + 1] = { kind = kind, dx = dx, dz = dz }
  return true
end

function M.encode(map)
  local out = {}
  for _, o in ipairs(map.list) do
    out[#out + 1] = key(o.kind, o.dx, o.dz)
  end
  return table.concat(out, "\n") .. "\n"
end

function M.merge(map, text)
  for line in (text or ""):gmatch("[^\r\n]+") do
    local kind, dx, dz = line:match("^(%a+),(%-?%d+),(%-?%d+)$")
    if kind then
      M.add(map, kind, tonumber(dx), tonumber(dz))
    end
  end
  return map
end

return M
