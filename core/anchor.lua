local M = {}

M.REFERENCE_X = 11299
M.REFERENCE_Z = 3243
M.ARRIVAL_HEIGHT = 4933

local REGION_TILES = 64
local HEIGHT_TOLERANCE = 100
local OBJECT_HEIGHT_TOLERANCE = 32
local TELEPORT_TILES = 20
local BOUNDS = { minDx = -45, maxDx = 32, minDz = -115, maxDz = 16 }

local onGrid = function(x, z)
  return (x - M.REFERENCE_X) % REGION_TILES == 0 and (z - M.REFERENCE_Z) % REGION_TILES == 0
end

function M.fromArrival(prevX, prevZ, x, z, height)
  if math.abs(height - M.ARRIVAL_HEIGHT) > HEIGHT_TOLERANCE or not onGrid(x, z) then
    return nil
  end
  if prevX and math.max(math.abs(x - prevX), math.abs(z - prevZ)) <= TELEPORT_TILES then
    return nil
  end
  return { x = x, z = z }
end

function M.sentBack(current, arrival, prevX, prevZ)
  return current ~= nil and prevX ~= nil
    and current.x == arrival.x and current.z == arrival.z
    and M.inVault(current, prevX, prevZ)
end

function M.fromObject(kind, x, z, y, objects)
  local found = nil
  for _, o in ipairs(objects) do
    if o.kind == kind and o.y and math.abs(o.y - y) <= OBJECT_HEIGHT_TOLERANCE then
      local ax, az = x - o.dx, z - o.dz
      if onGrid(ax, az) then
        if found and (found.x ~= ax or found.z ~= az) then
          return nil
        end
        found = { x = ax, z = az }
      end
    end
  end
  return found
end

function M.inVault(anchor, x, z)
  if not anchor then
    return false
  end
  local dx, dz = x - anchor.x, z - anchor.z
  return dx >= BOUNDS.minDx and dx <= BOUNDS.maxDx and dz >= BOUNDS.minDz and dz <= BOUNDS.maxDz
end

return M
