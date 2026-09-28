local nearby = require("core.nearby")

local M = {}

M.START_TILES = 3
M.STOP_TILES = 15

function M.chooseTarget(objects, playerX, playerZ, anchor, isLinked)
  if not anchor then return nil end
  local best, bestDistance = nil, M.START_TILES + 1
  for _, o in ipairs(objects) do
    if o.kind == "shadowAnchor" and not isLinked(o.tileX - anchor.x, o.tileZ - anchor.z) then
      local d = nearby.distance(o.tileX, o.tileZ, playerX, playerZ)
      if d < bestDistance then
        best, bestDistance = o, d
      end
    end
  end
  return best
end

function M.shouldStop(target, playerX, playerZ)
  return nearby.distance(target.tileX, target.tileZ, playerX, playerZ) > M.STOP_TILES
end

function M.snapshotLines(seconds, set)
  local keys = {}
  for k in pairs(set) do
    keys[#keys + 1] = k
  end
  table.sort(keys)
  local out = {}
  local stamp = string.format("[%8.2f] ", seconds)
  for _, k in ipairs(keys) do
    out[#out + 1] = stamp .. "= " .. k
  end
  if #out == 0 then return "" end
  return table.concat(out, "\n") .. "\n"
end

return M
