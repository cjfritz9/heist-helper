local coords = require("core.coords")
local links = require("core.links")
local watchlog = require("core.watchlog")
local signature = require("game.signature")

local M = {}

local MIN_RADIUS, MAX_RADIUS = 1, 8

local radius = 1
local target = nil
local log = nil
local frame = {}
local lastFrame = nil
local raw = {}

local offset = function(x, z)
  local tile = coords.fromWorld(x, z)
  local dx, dz = tile.tileX - target.tileX, tile.tileZ - target.tileZ
  if math.abs(dx) > radius or math.abs(dz) > radius then
    return nil
  end
  return dx .. "," .. dz
end

local atlasSize = function(event, vertex)
  local _, _, w, h = event:atlasxywh(event:vertexmeta(vertex))
  return w .. "x" .. h
end

function M.start(tileX, tileZ)
  target = { tileX = tileX, tileZ = tileZ }
  log = watchlog.new()
  frame, lastFrame = {}, nil
end

local backgroundLines = function(now)
  local keys = {}
  for sig in pairs(log.baseline) do
    keys[#keys + 1] = sig
  end
  table.sort(keys)
  raw[#raw + 1] = string.format("[%9.3f] window opened at %d,%d radius %d after %d background frames",
    now / 1e6, target.tileX, target.tileZ, radius, log.baselineFrames)
  for _, sig in ipairs(keys) do
    raw[#raw + 1] = string.format("  background %3d%% %s", math.floor(100 * log.baseline[sig] / log.baselineFrames + 0.5), sig)
  end
end

function M.arm(now)
  if log ~= nil and target ~= nil and watchlog.arm(log, now) then
    backgroundLines(now)
    return true
  end
  return false
end

function M.close()
  if log ~= nil and watchlog.close(log) then
    raw[#raw + 1] = "window closed"
    return true
  end
  return false
end

function M.report()
  if not log or not target then return "" end
  local lines = {
    string.format("watch at %d,%d radius %d, background %d, frames %d",
      target.tileX, target.tileZ, radius, watchlog.baselineSize(log), log.baselineFrames),
  }
  for _, item in ipairs(watchlog.items(log)) do
    lines[#lines + 1] = string.format("%s %s frames=%d at=+%.2fs", item.change, item.signature, item.frames, item.first)
  end
  return table.concat(lines, "\n") .. "\n"
end

function M.resize(step)
  radius = math.max(MIN_RADIUS, math.min(MAX_RADIUS, radius + step))
  if target then
    log = watchlog.new()
    frame = {}
  end
end

function M.clear()
  target, log, frame = nil, nil, {}
end

function M.area()
  if not target then return nil end
  return { tileX = target.tileX, tileZ = target.tileZ, radius = radius }
end

function M.stop()
  target = nil
end

function M.active()
  return target ~= nil
end

function M.inspectModel(bolt, event)
  local ox, _, oz = bolt.point(0, 0, 0):transform(event:modelmatrix()):get()
  local where = offset(ox, oz)
  if not where then return end
  frame["m|" .. links.signature(signature.of(event, event:vertexcount())) .. "@" .. where] = true
end

function M.inspectParticles(event)
  for i = 1, event:vertexcount(), 6 do
    local x, _, z = event:vertexparticleorigin(i):get()
    local where = offset(x, z)
    if where then
      frame["p|" .. atlasSize(event, i) .. "@" .. where] = true
    end
  end
end

function M.inspectBillboard(bolt, event)
  local ox, _, oz = bolt.point(0, 0, 0):transform(event:modelmatrix()):get()
  local where = offset(ox, oz)
  if where then
    frame["b|" .. event:vertexcount() .. ":" .. atlasSize(event, 1) .. "@" .. where] = true
  end
end

local recordRaw = function(now)
  if not log.armed or log.closed then
    lastFrame = frame
    return
  end
  if lastFrame then
    local stamp = string.format("[%9.3f] ", now / 1e6)
    for sig in pairs(frame) do
      if not lastFrame[sig] then raw[#raw + 1] = stamp .. "+ " .. sig end
    end
    for sig in pairs(lastFrame) do
      if not frame[sig] then raw[#raw + 1] = stamp .. "- " .. sig end
    end
  end
  lastFrame = frame
end

function M.endFrame(now)
  if not target then return end
  recordRaw(now)
  watchlog.observe(log, now, frame)
  frame = {}
end

function M.takeRaw()
  if #raw == 0 then return "" end
  local text = table.concat(raw, "\n") .. "\n"
  raw = {}
  return text
end

function M.status()
  if not log then
    return { active = false, radius = radius, items = {} }
  end
  local items = {}
  for i, item in ipairs(watchlog.items(log)) do
    local label, linkSignature = watchlog.describe(item.signature)
    items[i] = {
      index = i, change = item.change, label = label, frames = item.frames,
      at = string.format("%.2f", item.first), linkable = linkSignature ~= nil and item.change == "+",
    }
  end
  return {
    active = target ~= nil,
    radius = radius,
    closed = log.closed,
    tile = target and (target.tileX .. "," .. target.tileZ) or nil,
    baseline = target ~= nil and watchlog.inBaseline(log),
    background = watchlog.baselineSize(log),
    items = items,
  }
end

function M.linkTarget(index)
  if not log or not target then return nil end
  local item = watchlog.items(log)[index]
  if not item or item.change ~= "+" then return nil end
  local _, linkSignature, dx, dz = watchlog.describe(item.signature)
  if not linkSignature then return nil end
  return linkSignature, target.tileX + dx, target.tileZ + dz
end

return M
