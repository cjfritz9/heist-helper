local tickphase = require("core.tickphase")
local tickclock = require("core.tickclock")
local rollinglog = require("core.rollinglog")

local M = {}

local FILE = "ticks.log"
local LINES = 4000
local FLUSH_MICROSECONDS = 2 * 1000 * 1000
local SUMMARY_MICROSECONDS = 30 * 1000 * 1000
local MOVED_UNITS = 1
local GHOST_STILL_MICROSECONDS = 150 * 1000
local TRUSTED = { player = 0.3, ghost = 1, xp = 1 }
local PRIMARY = { xp = true }
local SEEN_LATE_MICROSECONDS = { player = 37 * 1000, ghost = 53 * 1000 }
local XP_PAUSE_MICROSECONDS = 5 * 1000 * 1000

local bolt = nil
local state = tickphase.new(TRUSTED, PRIMARY)
local lastXpAt = nil
local playerClock = tickclock.new()
local lastPosition = nil
local lastFrameAt, frameGap = nil, nil
local log = nil
local dirty, nextFlush, nextSummary = false, 0, 0
local bySource = {}

local append = function(at, line)
  rollinglog.append(log, string.format("[%9.3f] %s", at / 1e6, line))
  dirty = true
end

function M.init(boltApi)
  bolt = boltApi
  log = rollinglog.new(bolt.loadconfig(FILE), LINES)
end

local sample = function(now, source, at)
  at = at - (SEEN_LATE_MICROSECONDS[source] or 0)
  local r = tickphase.add(state, now, source, at, frameGap)
  local tally = bySource[source] or { n = 0, sum = 0, squares = 0 }
  bySource[source] = tally
  if r.residual then
    tally.n, tally.sum, tally.squares = tally.n + 1, tally.sum + r.residual, tally.squares + r.residual * r.residual
  end
  append(at, string.format("%s%s: %s, frame %d ms (clock: %d samples, spread %s)%s",
    source, r.used and "" or " (measured only)",
    r.residual and string.format("%+d ms from the tick", r.residual / 1000) or "no clock yet",
    (frameGap or 0) / 1000, #state.samples,
    state.spread and string.format("%d ms", state.spread / 1000) or "-",
    r.relocked and ", relocked" or ""))
end

function M.frame(now, player)
  frameGap = lastFrameAt and now - lastFrameAt or nil
  lastFrameAt = now
  if player and player.x then
    local moved = lastPosition ~= nil
      and math.abs(player.x - lastPosition.x) + math.abs(player.z - lastPosition.z) > MOVED_UNITS
    if tickclock.observe(playerClock, now, moved) then sample(now, "player", now - (frameGap or 0) / 2) end
    lastPosition = { x = player.x, z = player.z }
  end
  if now >= nextSummary then
    nextSummary = now + SUMMARY_MICROSECONDS
    local parts = {}
    for source, t in pairs(bySource) do
      if t.n > 0 then
        local mean = t.sum / t.n
        parts[#parts + 1] = string.format("%s %+d ms ± %d (n=%d)", source, mean / 1000,
          math.sqrt(math.max(0, t.squares / t.n - mean * mean)) / 1000, t.n)
      end
    end
    table.sort(parts)
    if #parts > 0 then append(now, "summary, distance from the tick by source: " .. table.concat(parts, ", ")) end
    bySource = {}
  end
  if dirty and now >= nextFlush then
    bolt.saveconfig(FILE, rollinglog.text(log))
    dirty, nextFlush = false, now + FLUSH_MICROSECONDS
  end
end

function M.ghostStart(e)
  if e.still >= GHOST_STILL_MICROSECONDS then sample(e.at, "ghost", e.at - (frameGap or 0) / 2) end
end

function M.xpDrop(now)
  local afterPause = lastXpAt == nil or now - lastXpAt > XP_PAUSE_MICROSECONDS
  lastXpAt = now
  sample(now, afterPause and "xpfirst" or "xp", now - (frameGap or 0) / 2)
end

function M.popup(now)
  sample(now, "popup", now - (frameGap or 0) / 2)
end

function M.chat(now)
  sample(now, "chat", now - (frameGap or 0) / 2)
end

function M.boundary(at, nearest)
  return tickphase.boundary(state, at, nearest)
end

function M.nextTick(after)
  return tickphase.nextTick(state, after)
end

return M
