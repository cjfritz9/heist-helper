local vault = require("data.vault")
local assert = require("tests.assert")

local T = {}

local countKinds = function()
  local counts, total = {}, 0
  for _, section in ipairs(vault.SECTIONS) do
    for _, entry in ipairs(section.loot) do
      counts[entry.kind] = (counts[entry.kind] or 0) + entry.count
      total = total + entry.count
    end
  end
  return counts, total
end

function T.layout_has_thirty_sources()
  local counts, total = countKinds()
  assert.eq(total, 30, "total sources")
  assert.eq(counts.legionary, 8, "legionaries")
  assert.eq(counts.chest, 6, "chests")
  assert.eq(counts.shadowChest, 7, "shadow chests")
  assert.eq(counts.safe, 8, "safes")
  assert.eq(counts.rareChest, 1, "rare chest")
end

function T.full_pool_is_535()
  assert.eq(vault.reachablePoints(120, 99), 535, "everything unlocked")
end

function T.reachability_matches_design_table()
  assert.eq(vault.reachablePoints(95, 1), 270, "95 thieving, no crevices")
  assert.eq(vault.reachablePoints(101, 72), 295, "no safes, crevices")
  assert.eq(vault.reachablePoints(102, 71), 480, "safes, no crevices")
  assert.eq(vault.reachablePoints(102, 72), 535, "everything")
end

return T
