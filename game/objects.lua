local coords = require("core.coords")
local catalog = require("core.catalog")
local extremes = require("core.extremes")
local links = require("core.links")
local signature = require("game.signature")

local M = {}

local RANGE_TILES = 40

local frame = {}
local watchedFrame = {}
local watched = {}
local target = nil
local targetPoints = nil
local outlinePoints = {}

local visible = function(depth)
  return depth and depth > 0 and depth <= 1
end

local modelExtremes = function(event, count, key)
  local cached = outlinePoints[key]
  if cached then
    return cached
  end
  local points = {}
  for i = 1, count do
    points[i] = { event:vertexpoint(i):get() }
  end
  cached = extremes.select(points)
  outlinePoints[key] = cached
  return cached
end

local projectPoints = function(bolt, event, model, count, key)
  local viewProj = event:viewprojmatrix()
  local scale = event:scale()
  local points = {}
  for _, p in ipairs(modelExtremes(event, count, key)) do
    local sx, sy, depth = bolt.point(p[1] * scale, p[2] * scale, p[3] * scale)
      :transform(model):transform(viewProj):togameview()
    if visible(depth) then
      points[#points + 1] = { sx, sy }
    end
  end
  return points
end

function M.setWatched(vertexCounts)
  watched = vertexCounts
end

function M.setTarget(model)
  target = model
end

function M.inspect(bolt, event, playerTileX, playerTileZ)
  local count = event:vertexcount()
  local isCatalogued = catalog.isCandidate(count)
  local isTargetSize = target ~= nil and target.vertices == count
  if not isCatalogued and not watched[count] and not isTargetSize then return end

  local model = event:modelmatrix()
  local ox, oy, oz = bolt.point(0, 0, 0):transform(model):get()
  local origin = coords.fromWorld(ox, oz)
  if playerTileX and (math.abs(origin.tileX - playerTileX) > RANGE_TILES
    or math.abs(origin.tileZ - playerTileZ) > RANGE_TILES) then
    return
  end

  local fingerprint = signature.fingerprint(event, count)
  if isTargetSize and not targetPoints and fingerprint == target.fingerprint
    and origin.tileX == target.tileX and origin.tileZ == target.tileZ then
    targetPoints = projectPoints(bolt, event, model, count, count .. ":" .. fingerprint)
  end
  if watched[count] then
    watchedFrame[#watchedFrame + 1] = {
      signature = links.signature({
        vertices = count, fingerprint = fingerprint, animated = event:animated(),
        colour = signature.colour(event, count), textureHash = signature.texture(event, count),
      }),
      tileX = origin.tileX,
      tileZ = origin.tileZ,
    }
  end
  if not isCatalogued then return end

  local textureHash = catalog.needsTexture(count, fingerprint) and signature.texture(event, count) or nil
  local kind, looted, locked = catalog.classify(count, fingerprint, event:animated(), textureHash)
  if not kind then return end

  local key = kind .. ":" .. origin.tileX .. "," .. origin.tileZ
  if frame[key] then return end
  frame[key] = {
    kind = kind,
    looted = looted,
    locked = locked,
    tileX = origin.tileX,
    tileZ = origin.tileZ,
    y = oy,
    points = looted ~= true and projectPoints(bolt, event, model, count, count .. ":" .. fingerprint) or nil,
  }
end

function M.takeFrame()
  local list = {}
  for _, o in pairs(frame) do
    list[#list + 1] = o
  end
  local watchedList, selected = watchedFrame, targetPoints
  frame, watchedFrame, targetPoints = {}, {}, nil
  return list, watchedList, selected
end

return M
