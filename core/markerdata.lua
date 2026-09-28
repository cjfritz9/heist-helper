local M = {}

local FIELD_COUNT = 10

function M.parseCsv(text)
  local rows = {}
  for line in text:gmatch("[^\r\n]+") do
    local fields = {}
    for field in line:gmatch("[^,]+") do
      fields[#fields + 1] = field
    end
    local n = tonumber(fields[1])
    if #fields == FIELD_COUNT and n then
      rows[#rows + 1] = {
        n = n,
        y = tonumber(fields[3]),
        tileX = tonumber(fields[5]),
        tileZ = tonumber(fields[6]),
      }
    end
  end
  return rows
end

function M.build(rows, sectionByHeight)
  local anchor = rows[1]
  local seen, markers = {}, {}
  for i, row in ipairs(rows) do
    local dx, dz = row.tileX - anchor.tileX, row.tileZ - anchor.tileZ
    local key = dx .. "," .. dz
    if not seen[key] then
      seen[key] = true
      markers[#markers + 1] = {
        n = row.n,
        dx = dx,
        dz = dz,
        y = row.y,
        section = sectionByHeight[row.y] or "?",
        arrival = i == 1,
      }
    end
  end
  return { anchorX = anchor.tileX, anchorZ = anchor.tileZ, markers = markers }
end

function M.serialize(data)
  local out = {
    "return {",
    string.format("  anchorX = %d,", data.anchorX),
    string.format("  anchorZ = %d,", data.anchorZ),
    "  markers = {",
  }
  for _, m in ipairs(data.markers) do
    out[#out + 1] = string.format(
      "    { n = %d, dx = %d, dz = %d, y = %d, section = %q, arrival = %s },",
      m.n, m.dx, m.dz, m.y, m.section, tostring(m.arrival))
  end
  out[#out + 1] = "  },"
  out[#out + 1] = "}"
  return table.concat(out, "\n") .. "\n"
end

function M.nearby(data, tileX, tileZ, radius)
  local found = {}
  for _, m in ipairs(data.markers) do
    local x, z = data.anchorX + m.dx, data.anchorZ + m.dz
    if math.abs(x - tileX) <= radius and math.abs(z - tileZ) <= radius then
      found[#found + 1] = { tileX = x, tileZ = z, y = m.y, section = m.section, arrival = m.arrival }
    end
  end
  return found
end

return M
