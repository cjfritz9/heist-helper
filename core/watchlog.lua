local M = {}

M.MAX_ITEMS = 12
M.STEADY_SHARE = 0.95

function M.new()
  return { armed = false, armedAt = nil, closed = false, baseline = {}, baselineFrames = 0, appeared = {}, gone = {} }
end

function M.inBaseline(log)
  return not log.armed
end

function M.close(log)
  if not log.armed or log.closed then return false end
  log.closed = true
  return true
end

function M.arm(log, now)
  if log.armed then return false end
  log.armed, log.armedAt = true, now
  return true
end

local isSteady = function(log, sig)
  return (log.baseline[sig] or 0) >= log.baselineFrames * M.STEADY_SHARE
end

function M.observe(log, now, seen)
  if log.closed then return end
  if not log.armed then
    log.baselineFrames = log.baselineFrames + 1
    for sig in pairs(seen) do
      log.baseline[sig] = (log.baseline[sig] or 0) + 1
    end
    return
  end
  local seconds = (now - log.armedAt) / 1e6
  for sig in pairs(seen) do
    if not log.baseline[sig] then
      local item = log.appeared[sig] or { first = seconds, frames = 0 }
      item.frames = item.frames + 1
      log.appeared[sig] = item
    end
  end
  for sig in pairs(log.baseline) do
    if not seen[sig] and isSteady(log, sig) then
      local item = log.gone[sig] or { first = seconds, frames = 0 }
      item.frames = item.frames + 1
      log.gone[sig] = item
    end
  end
end

function M.baselineSize(log)
  local count = 0
  for _ in pairs(log.baseline) do
    count = count + 1
  end
  return count
end

function M.items(log)
  local items = {}
  for sig, item in pairs(log.appeared) do
    items[#items + 1] = { signature = sig, change = "+", first = item.first, frames = item.frames }
  end
  for sig, item in pairs(log.gone) do
    items[#items + 1] = { signature = sig, change = "-", first = item.first, frames = item.frames }
  end
  table.sort(items, function(a, b)
    if a.first ~= b.first then return a.first < b.first end
    return a.signature < b.signature
  end)
  while #items > M.MAX_ITEMS do
    items[#items] = nil
  end
  return items
end

function M.describe(signature)
  local kind, rest = signature:match("^(%a)|(.*)$")
  if kind == "m" then
    local vertices, fingerprint, animated, colour, texture, dx, dz =
      rest:match("^(%d+):(%x+):([01]):(%x+):(%x+)@(%-?%d+),(%-?%d+)$")
    if vertices then
      local linkSignature = string.format("%s:%s:%s:%s:%s", vertices, fingerprint, animated, colour, texture)
      return string.format("model %sv %s%s col %s tex %s @%s,%s", vertices, fingerprint,
        animated == "1" and " animated" or "", colour, texture, dx, dz), linkSignature, tonumber(dx), tonumber(dz)
    end
  end
  if kind == "p" then
    return "particles " .. rest, nil
  end
  if kind == "b" then
    return "billboard " .. rest, nil
  end
  return signature, nil
end

return M
