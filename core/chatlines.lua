local M = {}

function M.split(message)
  local time, text = message:match("^%[(%d%d:%d%d:%d%d)%](.*)$")
  if not time then
    return nil, message
  end
  return time, text
end

return M
