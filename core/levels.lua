local M = {}

M.NAMES = { "thieving", "agility", "maze", "ghosts", "ghostsUnseen" }

function M.new()
  return { thieving = true, agility = true, maze = false, ghosts = true, ghostsUnseen = false }
end

function M.decode(text)
  local levels = M.new()
  for name, value in (text or ""):gmatch("(%a+)=([01])") do
    if levels[name] ~= nil then
      levels[name] = value == "1"
    end
  end
  return levels
end

function M.encode(levels)
  local out = {}
  for _, name in ipairs(M.NAMES) do
    out[#out + 1] = name .. "=" .. (levels[name] and "1" or "0")
  end
  return table.concat(out, "\n") .. "\n"
end

function M.toggle(levels, name)
  if levels[name] == nil then return false end
  levels[name] = not levels[name]
  return true
end

function M.canLoot(levels, kind, behindCrevice)
  if kind == "safe" and not levels.thieving then
    return false
  end
  return not behindCrevice or levels.agility
end

return M
