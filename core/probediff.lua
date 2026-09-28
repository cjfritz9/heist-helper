local M = {}

local sortedKeys = function(set)
  local keys = {}
  for k in pairs(set) do
    keys[#keys + 1] = k
  end
  table.sort(keys)
  return keys
end

function M.diff(previous, current)
  local added, removed = {}, {}
  for _, k in ipairs(sortedKeys(current)) do
    if not previous[k] then
      added[#added + 1] = k
    end
  end
  for _, k in ipairs(sortedKeys(previous)) do
    if not current[k] then
      removed[#removed + 1] = k
    end
  end
  return added, removed
end

function M.lines(seconds, added, removed)
  local out = {}
  local stamp = string.format("[%8.1f] ", seconds)
  for _, k in ipairs(added) do
    out[#out + 1] = stamp .. "+ " .. k
  end
  for _, k in ipairs(removed) do
    out[#out + 1] = stamp .. "- " .. k
  end
  if #out == 0 then
    return ""
  end
  return table.concat(out, "\n") .. "\n"
end

function M.relative(targetX, targetZ, tileX, tileZ, radius)
  local dx, dz = tileX - targetX, tileZ - targetZ
  if math.abs(dx) > radius or math.abs(dz) > radius then
    return nil
  end
  return dx .. "," .. dz
end

return M
