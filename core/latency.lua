local M = {}

M.SAMPLES = 20
M.DEFAULT = 50 * 1000
M.TICK = 600 * 1000
M.SLACK = 15 * 1000
M.NARROW = 60 * 1000
M.LONGEST_BELIEVED = 150 * 1000
M.SHORTEST_BELIEVED = 15 * 1000
M.MAX_MICROSECONDS = 1200 * 1000

function M.new()
  return { gaps = {} }
end

function M.note(state, gap)
  if gap < M.SHORTEST_BELIEVED or gap > M.MAX_MICROSECONDS then return end
  state.gaps[#state.gaps + 1] = gap
  if #state.gaps > M.SAMPLES then table.remove(state.gaps, 1) end
end

function M.bounds(state)
  local low, high = 0, nil
  for _, gap in ipairs(state.gaps) do
    local atMost, atLeast = gap + M.SLACK, gap - M.TICK - M.SLACK
    if not high or atMost < high then high = atMost end
    if atLeast > low and atLeast <= M.LONGEST_BELIEVED then low = atLeast end
  end
  return low, high
end

function M.estimate(state)
  local low, high = M.bounds(state)
  if not high then return M.DEFAULT end
  if low > high then return M.DEFAULT end
  if high - low <= M.NARROW then return (low + high) / 2 end
  return math.max(low, math.min(M.DEFAULT, high))
end

return M
