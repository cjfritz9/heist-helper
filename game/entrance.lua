local lobby = require("core.lobby")
local maze = require("core.maze")
local lines = require("gfx.lines")

local M = {}

local FILE = "entrance.csv"
local TILE_UNITS = 512
local COLOUR = { 90, 200, 255, 230 }
local THICKNESS = 3
local PICK_REACH_TILES = 40

local bolt = nil
local area = lobby.new()

local save = function()
  bolt.saveconfig(FILE, lobby.encode(area))
end

function M.init(boltApi)
  bolt = boltApi
  area = lobby.decode(bolt.loadconfig(FILE))
end

function M.command(argument)
  if argument == "always" then
    area.always = not area.always
  elseif argument == "clear" then
    area.a, area.b = nil, nil
  end
  save()
end

local tileAt = function(viewProj, player, x, y)
  local vx, vy = bolt.gameviewxywh()
  local px, py = x - vx, y - vy
  local corner = function(tx, tz)
    local sx, sy, depth = bolt.point(tx * TILE_UNITS, player.height, tz * TILE_UNITS):transform(viewProj):togameview()
    if not depth or depth <= 0 or depth > 1 then return nil end
    return { sx, sy }
  end
  for tx = player.tileX - PICK_REACH_TILES, player.tileX + PICK_REACH_TILES do
    for tz = player.tileZ - PICK_REACH_TILES, player.tileZ + PICK_REACH_TILES do
      local a, b, c, d = corner(tx, tz), corner(tx + 1, tz), corner(tx + 1, tz + 1), corner(tx, tz + 1)
      if a and b and c and d and maze.pointInQuad({ a, b, c, d }, px, py) then return tx, tz end
    end
  end
  return nil
end

function M.pick(which, viewProj, player, x, y)
  if not viewProj or not player then return false end
  local tx, tz = tileAt(viewProj, player, x, y)
  if not tx then return false end
  area[which] = { tileX = tx, tileZ = tz }
  save()
  return true
end

function M.atEntrance(player)
  return player ~= nil and lobby.near(player.tileX, player.tileZ, area)
end

function M.showPanel(player)
  if not player then return false end
  return area.always or lobby.near(player.tileX, player.tileZ, area)
end

function M.status()
  local corner = function(c) return c and (c.tileX .. ", " .. c.tileZ) or nil end
  return { a = corner(area.a), b = corner(area.b), always = area.always }
end

function M.draw(viewProj, player)
  local b = lobby.bounds(area)
  if not b or not viewProj or not player then return end
  local vx, vy, vw, vh = bolt.gameviewxywh()
  local corners = { { b.minX, b.minZ }, { b.maxX + 1, b.minZ }, { b.maxX + 1, b.maxZ + 1 }, { b.minX, b.maxZ + 1 } }
  local points = {}
  for i, c in ipairs(corners) do
    local sx, sy, depth = bolt.point(c[1] * TILE_UNITS, player.height, c[2] * TILE_UNITS):transform(viewProj):togameview()
    if not depth or depth <= 0 or depth > 1 then return end
    points[i] = { sx, sy }
  end
  local edges = {}
  for i = 1, 4 do
    local p, q = points[i], points[i % 4 + 1]
    edges[i] = { p[1], p[2], q[1], q[2], colour = COLOUR }
  end
  lines.setScreenDimensions(vw, vh)
  lines.drawLines(bolt, edges, THICKNESS, vx, vy)
end

return M
