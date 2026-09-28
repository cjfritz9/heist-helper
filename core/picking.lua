local M = {}

M.HEADER = "tag,rank,vertices,texture,animated,tileX,tileZ,dx,dz,originY,boxW,boxH,fingerprint,shape,uv,lastChat,mouseX,mouseY\n"

local HASH_MODULUS = 4294967296

function M.newBox()
  return { minX = math.huge, minY = math.huge, maxX = -math.huge, maxY = -math.huge }
end

function M.extend(box, x, y)
  if x < box.minX then box.minX = x end
  if y < box.minY then box.minY = y end
  if x > box.maxX then box.maxX = x end
  if y > box.maxY then box.maxY = y end
end

function M.contains(box, x, y)
  return x >= box.minX and x <= box.maxX and y >= box.minY and y <= box.maxY
end

function M.area(box)
  if box.maxX < box.minX then
    return math.huge
  end
  return (box.maxX - box.minX) * (box.maxY - box.minY)
end

function M.stride(count, maxSamples)
  return math.max(1, math.ceil(count / maxSamples))
end

function M.fingerprint(points)
  local hash = 5381
  for _, p in ipairs(points) do
    for _, v in ipairs(p) do
      hash = (hash * 33 + math.floor(v + 0.5)) % HASH_MODULUS
    end
  end
  return string.format("%08x", hash)
end

function M.rank(candidates)
  table.sort(candidates, function(a, b)
    return M.area(a.box) < M.area(b.box)
  end)
  return candidates
end

function M.startLog(text)
  if text and text:sub(1, #M.HEADER) == M.HEADER then
    return text
  end
  return M.HEADER
end

function M.lastTag(text)
  local last = 0
  for n in text:gmatch("\n(%d+),") do
    last = math.max(last, tonumber(n))
  end
  return last
end

function M.rows(tag, candidates, anchorX, anchorZ, mouseX, mouseY, lastChat, limit)
  local out = {}
  for rank = 1, math.min(limit, #candidates) do
    local c = candidates[rank]
    out[#out + 1] = string.format("%d,%d,%d,%d,%d,%d,%d,%d,%d,%.0f,%.0f,%.0f,%s,%s,%s,%s,%d,%d\n",
      tag, rank, c.vertices, c.texture, c.animated and 1 or 0,
      c.tileX, c.tileZ, c.tileX - anchorX, c.tileZ - anchorZ, c.originY,
      c.box.maxX - c.box.minX, c.box.maxY - c.box.minY,
      c.fingerprint, c.shape, c.uv, lastChat or "-", mouseX, mouseY)
  end
  return table.concat(out)
end

return M
