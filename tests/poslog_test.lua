local poslog = require("core.poslog")
local assert = require("tests.assert")

local T = {}

function T.empty_log_has_no_rows()
  assert.eq(poslog.countRows(poslog.HEADER), 0, "header only")
end

function T.counts_rows_after_header()
  local log = poslog.HEADER .. poslog.row(1, 0, 965, 0) .. poslog.row(2, 512, 965, 512)
  assert.eq(poslog.countRows(log), 2, "two rows")
end

function T.row_includes_tile_and_chunk()
  local row = poslog.row(7, 512 * 3205, 965, 512 * 3139)
  assert.eq(row, "7,1640960,965,1607168,3205,3139,50,49,5,3\n", "row")
end

return T
