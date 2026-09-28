local chatlog = require("game.chatlog")
local assert = require("tests.assert")

local T = {}

local BUBBLE_ROW_PIXELS =
  "\x00\x00\x01\xff\xc4\xd0\xcd\xff\xc4\xd0\xcd\xff\xd9\xe0\xde\xff" ..
  "\xc4\xd0\xcd\xff\xc4\xd0\xcd\xff\xc4\xd0\xcd\xff\xc4\xd0\xcd\xff" ..
  "\x9f\xd9\xce\xff\x9f\xd9\xce\xff\x00\x00\x01\xff"

local fakeEvent = function(images)
  return {
    verticesperimage = function() return 6 end,
    vertexcount = function() return #images * 6 end,
    vertexatlasdetails = function(_, i)
      local img = images[(i - 1) / 6 + 1]
      return img.x, 0, img.w, img.h
    end,
    texturecompare = function(_, x, y, data)
      local img = images[x]
      return y == 5 and img.row == data
    end,
  }
end

local bubble = function(x) return { x = x, w = 11, h = 11, row = BUBBLE_ROW_PIXELS } end
local other = function(x) return { x = x, w = 11, h = 11, row = "nope" } end

local fakeChat = function(messages, isChat, isScrolled)
  local calls = {}
  return {
    calls = calls,
    tryreadchat = function(_, _, start, prev, callback)
      calls[#calls + 1] = { start = start, prev = prev }
      for _, m in ipairs(messages) do callback(m) end
      return isChat, isScrolled
    end,
  }
end

function T.finds_image_after_speech_bubble()
  assert.eq(chatlog.findBubble(fakeEvent({ other(1), bubble(2), other(3) })), 13, "start index")
end

function T.no_bubble_means_no_chat()
  assert.eq(chatlog.findBubble(fakeEvent({ other(1), other(2) })), nil, "no bubble")
end

function T.first_read_skips_backlog_but_remembers_newest()
  local chat = fakeChat({ "[12:00:01] a", "[12:00:02] b" }, true, false)
  local reader = chatlog.new(chat)
  local seen = {}
  chatlog.read(reader, 1000, fakeEvent({ bubble(1) }), function(m) seen[#seen + 1] = m end)
  assert.eq(#seen, 0, "backlog skipped")
  assert.eq(reader.mostRecent, "[12:00:02] b", "most recent")
  assert.eq(chat.calls[1].start, 7, "reads after bubble")
end

function T.later_reads_deliver_new_messages()
  local chat = fakeChat({ "[12:00:03] c" }, true, false)
  local reader = chatlog.new(chat)
  reader.primed = true
  local seen = {}
  chatlog.read(reader, 1000, fakeEvent({ bubble(1) }), function(m) seen[#seen + 1] = m end)
  assert.eq(#seen, 1, "delivered")
  assert.eq(seen[1], "[12:00:03] c", "message")
end

function T.waits_before_rechecking_after_a_read()
  local chat = fakeChat({}, true, false)
  local reader = chatlog.new(chat)
  local event = fakeEvent({ bubble(1) })
  chatlog.read(reader, 1000, event, function() end)
  chatlog.read(reader, 2000, event, function() end)
  assert.eq(#chat.calls, 1, "throttled")
  chatlog.read(reader, 1000 + 500 * 1000, event, function() end)
  assert.eq(#chat.calls, 2, "rechecked")
end

function T.records_when_chat_is_scrolled_up()
  local reader = chatlog.new(fakeChat({}, true, true))
  chatlog.read(reader, 0, fakeEvent({ bubble(1) }), function() end)
  assert.eq(reader.scrolled, true, "scrolled")
end

return T
