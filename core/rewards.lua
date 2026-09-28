local M = {}

M.BAG_CAP = 500
M.POINTS_PER_ROLL = 25
M.MAX_COMMON_ROLLS = 20
M.XP_PER_POINT = 400
M.RARE_CHEST_POINTS = 50

local RARE_ANCHORS = {
  { points = 0, rate = 0 },
  { points = 100, rate = 1 / 234 },
  { points = 200, rate = 1 / 144 },
  { points = 300, rate = 1 / 90 },
  { points = 400, rate = 1 / 54 },
  { points = 500, rate = 1 / 36 },
}

local SPECIFIC_ITEM_SHARE = 1 / 3

local LUCK_BONUS = { [0] = 0, [1] = 0, [2] = 0.01, [3] = 0.02, [4] = 0.03 }

function M.capBag(points)
  return math.max(0, math.min(points, M.BAG_CAP))
end

function M.finalPoints(bagPoints, openedRareChest)
  local points = M.capBag(bagPoints)
  if openedRareChest then
    return points
  end
  return math.floor(points / 2)
end

function M.xp(points, instantXp)
  return points * M.XP_PER_POINT + (instantXp or 0)
end

function M.commonRolls(points)
  local guaranteed = math.floor(points / M.POINTS_PER_ROLL)
  if guaranteed >= M.MAX_COMMON_ROLLS then
    return M.MAX_COMMON_ROLLS, 0
  end
  return guaranteed, (points % M.POINTS_PER_ROLL) / M.POINTS_PER_ROLL
end

function M.rareRate(points, luckTier)
  local capped = M.capBag(points)
  local rate = RARE_ANCHORS[#RARE_ANCHORS].rate
  for i = 2, #RARE_ANCHORS do
    local low, high = RARE_ANCHORS[i - 1], RARE_ANCHORS[i]
    if capped <= high.points then
      local progress = (capped - low.points) / (high.points - low.points)
      rate = low.rate + progress * (high.rate - low.rate)
      break
    end
  end
  return rate * (1 + (LUCK_BONUS[luckTier or 0] or 0))
end

function M.specificItemRate(points, luckTier)
  return M.rareRate(points, luckTier) * SPECIFIC_ITEM_SHARE
end

function M.rareChestOverflow(bagPoints)
  return math.max(0, bagPoints + M.RARE_CHEST_POINTS - M.BAG_CAP)
end

function M.project(run)
  local points = M.finalPoints(run.bagPoints, run.openedRareChest)
  local rolls, extraRollChance = M.commonRolls(points)
  return {
    points = points,
    xp = M.xp(points, run.instantXp),
    commonRolls = rolls,
    extraRollChance = extraRollChance,
    rareRate = M.rareRate(points, run.luckTier),
    specificItemRate = M.specificItemRate(points, run.luckTier),
    pointsToCap = M.BAG_CAP - M.capBag(run.bagPoints),
  }
end

return M
