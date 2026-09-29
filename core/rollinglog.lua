local M = {}

function M.new(text, maxLines)
  local log = { lines = {}, max = maxLines }
  for line in (text or ""):gmatch("[^\n]+") do
    log.lines[#log.lines + 1] = line
  end
  M.trim(log)
  return log
end

function M.trim(log)
  local extra = #log.lines - log.max
  if extra <= 0 then return end
  local kept = {}
  for i = extra + 1, #log.lines do
    kept[#kept + 1] = log.lines[i]
  end
  log.lines = kept
end

function M.append(log, line)
  log.lines[#log.lines + 1] = line
  if #log.lines > log.max * 1.5 then
    M.trim(log)
  end
end

function M.text(log)
  M.trim(log)
  if #log.lines == 0 then return "" end
  return table.concat(log.lines, "\n") .. "\n"
end

return M
