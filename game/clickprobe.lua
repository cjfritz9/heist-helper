local imageprobe = require("game.imageprobe")

local M = {}

local probe = nil
local mouse = { x = 0, y = 0 }

function M.init(boltApi, tickAfter)
  probe = imageprobe.new(boltApi, "clickprobe.log", 200, 15 * 1000 * 1000, tickAfter)
end

function M.toggle(now)
  if imageprobe.active(probe) then
    imageprobe.stop(probe)
  else
    imageprobe.start(probe, mouse.x, mouse.y, now, "following the mouse")
  end
end

function M.active()
  return imageprobe.active(probe)
end

function M.status(now)
  return imageprobe.status(probe, now)
end

function M.mouseAt(x, y)
  mouse = { x = x, y = y }
  imageprobe.moveTo(probe, x, y)
end

function M.clicked(button, x, y)
  if not imageprobe.active(probe) then return end
  imageprobe.append(probe, string.format("%s click at %d,%d", button == 1 and "left" or (button == 2 and "right" or "middle"), x, y))
end

function M.inspect2d(event)
  imageprobe.inspect2d(probe, event)
end

function M.endFrame(now)
  imageprobe.endFrame(probe, now)
end

return M
