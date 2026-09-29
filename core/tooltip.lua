local M = {}

M.COLOUR = "e3d7cf"
M.LINE_GAP = 8
M.PATTERN = "LootStored:(%d+)$"

function M.lines(glyphs, font)
  local sorted = {}
  for _, g in ipairs(glyphs) do
    sorted[#sorted + 1] = g
  end
  table.sort(sorted, function(a, b) return a.y < b.y end)
  local lines, current = {}, nil
  for _, g in ipairs(sorted) do
    if not current or g.y - current.bottom > M.LINE_GAP then
      current = { bottom = g.y, glyphs = {} }
      lines[#lines + 1] = current
    end
    current.bottom = g.y
    current.glyphs[#current.glyphs + 1] = g
  end
  local texts = {}
  for i, line in ipairs(lines) do
    table.sort(line.glyphs, function(a, b) return a.x < b.x end)
    local chars = {}
    for j, g in ipairs(line.glyphs) do
      chars[j] = font[g.hash] or "?"
    end
    texts[i] = table.concat(chars)
  end
  return texts
end

function M.lootStored(glyphs, font)
  for _, text in ipairs(M.lines(glyphs, font)) do
    local value = text:match(M.PATTERN)
    if value then
      return tonumber(value)
    end
  end
  return nil
end

function M.newReconciler()
  return { last = nil }
end

function M.confirm(reconciler, value)
  local confirmed = value ~= nil and reconciler.last == value
  reconciler.last = value
  return confirmed and value or nil
end

return M
