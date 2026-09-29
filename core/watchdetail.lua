local picking = require("core.picking")

local M = {}

M.MAX_VARIANTS = 50

local scaled = function(values, factor)
  local out = {}
  for i, v in ipairs(values) do
    out[i] = v * factor
  end
  return out
end

local hashMatrices = function(matrices)
  local points = {}
  for i, m in ipairs(matrices) do
    points[i] = scaled(m, 1000)
  end
  return picking.fingerprint(points)
end

function M.model(d)
  return string.format("pos %d,%d,%d scale %.3f matrix %s tex %s colour %d,%d,%d,%d%s",
    math.floor(d.x + 0.5), math.floor(d.y + 0.5), math.floor(d.z + 0.5), d.scale,
    hashMatrices({ d.matrix }), tostring(d.textureId),
    d.colour[1], d.colour[2], d.colour[3], d.colour[4],
    d.pose and (" pose " .. hashMatrices(d.pose)) or "")
end

function M.colour(r, g, b, a)
  return string.format("%d,%d,%d,%d", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
    math.floor(b * 255 + 0.5), math.floor(a * 255 + 0.5))
end

function M.add(frame, key, instance)
  local list = frame[key] or {}
  list[#list + 1] = instance
  frame[key] = list
end

function M.finish(frame)
  local described = {}
  for key, list in pairs(frame) do
    table.sort(list)
    described[key] = "x" .. #list .. " " .. table.concat(list, " | ")
  end
  return described
end

function M.changes(previous, current)
  local changed = {}
  for key, detail in pairs(current) do
    if previous[key] and previous[key] ~= detail then
      changed[#changed + 1] = { key = key, detail = detail }
    end
  end
  table.sort(changed, function(a, b) return a.key < b.key end)
  return changed
end

function M.newVariants()
  return {}
end

function M.track(variants, described)
  for key, detail in pairs(described) do
    local v = variants[key] or { count = 0, seen = {} }
    if not v.seen[detail] and v.count < M.MAX_VARIANTS then
      v.seen[detail] = true
      v.count = v.count + 1
    end
    variants[key] = v
  end
end

function M.variantCount(variants, key)
  return variants[key] and variants[key].count or 0
end

return M
