-- Adapted from bolt-groundmarkers gfx/shaders.lua
-- Copyright (c) 2025 Sven van der Leest, MIT License (see THIRD_PARTY.md)

local M = {}

local BYTES_PER_VERTEX = 28
local UNIFORM_SCREEN = 3
local UNIFORM_HALF_THICKNESS = 4

local program = nil
local surface = nil
local surfaceW, surfaceH = 0, 0
local screenW, screenH = 1920, 1080

local createProgram = function(bolt)
  local vs = bolt.createvertexshader(
    "layout(location=0) in highp vec2 surfacePos;" ..
    "layout(location=1) in highp vec4 inColor;" ..
    "layout(location=2) in highp float edgeCoord;" ..
    "layout(location=3) uniform highp vec2 screenSize;" ..
    "out highp vec4 vColor;" ..
    "out highp float vEdgeCoord;" ..
    "void main() {" ..
      "vColor = inColor;" ..
      "vEdgeCoord = edgeCoord;" ..
      "gl_Position = vec4((surfacePos / screenSize) * 2.0 - 1.0, 0.0, 1.0);" ..
    "}"
  )
  local fs = bolt.createfragmentshader(
    "in highp vec4 vColor;" ..
    "in highp float vEdgeCoord;" ..
    "layout(location=4) uniform highp float halfThickness;" ..
    "out highp vec4 fragColor;" ..
    "void main() {" ..
      "highp float coverage = 1.0;" ..
      "if (halfThickness > 0.0) {" ..
        "highp float distToEdge = 1.0 - clamp(abs(vEdgeCoord), 0.0, 1.0);" ..
        "highp float feather = clamp(1.0 / (halfThickness + 0.0001), 0.0, 1.0);" ..
        "coverage = smoothstep(0.0, feather, distToEdge);" ..
      "}" ..
      "fragColor = vec4(vColor.rgb, vColor.a * coverage);" ..
    "}"
  )
  local p = bolt.createshaderprogram(vs, fs)
  p:setattribute(0, 4, true, true, 2, 0, BYTES_PER_VERTEX)
  p:setattribute(1, 4, true, true, 4, 8, BYTES_PER_VERTEX)
  p:setattribute(2, 4, true, true, 1, 24, BYTES_PER_VERTEX)
  return p
end

local addVertex = function(buf, offset, x, y, c, edge)
  buf:setfloat32(offset, x)
  buf:setfloat32(offset + 4, y)
  buf:setfloat32(offset + 8, c[1] / 255)
  buf:setfloat32(offset + 12, c[2] / 255)
  buf:setfloat32(offset + 16, c[3] / 255)
  buf:setfloat32(offset + 20, c[4] / 255)
  buf:setfloat32(offset + 24, edge)
  return offset + BYTES_PER_VERTEX
end

local prepare = function(bolt)
  program = program or createProgram(bolt)
  if not surface or surfaceW ~= screenW or surfaceH ~= screenH then
    surface = bolt.createsurface(screenW, screenH)
    surface:setalpha(1.0)
    surfaceW, surfaceH = screenW, screenH
  end
end

local submit = function(bolt, buf, vertexCount, halfThickness, vx, vy)
  surface:clear()
  program:setuniform2f(UNIFORM_SCREEN, screenW, screenH)
  program:setuniform1f(UNIFORM_HALF_THICKNESS, halfThickness)
  program:drawtosurface(surface, bolt.createshaderbuffer(buf), vertexCount)
  surface:drawtoscreen(0, 0, screenW, screenH, vx, vy, screenW, screenH)
end

function M.setScreenDimensions(w, h)
  if w and w > 0 then screenW = w end
  if h and h > 0 then screenH = h end
end

function M.drawQuads(bolt, quads, vx, vy)
  if #quads == 0 then return end
  prepare(bolt)
  local buf = bolt.createbuffer(#quads * 6 * BYTES_PER_VERTEX)
  local offset = 0
  for _, q in ipairs(quads) do
    offset = addVertex(buf, offset, q[1], q[2], q.colour, 0)
    offset = addVertex(buf, offset, q[3], q[4], q.colour, 0)
    offset = addVertex(buf, offset, q[5], q[6], q.colour, 0)
    offset = addVertex(buf, offset, q[1], q[2], q.colour, 0)
    offset = addVertex(buf, offset, q[5], q[6], q.colour, 0)
    offset = addVertex(buf, offset, q[7], q[8], q.colour, 0)
  end
  submit(bolt, buf, #quads * 6, -1.0, vx, vy)
end

function M.drawLines(bolt, lines, thickness, vx, vy)
  if #lines == 0 then return end
  prepare(bolt)
  local buf = bolt.createbuffer(#lines * 6 * BYTES_PER_VERTEX)
  local half = thickness / 2
  local offset = 0
  for _, l in ipairs(lines) do
    local dx, dy = l[3] - l[1], l[4] - l[2]
    local len = math.max(0.001, math.sqrt(dx * dx + dy * dy))
    local px, py = -dy / len * half, dx / len * half
    offset = addVertex(buf, offset, l[1] + px, l[2] + py, l.colour, 1)
    offset = addVertex(buf, offset, l[1] - px, l[2] - py, l.colour, -1)
    offset = addVertex(buf, offset, l[3] + px, l[4] + py, l.colour, 1)
    offset = addVertex(buf, offset, l[1] - px, l[2] - py, l.colour, -1)
    offset = addVertex(buf, offset, l[3] - px, l[4] - py, l.colour, -1)
    offset = addVertex(buf, offset, l[3] + px, l[4] + py, l.colour, 1)
  end
  submit(bolt, buf, #lines * 6, math.max(0.5, half), vx, vy)
end

return M
