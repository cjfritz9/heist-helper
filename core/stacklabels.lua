local M = {}

M.MARGIN = 4
M.LEARN_SECONDS = 20
M.REACH_TILES = 2
M.LOOT_GRACE_SECONDS = 2
M.HOVER_MARGIN = 48
M.HOVER_SECONDS = 1

local inside = function(icon, g)
  return g.x >= icon.x - M.MARGIN and g.x <= icon.x + icon.w + M.MARGIN
    and g.y >= icon.y - M.MARGIN and g.y <= icon.y + icon.h / 2
end

function M.label(icon, glyphs)
  local found = {}
  for _, g in ipairs(glyphs) do
    if inside(icon, g) then
      found[#found + 1] = g
    end
  end
  table.sort(found, function(a, b)
    if a.x ~= b.x then return a.x < b.x end
    return a.y < b.y
  end)
  local parts = {}
  for i, g in ipairs(found) do
    parts[i] = g.id
  end
  return table.concat(parts, " ")
end

function M.frame(icons, glyphs)
  local labels = {}
  for _, icon in ipairs(icons) do
    local key = icon.signature .. "@" .. math.floor(icon.x) .. "," .. math.floor(icon.y)
    labels[key] = { signature = icon.signature, label = M.label(icon, glyphs) }
  end
  return labels
end

function M.update(known, current)
  local changes = {}
  for key, entry in pairs(current) do
    local before = known[key]
    if before and before.label ~= entry.label then
      changes[#changes + 1] = { key = key, signature = entry.signature, before = before.label, after = entry.label }
    end
    known[key] = entry
  end
  table.sort(changes, function(a, b) return a.key < b.key end)
  return changes
end

function M.near(icon, x, y)
  return x >= icon.x - M.HOVER_MARGIN and x <= icon.x + icon.w + M.HOVER_MARGIN
    and y >= icon.y - M.HOVER_MARGIN and y <= icon.y + icon.h + M.HOVER_MARGIN
end

function M.present(icons, signature)
  for _, icon in ipairs(icons) do
    if icon.signature == signature then
      return true
    end
  end
  return false
end

function M.usedUp(wasPresent, icons, signature)
  return wasPresent and #icons > 0 and not M.present(icons, signature)
end

function M.aroundLoot(changeAt, lastLootAt)
  return lastLootAt ~= nil and math.abs(lastLootAt - changeAt) <= M.LOOT_GRACE_SECONDS * 1e6
end

function M.decided(now, changeAt)
  return now - changeAt > M.LOOT_GRACE_SECONDS * 1e6
end

function M.newLearner()
  return { recent = {} }
end

function M.note(learner, now, changes, tileX, tileZ)
  for _, c in ipairs(changes) do
    learner.recent[#learner.recent + 1] = { at = now, signature = c.signature, tileX = tileX, tileZ = tileZ }
  end
  local kept = {}
  for _, r in ipairs(learner.recent) do
    if now - r.at <= M.LEARN_SECONDS * 1e6 then
      kept[#kept + 1] = r
    end
  end
  learner.recent = kept
end

function M.learn(learner, now, anchorTileX, anchorTileZ)
  local signatures, count = {}, 0
  for _, r in ipairs(learner.recent) do
    local near = math.max(math.abs(r.tileX - anchorTileX), math.abs(r.tileZ - anchorTileZ)) <= M.REACH_TILES
    if near and now - r.at <= M.LEARN_SECONDS * 1e6 and not signatures[r.signature] then
      signatures[r.signature] = true
      count = count + 1
    end
  end
  if count ~= 1 then
    return nil, count
  end
  return next(signatures), 1
end

return M
