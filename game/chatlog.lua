local M = {}

local BUBBLE_SIZE = 11
local BUBBLE_ROW = 5
local BUBBLE_ROW_PIXELS =
  "\x00\x00\x01\xff\xc4\xd0\xcd\xff\xc4\xd0\xcd\xff\xd9\xe0\xde\xff" ..
  "\xc4\xd0\xcd\xff\xc4\xd0\xcd\xff\xc4\xd0\xcd\xff\xc4\xd0\xcd\xff" ..
  "\x9f\xd9\xce\xff\x9f\xd9\xce\xff\x00\x00\x01\xff"
local RECHECK_MICROSECONDS = 500 * 1000

function M.new(chatModule)
  return { chat = chatModule, mostRecent = nil, nextCheck = 0, scrolled = false, primed = false }
end

function M.findBubble(event)
  local perImage = event:verticesperimage()
  for i = 1, event:vertexcount(), perImage do
    local ax, ay, aw, ah = event:vertexatlasdetails(i)
    if aw == BUBBLE_SIZE and ah == BUBBLE_SIZE
      and event:texturecompare(ax, ay + BUBBLE_ROW, BUBBLE_ROW_PIXELS) then
      return i + perImage
    end
  end
  return nil
end

function M.read(reader, now, event, onMessage)
  if now < reader.nextCheck then return end
  local start = M.findBubble(event)
  if not start then return end
  local isChat, isScrolled = reader.chat:tryreadchat(event, start, reader.mostRecent, function(message)
    reader.mostRecent = message
    if reader.primed then
      onMessage(message)
    end
  end)
  if isChat then
    reader.primed = true
    reader.scrolled = isScrolled and true or false
    reader.nextCheck = now + RECHECK_MICROSECONDS
  end
end

return M
