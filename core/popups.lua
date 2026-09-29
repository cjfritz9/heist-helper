local M = {}

M.PLAYER_BOX = { left = 250, right = 450, above = 350, below = 100 }
M.MOUSE_BOX = { left = 300, right = 300, above = 200, below = 200 }

function M.inside(box, cx, cy, x, y)
  return x >= cx - box.left and x <= cx + box.right and y >= cy - box.above and y <= cy + box.below
end

return M
