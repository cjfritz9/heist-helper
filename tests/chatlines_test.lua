local chatlines = require("core.chatlines")
local assert = require("tests.assert")

local T = {}

function T.splits_timestamp_from_text()
  local time, text = chatlines.split("[22:57:46]YoulootafigurineofHet.")
  assert.eq(time, "22:57:46", "time")
  assert.eq(text, "YoulootafigurineofHet.", "text")
end

function T.message_without_timestamp_is_all_text()
  local time, text = chatlines.split("Looted.")
  assert.eq(time, nil, "no time")
  assert.eq(text, "Looted.", "text")
end

return T
