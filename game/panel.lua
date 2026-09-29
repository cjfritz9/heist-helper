local json = require("core.json")

local M = {}

local LAYOUT_FILE = "panel.csv"
local WIDTH = 260
local HEIGHT = 137
local SETTINGS_HEIGHT = 224
local DEV_HEIGHT = 720
local TAB_SIZE = 40
local SEND_MICROSECONDS = 250 * 1000

local bolt = nil
local handlers = {}
local layout = { x = 40, y = 120, expanded = true, dev = false, settings = false }
local panel, tab = nil, nil
local visible = false
local lastSent, nextSend = nil, 0
local captureWanted = false

local saveLayout = function()
  bolt.saveconfig(LAYOUT_FILE, string.format("%d,%d,%d,%d,%d",
    layout.x, layout.y, layout.expanded and 1 or 0, layout.dev and 1 or 0, layout.settings and 1 or 0))
end

local loadLayout = function(text)
  local x, y, expanded, dev, settings = (text or ""):match("^(%-?%d+),(%-?%d+),([01]),([01]),?([01]?)")
  if x then
    layout = { x = tonumber(x), y = tonumber(y), expanded = expanded == "1", dev = dev == "1", settings = settings == "1" }
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
  if message == "collapse" then
    setLayout(function() layout.expanded = false end)
  elseif message == "expand" then
    setLayout(function() layout.expanded = true end)
  elseif message == "dev" then
    setLayout(function() layout.dev = not layout.dev end)
  elseif message == "settings" then
    setLayout(function() layout.settings = not layout.settings end)
  else
    local command, argument = message:match("^(%a+):?(.*)$")
    local handler = command and handlers[command]
    if handler then
      handler(argument)
    end
  end
end

open = function()
  closeAll()
  lastSent = nil
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
end

function M.setVisible(show)
  if show == visible then return end
  visible = show
  if show then
    open()
  else
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
  if not panel or now < nextSend then return end
  nextSend = now + SEND_MICROSECONDS
  status.dev = layout.dev
  status.settings = layout.settings
  local text = json.encode(status)
  if text ~= lastSent then
    panel:sendmessage(text)
    lastSent = text
  end
end

return M
