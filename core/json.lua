local M = {}

local ESCAPES = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

local encodeString = function(s)
  local escaped = s:gsub('[%c"\\]', function(c)
    return ESCAPES[c] or string.format("\\u%04x", c:byte())
  end)
  return '"' .. escaped .. '"'
end

local isArray = function(t)
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
  for i = 1, count do
    if t[i] == nil then
      return false
    end
  end
  return true
end

local encodeValue

local encodeTable = function(t)
  local parts = {}
  if isArray(t) then
    for i = 1, #t do
      parts[i] = encodeValue(t[i])
    end
    return "[" .. table.concat(parts, ",") .. "]"
  end
  local keys = {}
  for k in pairs(t) do
    keys[#keys + 1] = k
  end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  for _, k in ipairs(keys) do
    parts[#parts + 1] = encodeString(tostring(k)) .. ":" .. encodeValue(t[k])
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

encodeValue = function(v)
  local kind = type(v)
  if kind == "string" then
    return encodeString(v)
  elseif kind == "boolean" then
    return tostring(v)
  elseif kind == "number" then
    if v ~= v or v == math.huge or v == -math.huge then
      return "null"
    end
    if v == math.floor(v) then
      return string.format("%d", v)
    end
    return string.format("%.4f", v)
  elseif kind == "table" then
    return encodeTable(v)
  end
  return "null"
end

M.encode = encodeValue

return M
