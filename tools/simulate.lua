-- Runs main.lua against a fake Bolt and prints what the plugin outlines and saves.
-- Scenario script used during development; run from the plugin folder: luajit tools/simulate.lua

package.path = "./?.lua;" .. package.path
local picking = require("core.picking")

local files, handlers = {}, {}
local playerPos = { 11875 * 512 + 256, 4933, 4203 * 512 + 256 }
local drawnLines = 0

local point
point = function(x, y, z)
  return {
    get = function() return x, y, z end,
    transform = function(self, m) return m(self) end,
    togameview = function() return 100 + x % 7, 200 + z % 5, 0.5 end,
    toscreen = function() return 100, 200, 0.5 end,
  }
end
local surface = function()
  return { clear = function() end, drawtoscreen = function() end, setalpha = function() end }
end

local silentPages = false

local bolt = {
  checkversion = function() end,
  time = function() return os.clock() * 1e6 end,
  createsurface = surface,
  createsurfacefromrgba = surface,
  loadconfig = function(name) return files[name] end,
  saveconfig = function(name, text) files[name] = text end,
  playerposition = function() return point(playerPos[1], playerPos[2], playerPos[3]) end,
  point = point,
  gameviewxywh = function() return 0, 0, 1920, 1080 end,
  createvertexshader = function() return {} end,
  createfragmentshader = function() return {} end,
  createshaderprogram = function()
    return { setattribute = function() end, setuniform2f = function() end, setuniform1f = function() end,
      drawtosurface = function(_, _, _, n) drawnLines = drawnLines + n end }
  end,
  createbuffer = function() return { setfloat32 = function() end } end,
  createshaderbuffer = function() return {} end,
  onmousebutton = function(f) handlers.mouse = f end,
  onrender3d = function(f) handlers.r3d = f end,
  onrender2d = function(f) handlers.r2d = f end,
  onswapbuffers = function(f) handlers.swap = f end,
  onrenderparticles = function(f) handlers.particles = f end,
  createembeddedbrowser = function(x, y, w, h, url)
    local b = { url = url, sent = {} }
    b.onmessage = function(self, f)
      self.message = f
      if url == "plugin://ui/panel.html" and not silentPages then f("ready") end
    end
    b.onreposition = function(self, f) self.reposition = f end
    b.oncloserequest = function() end
    b.sendmessage = function(self, text) self.sent[#self.sent + 1] = text end
    b.close = function(self) self.closed = true end
    b.enablecapture = function(self) self.capturing = true end
    b.disablecapture = function(self) self.capturing = false end
    handlers.browsers = handlers.browsers or {}
    handlers.browsers[url] = b
    if url ~= "plugin://ui/capture.html" then handlers.browser = b end
    return b
  end,
  onrenderbillboard = function(f) handlers.billboard = f end,
  onrendericon = function(f) handlers.icon = f end,
  onmousemotion = function(f) handlers.motion = f end,
}
package.loaded.bolt = bolt

local modelEvent = function(vertices, fingerprintSeed, tileX, tileZ, animated)
  local translate = function(p)
    local x, y, z = p:get()
    return point(x + tileX * 512, y, z + tileZ * 512)
  end
  return {
    vertexcount = function() return vertices end,
    modelmatrix = function()
      return setmetatable({
        get = function() return 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, tileX * 512, 0, tileZ * 512, 1 end,
      }, { __call = function(_, p) return translate(p) end })
    end,
    vertexanimation = function()
      return { get = function() return 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 end }
    end,
    viewprojmatrix = function() return function(p) return p end end,
    vertexpoint = function(_, i) return point(i, fingerprintSeed, i * 2) end,
    animated = function() return animated end,
    vertexcolour = function() return 1, 1, 1, 1 end,
    vertexuv = function() return 0.5, 0.5 end,
    scale = function() return 1 end,
    vertexmeta = function() return 1 end,
    atlasxywh = function() return 0, 0, 16, 16 end,
    texturedata = function(_, _, _, n) return string.rep(string.char(fingerprintSeed % 256), n) end,
    vertexpointscaled = function(_, i) return point(i, fingerprintSeed, i * 2) end,
    textureid = function() return 73 end,
  }
end

local fpFor = function(seed)
  local shape = {}
  for i = 1, 16 do shape[i] = { i, seed, i * 2 } end
  return picking.fingerprint(shape)
end

local chatQueue = {}
package.loaded["modules.chat.chat"] = {
  tryreadchat = function(_, _, _, _, callback)
    for _, m in ipairs(chatQueue) do callback(m) end
    chatQueue = {}
    return true, false
  end,
}
local ROW = "\x00\x00\x01\xff\xc4\xd0\xcd\xff\xc4\xd0\xcd\xff\xd9\xe0\xde\xff\xc4\xd0\xcd\xff\xc4\xd0\xcd\xff\xc4\xd0\xcd\xff\xc4\xd0\xcd\xff\x9f\xd9\xce\xff\x9f\xd9\xce\xff\x00\x00\x01\xff"
local chatEvent = {
  verticesperimage = function() return 6 end,
  vertexcount = function() return 6 end,
  vertexatlasdetails = function() return 0, 0, 11, 11 end,
  vertexscaledxy = function() return 0, 0 end,
  vertexcolour = function() return 1, 1, 1, 1 end,
  texturedata = function(_, _, _, n) return string.rep("a", n) end,
  texturecompare = function(_, _, _, data) return data == ROW end,
}
local iconEvent = function(vertices, x, y)
  return {
    xywh = function() return x, y, 32, 32 end,
    modelcount = function() return 1 end,
    modelvertexcount = function() return vertices end,
    modelvertexpoint = function(_, _, i) return point(i, vertices, 0) end,
  }
end
local stackEvent = function(x, y, atlasXs)
  return {
    verticesperimage = function() return 6 end,
    vertexcount = function() return 6 * #atlasXs end,
    vertexatlasdetails = function(_, i) return atlasXs[math.floor((i - 1) / 6) + 1], 900, 7, 10 end,
    vertexscaledxy = function(_, i) local n = math.floor((i - 1) / 6); return x + 2 + n * 7 + (i % 2) * 6, y + 2 + (i % 3) * 4 end,
    texturecompare = function() return false end,
    vertexcolour = function() return 1, 1, 0, 1 end,
    texturedata = function(_, x, _, n) return string.rep(string.char(x % 256), n) end,
  }
end
local showInventory = function(batteryDigits, coinDigits)
  handlers.icon(iconEvent(120, 1700, 800))
  handlers.r2d(stackEvent(1700, 800, batteryDigits))
  handlers.icon(iconEvent(80, 1740, 800))
  handlers.r2d(stackEvent(1740, 800, coinDigits))
end
local objectDraw = require("gfx.objects")
local realDraw = objectDraw.draw
lastHighlighted = {}
objectDraw.draw = function(b, objects)
  lastHighlighted = {}
  for _, o in ipairs(objects) do
    lastHighlighted[#lastHighlighted + 1] = o.kind .. (o.progress and ("(" .. o.progress.done .. "/" .. o.progress.total .. ")") or "")
  end
  return realDraw(b, objects)
end
dofile("main.lua")
local catalog = require("core.catalog")
catalog.MODELS[1].fingerprint = fpFor(1)
catalog.MODELS[6].fingerprint = fpFor(6)
catalog.MODELS[2].fingerprint = fpFor(2)
package.loaded["core.catalog"] = nil

handlers.swap()
print("anchor after arrival:", files["run.csv"])

handlers.r3d(modelEvent(3444, 1, 11875 + 11, 4203 - 4, false))
handlers.r3d(modelEvent(26187, 6, 11875 + 8, 4203 + 4, false))
playerPos = { (11875 + 8) * 512, 4933, (4203 + 5) * 512 }
handlers.swap()
print("highlighted:", table.concat(lastHighlighted, " "))
print("objects.csv:", files["objects.csv"])

handlers.r2d(chatEvent)
local clock = 0
bolt.time = function() clock = clock + 1e6; return clock end
chatQueue = { "[23:18:30]You'vetakeneverythingyoucanfromthattarget." }
handlers.r2d(chatEvent)
print("run.csv after corpse chat:", files["run.csv"])

drawnLines = 0
handlers.r3d(modelEvent(3444, 1, 11875 + 11, 4203 - 4, false))
handlers.r3d(modelEvent(26187, 6, 11875 + 8, 4203 + 4, false))
handlers.swap()
print("highlighted with corpse looted:", table.concat(lastHighlighted, " "))
handlers.r3d(modelEvent(3264, 2, 11875 + 11, 4203 - 4, false))
handlers.swap()
print("highlighted after chest opened:", "[" .. table.concat(lastHighlighted, " ") .. "]")

chatQueue = { "[23:20:00]CompletionTime:19:25.2" }
handlers.r2d(chatEvent)
print("run.csv after completion:", files["run.csv"])
print("chat.log:", files["chat.log"])

local frameWithCorpse = function()
  handlers.r3d(modelEvent(26187, 6, 11875 + 8, 4203 + 4, false))
  handlers.swap()
end
frameWithCorpse()
print("new run, corpse:", table.concat(lastHighlighted, " "))
local tagCorpse = function()
  handlers.browser.message("tag")
  handlers.mouse({ button = function() return 3 end, ctrl = function() return false end,
    shift = function() return false end, alt = function() return false end, xy = function() return 100, 200 end })
  handlers.swap()
  handlers.r3d(modelEvent(26187, 6, 11875 + 8, 4203 + 4, false))
  handlers.swap()
end
handlers.browser.message("crevice:1")
print("crevice without a tag, crevices.csv:", files["crevices.csv"])
tagCorpse()
handlers.browser.message("crevice:1")
print("crevices.csv:", files["crevices.csv"])
handlers.browser.message("level:agility")
frameWithCorpse()
print("agility off, corpse behind crevice:", "[" .. table.concat(lastHighlighted, " ") .. "]")
print("levels.csv:", (files["levels.csv"] or ""):gsub("\n", " "))
handlers.browser.message("level:agility")
handlers.browser.message("crevice:1")
frameWithCorpse()
print("agility on, crevice cleared:", table.concat(lastHighlighted, " "))
handlers.browser.message("settings")
print("settings open:", files["panel.csv"])
handlers.browser.message("settings")
for i = 1, 4 do
  chatQueue = { "[23:30:0" .. i .. "]Youlootacopperquadranscoin." }
  handlers.r2d(chatEvent)
end
frameWithCorpse()
print("after 4 loots:", table.concat(lastHighlighted, " "))
print("run.csv:", files["run.csv"])
chatQueue = { "[23:30:09]Youlootsomeancientlint." }
handlers.r2d(chatEvent)
frameWithCorpse()
print("after 5 loots:", "[" .. table.concat(lastHighlighted, " ") .. "]")

for _, m in ipairs(catalog.MODELS) do
  if m.kind == "shadowAnchor" then m.fingerprint = fpFor(9) end
end
local anchorX, anchorZ = 11875 - 8, 4203 - 63
playerPos = { (anchorX + 1) * 512, 2181, anchorZ * 512 }
local particleEvent = {
  vertexcount = function() return 6 end,
  vertexparticleorigin = function() return point((anchorX + 1) * 512, 2200, anchorZ * 512) end,
  vertexmeta = function() return 1 end,
  atlasxywh = function() return 0, 0, 64, 64 end,
}
local frame = function(powered)
  handlers.r3d(modelEvent(4506, 9, anchorX, anchorZ, false))
  if powered then handlers.particles(particleEvent) end
  handlers.swap()
end
for _ = 1, 3 do frame(false) end
local t0 = clock
for _ = 1, 3 do frame(false) end
for _ = 1, 3 do frame(true) end

print("panel url:", handlers.browser.url)
handlers.browser.message("dev")
print("panel reopened with dev:", handlers.browser.url, files["panel.csv"])
local panelBrowser = handlers.browser
panelBrowser.message("tag")
playerPos = { (11875 + 30) * 512, 261, (4203 - 30) * 512 }
handlers.mouse({ button = function() return 3 end, ctrl = function() return false end,
  shift = function() return false end, alt = function() return false end, xy = function() return 100, 200 end })
handlers.swap()
handlers.r3d(modelEvent(15555, 7, 11875 + 30, 4203 - 31, false))
handlers.swap()
print("tag rows:", select(2, (files["tags.csv"] or ""):gsub("\n", "")) - 1)
panelBrowser.message("add:corpse:1")
print("catalog.csv:", files["catalog.csv"])
handlers.r3d(modelEvent(15555, 7, 11875 + 30, 4203 - 31, false))
handlers.swap()
print("new corpse now highlighted:", table.concat(lastHighlighted, " "))
playerPos = { (anchorX + 1) * 512, 2181, anchorZ * 512 }
handlers.r3d(modelEvent(4506, 9, anchorX, anchorZ, false))
handlers.swap()
print("objects.csv heights:", files["objects.csv"])
print("last status:", panelBrowser.sent[#panelBrowser.sent])

local runFile = function() return files["run.csv"] or "" end
local tagModel = function(vertices, seed, x, z)
  panelBrowser.message("tag")
  handlers.mouse({ button = function() return 3 end, ctrl = function() return false end,
    shift = function() return false end, alt = function() return false end, xy = function() return 100, 200 end })
  handlers.swap()
  handlers.r3d(modelEvent(vertices, seed, x, z, false))
  handlers.swap()
end
runstate = require("core.runstate")
files["run.csv"] = nil
local objX, objZ = anchorX + 5, anchorZ + 3
playerPos = { (anchorX + 1) * 512, 2181, anchorZ * 512 }
panelBrowser.message("link:start")
tagModel(4506, 9, anchorX, anchorZ)
panelBrowser.message("link:anchor:1")
tagModel(900, 11, objX, objZ)
panelBrowser.message("link:before:1")
tagModel(950, 12, objX, objZ)
panelBrowser.message("link:after:1")
local status = panelBrowser.sent[#panelBrowser.sent]
print("wizard review:", status:match('"link":(%b{})'))
panelBrowser.message("link:save")
print("links.csv:", files["links.csv"])
handlers.r3d(modelEvent(4506, 9, anchorX, anchorZ, false))
handlers.r3d(modelEvent(900, 11, objX, objZ, false))
handlers.swap()
print("object in before state, highlighted:", table.concat(lastHighlighted, " "))
showInventory({ 10, 30 }, { 50 })
handlers.swap()
showInventory({ 20, 30 }, { 50 })
handlers.r3d(modelEvent(4506, 9, anchorX, anchorZ, false))
handlers.r3d(modelEvent(950, 12, objX, objZ, false))
handlers.swap()
print("object in after state, highlighted:", "[" .. table.concat(lastHighlighted, " ") .. "]")
print("battery.csv:", files["battery.csv"])
print("run.csv:", runFile())

tagModel(3444, 21, objX, objZ)
panelBrowser.message("compare:before:1")
tagModel(3444, 21, objX, objZ)
panelBrowser.message("compare:after:1")
handlers.swap()
print("same object verdict:", panelBrowser.sent[#panelBrowser.sent]:match('"verdict":"([^"]*)"'))
tagModel(3264, 22, objX, objZ)
panelBrowser.message("compare:after:1")
handlers.swap()
print("changed object verdict:", panelBrowser.sent[#panelBrowser.sent]:match('"verdict":"([^"]*)"'))

for _, m in ipairs(catalog.MODELS) do
  if m.kind == "shadowDial" then m.fingerprint = fpFor(13) end
end
bolt.time = function() clock = clock + 1000; return clock end
local dialX, dialZ = 11875 - 3, 4203 - 33
local partnerX, partnerZ = dialX - 25, dialZ + 27
playerPos = { (dialX + 1) * 512, 2949, dialZ * 512 }
handlers.r3d(modelEvent(684, 13, dialX, dialZ, false))
handlers.swap()
print("at dial, highlighted:", table.concat(lastHighlighted, " "))
playerPos = { (partnerX + 1) * 512, 261, partnerZ * 512 }
handlers.swap()
handlers.r3d(modelEvent(684, 13, partnerX, partnerZ, false))
handlers.swap()
print("after teleport, partner highlighted:", "[" .. table.concat(lastHighlighted, " ") .. "]")
print("section after the dial:", (files["run.csv"] or ""):match("section,(%d+)"))
playerPos = { (dialX + 1) * 512, 2949, dialZ * 512 }
handlers.swap()
handlers.r3d(modelEvent(684, 13, dialX, dialZ, false))
handlers.swap()
print("back at first dial, highlighted:", "[" .. table.concat(lastHighlighted, " ") .. "]")
print("section after dialling back:", (files["run.csv"] or ""):match("section,(%d+)"))

playerPos = { (objX + 1) * 512, 2181, objZ * 512 }
tagModel(777, 31, objX, objZ)
handlers.r3d(modelEvent(777, 31, objX, objZ, false))
handlers.swap()
print("selected outline shown:", table.concat(lastHighlighted, " "))
handlers.swap()
print("selected, model out of view:", "[" .. table.concat(lastHighlighted, " ") .. "]")

local crystalX, crystalZ = anchorX - 11, anchorZ - 1
local anchor6X, anchor6Z = anchorX - 4, anchorZ
playerPos = { (crystalX + 2) * 512, 2181, crystalZ * 512 }
local frameWith = function(animated)
  handlers.r3d(modelEvent(4506, 9, anchor6X, anchor6Z, false))
  handlers.r3d(modelEvent(2004, 41, crystalX, crystalZ, animated))
  handlers.swap()
end
panelBrowser.message("link:start")
tagModel(4506, 9, anchor6X, anchor6Z)
panelBrowser.message("link:anchor:1")
tagModel(2004, 41, crystalX, crystalZ)
panelBrowser.message("link:before:1")
panelBrowser.message("watch:start:1")
for _ = 1, 400 do frameWith(false) end
panelBrowser.message("watch:arm")
for _ = 1, 3 do frameWith(true) end
for _ = 1, 5 do frameWith(false) end
clock = clock + 0.3e6
frameWith(false)
local sent = panelBrowser.sent[#panelBrowser.sent]
print("watch items:", sent:match('"items":(%b[])'))
panelBrowser.message("watch:use:1")
print("using a - entry leaves the link unsaved:", files["links.csv"]:find("2004") == nil)
panelBrowser.message("watch:use:2")
panelBrowser.message("link:save")
panelBrowser.message("watch:close")
print("saved link:", files["links.csv"]:match("[^\n]*2004[^\n]*"))
playerPos = { (crystalX + 2) * 512, 2181, crystalZ * 512 }
frameWith(false)
print("crystal steady, anchor outlined:", table.concat(lastHighlighted, " "))
frameWith(true)
frameWith(false)
print("after flicker, anchor outlined:", "[" .. table.concat(lastHighlighted, " ") .. "]")

panelBrowser.message("watch:clear")
playerPos = { (crystalX + 2) * 512, 2181, crystalZ * 512 }
tagModel(2004, 41, crystalX, crystalZ)
panelBrowser.message("watch:start:1")
local drawCrystal = function(times)
  for _ = 1, times do handlers.r3d(modelEvent(2004, 41, crystalX, crystalZ, false)) end
  handlers.swap()
end
for _ = 1, 50 do drawCrystal(1) end
panelBrowser.message("watch:arm")
for _ = 1, 3 do drawCrystal(1) end
for _ = 1, 2 do drawCrystal(2) end
for _ = 1, 3 do drawCrystal(1) end
panelBrowser.message("watch:close")
bolt.time = function() clock = clock + 6e6; return clock end
handlers.swap()
bolt.time = function() clock = clock + 1000; return clock end
print("double draw in watch.log:")
for line in (files["watch.log"] or ""):gmatch("[^\n]+") do
  if line:find("~ ") or line:find("detail variants") then print("  " .. line) end
end
panelBrowser.message("watch:here")
panelBrowser.message("watch:radius:+")
panelBrowser.message("watch:radius:+")
handlers.swap()
local w = require("game.watch").area()
print("watch here, radius:", w and w.radius, w and (w.tileX .. "," .. w.tileZ))
panelBrowser.message("watch:maze")
local maze = require("game.watch").area()
print("watch maze:", maze and maze.radius, maze and ((maze.tileX - 11875) .. "," .. (maze.tileZ - 4203)))
panelBrowser.message("capture")
print("capture on:", handlers.browser.capturing)
handlers.browser.message("shot:P6\n2 1\n255\n\255\0\0\0\255\0")
print("capture saved:", files["capture-1.ppm"] and #files["capture-1.ppm"], "capture off:", handlers.browser.capturing == false)
print("capture grid rows:", select(2, (files["capture-1.csv"] or ""):gsub("\n", "")))
panelBrowser.message("watch:clear")
print("cleared:", require("game.watch").area() == nil)
local spareX, spareZ = 11875 + 20, 4203 - 20
playerPos = { (spareX + 1) * 512, 2181, spareZ * 512 }
local spareFrame = function(batteryDigits, coinDigits)
  showInventory(batteryDigits, coinDigits)
  handlers.r3d(modelEvent(4506, 9, spareX, spareZ, false))
  handlers.swap()
end
local middleClick = function(x, y)
  handlers.mouse({ button = function() return 3 end, ctrl = function() return false end,
    shift = function() return false end, alt = function() return false end, xy = function() return x, y end })
end
spareFrame({ 20, 30 }, { 50 })
panelBrowser.message("battery")
middleClick(1745, 810)
print("picked coins by mistake, battery.csv:", files["battery.csv"])
panelBrowser.message("battery")
middleClick(10, 10)
print("missed every icon, battery.csv unchanged:", files["battery.csv"])
panelBrowser.message("battery")
middleClick(1705, 810)
print("picked batteries, battery.csv:", files["battery.csv"])
spareFrame({ 20, 30 }, { 50 })
print("unpowered anchor outlined:", table.concat(lastHighlighted, " "))
spareFrame({ 20, 30 }, { 60 })
print("coins changed, anchor still outlined:", table.concat(lastHighlighted, " "))
handlers.motion({ xy = function() return 1710, 812 end })
spareFrame({ 20, 30, 70 }, { 60 })
spareFrame({ 20, 30 }, { 60 })
print("tooltip over batteries, anchor still outlined:", table.concat(lastHighlighted, " "))
handlers.motion({ xy = function() return 500, 500 end })
bolt.time = function() clock = clock + 2e6; return clock end
spareFrame({ 20, 30 }, { 60 })
bolt.time = function() clock = clock + 1000; return clock end
spareFrame({ 10, 30 }, { 60 })
spareFrame({ 10, 30 }, { 60 })
clock = clock + 2.5e6
spareFrame({ 10, 30 }, { 60 })
print("battery used, anchor outlined:", "[" .. table.concat(lastHighlighted, " ") .. "]")
local lastX, lastZ = spareX, spareZ - 6
playerPos = { (lastX + 1) * 512, 2181, lastZ * 512 }
local lastAnchorFrame = function(withBattery)
  if withBattery then
    handlers.icon(iconEvent(120, 1700, 800))
    handlers.r2d(stackEvent(1700, 800, { 10, 30 }))
  end
  handlers.icon(iconEvent(80, 1740, 800))
  handlers.r2d(stackEvent(1740, 800, { 60 }))
  handlers.r3d(modelEvent(4506, 9, lastX, lastZ, false))
  handlers.swap()
end
lastAnchorFrame(true)
lastAnchorFrame(true)
print("last anchor outlined:", table.concat(lastHighlighted, " "))
lastAnchorFrame(false)
lastAnchorFrame(false)
clock = clock + 2.5e6
lastAnchorFrame(false)
print("last batteries used up, anchor outlined:", "[" .. table.concat(lastHighlighted, " ") .. "]")
local popupFrame = function(digits)
  handlers.icon(iconEvent(120, 1700, 800))
  handlers.r2d(stackEvent(1700, 800, { 30 }))
  handlers.icon(iconEvent(200, 1700, 840))
  handlers.r2d(stackEvent(1700, 840, {}))
  if digits then handlers.r2d(stackEvent(98, 150, digits)) end
  handlers.r3d(modelEvent(4506, 9, spareX, spareZ, false))
  handlers.swap()
end
popupFrame()
popupFrame({ 101, 102 })
popupFrame({ 101, 102 })
popupFrame()
panelBrowser.message("lootbag")
middleClick(1705, 850)
handlers.motion({ xy = function() return 1710, 850 end })
popupFrame()
handlers.r2d(stackEvent(1720, 870, { 201, 202, 203 }))
popupFrame()
handlers.motion({ xy = function() return 500, 500 end })
popupFrame()
bolt.time = function() clock = clock + 3e6; return clock end
handlers.swap()
bolt.time = function() clock = clock + 1000; return clock end
print("lootbag.csv:", files["lootbag.csv"])
local font = require("data.popupfont")
local lootprobe = require("game.lootprobe")
local glyphEvent = function(atlasXs, x, y)
  return {
    verticesperimage = function() return 6 end,
    vertexcount = function() return 6 * #atlasXs end,
    vertexatlasdetails = function(_, i) return atlasXs[math.floor((i - 1) / 6) + 1], 700, 16, 34 end,
    vertexscaledxy = function(_, i) local n = math.floor((i - 1) / 6); return x + n * 16 + (i % 2) * 14, y + (i % 3) * 15 end,
    vertexcolour = function() return 1, 1, 1, 1 end,
    texturedata = function(_, ax, _, n) return string.rep(string.char(ax % 256), n) end,
    texturecompare = function() return false end,
  }
end
local atlasOf = {}
for i, c in ipairs({ "1", "0", "2", "L", "o", "t", "G", "a", "i", "n", "e", "d" }) do
  atlasOf[c] = 600 + i * 3
  font[lootprobe.pixelHash(glyphEvent({}, 0, 0), atlasOf[c], 700, 16, 34)] = c
end
local popupLine = function(text, y)
  local xs = {}
  for i = 1, #text do xs[i] = atlasOf[text:sub(i, i)] or 999 end
  return glyphEvent(xs, 20, y)
end
local lootNow = function() return tonumber(("\n" .. (files["run.csv"] or "")):match("\nloot,(%d+)")) or 0 end
local lootLines = 0
local lootLine = function()
  lootLines = lootLines + 1
  chatQueue = { string.format("[23:45:%02d]Youlootacopperquadranscoin.", lootLines) }
  clock = clock + 0.6e6
  handlers.r2d(chatEvent)
end
local playerTile = function() return math.floor(playerPos[1] / 512), math.floor(playerPos[3] / 512) end
local chestsOpened = 0
local openChest = function()
  local px, pz = playerTile()
  chestsOpened = chestsOpened + 1
  handlers.r3d(modelEvent(3264, 2, px - 2, pz - chestsOpened, false))
end
local lootFrame = function(...)
  local px, pz = playerTile()
  handlers.r3d(modelEvent(26187, 6, px + 1, pz, false))
  for _, e in ipairs({ ... }) do handlers.r2d(e) end
  handlers.swap()
end
local settle = function()
  clock = clock + 1.2e6
  lootFrame()
end
local before = lootNow()
lootFrame(popupLine("LootGained", 150))
openChest()
lootFrame(popupLine("10LootGained", 150))
lootFrame(popupLine("10LootGained", 145))
lootFrame()
lootFrame(popupLine("10LootGained", 140))
settle()
print("chest popup counted once:", lootNow() - before)
lootFrame(popupLine("Gained", 150))
lootLine()
lootFrame(popupLine("2LootGained", 150))
lootLine()
lootFrame(popupLine("2LootGained", 141), popupLine("Gained", 150))
lootFrame(popupLine("2LootGained", 140), popupLine("2LootGained", 150))
lootFrame(popupLine("2LootGained", 135), popupLine("2LootGained", 145))
settle()
print("two rummage popups on top of that:", lootNow() - before)
for i = 1, 8 do lootFrame(popupLine("2LootGained", 130 - i * 20)) end
settle()
settle()
print("popup flying off, not recounted:", lootNow() - before)
chatQueue = { "[23:50:00]Youhavebeencaught...Youlosesomeloot." }
clock = clock + 0.6e6
handlers.r2d(chatEvent)
print("after a catch:", lootNow() - before)
local tipFont = require("data.tooltipfont")
local tipEvent = function(text, x, y)
  local xs = {}
  for i = 1, #text do xs[i] = 800 + text:byte(i) end
  return {
    verticesperimage = function() return 6 end,
    vertexcount = function() return 6 * #xs end,
    vertexatlasdetails = function(_, i) return xs[math.floor((i - 1) / 6) + 1], 900, 8, 10 end,
    vertexscaledxy = function(_, i) local n = math.floor((i - 1) / 6); return x + n * 8 + (i % 2) * 6, y + (i % 3) * 4 end,
    vertexcolour = function() return 227 / 255, 215 / 255, 207 / 255, 1 end,
    texturedata = function(_, ax, _, n) return string.rep(string.char(ax % 256), n) end,
    texturecompare = function() return false end,
  }
end
for c in ("LootStored:0123456789"):gmatch(".") do
  tipFont[lootprobe.pixelHash(tipEvent("", 0, 0), 800 + c:byte(), 900, 8, 10)] = c
end
handlers.motion({ xy = function() return 1710, 850 end })
for _ = 1, 3 do
  handlers.r2d(tipEvent("LootStored:235", 1720, 880))
  popupFrame()
end
handlers.motion({ xy = function() return 500, 500 end })
clock = clock + 2e6
print("bag hovered, counter reconciled to:", lootNow())
local hiddenX, hiddenZ = 11875 - 20, 4203 - 40
local hiddenFrame = function(inventoryShown, digits)
  if inventoryShown then
    handlers.icon(iconEvent(120, 1700, 800))
    handlers.r2d(stackEvent(1700, 800, digits))
    handlers.icon(iconEvent(80, 1740, 800))
    handlers.r2d(stackEvent(1740, 800, { 60 }))
  end
  handlers.r3d(modelEvent(4506, 9, hiddenX, hiddenZ, false))
  handlers.swap()
end
playerPos = { (hiddenX + 1) * 512, 2181, hiddenZ * 512 }
hiddenFrame(true, { 30 })
hiddenFrame(true, { 30 })
hiddenFrame(false)
hiddenFrame(false)
playerPos = { (hiddenX + 12) * 512, 2181, hiddenZ * 512 }
hiddenFrame(false)
print("powered with inventory hidden, still outlined:", table.concat(lastHighlighted, " "))
hiddenFrame(true, { 20 })
hiddenFrame(true, { 20 })
clock = clock + 2.5e6
hiddenFrame(true, { 20 })
print("inventory reopened later, anchor outlined:", "[" .. table.concat(lastHighlighted, " ") .. "]")

local clickX, clickZ = 11875 - 30, 4203 - 50
local clickFrame = function()
  handlers.r3d(modelEvent(4506, 9, clickX, clickZ, false))
  handlers.swap()
end
playerPos = { (clickX + 8) * 512, 2181, clickZ * 512 }
clickFrame()
handlers.mouse({ button = function() return 1 end, xy = function() return 103, 202 end })
playerPos = { (clickX + 1) * 512, 2181, clickZ * 512 }
bolt.time = function() clock = clock + 1e4; return clock end
clickFrame()
clickFrame()
print("clicked, just arrived, still outlined:", table.concat(lastHighlighted, " "))
for _ = 1, 60 do clickFrame() end
print("clicked with no batteries in view, anchor outlined:", "[" .. table.concat(lastHighlighted, " ") .. "]")
local nearX, nearZ = 11875 - 30, 4203 - 70
playerPos = { (nearX + 1) * 512, 2181, (nearZ - 2) * 512 }
local chestFrame = function(opened, digits)
  handlers.icon(iconEvent(120, 1700, 800))
  handlers.r2d(stackEvent(1700, 800, digits))
  handlers.icon(iconEvent(80, 1740, 800))
  handlers.r2d(stackEvent(1740, 800, { 60 }))
  handlers.r3d(modelEvent(4506, 9, nearX, nearZ, false))
  handlers.r3d(modelEvent(opened and 3264 or 3444, opened and 2 or 1, nearX, nearZ - 3, false))
  handlers.swap()
end
chestFrame(false, { 10 })
chestFrame(false, { 10 })
chestFrame(false, { 10, 30 })
chestFrame(true, { 10, 30 })
clock = clock + 2.5e6
chestFrame(true, { 10, 30 })
print("batteries arriving just before the chest opens, anchor outlined:", table.concat(lastHighlighted, " "))
bolt.time = function() clock = clock + 3e6; return clock end
handlers.swap()
bolt.time = function() clock = clock + 1000; return clock end
print("inventory.log tail:\n" .. ((files["inventory.log"] or ""):match("[^\n]*\n[^\n]*\n[^\n]*\n[^\n]*\n[^\n]*\n[^\n]*\n$") or ""))
bolt.time = function() clock = clock + 1000; return clock end
bolt.time = function() clock = clock + 2e6; return clock end
handlers.swap()
bolt.time = function() clock = clock + 1000; return clock end
print("inventory.log:\n" .. (files["inventory.log"] or "<none>"))
local mazeroute = require("game.mazeroute")
for _, m in ipairs(catalog.MODELS) do
  if m.kind == "shadowCrystal" then m.fingerprint = fpFor(51) end
end
local crystalDx, crystalDz = -14, -76
local mazeAt = function(dx, dz, y)
  playerPos = { (11875 + dx) * 512, y or 2176, (4203 + dz) * 512 }
  handlers.r3d(modelEvent(2004, 51, 11875 + crystalDx, 4203 + crystalDz, false))
  handlers.swap()
end
local capturer = function() return handlers.browsers["plugin://ui/capture.html"] end
panelBrowser.message("level:maze")
mazeAt(-24, -70, 1221)
mazeAt(-13, -75)
print("no capture window before a crystal click:", capturer() == nil or capturer().closed == true)
handlers.mouse({ button = function() return 1 end, xy = function() return 103, 202 end })
mazeAt(-13, -75)
print("capture window after the click:", capturer() ~= nil and capturer().closed ~= true)
capturer().message("mazeinfo:ready")
clock = clock + 0.5e6
mazeAt(-13, -75)
print("not capturing during the 1.2 s wait:", capturer().capturing ~= true)
clock = clock + 1e6
mazeAt(-13, -75)
print("first frame of the burst:", capturer().capturing == true)
local lit = "-12,-77;-11,-77;-10,-77;-9,-77;-8,-77;-8,-76;-8,-75;-8,-74;-8,-73;-8,-72;-1,-82;1,-82;1,-83"
local frames = 0
for _ = 1, 6 do
  if capturer() and capturer().capturing then
    frames = frames + 1
    capturer().message("mazelit:" .. lit)
  end
  clock = clock + 0.7e6
  mazeAt(-13, -75)
end
print("frames captured in the burst:", frames, "window closed after:", capturer().closed == true)
mazeAt(-12, -75)
print("maze status on the start row:", require("core.json").encode(mazeroute.status()))
print("clicking the same crystal again keeps it:", mazeroute.trigger(clock, crystalDx, crystalDz) == false and mazeroute.status().known == true)
mazeAt(-11, -76)
print("in-between tile keeps the plan:", require("core.json").encode(mazeroute.status()))
mazeAt(-10, -77)
print("landed on step 1:", require("core.json").encode(mazeroute.status()))
mazeAt(-8, -76)
print("landed on step 2:", require("core.json").encode(mazeroute.status()))
mazeAt(-3, -70)
print("maze status on the end row:", require("core.json").encode(mazeroute.status()))
print("final crystal ignored:", mazeroute.trigger(clock, -6, -95) == false)
clock = clock + 3e6
lootFrame()
for line in (files["loot.log"] or ""):gmatch("[^\n]+") do
  if line:find("maze:") then print("  " .. line:sub(1, 140)) end
end
local a6x, a6z = 11875 + 5, 4203 - 94
local cx, cz = 11875 - 6, 4203 - 95
playerPos = { (a6x + 1) * 512, 2181, a6z * 512 }
local recFrame = function(animated)
  handlers.r3d(modelEvent(4506, 9, a6x, a6z, false))
  handlers.r3d(modelEvent(2004, 41, cx, cz, animated))
  handlers.swap()
end
for _ = 1, 40 do recFrame(false) end
for _ = 1, 40 do recFrame(true) end
for _ = 1, 40 do recFrame(false) end
playerPos = { (a6x + 30) * 512, 2181, a6z * 512 }
handlers.swap()
local rec = files["record.log"] or "<none>"
local lines = {}
for line in rec:gmatch("[^\n]+") do lines[#lines + 1] = line end
print("record.log lines:", #lines)
for i = 1, #lines do
  if lines[i]:find("recording") or lines[i]:find("2004") then print("  " .. lines[i]) end
end
local sectionNow = function() return (files["run.csv"] or ""):match("section,(%d+)") end
playerPos = { (11875 - 10) * 512, 256, (4203 - 43) * 512 }
handlers.swap()
local looted = select(2, (files["run.csv"] or ""):gsub("looted", ""))
playerPos = { 11875 * 512, 4933, 4203 * 512 }
handlers.swap()
print("caught and sent back, looted kept:", select(2, (files["run.csv"] or ""):gsub("looted", "")) == looted and looted > 0,
  "section:", sectionNow())
local standAt = function(dx, dz, y)
  playerPos = { (11875 + dx) * 512, y, (4203 + dz) * 512 }
  handlers.swap()
end
standAt(10, -8, 4933)
panelBrowser.message("checkpoint:legionary1")
standAt(10, -12, 2949)
panelBrowser.message("checkpoint:legionary2")
standAt(0, -50, 2179)
panelBrowser.message("checkpoint:praetorian3")
standAt(0, -53, 2179)
panelBrowser.message("checkpoint:praetorian4")
print("checkpoints.csv:", (files["checkpoints.csv"] or ""):gsub("\n", " "))
standAt(11, -9, 4933)
print("walked back past the legionary barrier:", sectionNow())
standAt(10, -13, 2949)
print("through it again:", sectionNow())
standAt(0, -49, 2179)
print("praetorian, section 3 side:", sectionNow())
standAt(0, -54, 2179)
print("praetorian, section 4 side:", sectionNow())
standAt(11, -9, 4933)
standAt(19, 1, 4933)
chatQueue = { "[23:40:01]Youlootacopperquadranscoin." }
handlers.r3d(modelEvent(26187, 6, 11875 + 19, 4203, false))
handlers.swap()
handlers.r2d(chatEvent)
print("corpse looted in section 1:", (files["objects.csv"] or ""):match("corpse,19,0[^\n]*"))
silentPages = true
panelBrowser.message("settings")
local blank = handlers.browser
for _ = 1, 400 do handlers.swap() end
print("blank panel reopened:", blank.closed == true and handlers.browser ~= blank, "status sent to it:", #blank.sent)
silentPages = false
handlers.browser.message("settings")
handlers.swap()
print("ready panel got status:", #handlers.browser.sent > 0)
playerPos = { 3297 * 512, 2005, 3184 * 512 }
handlers.swap()
print("outside vault, panel closed:", handlers.browser.closed == true)
local before = #lastHighlighted
handlers.r3d(modelEvent(3444, 1, 11875 + 11, 4203 - 4, false))
handlers.swap()
playerPos = { (11875 + 8) * 512, 4933, (4203 + 5) * 512 }
handlers.swap()
print("back inside, panel reopened:", handlers.browser.closed ~= true and handlers.browser.url)
print("probe.log:\n" .. (files["probe.log"] or "<none>"))
print("errors:", files["error.log"])
