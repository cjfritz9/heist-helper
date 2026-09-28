local runstate = require("core.runstate")

local M = {}

local SECTION_HEIGHTS = {
  { section = 1, height = 4933 },
  { section = 2, height = 2949 },
  { section = 3, height = 258 },
  { section = 4, height = 2179 },
}
local SECTION_TOLERANCE = 200

function M.section(height)
  local best, bestDistance = nil, SECTION_TOLERANCE + 1
  for _, s in ipairs(SECTION_HEIGHTS) do
    local distance = math.abs(height - s.height)
    if distance < bestDistance then
      best, bestDistance = s.section, distance
    end
  end
  return best
end

function M.build(run, objects, playerHeight)
  local remaining = { chest = 0, safe = 0, rareChest = 0, corpse = 0 }
  local corpses = {}
  local anchors = { powered = 0, total = 0 }
  if run.anchor then
    for _, o in ipairs(objects) do
      if o.kind == "corpse" then
        if not runstate.isCorpseLooted(run, o.dx, o.dz) then
          remaining.corpse = remaining.corpse + 1
          local done = runstate.rummageCount(run, o.dx, o.dz)
          if done > 0 then
            corpses[#corpses + 1] = { done = done, total = runstate.RUMMAGES_PER_CORPSE }
          end
        end
      elseif o.kind == "shadowAnchor" then
        anchors.total = anchors.total + 1
        if runstate.isAnchorPowered(run, o.dx, o.dz) then
          anchors.powered = anchors.powered + 1
        end
      elseif remaining[o.kind] and not runstate.isObjectLooted(run, o.kind, o.dx, o.dz) then
        remaining[o.kind] = remaining[o.kind] + 1
      end
    end
  end
  return {
    anchored = run.anchor ~= nil,
    section = playerHeight and M.section(playerHeight) or nil,
    remaining = remaining,
    corpses = corpses,
    anchors = anchors,
  }
end

return M
