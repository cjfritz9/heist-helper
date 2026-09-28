local M = {}

local cross = function(o, a, b)
  return (a[1] - o[1]) * (b[2] - o[2]) - (a[2] - o[2]) * (b[1] - o[1])
end

function M.convex(points)
  if #points < 3 then
    return {}
  end
  local sorted = {}
  for i, p in ipairs(points) do
    sorted[i] = p
  end
  table.sort(sorted, function(a, b)
    return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2])
  end)

  local lower, upper = {}, {}
  for _, p in ipairs(sorted) do
    while #lower >= 2 and cross(lower[#lower - 1], lower[#lower], p) <= 0 do
      lower[#lower] = nil
    end
    lower[#lower + 1] = p
  end
  for i = #sorted, 1, -1 do
    local p = sorted[i]
    while #upper >= 2 and cross(upper[#upper - 1], upper[#upper], p) <= 0 do
      upper[#upper] = nil
    end
    upper[#upper + 1] = p
  end

  local result = {}
  for i = 1, #lower - 1 do
    result[#result + 1] = lower[i]
  end
  for i = 1, #upper - 1 do
    result[#result + 1] = upper[i]
  end
  return result
end

return M
