local json = require("core.json")
local assert = require("tests.assert")

local T = {}

function T.scalars()
  assert.eq(json.encode(3), "3", "integer")
  assert.eq(json.encode(0.5), "0.5000", "float")
  assert.eq(json.encode(true), "true", "boolean")
  assert.eq(json.encode(nil), "null", "nil")
  assert.eq(json.encode(0 / 0), "null", "nan")
end

function T.strings_are_escaped()
  assert.eq(json.encode('say "hi"\n'), '"say \\"hi\\"\\n"', "quotes and newline")
  assert.eq(json.encode("\1"), '"\\u0001"', "control character")
end

function T.arrays_and_objects()
  assert.eq(json.encode({ 1, 2, 3 }), "[1,2,3]", "array")
  assert.eq(json.encode({}), "[]", "empty")
  assert.eq(json.encode({ b = 1, a = { x = true } }), '{"a":{"x":true},"b":1}', "sorted keys")
end

function T.nil_fields_are_left_out()
  assert.eq(json.encode({ anchored = false, section = nil }), '{"anchored":false}', "no section")
end

return T
