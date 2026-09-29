local M = {}

M.MARGIN = 8
M.CLICK_SECONDS = 30
M.SETTLE_SECONDS = 3
M.REACH_TILES = 2

function M.contains(points, x, y)
  if not points or #points == 0 then return false end
  local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
  for _, p in ipairs(points) do
    minX, maxX = math.min(minX, p[1]), math.max(maxX, p[1])
    minY, maxY = math.min(minY, p[2]), math.max(maxY, p[2])
  end
  return x >= minX - M.MARGIN and x <= maxX + M.MARGIN and y >= minY - M.MARGIN and y <= maxY + M.MARGIN
end

function M.new()
  return { click = nil }
end

function M.clicked(state, dx, dz, now)
  state.click = { dx = dx, dz = dz, at = now, arrivedAt = nil }
end

function M.ready(state, now, playerDx, playerDz, batteryVisible)
  local c = state.click
  if not c then return nil end
  if now - c.at > M.CLICK_SECONDS * 1e6 then
    state.click = nil
    return nil
  end
  local near = math.max(math.abs(playerDx - c.dx), math.abs(playerDz - c.dz)) <= M.REACH_TILES
  if not near then
    c.arrivedAt = nil
    return nil
  end
  c.arrivedAt = c.arrivedAt or now
  if batteryVisible or now - c.arrivedAt < M.SETTLE_SECONDS * 1e6 then
    return nil
  end
  state.click = nil
  return c.dx, c.dz
end

return M
