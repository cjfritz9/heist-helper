local M = {}

M.TICK_MICROSECONDS = 600 * 1000
M.STILL_MICROSECONDS = 150 * 1000

function M.new()
  return { moving = false, stillSince = nil, phase = nil }
end

function M.observe(clock, now, moved)
  if moved then
    local started = not clock.moving and clock.stillSince ~= nil
      and now - clock.stillSince >= M.STILL_MICROSECONDS
    if started then clock.phase = now end
    clock.moving, clock.stillSince = true, nil
    return started
  end
  if clock.moving or not clock.stillSince then clock.stillSince = now end
  clock.moving = false
  return false
end

function M.standing(clock, now)
  return not clock.moving and clock.stillSince ~= nil and now - clock.stillSince >= M.STILL_MICROSECONDS
end

function M.nextTick(clock, after)
  if not clock.phase then return nil end
  return clock.phase + (math.floor((after - clock.phase) / M.TICK_MICROSECONDS) + 1) * M.TICK_MICROSECONDS
end

return M
