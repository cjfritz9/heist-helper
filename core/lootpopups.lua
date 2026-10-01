local M = {}

M.LINE_TOLERANCE = 6
M.MATCH_DX = 30
M.RISE_MAX, M.FALL_MAX = 60, 3
M.GRACE_SECONDS = 1
M.MIN_PARTIAL = 3
M.PAIR_SECONDS = 1.5
M.SETTLE_SECONDS = 0.3
M.SUFFIX = "LootGained"

function M.lines(glyphs, font)
  local sorted = {}
  for _, g in ipairs(glyphs) do
    sorted[#sorted + 1] = g
  end
  table.sort(sorted, function(a, b)
    if math.abs(a.y - b.y) > M.LINE_TOLERANCE then return a.y < b.y end
    return a.x < b.x
  end)
  local lines, current = {}, nil
  for _, g in ipairs(sorted) do
    if not current or math.abs(g.y - current.y) > M.LINE_TOLERANCE then
      current = { x = g.x, y = g.y, right = g.x, chars = {}, unknown = {} }
      lines[#lines + 1] = current
    end
    current.right = math.max(current.right, g.x)
    local char = font[g.hash]
    current.chars[#current.chars + 1] = char or "?"
    if not char then
      current.unknown[#current.unknown + 1] = g.hash
    end
  end
  for _, line in ipairs(lines) do
    line.text = table.concat(line.chars)
  end
  return lines
end

function M.digits(text)
  return text:match("^(%d+)" .. M.SUFFIX .. "$")
end

function M.value(text)
  local digits = M.digits(text)
  return digits and tonumber(digits) or nil
end

function M.isLootLine(text)
  local rest = text:gsub("^[%d?]+", "")
  if #rest < M.MIN_PARTIAL then return false end
  return M.SUFFIX:sub(1, #rest) == rest or M.SUFFIX:sub(-#rest) == rest
end

function M.newTracker()
  return { lines = {} }
end

local matches = function(old, line)
  local rise = old.y - line.y
  local a, b = old.best, M.digits(line.text)
  local conflict = a and b and not (a:find(b, 1, true) or b:find(a, 1, true))
  local near = math.abs(old.right - line.right) <= M.MATCH_DX or math.abs(old.x - line.x) <= M.MATCH_DX
  return near and rise <= M.RISE_MAX and rise >= -M.FALL_MAX and not conflict
end

local closest = function(tracker, claimed, line)
  local best, bestDistance = nil, math.huge
  for i, old in ipairs(tracker.lines) do
    if not claimed[i] and matches(old, line) then
      local distance = math.abs(old.y - line.y) + math.abs(old.right - line.right)
      if distance < bestDistance then
        best, bestDistance = i, distance
      end
    end
  end
  return best
end

local finished = function(entry)
  entry.counted = true
  return { value = tonumber(entry.best), at = entry.firstRead }
end

function M.update(tracker, now, lines)
  local ready, unreadable, appeared = {}, {}, 0
  local claimed = {}
  for _, line in ipairs(lines) do
    if M.isLootLine(line.text) then
      local found = closest(tracker, claimed, line)
      local entry = found and tracker.lines[found]
      if not entry then
        entry = { counted = false }
        appeared = appeared + 1
        tracker.lines[#tracker.lines + 1] = entry
        found = #tracker.lines
      end
      claimed[found] = true
      entry.x, entry.right, entry.y, entry.seen, entry.text = line.x, line.right, line.y, now, line.text
      local digits = M.digits(line.text)
      if digits and (not entry.best or #digits > #entry.best) then
        entry.best = digits
        entry.firstRead = entry.firstRead or now
      end
      if #line.unknown > 0 and not entry.reported then
        entry.reported = true
        unreadable[#unreadable + 1] = line
      end
      if not entry.counted and entry.best and now - entry.firstRead >= M.SETTLE_SECONDS * 1e6 then
        ready[#ready + 1] = finished(entry)
      end
    end
  end
  local kept = {}
  for _, old in ipairs(tracker.lines) do
    if now - old.seen <= M.GRACE_SECONDS * 1e6 then
      kept[#kept + 1] = old
    elseif not old.counted and old.best then
      ready[#ready + 1] = finished(old)
    end
  end
  tracker.lines = kept
  return ready, unreadable, appeared
end

M.VALUES = {
  corpse = { [2] = true, [4] = true, [6] = true },
  chest = { [10] = true, [15] = true },
  safe = { [30] = true },
  rareChest = { [50] = true },
}

function M.newPairing()
  return { popups = {}, actions = {} }
end

function M.popup(pairing, now, value)
  pairing.popups[#pairing.popups + 1] = { at = now, value = value }
  table.sort(pairing.popups, function(a, b) return a.at < b.at end)
end

function M.action(pairing, now, kind, section)
  pairing.actions[#pairing.actions + 1] = { at = now, kind = kind, section = section }
end

local fits = function(action, popup, window)
  local values = M.VALUES[action.kind]
  return values and values[popup.value] and math.abs(popup.at - action.at) <= window
end

function M.settle(pairing, now)
  local window = M.PAIR_SECONDS * 1e6
  local counted, dropped, waiting = {}, {}, {}
  for _, popup in ipairs(pairing.popups) do
    local match = nil
    for i, action in ipairs(pairing.actions) do
      if fits(action, popup, window) then
        match = i
        break
      end
    end
    if match then
      counted[#counted + 1] = { value = popup.value, section = table.remove(pairing.actions, match).section }
    elseif now - popup.at > window then
      dropped[#dropped + 1] = popup.value
    else
      waiting[#waiting + 1] = popup
    end
  end
  pairing.popups = waiting
  local kept = {}
  for _, action in ipairs(pairing.actions) do
    if now - action.at <= window then
      kept[#kept + 1] = action
    end
  end
  pairing.actions = kept
  return counted, dropped
end

return M
