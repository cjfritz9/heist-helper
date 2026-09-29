local M = {}

M.MIN_INSIDE = 6
M.MIN_MARGIN = 3

local key = function(dx, dz)
  return dx .. "," .. dz
end

function M.legKey(start, finish)
  return start .. "-" .. finish
end

function M.set(tiles)
  local out, count = {}, 0
  for _, t in ipairs(tiles) do
    local k = key(t.dx, t.dz)
    if not out[k] then
      out[k] = t
      count = count + 1
    end
  end
  return out, count
end

local size = function(set)
  local n = 0
  for _ in pairs(set) do n = n + 1 end
  return n
end

local fit = function(pattern, seen)
  local inside, outside = 0, 0
  for k in pairs(seen) do
    if pattern[k] then inside = inside + 1 else outside = outside + 1 end
  end
  return inside, outside
end

function M.match(patterns, seen, ignore)
  local considered = {}
  for k, t in pairs(seen) do
    if not (ignore and ignore[k]) then considered[k] = t end
  end
  local ranked = {}
  for i, pattern in ipairs(patterns or {}) do
    local inside, outside = fit(pattern.tiles, considered)
    ranked[#ranked + 1] = { index = i, inside = inside, outside = outside }
  end
  table.sort(ranked, function(a, b) return a.inside > b.inside end)
  local best, second = ranked[1], ranked[2]
  if not best or best.inside < M.MIN_INSIDE then
    return nil, string.format("only %d path tiles on any known shape", best and best.inside or 0)
  end
  local margin = best.inside - (second and second.inside or 0)
  local name = patterns[best.index].name or tostring(best.index)
  if margin < M.MIN_MARGIN then
    return nil, string.format("shape %s leads by only %d", name, margin)
  end
  return best.index, string.format("shape %s: %d/%d tiles, leads by %d, %d stray", name, best.inside,
    patterns[best.index].count, margin, best.outside)
end

function M.timeline(frames, pattern, ignore)
  local found, parts = {}, {}
  for _, frame in ipairs(frames) do
    local onShape, new = 0, 0
    for _, t in ipairs(frame.tiles) do
      local k = key(t.dx, t.dz)
      if pattern[k] and not (ignore and ignore[k]) then
        onShape = onShape + 1
        if not found[k] then
          found[k] = true
          new = new + 1
        end
      end
    end
    parts[#parts + 1] = string.format("%.2fs %d (+%d)", frame.seconds, onShape, new)
  end
  return table.concat(parts, ", ")
end

function M.pattern(tiles)
  local set, count = M.set(tiles)
  return { tiles = set, count = count }
end

function M.fromShapes(definition)
  local library = {}
  for leg, frame in pairs(definition.legs) do
    library[leg] = {}
    for _, name in ipairs({ "A", "B", "C" }) do
      local tiles = {}
      for _, uv in ipairs(frame.shapes[name] or {}) do
        tiles[#tiles + 1] = {
          dx = frame.origin[1] + frame.u[1] * uv[1] + frame.v[1] * uv[2],
          dz = frame.origin[2] + frame.u[2] * uv[1] + frame.v[2] * uv[2],
        }
      end
      if #tiles > 0 then
        local p = M.pattern(tiles)
        p.name = name
        library[leg][#library[leg] + 1] = p
      end
    end
  end
  return library
end

return M
