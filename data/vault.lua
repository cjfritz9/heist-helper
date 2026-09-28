local M = {}

M.CREVICE_AGILITY = 72

M.SOURCES = {
  legionary = { thieving = 95, points = 10, instantXp = 1385, interactions = 5 },
  chest = { thieving = 95, points = 10, instantXp = 2280, interactions = 4 },
  shadowChest = { thieving = 95, points = 15, instantXp = 2660, interactions = 4 },
  safe = { thieving = 102, points = 30, instantXp = 5200, interactions = 4 },
  rareChest = { thieving = 95, points = 50, instantXp = 28000, interactions = 7 },
}

M.PENALTIES = {
  ghost = { points = 20, withMasterCape = 14 },
  pylonMisstep = { points = 5, withMasterCape = 3 },
}

M.SECTIONS = {
  { id = "1", loot = {
    { kind = "legionary", count = 2 },
    { kind = "chest", count = 1 },
  } },
  { id = "2", loot = {
    { kind = "legionary", count = 2 },
    { kind = "chest", count = 1 },
    { kind = "safe", count = 1 },
    { kind = "shadowChest", count = 1 },
    { kind = "shadowChest", count = 1, crevice = true },
  } },
  { id = "3", loot = {
    { kind = "legionary", count = 2 },
    { kind = "chest", count = 2 },
    { kind = "safe", count = 2 },
    { kind = "shadowChest", count = 2 },
  } },
  { id = "4 west", loot = {
    { kind = "shadowChest", count = 1 },
  } },
  { id = "4 north", loot = {
    { kind = "legionary", count = 2 },
    { kind = "safe", count = 1 },
    { kind = "safe", count = 1, crevice = true },
    { kind = "chest", count = 1, crevice = true },
    { kind = "shadowChest", count = 1 },
  } },
  { id = "4 east", loot = {
    { kind = "rareChest", count = 1 },
    { kind = "safe", count = 1 },
    { kind = "shadowChest", count = 1 },
  } },
  { id = "4 south", optional = true, loot = {
    { kind = "chest", count = 1 },
    { kind = "safe", count = 2 },
  } },
}

function M.canLoot(entry, thieving, agility)
  if thieving < M.SOURCES[entry.kind].thieving then
    return false
  end
  return not entry.crevice or agility >= M.CREVICE_AGILITY
end

function M.reachablePoints(thieving, agility)
  local total = 0
  for _, section in ipairs(M.SECTIONS) do
    for _, entry in ipairs(section.loot) do
      if M.canLoot(entry, thieving, agility) then
        total = total + entry.count * M.SOURCES[entry.kind].points
      end
    end
  end
  return total
end

return M
