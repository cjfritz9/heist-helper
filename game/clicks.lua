local clicktarget = require("core.clicktarget")
local known = require("data.clicktargets")

local M = {}

local CLICK_NEAR_PIXELS = 40

local state = clicktarget.new(known)
local onInteract = function() end

function M.init(handler)
  onInteract = handler or onInteract
end

function M.mouseAt(x, y)
  state.mouse = { x = x, y = y }
end

function M.click(x, y, now)
  clicktarget.click(state, x, y, now)
end

function M.wants(x, y, colour)
  if colour == "00ffff" and state.mouse then return true end
  for _, c in ipairs(state.clicks) do
    if math.abs(x - c.x) <= CLICK_NEAR_PIXELS and math.abs(y - c.y) <= CLICK_NEAR_PIXELS then return true end
  end
  return false
end

function M.frame(glyphs, now)
  for _, g in ipairs(glyphs) do
    if g.pixels then
      clicktarget.glyph(state, g.pixels, g.x, g.y, g.colour)
      local result = #state.clicks > 0 and clicktarget.image(state, g.pixels, g.x, g.y, now)
      if result then onInteract(result) end
    end
  end
  clicktarget.endFrame(state, now)
end

return M
