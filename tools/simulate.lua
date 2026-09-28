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
    b.onmessage = function(self, f) self.message = f end
    b.onreposition = function(self, f) self.reposition = f end
    b.oncloserequest = function() end
    b.sendmessage = function(self, text) self.sent[#self.sent + 1] = text end
    b.close = function(self) self.closed = true end
    handlers.browser = b
    return b
  end,
  onrenderbillboard = function(f) handlers.billboard = f end,
}
package.loaded.bolt = bolt

local modelEvent = function(vertices, fingerprintSeed, tileX, tileZ, animated)
  local translate = function(p)
    local x, y, z = p:get()
    return point(x + tileX * 512, y, z + tileZ * 512)
  end
  return {
    vertexcount = function() return vertices end,
    modelmatrix = function() return translate end,
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
  texturecompare = function(_, _, _, data) return data == ROW end,
}
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
print("anchor before toggle:", table.concat(lastHighlighted, " "))
panelBrowser.message("anchor")
handlers.r3d(modelEvent(4506, 9, anchorX, anchorZ, false))
handlers.swap()
print("anchor after toggle:", "[" .. table.concat(lastHighlighted, " ") .. "]")
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
panelBrowser.message("anchor")
print("anchor unpowered again:", not runFile():find("powered"))
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
handlers.r3d(modelEvent(4506, 9, anchorX, anchorZ, false))
handlers.r3d(modelEvent(950, 12, objX, objZ, false))
handlers.swap()
print("object in after state, highlighted:", "[" .. table.concat(lastHighlighted, " ") .. "]")
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
playerPos = { (dialX + 1) * 512, 2949, dialZ * 512 }
handlers.swap()
handlers.r3d(modelEvent(684, 13, dialX, dialZ, false))
handlers.swap()
print("back at first dial, highlighted:", "[" .. table.concat(lastHighlighted, " ") .. "]")

playerPos = { (objX + 1) * 512, 2181, objZ * 512 }
tagModel(777, 31, objX, objZ)
handlers.r3d(modelEvent(777, 31, objX, objZ, false))
handlers.swap()
print("selected outline shown:", table.concat(lastHighlighted, " "))
handlers.swap()
print("selected, model out of view:", "[" .. table.concat(lastHighlighted, " ") .. "]")

local crystalX, crystalZ = anchorX - 11, anchorZ - 1
local anchor6X, anchor6Z = anchorX, anchorZ
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
local sent = panelBrowser.sent[#panelBrowser.sent]
print("watch items:", sent:match('"items":(%b[])'))
panelBrowser.message("watch:use:1")
print("using a - entry leaves the link unsaved:", files["links.csv"]:find("2004") == nil)
panelBrowser.message("watch:use:2")
panelBrowser.message("link:save")
panelBrowser.message("watch:close")
print("saved link:", files["links.csv"]:match("[^\n]*2004[^\n]*"))
playerPos = { (anchor6X + 1) * 512, 2181, anchor6Z * 512 }
frameWith(false)
panelBrowser.message("anchor")
playerPos = { (crystalX + 2) * 512, 2181, crystalZ * 512 }
frameWith(false)
print("crystal steady, anchor outlined:", table.concat(lastHighlighted, " "))
frameWith(true)
frameWith(false)
print("after flicker, anchor outlined:", "[" .. table.concat(lastHighlighted, " ") .. "]")

panelBrowser.message("watch:here")
panelBrowser.message("watch:radius:+")
panelBrowser.message("watch:radius:+")
handlers.swap()
local w = require("game.watch").area()
print("watch here, radius:", w and w.radius, w and (w.tileX .. "," .. w.tileZ))
panelBrowser.message("watch:clear")
print("cleared:", require("game.watch").area() == nil)
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
