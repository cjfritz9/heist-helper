local coords = require("core.coords")
local catalog = require("core.catalog")
local picking = require("core.picking")

local M = {}

local RANGE_TILES = 40
local HULL_SAMPLES = 128

local frame = {}

local visible = function(depth)
  return depth and depth > 0 and depth <= 1
end

local fingerprintOf = function(event, count)
  local shape = {}
  for i = 1, math.min(count, catalog.FINGERPRINT_VERTICES) do
    shape[i] = { event:vertexpoint(i):get() }
  end
  return picking.fingerprint(shape)
end

local projectPoints = function(event, model, count)
  local viewProj = event:viewprojmatrix()
  local points = {}
  for i = 1, count, picking.stride(count, HULL_SAMPLES) do
    local sx, sy, depth = event:vertexpoint(i):transform(model):transform(viewProj):togameview()
    if visible(depth) then
      points[#points + 1] = { sx, sy }
    end
  end
  return points
end

function M.inspect(bolt, event, playerTileX, playerTileZ)
  local count = event:vertexcount()
  if not catalog.isCandidate(count) then return end

  local model = event:modelmatrix()
  local ox, _, oz = bolt.point(0, 0, 0):transform(model):get()
  local origin = coords.fromWorld(ox, oz)
  if playerTileX and (math.abs(origin.tileX - playerTileX) > RANGE_TILES
    or math.abs(origin.tileZ - playerTileZ) > RANGE_TILES) then
    return
  end

  local kind, looted = catalog.classify(count, fingerprintOf(event, count), event:animated())
  if not kind then return end

  local key = kind .. ":" .. origin.tileX .. "," .. origin.tileZ
  if frame[key] then return end
  frame[key] = {
    kind = kind,
    looted = looted,
    tileX = origin.tileX,
    tileZ = origin.tileZ,
    points = looted ~= true and projectPoints(event, model, count) or nil,
  }
end

function M.takeFrame()
  local list = {}
  for _, o in pairs(frame) do
    list[#list + 1] = o
  end
  frame = {}
  return list
end

return M
