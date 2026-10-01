local M = {}

M.CORNER_SECONDS = 0.35
M.MIN_OVERLAP = 8
M.MIN_LOOP_OVERLAP = 4

local key = function(t)
  return t.x .. "," .. t.z
end

M.key = key

local diagonal = function(a, b)
  return math.abs(a.x - b.x) == 1 and math.abs(a.z - b.z) == 1
end

function M.clean(tiles)
  local out = {}
  for _, t in ipairs(tiles) do
    local last = out[#out]
    if not last or last.x ~= t.x or last.z ~= t.z then out[#out + 1] = t end
  end
  local i = 2
  while i < #out do
    local a, b, c = out[i - 1], out[i], out[i + 1]
    if diagonal(a, c) and (c.at - b.at) < M.CORNER_SECONDS * 1e6 then
      table.remove(out, i)
    else
      i = i + 1
    end
  end
  local keys = {}
  for n, t in ipairs(out) do
    local prev = out[n - 1]
    if prev then
      local dx, dz = t.x - prev.x, t.z - prev.z
      if math.max(math.abs(dx), math.abs(dz)) == 2 and (dx == 0 or dz == 0 or math.abs(dx) == math.abs(dz)) then
        keys[#keys + 1] = key({ x = prev.x + dx / 2, z = prev.z + dz / 2 })
      end
    end
    keys[#keys + 1] = key(t)
  end
  return keys
end

function M.fixCutCorners(reads)
  local count = {}
  for _, r in ipairs(reads) do
    for i = 2, #r do count[r[i - 1] .. ">" .. r[i]] = (count[r[i - 1] .. ">" .. r[i]] or 0) + 1 end
  end
  local xz = function(k) local x, z = k:match("(%-?%d+),(%-?%d+)") return tonumber(x), tonumber(z) end
  for _, r in ipairs(reads) do
    local i = 2
    while i <= #r do
      local ax, az = xz(r[i - 1])
      local cx, cz = xz(r[i])
      if math.abs(cx - ax) == 1 and math.abs(cz - az) == 1 then
        local diagonal = count[r[i - 1] .. ">" .. r[i]] or 0
        local best, bestCount = nil, diagonal
        for _, b in ipairs({ cx .. "," .. az, ax .. "," .. cz }) do
          local via = math.min(count[r[i - 1] .. ">" .. b] or 0, count[b .. ">" .. r[i]] or 0)
          if via > bestCount then best, bestCount = b, via end
        end
        if best then table.insert(r, i, best) end
      end
      i = i + 1
    end
  end
  return reads
end

local contains = function(a, b)
  for start = 1, #a - #b + 1 do
    local same = true
    for k = 1, #b do
      if a[start + k - 1] ~= b[k] then same = false break end
    end
    if same then return true end
  end
  return false
end

local overlap = function(a, b, minimum)
  for k = math.min(#a, #b) - 1, minimum, -1 do
    local same = true
    for n = 1, k do
      if a[#a - k + n] ~= b[n] then same = false break end
    end
    if same then return k end
  end
  return 0
end

function M.assemble(reads, minimum)
  minimum = minimum or M.MIN_OVERLAP
  local contigs = {}
  for _, r in ipairs(reads) do
    if #r >= minimum then contigs[#contigs + 1] = r end
  end
  local merged = true
  while merged do
    merged = false
    for i = #contigs, 1, -1 do
      for j = 1, #contigs do
        if i ~= j and contigs[i] and contigs[j] and #contigs[i] <= #contigs[j] and contains(contigs[j], contigs[i]) then
          table.remove(contigs, i)
          merged = true
          break
        end
      end
    end
    local best, bi, bj = 0, nil, nil
    for i, a in ipairs(contigs) do
      for j, b in ipairs(contigs) do
        if i ~= j then
          local k = overlap(a, b, minimum)
          if k > best then best, bi, bj = k, i, j end
        end
      end
    end
    if bi then
      local a, b = contigs[bi], contigs[bj]
      local joined = {}
      for _, v in ipairs(a) do joined[#joined + 1] = v end
      for n = best + 1, #b do joined[#joined + 1] = b[n] end
      local keep = {}
      for n, c in ipairs(contigs) do
        if n ~= bi and n ~= bj then keep[#keep + 1] = c end
      end
      keep[#keep + 1] = joined
      contigs = keep
      merged = true
    end
  end
  table.sort(contigs, function(a, b) return #a > #b end)
  return contigs
end

function M.loop(contig, minimum)
  minimum = minimum or M.MIN_LOOP_OVERLAP
  for k = #contig - 1, minimum, -1 do
    local same = true
    for n = 1, k do
      if contig[#contig - k + n] ~= contig[n] then same = false break end
    end
    if same and #contig - k >= minimum then
      local loop = {}
      for n = 1, #contig - k do loop[n] = contig[n] end
      return loop
    end
  end
  return nil
end

return M
