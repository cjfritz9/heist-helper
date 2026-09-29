local rollinglog = require("core.rollinglog")
local assert = require("tests.assert")

local T = {}

function T.keeps_the_most_recent_lines()
  local log = rollinglog.new("a\nb\nc\n", 3)
  rollinglog.append(log, "d")
  rollinglog.append(log, "e")
  assert.eq(rollinglog.text(log), "c\nd\ne\n", "last three")
end

function T.loading_a_long_file_trims_it()
  local log = rollinglog.new("1\n2\n3\n4\n5\n", 2)
  assert.eq(rollinglog.text(log), "4\n5\n", "trimmed on load")
end

function T.empty()
  assert.eq(rollinglog.text(rollinglog.new(nil, 5)), "", "nothing")
end

return T
