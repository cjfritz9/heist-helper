local M = {}

M.FINGERPRINT_VERTICES = 16

M.MODELS = {
  { vertices = 3444, fingerprint = "9f69f595", kind = "chest", looted = false },
  { vertices = 3264, fingerprint = "8eaac06a", kind = "chest", looted = true },
  { vertices = 3456, fingerprint = "d77d3421", kind = "safe" },
  { vertices = 3411, fingerprint = "6ea760dd", kind = "rareChest", looted = false },
  { vertices = 3231, fingerprint = "fca0baf0", kind = "rareChest", looted = true },
  { vertices = 26187, fingerprint = "b940405f", kind = "corpse" },
  { vertices = 15108, fingerprint = "0928e6ef", kind = "corpse" },
  { vertices = 21867, fingerprint = "a99b1b05", kind = "corpse" },
  { vertices = 25818, fingerprint = "ac0eb5ba", kind = "corpse" },
  { vertices = 4506, fingerprint = "17aa0a87", kind = "shadowAnchor" },
}

local byVertices = {}
for _, model in ipairs(M.MODELS) do
  byVertices[model.vertices] = byVertices[model.vertices] or {}
  table.insert(byVertices[model.vertices], model)
end

function M.isCandidate(vertexCount)
  return byVertices[vertexCount] ~= nil
end

function M.classify(vertexCount, fingerprint, animated)
  for _, model in ipairs(byVertices[vertexCount] or {}) do
    if model.fingerprint == fingerprint then
      if model.kind == "safe" then
        return model.kind, not animated
      end
      return model.kind, model.looted
    end
  end
  return nil
end

return M
