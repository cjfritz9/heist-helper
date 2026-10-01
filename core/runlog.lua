local M = {}

M.HEADER = "seconds,loot"

function M.parseTime(text)
  local m, s = (text or ""):match("(%d+):(%d+%.?%d*)")
  if not m then return nil end
  return tonumber(m) * 60 + tonumber(s)
end

function M.decode(text)
  local rows = {}
  for line in (text or ""):gmatch("[^\n]+") do
    local seconds, loot = line:match("^([%d.]+),(%d+)")
    if seconds then rows[#rows + 1] = { seconds = tonumber(seconds), loot = tonumber(loot) } end
  end
  return rows
end

function M.encode(rows)
  local out = { M.HEADER }
  for _, r in ipairs(rows) do out[#out + 1] = string.format("%.1f,%d", r.seconds, r.loot) end
  return table.concat(out, "\n") .. "\n"
end

function M.stats(rows, sessionFrom)
  local session = { runs = 0, total = 0, best = nil }
  for i = sessionFrom + 1, #rows do
    local r = rows[i]
    session.runs, session.total = session.runs + 1, session.total + r.seconds
    if not session.best or r.seconds < session.best then session.best = r.seconds end
  end
  local last = rows[#rows]
  return {
    last = last and { time = M.clock(last.seconds), loot = last.loot } or nil,
    lifetime = #rows,
    session = session.runs,
    average = session.runs > 0 and session.total / session.runs or nil,
    best = session.best,
  }
end

function M.clock(seconds)
  if not seconds then return "–" end
  return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60 + 0.5))
end

return M
