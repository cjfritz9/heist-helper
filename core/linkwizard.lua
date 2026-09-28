local links = require("core.links")

local M = {}

function M.new()
  return { step = "idle" }
end

function M.start(w)
  w.step, w.anchor, w.before, w.after, w.object, w.message = "anchor", nil, nil, nil, nil, nil
end

function M.cancel(w)
  w.step, w.anchor, w.before, w.after, w.object, w.message = "idle", nil, nil, nil, nil, nil
end

function M.useAnchor(w, dx, dz, kind)
  if w.step ~= "anchor" then return false end
  w.anchor = { dx = dx, dz = dz }
  w.message = kind ~= "shadowAnchor" and "That isn't a recognised shadow anchor, but it'll be used anyway." or nil
  w.step = "before"
  return true
end

function M.useBefore(w, model, dx, dz)
  if w.step ~= "before" then return false end
  w.before = links.signature(model)
  w.object = { dx = dx, dz = dz }
  w.message = nil
  w.step = "after"
  return true
end

function M.skipBefore(w)
  if w.step ~= "before" then return false end
  w.before = links.ABSENT
  w.message = nil
  w.step = "after"
  return true
end

function M.useAfter(w, model, dx, dz)
  return M.useAfterSignature(w, links.signature(model), dx, dz)
end

function M.useAfterSignature(w, afterSignature, dx, dz, fromWatch)
  if w.step ~= "after" then return false end
  if not fromWatch and w.object and (w.object.dx ~= dx or w.object.dz ~= dz) then
    w.message = "That's a different tile from the before tag. Pick the same object."
    return false
  end
  w.after = afterSignature
  w.object = fromWatch and { dx = dx, dz = dz } or w.object or { dx = dx, dz = dz }
  w.message = w.after == w.before and "Before and after look identical, so this link can't be detected." or nil
  w.step = "review"
  return true
end

function M.markGone(w)
  if w.step ~= "after" then return false end
  if w.before == links.ABSENT then
    w.message = "It can't both appear and disappear."
    return false
  end
  w.after = links.ABSENT
  w.message = nil
  w.step = "review"
  return true
end

function M.result(w)
  if w.step ~= "review" then return nil end
  return {
    anchorDx = w.anchor.dx, anchorDz = w.anchor.dz,
    objectDx = w.object.dx, objectDz = w.object.dz,
    before = w.before, after = w.after,
  }
end

function M.status(w)
  if w.step == "idle" then
    return { step = "idle" }
  end
  local result = M.result(w)
  return {
    step = w.step,
    anchor = w.anchor and (w.anchor.dx .. "," .. w.anchor.dz) or nil,
    object = w.object and (w.object.dx .. "," .. w.object.dz) or nil,
    before = w.before,
    after = w.after,
    mode = result and links.mode(result) or nil,
    message = w.message,
  }
end

return M
