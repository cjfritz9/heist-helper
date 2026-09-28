local M = {}

M.FIELDS = {
  { key = "vertices", label = "Vertices" },
  { key = "fingerprint", label = "Model" },
  { key = "animated", label = "Animated" },
  { key = "shape", label = "Shape" },
  { key = "uv", label = "UVs" },
  { key = "colour", label = "Colours" },
  { key = "textureHash", label = "Texture" },
  { key = "tile", label = "Tile" },
  { key = "size", label = "Size on screen" },
}

local IGNORED_FOR_VERDICT = { size = true }

function M.snapshot(candidate, anchorX, anchorZ)
  local tile = anchorX and ((candidate.tileX - anchorX) .. "," .. (candidate.tileZ - anchorZ))
    or (candidate.tileX .. "," .. candidate.tileZ)
  return {
    vertices = tostring(candidate.vertices),
    fingerprint = candidate.fingerprint,
    animated = candidate.animated and "yes" or "no",
    shape = candidate.shape,
    uv = candidate.uv,
    colour = candidate.colour,
    textureHash = candidate.textureHash,
    tile = tile,
    size = string.format("%dx%d", math.floor(candidate.box.maxX - candidate.box.minX + 0.5),
      math.floor(candidate.box.maxY - candidate.box.minY + 0.5)),
  }
end

function M.diff(before, after)
  local rows, differs = {}, {}
  for _, field in ipairs(M.FIELDS) do
    local a = before and before[field.key] or nil
    local b = after and after[field.key] or nil
    local same = a ~= nil and b ~= nil and a == b
    rows[#rows + 1] = { label = field.label, before = a or "", after = b or "", same = same }
    if before and after and not same and not IGNORED_FOR_VERDICT[field.key] then
      differs[#differs + 1] = field.label
    end
  end
  return rows, differs
end

function M.verdict(before, after)
  if not before or not after then
    return nil
  end
  local _, differs = M.diff(before, after)
  if #differs == 0 then
    return "Identical in everything Bolt can see"
  end
  return "Differs in: " .. table.concat(differs, ", ")
end

return M
