local coords = require("core.coords")
local links = require("core.links")
local probediff = require("core.probediff")
local recording = require("core.recording")
local nearby = require("core.nearby")
local signature = require("game.signature")

local M = {}

local AREA_TILES = 12
local WINDOW_MICROSECONDS = 250 * 1000

local target = nil
local sampling = false
local nextWindow = 0
local previous = nil
local current = {}

local where = function(x, z)
  local tile = coords.fromWorld(x, z)
  return probediff.relative(target.tileX, target.tileZ, tile.tileX, tile.tileZ, AREA_TILES)
end

local atlasSize = function(event, vertex)
  local _, _, w, h = event:atlasxywh(event:vertexmeta(vertex))
  return w .. "x" .. h
end

function M.active()
  return target ~= nil
end

function M.sampling()
  return target ~= nil and sampling
end

function M.inspectModel(bolt, event)
  local ox, _, oz = bolt.point(0, 0, 0):transform(event:modelmatrix()):get()
  local at = where(ox, oz)
  if not at then return end
  current["m|" .. links.signature(signature.of(event, event:vertexcount())) .. "@" .. at] = true
end

function M.inspectParticles(event)
  for i = 1, event:vertexcount(), 6 do
    local x, _, z = event:vertexparticleorigin(i):get()
    local at = where(x, z)
    if at then
      current["p|" .. atlasSize(event, i) .. "@" .. at] = true
    end
  end
end

function M.inspectBillboard(bolt, event)
  local ox, _, oz = bolt.point(0, 0, 0):transform(event:modelmatrix()):get()
  local at = where(ox, oz)
  if at then
    current["b|" .. event:vertexcount() .. ":" .. atlasSize(event, 1) .. "@" .. at] = true
  end
end

local start = function(now, anchorObject, runAnchor, write)
  target = { tileX = anchorObject.tileX, tileZ = anchorObject.tileZ }
  previous, current, sampling, nextWindow = nil, {}, true, now
  write(string.format("[%8.2f] recording shadow anchor at %d,%d (%d,%d from arrival)\n", now / 1e6,
    target.tileX, target.tileZ, target.tileX - runAnchor.x, target.tileZ - runAnchor.z))
end

local stop = function(now, write)
  write(string.format("[%8.2f] recording stopped\n", now / 1e6))
  target, previous, current, sampling = nil, nil, {}, false
end

function M.update(now, objects, playerX, playerZ, runAnchor, isLinked, write)
  if target and recording.shouldStop(target, playerX, playerZ) then
    stop(now, write)
  end
  if not target then
    local found = recording.chooseTarget(objects, playerX, playerZ, runAnchor, isLinked)
    if found then
      start(now, found, runAnchor, write)
    end
    return
  end
  if sampling then
    local seconds = now / 1e6
    if previous == nil then
      write(recording.snapshotLines(seconds, current))
    else
      local added, removed = probediff.diff(previous, current)
      write(probediff.lines(seconds, added, removed))
    end
    previous, current = current, {}
    nextWindow = now + WINDOW_MICROSECONDS
  end
  local atAnchor = nearby.distance(target.tileX, target.tileZ, playerX, playerZ) <= recording.START_TILES
  sampling = atAnchor or now >= nextWindow
end

function M.note(now, text, write)
  if target then
    write(string.format("[%8.2f] chat %s\n", now / 1e6, text))
  end
end

return M
