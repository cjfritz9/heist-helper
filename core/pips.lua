local M = {}

M.SIZE = 8
M.GAP = 3
M.LIFT = 10

function M.layout(outline, filled, total)
  if #outline == 0 then
    return {}
  end
  local minX, maxX, top = math.huge, -math.huge, math.huge
  for _, p in ipairs(outline) do
    minX = math.min(minX, p[1])
    maxX = math.max(maxX, p[1])
    top = math.min(top, p[2])
  end
  local width = total * M.SIZE + (total - 1) * M.GAP
  local left = (minX + maxX) / 2 - width / 2
  local y = top - M.LIFT - M.SIZE
  local pips = {}
  for i = 1, total do
    local x = left + (i - 1) * (M.SIZE + M.GAP)
    pips[i] = { x = x, y = y, w = M.SIZE, h = M.SIZE, filled = i <= filled }
  end
  return pips
end

return M
