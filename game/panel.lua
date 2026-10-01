local json = require("core.json")
local rollinglog = require("core.rollinglog")

local M = {}

local LAYOUT_FILE = "panel.csv"
local WIDTH = 260
local HEIGHT = 155
local SETTINGS_HEIGHT = 304
local DEV_HEIGHT = 720
local TAB_SIZE = 40
local SEND_MICROSECONDS = 250 * 1000
local READY_TIMEOUT_MICROSECONDS = 4 * 1000 * 1000
local PAINT_TIMEOUT_MICROSECONDS = 3 * 1000 * 1000
local FIRST_RECREATE_MICROSECONDS = 1500 * 1000
local MAX_REOPENS = 3
local LOG_FILE = "panel.log"
local LOG_LINES = 300

local bolt = nil
local handlers = {}
local layout = { x = 40, y = 120, expanded = true, dev = false, settings = false, devTools = false }
local panel, tab = nil, nil
local visible = false
local lastSent, nextSend = nil, 0
local captureWanted = false
local ready, openedAt, reopens = false, 0, 0
local readyAt, painted = nil, false
local firstPanelRecreated = false
local log = nil

local note = function(text)
  if not log then return end
  rollinglog.append(log, string.format("[%9.3f] %s", bolt.time() / 1e6, text))
  bolt.saveconfig(LOG_FILE, rollinglog.text(log))
end

local saveLayout = function()
  bolt.saveconfig(LAYOUT_FILE, string.format("%d,%d,%d,%d,%d,%d",
    layout.x, layout.y, layout.expanded and 1 or 0, layout.dev and 1 or 0, layout.settings and 1 or 0,
    layout.devTools and 1 or 0))
end

local loadLayout = function(text)
  local x, y, expanded, dev, settings, devTools = (text or ""):match("^(%-?%d+),(%-?%d+),([01]),([01]),?([01]?),?([01]?)")
  if x then
    layout = { x = tonumber(x), y = tonumber(y), expanded = expanded == "1", dev = dev == "1", settings = settings == "1" }
    layout.devTools = devTools == "1" or (devTools == "" and layout.dev)
  end
end

local closeAll = function()
  if panel then panel:close() end
  if tab then tab:close() end
  panel, tab = nil, nil
end

local open

local rememberPosition = function(event)
  local x, y = event:xywh()
  layout.x, layout.y = x, y
  saveLayout()
end

local setLayout = function(change)
  change()
  saveLayout()
  open()
end

function M.dispatch(message)
  if message == "ready" then
    ready, readyAt = true, bolt.time()
    lastSent, nextSend = nil, 0
    note(string.format("page ready %d ms after opening", (readyAt - openedAt) / 1000))
  elseif message == "painted" then
    painted = true
    note(string.format("page drew a frame %d ms after opening", (bolt.time() - openedAt) / 1000))
  elseif message == "collapse" then
    setLayout(function() layout.expanded = false end)
  elseif message == "expand" then
    setLayout(function() layout.expanded = true end)
  elseif message == "dev" then
    setLayout(function() layout.dev = not layout.dev end)
  elseif message == "settings" then
    setLayout(function() layout.settings = not layout.settings end)
  elseif message == "devtools" then
    setLayout(function()
      layout.devTools = not layout.devTools
      layout.dev = layout.dev and layout.devTools
    end)
  else
    local command, argument = message:match("^(%a+):?(.*)$")
    local handler = command and handlers[command]
    if handler then
      handler(argument)
    end
  end
end

open = function(why)
  closeAll()
  lastSent = nil
  ready, openedAt, readyAt, painted = false, bolt.time(), nil, false
  note(string.format("opening the %s at %d,%d%s", layout.expanded and "panel" or "tab", layout.x, layout.y,
    why and (": " .. why) or ""))
  if layout.expanded then
    local height = (layout.dev and DEV_HEIGHT) or (layout.settings and SETTINGS_HEIGHT) or HEIGHT
    panel = bolt.createembeddedbrowser(layout.x, layout.y, WIDTH, height, "plugin://ui/panel.html")
    panel:onmessage(M.dispatch)
    panel:onreposition(rememberPosition)
    panel:oncloserequest(function() M.dispatch("collapse") end)
    captureWanted = false
  else
    tab = bolt.createembeddedbrowser(layout.x, layout.y, TAB_SIZE, TAB_SIZE, "plugin://ui/tab.html")
    tab:onmessage(M.dispatch)
    tab:onreposition(rememberPosition)
  end
end

function M.init(boltApi, commandHandlers)
  bolt = boltApi
  handlers = commandHandlers
  loadLayout(bolt.loadconfig(LAYOUT_FILE))
  log = rollinglog.new(bolt.loadconfig(LOG_FILE), LOG_LINES)
  note("plugin loaded")
end

function M.setVisible(show, where)
  if show == visible then return end
  visible = show
  if show then
    reopens = 0
    open("shown, " .. (where or "position unknown"))
  else
    note("hidden, " .. (where or "position unknown"))
    closeAll()
  end
end

function M.capture(enable)
  if enable == captureWanted then return panel ~= nil end
  captureWanted = enable
  if not panel then return false end
  if enable then
    panel:enablecapture()
  else
    panel:disablecapture()
  end
  return true
end

function M.devEnabled()
  return layout.dev
end

function M.update(now, status)
  if not panel then return end
  if not ready then
    if now - openedAt > READY_TIMEOUT_MICROSECONDS and reopens < MAX_REOPENS then
      reopens = reopens + 1
      open("the page never reported ready")
    end
    return
  end
  if not firstPanelRecreated and now - readyAt > FIRST_RECREATE_MICROSECONDS then
    firstPanelRecreated = true
    open("first panel since the plugin loaded, recreated once in case it came up blank")
    return
  end
  if not painted and now - readyAt > PAINT_TIMEOUT_MICROSECONDS and reopens < MAX_REOPENS then
    reopens = reopens + 1
    open("the page was ready but never drew a frame")
    return
  end
  if now < nextSend then return end
  nextSend = now + SEND_MICROSECONDS
  status.dev = layout.dev
  status.settings = layout.settings
  status.devTools = layout.devTools
  local text = json.encode(status)
  if text ~= lastSent then
    panel:sendmessage(text)
    lastSent = text
  end
end

return M
