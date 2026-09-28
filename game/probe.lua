local coords = require("core.coords")
local picking = require("core.picking")
local probediff = require("core.probediff")

local M = {}

local RADIUS_TILES = 3
local WINDOW_MICROSECONDS = 1000 * 1000
local FINGERPRINT_VERTICES = 16
local COLOUR_SAMPLES = 128

local target = nil
local window = {}
local previous = {}
local windowEnds = 0

local atlasSize = function(event, vertex)
  local _, _, w, h = event:atlasxywh(event:vertexmeta(vertex))
  return w .. "x" .. h
end

local near = function(x, z)
  if not target then return nil end
  local tile = coords.fromWorld(x, z)
  return probediff.relative(target.tileX, target.tileZ, tile.tileX, tile.tileZ, RADIUS_TILES)
end

function M.active()
  return target ~= nil
end

function M.inspectModel(bolt, event)
  local ox, _, oz = bolt.point(0, 0, 0):transform(event:modelmatrix()):get()
  local where = near(ox, oz)
  if not where then return end
  local count = event:vertexcount()
  local shape, colours = {}, {}
  for i = 1, math.min(count, FINGERPRINT_VERTICES) do
    shape[i] = { event:vertexpoint(i):get() }
  end
  for i = 1, count, picking.stride(count, COLOUR_SAMPLES) do
    local r, g, b, a = event:vertexcolour(i)
    colours[#colours + 1] = { r * 255, g * 255, b * 255, a * 255 }
  end
  local sig = string.format("m:%d:%s:%d:c%s@%s", count, picking.fingerprint(shape), event:animated() and 1 or 0,
    picking.fingerprint(colours), where)
  window[sig] = true
end

function M.inspectParticles(event)
  local count = event:vertexcount()
  for i = 1, count, 6 do
    local x, _, z = event:vertexparticleorigin(i):get()
    local where = near(x, z)
    if where then
      window["p:" .. atlasSize(event, i) .. "@" .. where] = true
    end
  end
end

function M.inspectBillboard(bolt, event)
  local ox, _, oz = bolt.point(0, 0, 0):transform(event:modelmatrix()):get()
  local where = near(ox, oz)
  if not where then return end
  window["b:" .. event:vertexcount() .. ":" .. atlasSize(event, 1) .. "@" .. where] = true
end

function M.update(now, objects, playerTileX, playerTileZ, onLines)
  local found = nil
  for _, o in ipairs(objects) do
    if o.kind == "shadowAnchor"
      and math.max(math.abs(o.tileX - playerTileX), math.abs(o.tileZ - playerTileZ)) <= RADIUS_TILES then
      found = o
      break
    end
  end

  if not found then
    target, window, previous = nil, {}, {}
    return
  end
  if not target or target.tileX ~= found.tileX or target.tileZ ~= found.tileZ then
    target = { tileX = found.tileX, tileZ = found.tileZ }
    window, previous, windowEnds = {}, {}, now + WINDOW_MICROSECONDS
    onLines(string.format("[%8.1f] probing shadow anchor at %d,%d\n", now / 1e6, found.tileX, found.tileZ))
    return
  end
  if now < windowEnds then return end

  local added, removed = probediff.diff(previous, window)
  onLines(probediff.lines(now / 1e6, added, removed))
  previous, window, windowEnds = window, {}, now + WINDOW_MICROSECONDS
end

return M
