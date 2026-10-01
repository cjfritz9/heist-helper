local M = {}

M.ROW_PIXELS = 6
M.TEXT_REACH = 250
M.TEXT_FRESH = 200 * 1000
M.CROSS_REACH = 14
M.CROSS_OFFSET = 4
M.CROSS_WAIT = 400 * 1000

function M.new(known)
  return { known = known, mouse = nil, glyphs = {}, text = nil, textAt = nil, clicks = {} }
end

function M.signature(glyphs)
  local sorted = {}
  for _, g in ipairs(glyphs) do sorted[#sorted + 1] = g end
  table.sort(sorted, function(a, b)
    if math.abs(a.y - b.y) > M.ROW_PIXELS then return a.y < b.y end
    return a.x < b.x
  end)
  local hashes = {}
  for i, g in ipairs(sorted) do hashes[i] = g.hash end
  return table.concat(hashes, " ")
end

function M.nameOf(state, text)
  if not text then return nil end
  for name, signature in pairs(state.known.names) do
    if text:find(signature, 1, true) then return name end
  end
  return nil
end

function M.glyph(state, hash, x, y, colour)
  local m = state.mouse
  if colour ~= "00ffff" or not m then return end
  if x < m.x - M.TEXT_REACH or x > m.x + M.TEXT_REACH or y < m.y - M.TEXT_REACH or y > m.y + M.TEXT_REACH then return end
  state.glyphs[#state.glyphs + 1] = { hash = hash, x = x, y = y }
end

function M.image(state, hash, x, y, now)
  local kind = (state.known.crossInteract[hash] and "interact") or (state.known.crossWalk[hash] and "walk")
  if not kind then return nil end
  for i, c in ipairs(state.clicks) do
    if math.abs(x - c.x - M.CROSS_OFFSET) <= M.CROSS_REACH and math.abs(y - c.y - M.CROSS_OFFSET) <= M.CROSS_REACH then
      table.remove(state.clicks, i)
      return { kind = kind, x = c.x, y = c.y, at = c.at, target = c.target, name = M.nameOf(state, c.target), seenAt = now }
    end
  end
  return nil
end

function M.endFrame(state, now)
  if #state.glyphs > 0 then
    state.text, state.textAt = M.signature(state.glyphs), now
    state.glyphs = {}
  end
  local kept = {}
  for _, c in ipairs(state.clicks) do
    if now - c.at <= M.CROSS_WAIT then kept[#kept + 1] = c end
  end
  state.clicks = kept
end

function M.click(state, x, y, now)
  local fresh = state.textAt and now - state.textAt <= M.TEXT_FRESH
  state.clicks[#state.clicks + 1] = { x = x, y = y, at = now, target = fresh and state.text or nil }
end

return M
