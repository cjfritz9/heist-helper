package.path = "./?.lua;" .. package.path

local SUITES = {
  "tests.anchor_test",
  "tests.anchorclick_test",
  "tests.catalog_test",
  "tests.checkpoints_test",
  "tests.chatlines_test",
  "tests.chatlog_test",
  "tests.compare_test",
  "tests.coords_test",
  "tests.digitfont_test",
  "tests.extremes_test",
  "tests.hull_test",
  "tests.json_test",
  "tests.levels_test",
  "tests.lobby_test",
  "tests.links_test",
  "tests.linkwizard_test",
  "tests.lootpopups_test",
  "tests.markerdata_test",
  "tests.maze_test",
  "tests.mazepatterns_test",
  "tests.markerstore_test",
  "tests.nearby_test",
  "tests.objectmap_test",
  "tests.picking_test",
  "tests.pips_test",
  "tests.probediff_test",
  "tests.recording_test",
  "tests.popups_test",
  "tests.poslog_test",
  "tests.rewards_test",
  "tests.rollinglog_test",
  "tests.runstate_test",
  "tests.runlog_test",
  "tests.stacklabels_test",
  "tests.status_test",
  "tests.tickclock_test",
  "tests.latency_test",
  "tests.truetile_test",
  "tests.spawntimer_test",
  "tests.clicktarget_test",
  "tests.minimapicons_test",
  "tests.tickphase_test",
  "tests.visionring_test",
  "tests.ghosttrack_test",
  "tests.ghostroutes_test",
  "tests.ghostpaths_test",
  "tests.ghostpathsdata_test",
  "tests.ghostsync_test",
  "tests.ghostspawns_test",
  "tests.routeassembly_test",
  "tests.watchdetail_test",
  "tests.watchlog_test",
  "tests.tooltip_test",
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
