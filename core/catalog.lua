local M = {}

M.FINGERPRINT_VERTICES = 16

M.MODELS = {
  { vertices = 3444, fingerprint = "9f69f595", kind = "chest", looted = false, lockedTextures = { bd02db92 = true } },
  { vertices = 3264, fingerprint = "8eaac06a", kind = "chest", looted = true },
  { vertices = 3456, fingerprint = "d77d3421", kind = "safe" },
  { vertices = 3411, fingerprint = "6ea760dd", kind = "rareChest", looted = false },
  { vertices = 3231, fingerprint = "fca0baf0", kind = "rareChest", looted = true },
  { vertices = 26187, fingerprint = "b940405f", kind = "corpse" },
  { vertices = 15108, fingerprint = "0928e6ef", kind = "corpse" },
  { vertices = 21867, fingerprint = "a99b1b05", kind = "corpse" },
  { vertices = 25818, fingerprint = "ac0eb5ba", kind = "corpse" },
  { vertices = 4506, fingerprint = "17aa0a87", kind = "shadowAnchor" },
  { vertices = 684, fingerprint = "c8aa0e18", kind = "shadowDial" },
  { vertices = 2004, fingerprint = "a55442d9", kind = "shadowCrystal" },
}

M.userModels = {}

local byVertices = {}

local index = function(model)
  byVertices[model.vertices] = byVertices[model.vertices] or {}
  table.insert(byVertices[model.vertices], model)
end

for _, model in ipairs(M.MODELS) do
  index(model)
end

local LOOTED_CODES = { [true] = "1", [false] = "0" }

function M.add(vertices, fingerprint, kind, looted)
  for _, model in ipairs(byVertices[vertices] or {}) do
    if model.fingerprint == fingerprint then
      return false
    end
  end
  local model = { vertices = vertices, fingerprint = fingerprint, kind = kind, looted = looted }
  M.userModels[#M.userModels + 1] = model
  index(model)
  return true
end

function M.encodeUser()
  local out = {}
  for _, m in ipairs(M.userModels) do
    local looted = LOOTED_CODES[m.looted] or "-"
    out[#out + 1] = string.format("%d,%s,%s,%s", m.vertices, m.fingerprint, m.kind, looted)
  end
  return table.concat(out, "\n") .. "\n"
end

function M.loadUser(text)
  for line in (text or ""):gmatch("[^\r\n]+") do
    local vertices, fingerprint, kind, looted = line:match("^(%d+),(%x+),(%a+),([01%-])$")
    if vertices then
      local state = nil
      if looted == "1" then state = true elseif looted == "0" then state = false end
      M.add(tonumber(vertices), fingerprint, kind, state)
    end
  end
end

function M.isCandidate(vertexCount)
  return byVertices[vertexCount] ~= nil
end

local findModel = function(vertexCount, fingerprint)
  for _, model in ipairs(byVertices[vertexCount] or {}) do
    if model.fingerprint == fingerprint then
      return model
    end
  end
  return nil
end

function M.needsTexture(vertexCount, fingerprint)
  local model = findModel(vertexCount, fingerprint)
  return model ~= nil and model.lockedTextures ~= nil
end

function M.classify(vertexCount, fingerprint, animated, textureHash)
  local model = findModel(vertexCount, fingerprint)
  if not model then
    return nil
  end
  local locked = model.lockedTextures ~= nil and textureHash ~= nil and model.lockedTextures[textureHash] == true
  if model.kind == "safe" then
    return model.kind, not animated, locked
  end
  return model.kind, model.looted, locked
end

return M
