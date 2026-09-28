# Vault of Hereditas (Bolt plugin)

A display-only Bolt plugin for the Vault of Hereditas heist. The design, feature list and compliance rules are in [the design report](../research/reports/vault-of-hereditas-plugin.md).

## Status

**Object highlighting (0.7.0).** Inside the vault, every unlooted chest, safe, rare chest and corpse gets an outline around its model: yellow for chests (shadow chests use the same model), cyan for safes, magenta for the rare chest, orange for corpses. An outline disappears once the object is looted:

| Object | How the plugin knows it's looted |
|---|---|
| Chest, rare chest | The game swaps in the opened model |
| Safe | The model stops animating once cracked |
| Corpse | Five `You loot …` chat lines while it's the nearest recognised object within 3 tiles (pips above it show progress). `You've taken everything you can from that target.` finishes it early as a backup |

Vault instances land in a different place on the map each run, always shifted by whole 64-tile regions. The plugin finds each run's arrival tile (its **anchor**) automatically:

- when you arrive, from the teleport onto a tile at the arrival height that sits on the right place in the 64-tile grid
- otherwise from any recognised object whose position relative to the arrival tile is known (`data/objects.lua`, plus `objects.csv`, which grows as the plugin sees more objects)

The anchor and the looted corpses are saved to `run.csv`, so restarting the plugin mid-run keeps them. `Completion Time: …` in chat resets the looted state for the next run. Tile markers are placed relative to the same anchor.

Chat needs **timestamps turned on**, and the chat box must be visible and scrolled to the bottom.

### Controls

| Input | Action | Flash |
|---|---|---|
| **Alt + Middle Click** | Toggle a marker on the tile you're standing on: removes it if there is one, adds one if not. Takes effect immediately | White = added, orange = removed |
| **Shift + Middle Click** | Log your tile to `positions.csv` for mapping | Green |
| **Ctrl + Middle Click** on an object | Tag it: records the 3D models under the cursor (up to 8, smallest first) to `tags.csv`, with vertex count, animation flag, tile, on-screen size, shape and texture hashes, and the time of the latest chat line | Cyan = tagged, red = nothing found |
| *(automatic)* | While you're in the vault, new chat lines are appended to `chat.log`. **Needs chat timestamps turned on**, and the chat box must be visible and not scrolled up | None |
| Either, while your position is unknown | Nothing. Walk a tile and retry | Red |

Marker edits are saved to `markers.csv` in the plugin's Bolt config folder and loaded on the next start. That file takes priority over `data/markers.lua`: to go back to the generated markers, delete `markers.csv` and restart the plugin. Code changes still need a plugin restart; marker edits don't. The reward maths (F1) and the level-based reachability model (F2) are written and unit-tested, but they aren't shown on screen yet.

## Layout

| Path | What it is |
|---|---|
| `bolt.json` | Bolt plugin manifest |
| `main.lua` | Entry point: tile markers plus the position logger |
| `core/coords.lua` | World units to tile and chunk conversion (512 units per tile, 64 tiles per chunk; X is east, Z is north) |
| `core/poslog.lua` | CSV rows for the position log |
| `core/markerstore.lua` | Saves and loads edited markers; toggles a marker on a tile |
| `core/chatlines.lua` | Splits chat lines into timestamp and text |
| `core/catalog.lua` | Known object models (vertex count + fingerprint) and their looted state |
| `core/anchor.lua` | Finds each run's arrival tile from arrival or from a recognised object; vault bounds |
| `core/runstate.lua` | Current anchor, looted corpses, chat events that change them; saved to `run.csv` |
| `core/objectmap.lua` | Object positions relative to the arrival tile; seeded from `data/objects.lua` |
| `core/probediff.lua` | Set differences and log lines for the shadow anchor probe |
| `game/probe.lua` | Records models, particles and billboards around a nearby shadow anchor and logs what changes |
| `core/pips.lua` | Layout of the rummage-progress pips |
| `core/hull.lua` | Convex hull used for the model outlines |
| `data/objects.lua` | Object positions measured during the tag runs |
| `game/objects.lua` | Recognises catalogued models each frame and projects their outline points |
| `gfx/objects.lua` | Draws the outlines |
| `core/picking.lua` | Screen boxes, model fingerprints and `tags.csv` rows for object tagging |
| `gfx/picker.lua` | Finds the 3D models under the cursor on the frame after a Ctrl + Middle Click |
| `core/markerdata.lua` | Turns a mapping CSV into markers relative to the arrival tile; nearby-marker lookup |
| `data/markers.lua` | **Generated** marker data. Don't edit by hand |
| `gfx/lines.lua` | Shader-based line and quad drawing (adapted from bolt-groundmarkers, see `THIRD_PARTY.md`) |
| `game/chatlog.lua` | Finds the chat box by its speech-bubble icon and passes new lines on |
| `modules/chat/` | Vendored bolt-chatmodule, which reads chat text (public domain, see `THIRD_PARTY.md`) |
| `gfx/markers.lua` | Projects markers onto the game view and draws them |
| `tools/build_markers.lua` | Regenerates `data/markers.lua` from a mapping CSV |
| `mapping/` | Mapping runs: raw logs, cleaned CSVs, plots |
| `core/rewards.lua` | Bag cap, rare chest halving, XP, common rolls, interpolated rare rates |
| `data/vault.lua` | Static heist data: sources, penalties, sections, crevice gates, reachability |
| `tests/` | Plain-Lua test runner and suites; no Bolt needed |

Everything under `core/` and `data/` is pure Lua with no dependency on Bolt, so it runs and tests outside the game. `gfx/` and `main.lua` need Bolt.

## Regenerating markers

```bash
luajit tools/build_markers.lua mapping/run1.csv > data/markers.lua
```

The CSV's first row must be the arrival tile. Every other row becomes an offset from it, and duplicate tiles are merged. Then turn the plugin off and on in Bolt to reload it. If drawing, tagging or chat reading fails in game, the first error of each kind is saved to `error.log` in the plugin's Bolt config folder, next to `positions.csv`.

## Development

```bash
sudo apt install luajit
luajit tests/run.lua
```

Run the tests from this folder. Bolt runs plugins on LuaJIT (Lua 5.1), so avoid Lua 5.2+ features.

## Running it in Bolt (Windows)

1. Download https://bolt.adamcake.com/Bolt-Windows.zip (v0.24.0 at the time of writing), extract it to its own folder, and run `bolt.exe`. It's unsigned, so Windows SmartScreen may warn you.
2. Log in with your Jagex account from Bolt's Log In button.
3. Turn on the plugin loader in Bolt's RS3 settings.
4. Add a local plugin and pick this folder's `bolt.json`. In the Windows file picker it's under `\\wsl.localhost\<distro>\<path to>\vault-of-hereditas` (run `wslpath -w .` in this folder to get the exact path).
5. Launch RS3 from Bolt. **Don't use the in-game Vulkan beta renderer**: Bolt's plugins only hook OpenGL and won't load under Vulkan.

Shift + Middle Click flashes a **green square** in the top-left corner when a tile is logged, or a **red square** when the player's position isn't known yet (walk a tile and retry). `print` output isn't visible on Windows, so the flash is the only feedback.

## Phase 0: mapping the vault

1. Enter the vault. Stand on the tile you arrive on and Shift + Middle Click first, so later positions can be made relative to it.
2. Stand next to each loot source, anchor and hazard and Shift + Middle Click. Keep a numbered list alongside, for example `3 = section 1 chest`, because there's no in-game way to label rows.
3. Rows are written to `positions.csv` in the plugin's Bolt config directory, somewhere under a `bolt-launcher` folder in your Windows AppData: `n,worldX,worldY,worldZ,tileX,tileZ,chunkX,chunkZ,localX,localZ`. `worldY` is height and follows the terrain, so it is not a floor number.

Instances are placed at different world coordinates each time, so the stable data is the **offset from the arrival tile**, not the absolute tile. Map it twice to confirm the offsets match.

## Assumptions to verify in game

- Leaving without the rare chest halves points **rounded down**.
- Luck multiplies the rare rate (tier 4 gives ×1.03) rather than adding 3 percentage points.
- Rare-rate interpolation is linear in probability between anchors. This matches the wiki's 157 points ≈ 1/172.5 example.

## Credits

The tile and chunk constants follow [bolt-groundmarkers](https://github.com/J3sven/bolt-groundmarkers) by J3sven (MIT).
