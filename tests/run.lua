package.path = "./?.lua;" .. package.path

local SUITES = {
  "tests.coords_test",
  "tests.markerdata_test",
  "tests.markerstore_test",
  "tests.picking_test",
  "tests.poslog_test",
  "tests.rewards_test",
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
