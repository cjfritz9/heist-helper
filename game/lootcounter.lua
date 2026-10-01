local runstate = require("core.runstate")
local rollinglog = require("core.rollinglog")
local stacklabels = require("core.stacklabels")
local popups = require("core.popups")
local lootpopups = require("core.lootpopups")
local tooltip = require("core.tooltip")
local lootOverlay = require("gfx.lootoverlay")
local popupFont = require("data.popupfont")
local tooltipFont = require("data.tooltipfont")
local defaultIcons = require("data.icons")

local M = {}

local LOG_FILE = "loot.log"
local BAG_FILE = "lootbag.csv"
local LOG_LINES = 2000
local FLUSH_MICROSECONDS = 1000 * 1000

local bolt, run, saveRun = nil, nil, nil
local log, dirty, nextFlush = nil, false, 0
local bagSignature = nil
local tracker, pairing, reconciler = lootpopups.newTracker(), lootpopups.newPairing(), tooltip.newReconciler()
local mouse, playerScreen, lastIcons = nil, nil, {}
local bagIcon, bagHovered = nil, false
local QUIET_MICROSECONDS = 10 * 1000 * 1000
local quietUntil, wasInRun = 0, false

local onPopupAppear = function() end

function M.onPopupAppear(listener)
  onPopupAppear = listener
end

function M.loggedIn(now)
  quietUntil = now + QUIET_MICROSECONDS
end

function M.init(boltApi, currentRun, save)
  bolt, run, saveRun = boltApi, currentRun, save
  log = rollinglog.new(bolt.loadconfig(LOG_FILE), LOG_LINES)
  bagSignature = (bolt.loadconfig(BAG_FILE) or ""):match("^%s*(%S+)") or defaultIcons.lootBag
end

function M.append(line)
  rollinglog.append(log, string.format("[%9.3f] %s", bolt.time() / 1e6, line))
  dirty = true
end

function M.flush(now)
  if not dirty or now < nextFlush then return end
  bolt.saveconfig(LOG_FILE, rollinglog.text(log))
  dirty = false
  nextFlush = now + FLUSH_MICROSECONDS
end

function M.setBag(signature)
  bagSignature = signature
  bolt.saveconfig(BAG_FILE, signature .. "\n")
end

function M.bagKnown()
  return bagSignature ~= nil
end

function M.setMouse(x, y)
  mouse = { x = x, y = y }
end

local lastActionAt = nil

function M.action(now, kind, section)
  lastActionAt = now
  lootpopups.action(pairing, now, kind, section)
end

function M.lastActionAt()
  return lastActionAt
end

function M.caught(wrongStep)
  local loss = runstate.lossFor(wrongStep)
  M.append(string.format("%s: -%d, bag %d", wrongStep and "wrong step off the maze path" or "caught", loss,
    runstate.addLoot(run, -loss, run.section)))
  saveRun()
end

function M.updatePlayerScreen(viewProj)
  playerScreen = nil
  local position = bolt.playerposition()
  if not position or not viewProj then return end
  local x, y, z = position:get()
  local sx, sy, depth = bolt.point(x, y, z):transform(viewProj):togameview()
  if not depth or depth <= 0 or depth > 1 then return end
  local vx, vy = bolt.gameviewxywh()
  playerScreen = { x = sx + vx, y = sy + vy }
end

local extraGlyphs = function() return false end

function M.alsoWantGlyph(wanted)
  extraGlyphs = wanted
end

M.want = {
  image = function(x, y)
    return playerScreen ~= nil and popups.inside(popups.PLAYER_BOX, playerScreen.x, playerScreen.y, x, y)
  end,
  glyph = function(x, y, colour)
    return (bagHovered and colour == tooltip.COLOUR and popups.inside(popups.MOUSE_BOX, mouse.x, mouse.y, x, y))
      or extraGlyphs(x, y, colour)
  end,
  known = function(hash)
    return popupFont[hash] ~= nil or tooltipFont[hash] ~= nil
  end,
}

local mouseOverBag = function()
  if not bagSignature or not mouse then return false end
  for _, icon in ipairs(lastIcons) do
    if icon.signature == bagSignature and stacklabels.near(icon, mouse.x, mouse.y) then
      return true
    end
  end
  return false
end

local popupGlyphs = function(images)
  local heights = {}
  for _, image in ipairs(images) do
    if popupFont[image.hash] then heights[image.h] = true end
  end
  local glyphs = {}
  for _, image in ipairs(images) do
    if heights[image.h] then glyphs[#glyphs + 1] = image end
  end
  return glyphs
end

local count = function(images, now)
  if not playerScreen then return end
  local near = {}
  for _, image in ipairs(images) do
    if popups.inside(popups.PLAYER_BOX, playerScreen.x, playerScreen.y, image.x, image.y) then
      near[#near + 1] = image
    end
  end
  local ready, unreadable, appeared = lootpopups.update(tracker, now, lootpopups.lines(popupGlyphs(near), popupFont))
  if appeared > 0 then onPopupAppear(now) end
  for _, item in ipairs(ready) do
    lootpopups.popup(pairing, item.at, item.value)
  end
  for _, line in ipairs(unreadable) do
    M.append(string.format("unreadable loot popup '%s', unknown glyphs %s", line.text, table.concat(line.unknown, " ")))
  end
  local counted, dropped = lootpopups.settle(pairing, now)
  for _, c in ipairs(counted) do
    local section = c.section or run.section
    M.append(string.format("counted +%d in section %s: bag %d", c.value, tostring(section),
      runstate.addLoot(run, c.value, section)))
    saveRun()
  end
  for _, value in ipairs(dropped) do
    M.append(string.format("ignored popup +%d: no loot action with it", value))
  end
end

local reconcile = function(glyphs)
  local value = nil
  if bagHovered and bolt.time() >= quietUntil then
    local near = {}
    for _, g in ipairs(glyphs) do
      if g.pixels and g.colour == tooltip.COLOUR and popups.inside(popups.MOUSE_BOX, mouse.x, mouse.y, g.x, g.y) then
        near[#near + 1] = { x = g.x, y = g.y, hash = g.pixels }
      end
    end
    value = tooltip.lootStored(near, tooltipFont)
  end
  local confirmed = tooltip.confirm(reconciler, value)
  if confirmed and confirmed ~= run.loot then
    M.append(string.format("reconciled: counter %d, bag says %d (%+d)", run.loot, confirmed, confirmed - run.loot))
    runstate.setLoot(run, confirmed, run.section)
    saveRun()
  end
end

local logUnknownBitmaps = function(glyphs, images)
  for _, image in ipairs(images) do
    if image.bitmap then
      M.append(string.format("bitmap %s %dx%d: %s", image.hash, image.w, image.h, image.bitmap))
    end
  end
  for _, g in ipairs(glyphs) do
    if g.bitmap then
      M.append(string.format("bitmap %s %dx%d: %s", g.pixels, g.w, g.h, g.bitmap))
    end
  end
end

function M.frame(icons, glyphs, images, knownIcons, inRun)
  lastIcons = knownIcons
  bagIcon = nil
  for _, icon in ipairs(icons) do
    if icon.signature == bagSignature then bagIcon = icon end
  end
  bagHovered = mouseOverBag()
  if inRun and not wasInRun then quietUntil = math.max(quietUntil, bolt.time() + QUIET_MICROSECONDS) end
  wasInRun = inRun
  if not inRun then return end
  logUnknownBitmaps(glyphs, images)
  count(images, bolt.time())
  reconcile(glyphs)
end

function M.draw()
  lootOverlay.draw(bolt, bagIcon, run.loot)
end

return M
