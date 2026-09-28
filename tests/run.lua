package.path = "./?.lua;" .. package.path

local SUITES = {
  "tests.anchor_test",
  "tests.catalog_test",
  "tests.chatlines_test",
  "tests.chatlog_test",
  "tests.coords_test",
  "tests.hull_test",
  "tests.markerdata_test",
  "tests.markerstore_test",
  "tests.objectmap_test",
  "tests.picking_test",
  "tests.pips_test",
  "tests.probediff_test",
  "tests.poslog_test",
  "tests.rewards_test",
  "tests.runstate_test",
  "tests.vault_test",
}

local passed, failed = 0, 0

for _, suiteName in ipairs(SUITES) do
  local suite = require(suiteName)
  local names = {}
  for name in pairs(suite) do
    names[#names + 1] = name
  end
  table.sort(names)
  for _, name in ipairs(names) do
    local ok, err = pcall(suite[name])
    if ok then
      passed = passed + 1
    else
      failed = failed + 1
      print(string.format("FAIL %s.%s\n  %s", suiteName, name, tostring(err)))
    end
  end
end

print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
