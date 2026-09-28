local links = require("core.links")
local assert = require("tests.assert")

local T = {}

local closed = { vertices = 3444, fingerprint = "9f69f595", animated = false, colour = "11111111", textureHash = "aaaaaaaa" }
local open = { vertices = 3264, fingerprint = "8eaac06a", animated = false, colour = "22222222", textureHash = "bbbbbbbb" }

local link = function(before, after)
  return { anchorDx = -8, anchorDz = -63, objectDx = -3, objectDz = -60, before = before, after = after }
end

function T.signature_and_vertex_count()
  local sig = links.signature(closed)
  assert.eq(sig, "3444:9f69f595:0:11111111:aaaaaaaa", "signature")
  assert.eq(links.vertexCount(sig), 3444, "vertex count")
end

function T.texture_only_change_is_a_change()
  local shadow = { vertices = 3444, fingerprint = "9f69f595", animated = false, colour = "11111111", textureHash = "cccccccc" }
  assert.eq(links.mode(link(links.signature(shadow), links.signature(closed))), "change", "texture differs")
end

function T.modes()
  local a, b = links.signature(closed), links.signature(open)
  assert.eq(links.mode(link(a, b)), "change", "change")
  assert.eq(links.mode(link(links.ABSENT, b)), "appear", "appear")
  assert.eq(links.mode(link(a, links.ABSENT)), "disappear", "disappear")
  assert.eq(links.mode(link(a, a)), "none", "none")
end

function T.put_replaces_link_for_same_anchor()
  local set = links.new()
  links.put(set, link("x", "y"))
  links.put(set, link("x", "z"))
  assert.eq(#set.list, 1, "one per anchor")
  assert.eq(set.list[1].after, "z", "replaced")
end

function T.encode_decode_round_trip()
  local set = links.new()
  links.put(set, link(links.signature(closed), links.ABSENT))
  local restored = links.decode(links.encode(set))
  assert.eq(#restored.list, 1, "count")
  assert.eq(restored.list[1].objectDz, -60, "negative offset")
  assert.eq(restored.list[1].after, links.ABSENT, "absent kept")
end

function T.is_linked_by_anchor_offset()
  local set = links.new()
  links.put(set, link("x", "y"))
  assert.eq(links.isLinked(set, -8, -63), true, "linked")
  assert.eq(links.isLinked(set, 5, -25), false, "other anchor")
end

function T.saved_links_override_bundled_ones_per_anchor()
  local seed = { link("seedBefore", "seedAfter"), {
    anchorDx = 5, anchorDz = -25, objectDx = -5, objectDz = -16, before = "a", after = "b" } }
  local set = links.withSeed(seed, "-8,-63,-3,-60,userBefore,userAfter\n")
  assert.eq(#set.list, 2, "merged")
  assert.eq(set.list[1].before, "userBefore", "user link wins")
  assert.eq(set.list[2].after, "b", "other bundled link kept")
end

function T.bundled_links_cover_the_five_chest_anchors()
  local set = links.withSeed(require("data.links"), nil)
  assert.eq(#set.list, 5, "five links")
  for _, l in ipairs(set.list) do
    assert.eq(links.mode(l), "change", "each link changes")
  end
end

function T.watched_vertex_counts_skip_absent()
  local set = links.new()
  links.put(set, link(links.ABSENT, links.signature(open)))
  local counts = links.watchedVertexCounts(set)
  assert.eq(counts[3264], true, "after model watched")
end

function T.change_and_appear_trigger_on_after_signature()
  local a, b = links.signature(closed), links.signature(open)
  assert.eq(links.poweredNow(link(a, b), { [a] = true }, true, {}), false, "still before")
  assert.eq(links.poweredNow(link(a, b), { [b] = true }, true, {}), true, "after seen")
  assert.eq(links.poweredNow(link(links.ABSENT, b), { [b] = true }, false, {}), true, "appeared")
end

function T.disappear_needs_sustained_absence_while_near()
  local a = links.signature(closed)
  local l, tracker = link(a, links.ABSENT), {}
  for _ = 1, links.DISAPPEAR_FRAMES - 1 do
    assert.eq(links.poweredNow(l, {}, true, tracker), false, "not yet")
  end
  assert.eq(links.poweredNow(l, {}, true, tracker), true, "gone long enough")
  tracker = {}
  for _ = 1, links.DISAPPEAR_FRAMES + 5 do
    assert.eq(links.poweredNow(l, {}, false, tracker), false, "far away never counts")
  end
end

return T
