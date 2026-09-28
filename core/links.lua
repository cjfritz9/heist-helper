local M = {}

M.ABSENT = "-"
M.DISAPPEAR_FRAMES = 60
M.WATCH_TILES = 12

function M.signature(model)
  return string.format("%d:%s:%d:%s:%s", model.vertices, model.fingerprint, model.animated and 1 or 0,
    model.colour, model.textureHash)
end

function M.vertexCount(signature)
  return tonumber(signature:match("^(%d+):"))
end

function M.mode(link)
  if link.before == M.ABSENT then
    return "appear"
  end
  if link.after == M.ABSENT then
    return "disappear"
  end
  if link.before == link.after then
    return "none"
  end
  return "change"
end

local anchorKey = function(link)
  return link.anchorDx .. "," .. link.anchorDz
end

function M.new()
  return { list = {} }
end

function M.put(links, link)
  for i, existing in ipairs(links.list) do
    if anchorKey(existing) == anchorKey(link) then
      links.list[i] = link
      return
    end
  end
  links.list[#links.list + 1] = link
end

function M.isLinked(links, anchorDx, anchorDz)
  for _, link in ipairs(links.list) do
    if link.anchorDx == anchorDx and link.anchorDz == anchorDz then
      return true
    end
  end
  return false
end

function M.watchedVertexCounts(links)
  local counts = {}
  for _, link in ipairs(links.list) do
    for _, signature in ipairs({ link.before, link.after }) do
      if signature ~= M.ABSENT then
        counts[M.vertexCount(signature)] = true
      end
    end
  end
  return counts
end

function M.encode(links)
  local out = {}
  for _, l in ipairs(links.list) do
    out[#out + 1] = string.format("%d,%d,%d,%d,%s,%s", l.anchorDx, l.anchorDz, l.objectDx, l.objectDz, l.before, l.after)
  end
  return table.concat(out, "\n") .. "\n"
end

function M.withSeed(seed, text)
  local links = M.new()
  for _, link in ipairs(seed or {}) do
    M.put(links, link)
  end
  for _, link in ipairs(M.decode(text).list) do
    M.put(links, link)
  end
  return links
end

function M.decode(text)
  local links = M.new()
  for line in (text or ""):gmatch("[^\r\n]+") do
    local ax, az, ox, oz, before, after = line:match("^(%-?%d+),(%-?%d+),(%-?%d+),(%-?%d+),([^,]+),([^,]+)$")
    if ax then
      M.put(links, {
        anchorDx = tonumber(ax), anchorDz = tonumber(az),
        objectDx = tonumber(ox), objectDz = tonumber(oz),
        before = before, after = after,
      })
    end
  end
  return links
end

function M.poweredNow(link, seenSignatures, playerNear, tracker)
  local mode = M.mode(link)
  if mode == "change" or mode == "appear" then
    return seenSignatures[link.after] == true
  end
  if mode == "disappear" then
    local key = anchorKey(link)
    if not playerNear or seenSignatures[link.before] then
      tracker[key] = 0
      return false
    end
    tracker[key] = (tracker[key] or 0) + 1
    return tracker[key] >= M.DISAPPEAR_FRAMES
  end
  return false
end

return M
