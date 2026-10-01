local lootprobe = require("game.lootprobe")
local rollinglog = require("core.rollinglog")

local M = {}

local LINES = 4000
local MAX_IMAGE_PIXELS = 128
local FOLLOW_PIXELS = 24
local FLUSH_MICROSECONDS = 1000 * 1000

function M.new(bolt, file, radius, duration, nextTick)
  return { bolt = bolt, file = file, radius = radius, duration = duration, nextTick = nextTick or function() return nil end,
    log = rollinglog.new(bolt.loadconfig(file), LINES), centre = nil, untilAt = nil, frame = {}, previous = {},
    hashes = {}, appearances = 0, nextFlush = 0 }
end

function M.append(probe, line)
  rollinglog.append(probe.log, string.format("[%9.3f] %s", probe.bolt.time() / 1e6, line))
end

function M.start(probe, x, y, now, what)
  probe.centre, probe.untilAt, probe.previous, probe.appearances = { x = x, y = y }, now + probe.duration, {}, 0
  M.append(probe, string.format("probe started %s for %d s", what, probe.duration / 1e6))
  probe.bolt.saveconfig(probe.file, rollinglog.text(probe.log))
end

function M.stop(probe)
  if not probe.centre then return end
  probe.untilAt = 0
end

function M.moveTo(probe, x, y)
  if probe.centre then probe.centre = { x = x, y = y } end
end

function M.active(probe)
  return probe.centre ~= nil
end

function M.status(probe, now)
  if not probe.centre then return nil end
  return { seconds = math.max(0, math.ceil((probe.untilAt - now) / 1e6)), appearances = probe.appearances }
end

local hashOf = function(probe, event, ax, ay, aw, ah)
  local k = ax .. "," .. ay .. "," .. aw .. "," .. ah
  if not probe.hashes[k] then probe.hashes[k] = lootprobe.pixelHash(event, ax, ay, aw, ah) end
  return probe.hashes[k]
end

function M.inspect2d(probe, event)
  local centre = probe.centre
  if not centre then return end
  local perImage = event:verticesperimage()
  for i = 1, event:vertexcount(), perImage do
    local ax, ay, aw, ah = event:vertexatlasdetails(i)
    if aw > 0 and ah > 0 and aw <= MAX_IMAGE_PIXELS and ah <= MAX_IMAGE_PIXELS then
      local x, y = event:vertexscaledxy(i)
      if math.abs(x - centre.x) <= probe.radius and math.abs(y - centre.y) <= probe.radius then
        local hash = hashOf(probe, event, ax, ay, aw, ah)
        local r, g, b = event:vertexcolour(i)
        probe.frame[#probe.frame + 1] = { hash = hash, x = x, y = y, w = aw, h = ah, colour = lootprobe.colourHex(r, g, b),
          bitmap = lootprobe.bitmap(event, hash, ax, ay, aw, ah) }
      end
    end
  end
end

local followed = function(probe, image)
  for i, p in ipairs(probe.previous) do
    if p.hash == image.hash and math.abs(p.x - image.x) <= FOLLOW_PIXELS and math.abs(p.y - image.y) <= FOLLOW_PIXELS then
      table.remove(probe.previous, i)
      return true
    end
  end
  return false
end

function M.endFrame(probe, now)
  if not probe.centre then return end
  local current = probe.frame
  probe.frame = {}
  local new = {}
  for _, image in ipairs(current) do
    if not followed(probe, image) then new[#new + 1] = image end
  end
  probe.previous = current
  if #new > 0 then
    local tick = probe.nextTick(now)
    local offset = tick and (now - (tick - 600 * 1000)) / 1000 or nil
    if offset and offset > 300 then offset = offset - 600 end
    local parts = {}
    for _, image in ipairs(new) do
      probe.appearances = probe.appearances + 1
      parts[#parts + 1] = string.format("%s %dx%d #%s at %d,%d", image.hash, image.w, image.h, image.colour, image.x, image.y)
      if image.bitmap then M.append(probe, string.format("bitmap %s %dx%d: %s", image.hash, image.w, image.h, image.bitmap)) end
    end
    M.append(probe, string.format("%d new (%s from the tick): %s", #new,
      offset and string.format("%+d ms", offset) or "no tick clock", table.concat(parts, "; ")))
  end
  local finished = now >= probe.untilAt
  if finished then
    M.append(probe, string.format("probe finished: %d appearances", probe.appearances))
    probe.centre = nil
  end
  if finished or now >= probe.nextFlush then
    probe.bolt.saveconfig(probe.file, rollinglog.text(probe.log))
    probe.nextFlush = now + FLUSH_MICROSECONDS
  end
end

return M
