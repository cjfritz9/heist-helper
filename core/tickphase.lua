local M = {}

M.PERIOD = 600 * 1000
M.WINDOW = 120 * 1000 * 1000
M.DRIFT = 55 / 600000
M.RELOCK_OFF = 100 * 1000
M.RELOCK_COUNT = 3
M.RELOCK_COUNT_OUTVOTED = 5
M.RELOCK_AGREE = 60 * 1000
M.HOLD = 10 * 60 * 1000 * 1000
M.STEADY_FRAME = 20 * 1000

function M.new(trusted, primary)
  return { trusted = trusted or {}, primary = primary or {}, samples = {}, phase = nil, spread = nil }
end

function M.weight(frameGap)
  if not frameGap or frameGap <= M.STEADY_FRAME then return 1 end
  return M.STEADY_FRAME / frameGap
end

function M.residual(phase, at)
  local r = (at - phase) % M.PERIOD
  if r > M.PERIOD / 2 then r = r - M.PERIOD end
  return r
end

local drifted = function(s, now)
  return s.at + (now - s.at) * M.DRIFT
end

local circularMean = function(samples, now)
  local sx, sy, total = 0, 0, 0
  for _, s in ipairs(samples) do
    local angle = (drifted(s, now) % M.PERIOD) / M.PERIOD * 2 * math.pi
    sx, sy, total = sx + math.cos(angle) * s.weight, sy + math.sin(angle) * s.weight, total + s.weight
  end
  if total == 0 then return nil end
  local angle = math.atan2(sy, sx)
  if angle < 0 then angle = angle + 2 * math.pi end
  return angle / (2 * math.pi) * M.PERIOD
end

local spreadOf = function(phase, samples, now)
  local sum, total = 0, 0
  for _, s in ipairs(samples) do
    local r = M.residual(phase, drifted(s, now))
    sum, total = sum + r * r * s.weight, total + s.weight
  end
  return total > 0 and math.sqrt(sum / total) or nil
end

local refresh = function(state, now)
  local kept = {}
  for _, s in ipairs(state.samples) do
    if now - s.at <= M.WINDOW then kept[#kept + 1] = s end
  end
  state.samples = kept
  state.phase = circularMean(kept, now)
  state.phaseAt = now
  state.spread = state.phase and spreadOf(state.phase, kept, now) or nil
end

function M.phaseAt(state, at)
  if not state.phase then return nil end
  return state.phase + (at - state.phaseAt) * M.DRIFT
end

local held = function(state, now)
  return state.primaryAt ~= nil and now - state.primaryAt <= M.HOLD
end

local agree = function(samples, now)
  local mean = circularMean(samples, now)
  for _, s in ipairs(samples) do
    if math.abs(M.residual(mean, drifted(s, now))) > M.RELOCK_AGREE then return false end
  end
  return true
end

local offBeat = function(state, now, sample, result, outvoted)
  local need = outvoted and M.RELOCK_COUNT_OUTVOTED or M.RELOCK_COUNT
  local recent = state.recent or {}
  recent[#recent + 1] = sample
  while #recent > need do table.remove(recent, 1) end
  state.recent = recent
  if #recent < need or not agree(recent, now) then return end
  state.samples, state.recent, state.primaryAt = recent, nil, nil
  for _, s in ipairs(recent) do
    if s.primary then state.primaryAt = now end
  end
  result.relocked, result.used = true, true
  refresh(state, now)
end

function M.add(state, now, source, at, frameGap)
  local trust = state.trusted[source]
  local primary = state.primary[source] == true
  local result = { source = source, at = at, trusted = trust and true or false, used = false }
  if state.phase then result.residual = M.residual(M.phaseAt(state, at), at) end
  if not result.trusted then return result end
  local sample = { at = at, primary = primary,
    weight = M.weight(frameGap) * (type(trust) == "number" and trust or 1) }
  local outvoted = held(state, now) and not primary
  if primary and state.phase and not held(state, now) then
    state.samples, state.recent, state.primaryAt = { sample }, nil, now
    result.relocked, result.used = true, true
    refresh(state, now)
    return result
  end
  if result.residual and math.abs(result.residual) > M.RELOCK_OFF then
    offBeat(state, now, sample, result, outvoted)
    return result
  end
  state.recent = nil
  if outvoted then return result end
  if primary then state.primaryAt = now end
  state.samples[#state.samples + 1] = sample
  result.used = true
  refresh(state, now)
  return result
end

function M.tickIndex(state, at, nearest)
  if not state.phase then return nil end
  local ticks = (at - M.phaseAt(state, at)) / M.PERIOD
  return math.floor(ticks + (nearest and 0.5 or 0))
end

function M.boundary(state, at, nearest)
  local k = M.tickIndex(state, at, nearest)
  return k and M.phaseAt(state, at) + k * M.PERIOD or nil
end

function M.nextTick(state, after)
  if not state.phase then return nil end
  return after + (M.phaseAt(state, after) - after) % M.PERIOD
end

return M
