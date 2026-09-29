local span = function(tiles, u0, u1, v0, v1)
  for u = math.min(u0, u1), math.max(u0, u1) do
    for v = math.min(v0, v1), math.max(v0, v1) do
      tiles[#tiles + 1] = { u, v }
    end
  end
  return tiles
end

local centred = {
  A = span(span(span({}, 13, 13, 1, 3), 0, 13, 4, 4), 0, 0, 5, 11),
  B = span(span(span(span({}, 12, 12, 1, 7), 8, 12, 7, 7), 8, 8, 8, 10), 0, 8, 11, 11),
  C = span(span(span(span(span(span({}, 10, 10, 1, 1), 8, 10, 2, 2), 8, 8, 3, 6), 7, 8, 7, 7), 7, 7, 8, 10), 0, 7, 11, 11),
}

local west = {
  A = span(span(span({}, 7, 7, 1, 3), 0, 7, 4, 4), 0, 0, 5, 11),
  B = span(span(span(span({}, 6, 6, 1, 7), 2, 6, 7, 7), 2, 2, 8, 10), 0, 2, 11, 11),
  C = span(span(span(span(span(span({}, 4, 4, 1, 1), 2, 4, 2, 2), 2, 2, 3, 6), 1, 2, 7, 7), 1, 1, 8, 10), 0, 1, 11, 11),
}

return {
  legs = {
    ["west-north"] = { origin = { -12, -70 }, u = { 0, -1 }, v = { 1, 0 }, shapes = west },
    ["north-east"] = { origin = { 10, -70 }, u = { -1, 0 }, v = { 0, -1 }, shapes = centred },
    ["east-south"] = { origin = { 10, -92 }, u = { 0, 1 }, v = { -1, 0 }, shapes = centred },
  },
}
