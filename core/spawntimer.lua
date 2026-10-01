local M = {}

M.TICKS = 12
M.PERIOD = 600 * 1000

function M.remaining(appearedTick, now)
  if not appearedTick then return nil end
  local left = M.TICKS - math.floor((now - appearedTick) / M.PERIOD)
  if left <= 0 or left > M.TICKS then return nil end
  return left
end

M.GAP_PIXELS = 1
M.PAD_PIXELS = 2

local quad = function(x0, y0, x1, y1, colour)
  return { x0, y0, x1, y0, x1, y1, x0, y1, colour = colour }
end

function M.bar(left, centreX, bottomY, width, height, colours)
  local x0, y0 = centreX - width / 2, bottomY - height
  local out = { quad(x0 - M.PAD_PIXELS, y0 - M.PAD_PIXELS, x0 + width + M.PAD_PIXELS, bottomY + M.PAD_PIXELS, colours.back) }
  local cell = (width - (M.TICKS - 1) * M.GAP_PIXELS) / M.TICKS
  for i = 1, M.TICKS do
    local cx = x0 + (i - 1) * (cell + M.GAP_PIXELS)
    out[#out + 1] = quad(cx, y0, cx + cell, bottomY, i <= left and colours.full or colours.empty)
  end
  return out
end

return M
