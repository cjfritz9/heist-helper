local M = {}

local CHEST = {
  "...........",
  ".kkkkkkkkk.",
  "kllllllllck",
  "kcccccccddk",
  "kkkkkwkkkkk",
  "kccckwkcddk",
  "kccckkkcddk",
  "kcccccccddk",
  "kdddddddddk",
  ".kkkkkkkkk.",
  "...........",
}

M.SHAPES = {
  chest = CHEST,
  rareChest = {
    ".........w.",
    ".kkkkkkkwww",
    "kllllllllwk",
    "kcccccccddk",
    "kkkkkwkkkkk",
    "kccckwkcddk",
    "kccckkkcddk",
    "kcccccccddk",
    "kdddddddddk",
    ".kkkkkkkkk.",
    "...........",
  },
  safe = {
    ".kkkkkkkkk.",
    "klllllllllk",
    "klcckkkccdk",
    "klckwwwkcdk",
    "klckwkwkcdk",
    "klckwwwkcdk",
    "klcckkkccdk",
    "klcccccccdk",
    "kdddddddddk",
    ".kk.....kk.",
    "...........",
  },
  corpse = {
    "...kkkkk...",
    ".kklllllkk.",
    "kllllllllck",
    "klkkklkkkck",
    "klkkklkkkck",
    "kllllkllllk",
    ".kllllllck.",
    "..klklklk..",
    "..kkkkkkk..",
    "...........",
    "...........",
  },
  ghost = {
    "...kkkkk...",
    "..kllccck..",
    ".klcccccdk.",
    ".klkkckkdk.",
    ".klkkckkdk.",
    ".klcccccdk.",
    ".kccccccdk.",
    ".kccccccdk.",
    ".kckckckck.",
    ".k.k.k.k.k.",
    "...........",
  },
}

local LIGHTEN = 0.4
local DARKEN = 0.6

local byte = function(v)
  return string.char(math.max(0, math.min(255, math.floor(v + 0.5))))
end

local pixel = function(rgb, alpha)
  return byte(rgb[1]) .. byte(rgb[2]) .. byte(rgb[3]) .. byte(alpha)
end

function M.palette(rgb)
  local light = {}
  local dark = {}
  for i = 1, 3 do
    light[i] = rgb[i] + (255 - rgb[i]) * LIGHTEN
    dark[i] = rgb[i] * DARKEN
  end
  return {
    ["."] = "\0\0\0\0",
    k = pixel({ 0, 0, 0 }, 235),
    w = pixel({ 255, 255, 255 }, 255),
    c = pixel(rgb, 255),
    l = pixel(light, 255),
    d = pixel(dark, 255),
  }
end

function M.render(kind, rgb, scale)
  local shape = M.SHAPES[kind]
  if not shape then return nil end
  scale = scale or 1
  local colours = M.palette(rgb)
  local rows = {}
  for _, row in ipairs(shape) do
    local pixels = {}
    for x = 1, #row do
      local p = colours[row:sub(x, x)]
      for _ = 1, scale do pixels[#pixels + 1] = p end
    end
    local line = table.concat(pixels)
    for _ = 1, scale do rows[#rows + 1] = line end
  end
  return #shape[1] * scale, #shape * scale, table.concat(rows)
end

return M
