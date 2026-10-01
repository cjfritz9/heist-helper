local runlog = require("core.runlog")
local assert = require("tests.assert")

local T = {}

function T.completion_time_from_the_chat_line()
  assert.eq(runlog.parseTime("CompletionTime:14:35.4"), 875.4, "minutes and seconds")
  assert.eq(runlog.parseTime("nonsense"), nil, "no time")
end

function T.rows_survive_a_save_and_load()
  local rows = { { seconds = 875.4, loot = 480 }, { seconds = 812, loot = 500 } }
  local again = runlog.decode(runlog.encode(rows))
  assert.eq(#again, 2, "two runs")
  assert.eq(again[1].seconds, 875.4, "time kept")
  assert.eq(again[2].loot, 500, "loot kept")
end

function T.session_counts_runs_since_the_plugin_loaded()
  local rows = { { seconds = 900, loot = 400 }, { seconds = 840, loot = 480 }, { seconds = 800, loot = 500 }, { seconds = 860, loot = 470 } }
  local s = runlog.stats(rows, 2)
  assert.eq(s.lifetime, 4, "all recorded runs")
  assert.eq(s.session, 2, "two since loading")
  assert.eq(s.average, 830, "session average")
  assert.eq(s.best, 800, "session best")
  assert.eq(runlog.clock(s.best), "13:20", "shown as minutes")
  assert.eq(runlog.stats(rows, 4).average, nil, "nothing yet this session")
  assert.eq(s.last.time .. " " .. s.last.loot, "14:20 470", "the last run")
  assert.eq(runlog.stats({}, 0).last, nil, "no runs yet")
end

return T
