local coords = require("core.coords")
local picking = require("core.picking")

local M = {}

local PICK_RADIUS_TILES = 20
local MAX_SAMPLES = 256
local FINGERPRINT_VERTICES = 16
local UV_PRECISION = 4096

local pending = nil

local onScreen = function(depth)
  return depth and depth >= -1 and depth <= 1
end

function M.request(x, y)
  pending = { x = x, y = y, candidates = {}, collecting = false }
end

function M.collecting()
  return pending ~= nil and pending.collecting
end

function M.inspect(bolt, event)
  local position = bolt.playerposition()
  if not position then return end
  local px, _, pz = position:get()
  local player = coords.fromWorld(px, pz)

  local model = event:modelmatrix()
  local ox, oy, oz = bolt.point(0, 0, 0):transform(model):get()
  local origin = coords.fromWorld(ox, oz)
  if math.abs(origin.tileX - player.tileX) > PICK_RADIUS_TILES
    or math.abs(origin.tileZ - player.tileZ) > PICK_RADIUS_TILES then
    return
  end

  local viewProj = event:viewprojmatrix()
  local count = event:vertexcount()
  local box = picking.newBox()
  local sampled = {}
  for i = 1, count, picking.stride(count, MAX_SAMPLES) do
    local modelPoint = event:vertexpoint(i)
    local sx, sy, depth = modelPoint:transform(model):transform(viewProj):toscreen()
    if onScreen(depth) then
      picking.extend(box, sx, sy)
    end
    sampled[#sampled + 1] = { i = i, point = modelPoint }
  end
  if not picking.contains(box, pending.x, pending.y) then return end

  local shapePoints, uvPoints = {}, {}
  for n, s in ipairs(sampled) do
    shapePoints[n] = { s.point:get() }
    local u, v = event:vertexuv(s.i)
    uvPoints[n] = { u * UV_PRECISION, v * UV_PRECISION }
  end

  local shape = {}
  for i = 1, math.min(count, FINGERPRINT_VERTICES) do
    shape[i] = { event:vertexpoint(i):get() }
  end

  pending.candidates[#pending.candidates + 1] = {
    vertices = count,
    texture = event:textureid(),
    animated = event:animated(),
    tileX = origin.tileX,
    tileZ = origin.tileZ,
    originY = oy,
    box = box,
    fingerprint = picking.fingerprint(shape),
    shape = picking.fingerprint(shapePoints),
    uv = picking.fingerprint(uvPoints),
  }
end

function M.advance()
  if not pending then return nil end
  if not pending.collecting then
    pending.collecting = true
    return nil
  end
  local finished = pending
  pending = nil
  finished.candidates = picking.rank(finished.candidates)
  return finished
end

return M
