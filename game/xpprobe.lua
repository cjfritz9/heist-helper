local imageprobe = require("game.imageprobe")

local M = {}

local probe = nil

function M.init(boltApi, tickAfter)
  probe = imageprobe.new(boltApi, "xpprobe.log", 150, 20 * 1000 * 1000, tickAfter)
end

function M.start(x, y, now)
  imageprobe.start(probe, x, y, now, string.format("around %d,%d", x, y))
end

function M.active()
  return imageprobe.active(probe)
end

function M.status(now)
  return imageprobe.status(probe, now)
end

function M.inspect2d(event)
  imageprobe.inspect2d(probe, event)
end

function M.endFrame(now)
  imageprobe.endFrame(probe, now)
end

return M
