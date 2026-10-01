local lootprobe = require("game.lootprobe")

local M = {}

M.PLUS_HASH = "f39c97d3"
M.PLUS_COLOUR = "f5b241"
M.PLUS_WIDTH, M.PLUS_HEIGHT = 8, 9
local FOLLOW_PIXELS = 24

local hashes = {}
local frame, previous = {}, {}

function M.inspect2d(event)
  local perImage = event:verticesperimage()
  for i = 1, event:vertexcount(), perImage do
    local ax, ay, aw, ah = event:vertexatlasdetails(i)
    if aw == M.PLUS_WIDTH and ah == M.PLUS_HEIGHT then
      local k = ax .. "," .. ay
      if not hashes[k] then hashes[k] = lootprobe.pixelHash(event, ax, ay, aw, ah) end
      if hashes[k] == M.PLUS_HASH then
        local r, g, b = event:vertexcolour(i)
        if lootprobe.colourHex(r, g, b) == M.PLUS_COLOUR then
          local x, y = event:vertexscaledxy(i)
          frame[#frame + 1] = { x = x, y = y }
        end
      end
    end
  end
end

function M.endFrame(now, onDrop)
  local appeared = 0
  for _, plus in ipairs(frame) do
    local followed = false
    for j, p in ipairs(previous) do
      if math.abs(p.x - plus.x) <= FOLLOW_PIXELS and math.abs(p.y - plus.y) <= FOLLOW_PIXELS then
        table.remove(previous, j)
        followed = true
        break
      end
    end
    if not followed then appeared = appeared + 1 end
  end
  previous, frame = frame, {}
  if appeared > 0 and onDrop then onDrop(now) end
end

return M
