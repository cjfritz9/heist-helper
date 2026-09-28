local M = {}

function M.eq(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", label or "eq", tostring(expected), tostring(actual)), 2)
  end
end

function M.near(actual, expected, tolerance, label)
  if math.abs(actual - expected) > tolerance then
    error(string.format("%s: expected %s +/- %s, got %s",
      label or "near", tostring(expected), tostring(tolerance), tostring(actual)), 2)
  end
end

return M
