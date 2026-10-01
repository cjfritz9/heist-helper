# Porting to the official plugin API

Heist Helper runs on Bolt, which only shows a plugin what the game draws. The plan is to move it to RS3's official plugin API once that exists. This file sorts the code by how it's likely to port, so new work keeps that path open. Keep it up to date when modules are added or change role.

What the official API will actually offer is unknown. The guesses below assume the kind of thing such APIs usually expose:

- object and NPC ids with true (server) positions;
- your own position and actions;
- chat lines and click targets as events;
- inventory contents;
- a tick event;
- drawing and UI primitives.

## Principles

- **Game logic lives in `core/`, as plain Lua over plain data.** None of `core/` touches Bolt, and it should stay that way.
- **Bolt-specific detection lives in `game/` and `gfx/`.** That covers reading models, pixels and screen captures, and turning them into facts.
- **Inputs to `core/` should be the facts an official API would give directly.** For example: "ghost g on tile T at tick N", "you clicked object X", "chat line L", "the bag holds N". Then a port swaps the adapter, not the logic.
- **When something is inferred, keep the inference in its own step.** Examples: a ghost's drawn lag, a click target from the cross and mouseover text, a section from checkpoints. That way it can be dropped when the API reports the fact directly.

## Keep: vault knowledge and logic

These describe the heist itself and should carry over as they are.

| Module | Notes |
|---|---|
| `core/maze.lua`, `core/mazepatterns.lua`, `data/maze.lua`, `data/mazeshapes.lua` | Barrier rows, the three shapes, route planning. The lit path may still need reading somehow, but the matching and routing don't care how. |
| `core/runstate.lua`, `core/status.lua`, `core/levels.lua`, `core/rewards.lua`, `data/vault.lua` | Run progress, splits, what's left, level gates, loot values. |
| `core/checkpoints.lua`, `data/checkpoints.lua` | Section detection by position. Could be replaced if the API names the section. |
| `core/objectmap.lua`, `data/objects.lua`, `core/links.lua`, `core/linkwizard.lua`, `data/links.lua` | Where objects are relative to the arrival tile, and which anchor powers which chest. Object kinds would come from ids rather than model fingerprints. |
| `core/runlog.lua`, `core/lobby.lua` | Run stats and the entrance area. |
| `core/visionring.lua`, `core/spawntimer.lua`, `data/ghostspawns.lua` | Vision ring tile mask, the 12-tick spawn timer, spawn tiles. |
| `core/ghostpaths.lua`, `data/ghostpaths.lua` (tiles, heights, stalls) | Patrol loops as tick timelines. Still useful for predicting where a ghost goes next. |
| `core/coords.lua`, `core/json.lua`, `core/rollinglog.lua`, `core/chatlines.lua`, `core/nearby.lua`, `core/hull.lua`, `core/pips.lua` | General helpers. |

## Adapt: logic fed by inferred data today

| Module | Today | With an official API |
|---|---|---|
| `core/ghostsync.lua` | Syncs each patrol from the drawn ring plus a per-tile lag table (`lag` in `data/ghostpaths.lua`), and draws the outline one tile ahead of the drawn ghost. | If NPC true tiles are given, sync from them directly, and the lag table and one-ahead rule go away. Route prediction stays. |
| `core/ghosttrack.lua` | Tells ghosts apart by matching vision rings frame to frame. | Track by NPC id. |
| `core/truetile.lua`, `core/latency.lua` | Models your server tile from clicks, ticks and an estimated round trip. | Unnecessary if your true tile is given. Keep the "next maze step" logic, fed by the real tile. |
| `core/anchor.lua` | Finds each instance's offset from the arrival teleport or a recognised object. | The instance origin may be exposed directly. |
| `core/tickphase.lua`, `core/tickclock.lua` | Places ticks on our clock from XP drops and movement starts, with drift. | Replace with the API's tick event if there is one. |
| `core/clicktarget.lua` | Infers a click's target from the click cross and the mouseover text. | Replace with click events. |
| `core/lootpopups.lua`, `core/tooltip.lua`, `core/stacklabels.lua` | Read loot popups, the bag tooltip and battery stack numbers from pixels. | Replace with inventory and bag values if exposed. The pairing and reconciliation rules may still be useful. |

## Replace: Bolt workarounds

These exist only because Bolt shows drawing, not game state.

- **Model identity:** `core/catalog.lua`, `game/signature.lua`, `game/objects.lua`, `core/picking.lua`, `gfx/picker.lua`.
- **Pixel reading:** `game/inventory.lua`, `game/lootcounter.lua` (its reading side), `game/lootprobe.lua`, `game/xpdrops.lua`, `game/clicks.lua`, `data/popupfont.lua`, `data/tooltipfont.lua`, `data/icons.lua`, `data/clicktargets.lua`, `core/digitfont.lua`.
- **Chat scraping:** `game/chatlog.lua`, `modules/chat/`.
- **Screen capture for the maze:** `game/mazegrid.lua`, `ui/capture.html`, the capture part of `game/mazeroute.lua`.
- **Ghost detection from drawn rings:** the detection side of `game/visionrings.lua`.
- **Rendering:** `gfx/lines.lua`, `gfx/objects.lua`, `gfx/markers.lua`, `gfx/lootoverlay.lua`, `game/minimap.lua` (minimap projection from Bolt's events).
- **UI host:** `game/panel.lua`, `ui/panel.html`, `ui/tab.html`. The panel content may port; the embedded-browser plumbing won't.
- **Tick sources:** `game/ticksync.lua`.

## Review before submitting

- **Keep patrols drawn out of view** (`ghostsUnseen` in `core/levels.lua`, `ghostsync.unseen`): draws synced patrols when their ghost isn't on screen. The user's view is that the routes are fixed and fully known, so this reveals nothing; the design report's compliance section lists patrol prediction beyond what's on screen as a risk. Decide before submitting, and remove it if in doubt.

## Drop: research tools

These were built to find things out in game and won't be needed in a port:

- `game/watch.lua`, `core/watchlog.lua`, `core/watchdetail.lua`, `gfx/area.lua`
- `core/compare.lua`, `core/recording.lua`, `game/recorder.lua`, `core/probediff.lua`
- `game/xpprobe.lua`, `game/clickprobe.lua`, `game/imageprobe.lua`
- `core/poslog.lua`, `core/markerstore.lua`, `core/markerdata.lua`, `data/markers.lua`, `tools/build_markers.lua`
- `core/routeassembly.lua`, `core/ghostroutes.lua`, `tools/ghostroutes.lua`: their output, `data/ghostpaths.lua`, is what's kept.

## `main.lua`

`main.lua` wires everything to Bolt's events and is the most Bolt-specific file. It also runs into LuaJIT's limits: 200 locals per function, 60 upvalues per closure. Moving its feature wiring into small `game/` adapters, each turning Bolt events into the facts above, would shrink what a port has to rewrite. That can happen gradually, as features are touched.
