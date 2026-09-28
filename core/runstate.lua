local M = {}

M.CORPSE_DONE = "You'vetakeneverythingyoucanfromthattarget."
M.RUN_COMPLETE_PREFIX = "CompletionTime:"
M.LOOT_PREFIX = "Youloot"
M.RUMMAGES_PER_CORPSE = 5

local CORPSE_REACH_TILES = 3

local key = function(dx, dz)
  return dx .. "," .. dz
end

local objectKey = function(kind, dx, dz)
  return kind .. "," .. dx .. "," .. dz
end

function M.new()
  return { anchor = nil, lootedCorpses = {}, rummages = {}, lootedObjects = {}, poweredAnchors = {} }
end

function M.setAnchor(state, anchor)
  if state.anchor and state.anchor.x == anchor.x and state.anchor.z == anchor.z then
    return false
  end
  state.anchor = { x = anchor.x, z = anchor.z }
  M.resetRun(state)
  return true
end

function M.resetRun(state)
  state.lootedCorpses = {}
  state.rummages = {}
  state.lootedObjects = {}
  state.poweredAnchors = {}
end

function M.markObjectLooted(state, kind, dx, dz)
  local k = objectKey(kind, dx, dz)
  if state.lootedObjects[k] then
    return false
  end
  state.lootedObjects[k] = true
  return true
end

function M.isObjectLooted(state, kind, dx, dz)
  return state.lootedObjects[objectKey(kind, dx, dz)] == true
end

function M.toggleAnchor(state, dx, dz)
  local k = key(dx, dz)
  state.poweredAnchors[k] = not state.poweredAnchors[k] or nil
  return state.poweredAnchors[k] == true
end

function M.setAnchorPowered(state, dx, dz)
  local k = key(dx, dz)
  if state.poweredAnchors[k] then
    return false
  end
  state.poweredAnchors[k] = true
  return true
end

function M.isAnchorPowered(state, dx, dz)
  return state.poweredAnchors[key(dx, dz)] == true
end

function M.rummageCount(state, dx, dz)
  return state.rummages[key(dx, dz)] or 0
end

local distanceTo = function(o, x, z)
  return math.max(math.abs(o.tileX - x), math.abs(o.tileZ - z))
end

function M.recordLoot(state, objects, playerX, playerZ)
  if not state.anchor then
    return nil
  end
  local best, bestDistance, tied = nil, CORPSE_REACH_TILES + 1, false
  for _, o in ipairs(objects) do
    local done = o.kind == "corpse"
      and M.isCorpseLooted(state, o.tileX - state.anchor.x, o.tileZ - state.anchor.z)
    if not done then
      local distance = distanceTo(o, playerX, playerZ)
      if distance < bestDistance then
        best, bestDistance, tied = o, distance, false
      elseif distance == bestDistance then
        tied = true
      end
    end
  end
  if not best or tied or best.kind ~= "corpse" then
    return nil
  end
  local k = key(best.tileX - state.anchor.x, best.tileZ - state.anchor.z)
  local count = (state.rummages[k] or 0) + 1
  state.rummages[k] = count
  if count >= M.RUMMAGES_PER_CORPSE then
    state.lootedCorpses[k] = true
  end
  return k, count
end

function M.isCorpseLooted(state, dx, dz)
  return state.lootedCorpses[key(dx, dz)] == true
end

function M.markNearestCorpse(state, corpses, playerX, playerZ)
  local best, bestDistance = nil, CORPSE_REACH_TILES + 1
  for _, c in ipairs(corpses) do
    local distance = distanceTo(c, playerX, playerZ)
    if distance < bestDistance then
      best, bestDistance = c, distance
    end
  end
  if not best or not state.anchor then
    return nil
  end
  local k = key(best.tileX - state.anchor.x, best.tileZ - state.anchor.z)
  state.lootedCorpses[k] = true
  return k
end

function M.chatEvent(text)
  if text == M.CORPSE_DONE then
    return "corpseLooted"
  end
  if text:sub(1, #M.LOOT_PREFIX) == M.LOOT_PREFIX then
    return "loot"
  end
  if text:sub(1, #M.RUN_COMPLETE_PREFIX) == M.RUN_COMPLETE_PREFIX then
    return "runComplete"
  end
  return nil
end

function M.encode(state)
  local out = {}
  if state.anchor then
    out[#out + 1] = string.format("anchor,%d,%d", state.anchor.x, state.anchor.z)
  end
  for k in pairs(state.lootedCorpses) do
    out[#out + 1] = "corpse," .. k
  end
  for k, count in pairs(state.rummages) do
    out[#out + 1] = "rummage," .. k .. "," .. count
  end
  for k in pairs(state.lootedObjects) do
    out[#out + 1] = "looted," .. k
  end
  for k in pairs(state.poweredAnchors) do
    out[#out + 1] = "powered," .. k
  end
  table.sort(out)
  return table.concat(out, "\n") .. "\n"
end

function M.decode(text)
  local state = M.new()
  for line in (text or ""):gmatch("[^\r\n]+") do
    local kind, a, b, c = line:match("^(%a+),(%-?%d+),(%-?%d+),?(%d*)$")
    if kind == "anchor" then
      state.anchor = { x = tonumber(a), z = tonumber(b) }
    elseif kind == "corpse" then
      state.lootedCorpses[key(tonumber(a), tonumber(b))] = true
    elseif kind == "rummage" and c ~= "" then
      state.rummages[key(tonumber(a), tonumber(b))] = tonumber(c)
    elseif kind == "powered" then
      state.poweredAnchors[key(tonumber(a), tonumber(b))] = true
    end
    local lootedKind, lx, lz = line:match("^looted,(%a+),(%-?%d+),(%-?%d+)$")
    if lootedKind then
      state.lootedObjects[objectKey(lootedKind, tonumber(lx), tonumber(lz))] = true
    end
  end
  return state
end

return M
