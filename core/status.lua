local runstate = require("core.runstate")
local objectmap = require("core.objectmap")
local levels = require("core.levels")

local M = {}

M.LOOT_KINDS = { chest = true, safe = true, rareChest = true, corpse = true }
M.POINTS = { corpse = 10, chest = 10, safe = 30, rareChest = 50 }
M.SHADOW_POINTS = 15
M.SECTIONS = 4

function M.points(o)
  if o.kind == "chest" and o.shadow then return M.SHADOW_POINTS end
  return M.POINTS[o.kind] or 0
end

local splits = function(run, map, playerLevels)
  local out = {}
  for s = 1, M.SECTIONS do
    out[s] = { section = s, gained = run.sectionLoot and run.sectionLoot[s] or 0, potential = 0 }
  end
  for _, o in ipairs(map.list) do
    local split = o.section and out[o.section]
    if split and M.LOOT_KINDS[o.kind]
      and levels.canLoot(playerLevels, o.kind, objectmap.behindCrevice(map, o.dx, o.dz)) then
      split.potential = split.potential + M.points(o)
    end
  end
  return out
end

local emptyCounts = function()
  return { chest = 0, safe = 0, rareChest = 0, corpse = 0 }
end

local isLeft = function(run, o)
  if o.kind == "corpse" then
    return not runstate.isCorpseLooted(run, o.dx, o.dz)
  end
  return not runstate.isObjectLooted(run, o.kind, o.dx, o.dz)
end

function M.remaining(run, map, playerLevels)
  local out = {}
  if not run.anchor then return out end
  for _, o in ipairs(map.list) do
    if M.LOOT_KINDS[o.kind] and isLeft(run, o)
      and levels.canLoot(playerLevels, o.kind, objectmap.behindCrevice(map, o.dx, o.dz)) then
      out[#out + 1] = o
    end
  end
  return out
end

function M.build(run, map, section, playerLevels)
  local total = emptyCounts()
  local current = section and emptyCounts() or nil
  if run.anchor then
    for _, o in ipairs(map.list) do
      if M.LOOT_KINDS[o.kind] and isLeft(run, o)
        and levels.canLoot(playerLevels, o.kind, objectmap.behindCrevice(map, o.dx, o.dz)) then
        local here = current ~= nil and o.section == section
        total[o.kind] = total[o.kind] + 1
        if here then
          current[o.kind] = current[o.kind] + 1
        end
      end
    end
  end
  return {
    anchored = run.anchor ~= nil,
    section = section,
    current = run.anchor and current or nil,
    total = total,
    splits = run.anchor and splits(run, map, playerLevels) or nil,
    levels = playerLevels,
  }
end

function M.mapping(map)
  local withHeight, loot, withSection, crevices = 0, 0, 0, {}
  for _, o in ipairs(map.list) do
    if o.y then
      withHeight = withHeight + 1
    end
    if M.LOOT_KINDS[o.kind] then
      loot = loot + 1
      if o.section then
        withSection = withSection + 1
      end
    end
    if objectmap.behindCrevice(map, o.dx, o.dz) then
      crevices[#crevices + 1] = { kind = o.kind, dx = o.dx, dz = o.dz }
    end
  end
  return { withHeight = withHeight, total = #map.list, withSection = withSection, loot = loot, crevices = crevices }
end

return M
