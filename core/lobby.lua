local M = {}

M.DEFAULT = { minX = 2487, maxX = 2495, minZ = 7577, maxZ = 7584 }

function M.new()
  return { a = nil, b = nil, always = false }
end

function M.decode(text)
  local area = M.new()
  for name, x, z in (text or ""):gmatch("([ab]),(%-?%d+),(%-?%d+)") do
    area[name] = { tileX = tonumber(x), tileZ = tonumber(z) }
  end
  area.always = (text or ""):find("always,1") ~= nil
  return area
end

function M.encode(area)
  local out = {}
  for _, name in ipairs({ "a", "b" }) do
    if area[name] then out[#out + 1] = string.format("%s,%d,%d", name, area[name].tileX, area[name].tileZ) end
  end
  out[#out + 1] = "always," .. (area.always and 1 or 0)
  return table.concat(out, "\n") .. "\n"
end

function M.bounds(area)
  if not area or not area.a or not area.b then return M.DEFAULT end
  return {
    minX = math.min(area.a.tileX, area.b.tileX), maxX = math.max(area.a.tileX, area.b.tileX),
    minZ = math.min(area.a.tileZ, area.b.tileZ), maxZ = math.max(area.a.tileZ, area.b.tileZ),
  }
end

function M.near(tileX, tileZ, area)
  if not tileX or not tileZ then return false end
  local b = M.bounds(area)
  return tileX >= b.minX and tileX <= b.maxX and tileZ >= b.minZ and tileZ <= b.maxZ
end

return M
