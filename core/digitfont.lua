local M = {}

local GLYPHS = {
  ["0"] = { "###", "#.#", "#.#", "#.#", "###" },
  ["1"] = { ".#.", "##.", ".#.", ".#.", "###" },
  ["2"] = { "###", "..#", "###", "#..", "###" },
  ["3"] = { "###", "..#", ".##", "..#", "###" },
  ["4"] = { "#.#", "#.#", "###", "..#", "..#" },
  ["5"] = { "###", "#..", "###", "..#", "###" },
  ["6"] = { "###", "#..", "###", "#.#", "###" },
  ["7"] = { "###", "..#", ".#.", ".#.", ".#." },
  ["8"] = { "###", "#.#", "###", "#.#", "###" },
  ["9"] = { "###", "#.#", "###", "..#", "###" },
  ["?"] = { "###", "..#", ".##", "...", ".#." },
}

local GLYPH_W, GLYPH_H, GAP = 3, 5, 1
local WHITE, BLACK, CLEAR = "\255\255\255\255", "\0\0\0\255", "\0\0\0\0"

local inkGrid = function(text)
  local w = #text * (GLYPH_W + GAP) - GAP + 2
  local h = GLYPH_H + 2
  local grid = {}
  for y = 1, h do
    grid[y] = {}
    for x = 1, w do grid[y][x] = 0 end
  end
  for i = 1, #text do
    local glyph = GLYPHS[text:sub(i, i)] or GLYPHS["?"]
    local left = 1 + (i - 1) * (GLYPH_W + GAP)
    for gy = 1, GLYPH_H do
      for gx = 1, GLYPH_W do
        if glyph[gy]:sub(gx, gx) == "#" then
          grid[gy + 1][left + gx] = 2
        end
      end
    end
  end
  for y = 1, h do
    for x = 1, w do
      if grid[y][x] == 0 then
        for dy = -1, 1 do
          for dx = -1, 1 do
            local row = grid[y + dy]
            if row and row[x + dx] == 2 then grid[y][x] = 1 end
          end
        end
      end
    end
  end
  return grid, w, h
end

function M.render(text, scale)
  local grid, w, h = inkGrid(text)
  local rows = {}
  for y = 1, h do
    local pixels = {}
    for x = 1, w do
      local cell = grid[y][x]
      pixels[x] = string.rep(cell == 2 and WHITE or cell == 1 and BLACK or CLEAR, scale)
    end
    local line = table.concat(pixels)
    for _ = 1, scale do
      rows[#rows + 1] = line
    end
  end
  return w * scale, h * scale, table.concat(rows)
end

return M
