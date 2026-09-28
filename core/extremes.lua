local M = {}

M.DIRECTIONS = {}
for x = -1, 1 do
  for y = -1, 1 do
    for z = -1, 1 do
      if x ~= 0 or y ~= 0 or z ~= 0 then
        M.DIRECTIONS[#M.DIRECTIONS + 1] = { x, y, z }
      end
    end
  end
end

function M.select(points)
  local chosen, seen = {}, {}
  for _, d in ipairs(M.DIRECTIONS) do
    local best, bestDot = nil, -math.huge
    for i, p in ipairs(points) do
      local dot = p[1] * d[1] + p[2] * d[2] + p[3] * d[3]
      if dot > bestDot then
        best, bestDot = i, dot
      end
    end
    if best and not seen[best] then
      seen[best] = true
      chosen[#chosen + 1] = points[best]
    end
  end
  return chosen
end

return M
