local M = {}

local split = function(line)
  local fields = {}
  for field in line:gmatch("[^,]+") do
    fields[#fields + 1] = field
  end
  return fields
end

function M.copy(data)
  local markers = {}
  for i, m in ipairs(data.markers) do
    markers[i] = { dx = m.dx, dz = m.dz, y = m.y, section = m.section, arrival = m.arrival }
  end
  return { anchorX = data.anchorX, anchorZ = data.anchorZ, markers = markers }
end

function M.encode(data)
  local out = { string.format("anchor,%d,%d", data.anchorX, data.anchorZ) }
  for _, m in ipairs(data.markers) do
    out[#out + 1] = string.format("marker,%d,%d,%d,%s,%d",
      m.dx, m.dz, m.y, m.section, m.arrival and 1 or 0)
  end
  return table.concat(out, "\n") .. "\n"
end

function M.decode(text)
  local data = { markers = {} }
  for line in text:gmatch("[^\r\n]+") do
    local f = split(line)
    if f[1] == "anchor" and #f == 3 then
      data.anchorX, data.anchorZ = tonumber(f[2]), tonumber(f[3])
    elseif f[1] == "marker" and #f == 6 then
      data.markers[#data.markers + 1] = {
        dx = tonumber(f[2]),
        dz = tonumber(f[3]),
        y = tonumber(f[4]),
        section = f[5],
        arrival = f[6] == "1",
      }
    end
  end
  if not data.anchorX or not data.anchorZ then
    return nil
  end
  return data
end

function M.toggle(data, tileX, tileZ, y)
  local dx, dz = tileX - data.anchorX, tileZ - data.anchorZ
  for i, m in ipairs(data.markers) do
    if m.dx == dx and m.dz == dz then
      table.remove(data.markers, i)
      return "removed"
    end
  end
  data.markers[#data.markers + 1] = { dx = dx, dz = dz, y = math.floor(y + 0.5), section = "?", arrival = false }
  return "added"
end

return M
