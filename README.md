# Heist Helper (Bolt plugin)

A display-only Bolt plugin for the Vault of Hereditas heist. The design, feature list and compliance rules are in [the design report](../research/reports/vault-of-hereditas-plugin.md).

## Status

The plugin only runs inside the Vault of Hereditas. Outside it the panel is hidden and nothing is drawn or read. It wakes up when you teleport in, or when it recognises a vault object after a restart mid-run.


**Object highlighting (0.7.0).** Inside the vault, every unlooted chest, safe, rare chest and corpse gets an outline around its model: yellow for chests (shadow chests use the same model; grey while a shadow chest is still locked), cyan for safes, magenta for the rare chest, orange for corpses, and purple for shadow dials until you use them. The teleport marks the dial you used and its partner at the landing spot. Outlines are 4 px thick. An outline disappears once the object is looted:

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

### Panel

A small panel sits over the game. Drag it by its title bar, and collapse it to an **H** tab with ▾. Click the tab to reopen it, or drag it to move it.

- **Section:** chests, safes, corpses and rare chest left in the section you're in. Types with nothing left are hidden, and once nothing is left the block shows **✓ Section complete** (the Vault block does the same with **✓ Vault complete**). Rummage progress shows as pips above the corpse in game. Sections follow the wiki (1 → legionary barrier → 2 → shadow dial → 3 → praetorian barrier → 4) and change at checkpoints, both ways. Arriving puts you in section 1, the shadow dial you use sets 3 (or 2 coming back), and coming within 2 tiles of a barrier marker on its floor sets that marker's section. The section is saved in `run.csv`. An object counts toward a section once its section is known, either from `data/objects.lua` or learned when you loot it (saved in `objects.csv`, only once all four barrier markers are set).
- **Vault:** the same counts for the whole vault, and the loot split by section: gained against available for sections 1–4 (only what your level toggles allow). The section block's title shows the same for your section.
- **⚙ Your levels:** **Thieving 102+** (safes) and **Agility 72+** (crevices), both on by default and saved to `levels.csv`. Turning one off removes what it gates from the counts and from the outlines in game.
- Linked shadow anchors are outlined in teal until their linked object changes, which marks them powered. Anchors without a link (anchor 6) are outlined too, and marked powered when the battery stack's number changes while you're within 3 tiles of them. Pick the battery once in dev (**Pick battery**, then middle-click the batteries in your inventory, saved to `battery.csv`). Without a pick, it's learned the first time a linked anchor is powered. Bolt only sees what the game draws, so this works best with the inventory visible. Without it: if the battery count has gone down when the inventory is next drawn, the anchors you stood next to while it was hidden are marked; and clicking an anchor, then standing next to it for 3 seconds without the batteries in view, marks it too (a failed attempt would be marked as well). For linked anchors, the battery check is a fallback, since their links work without the inventory.
- **Maze route** (turn it on in ⚙): when you click a shadow crystal, the lit path through the centre room is read from 4 screen captures over the next few seconds, matched against the maze's three known shapes, and once you're in the maze, the fastest route from your tile to the next room is drawn on the floor: filled tiles to click, 2 per running tick, the next one bright green and the rest blue, joined by a green line. It only shows while the game shows the path. The rows flush against each barrier are always safe, so the route can use them.
- **Loot bag counter:** the bag's point total is drawn over the loot bag in your inventory and shown in the panel (**Loot N/500**). It comes from the game's "N Loot Gained" popups, each paired with a loot action that could produce that value (a corpse rummage, or a chest, safe or rare chest opening), minus 20 per catch, and hovering the bag corrects it from the tooltip's "Loot Stored: N". Popups with digits the plugin hasn't learned yet (4, 7, 8, 9) are skipped and logged.
- The panel's height fits its content exactly: every row is always shown, with **–** until there's a value.
- **dev** shows developer tools:
  - **Tag object**, then middle-click an object (no modifier keys) to tag it
  - **Mark tile** and **Log tile**
  - **Section checkpoints:** one button per barrier side (legionary: section 1 and 2 sides; praetorian: section 3 and 4 sides). Stand 1–2 tiles from the barrier on that side and press it. Saved to `checkpoints.csv`. **Loot with a section** shows how many loot objects have one.
  - **Maze:** West, North, East and South buttons. Stand on one end of the 5-tile row flush against that barrier and press, then the other end. **Path** shows lit tiles, the leg and the route length.
  - **Pick battery**, then middle-click the batteries in your inventory, to set the stack watched for anchor powering. **Battery stack** shows whether it's known.
  - **Pick loot bag**, then middle-click the loot bag, if the default doesn't match yours. `loot.log` records what the counter does (counted, ignored, reconciled, caught) and bitmaps of any popup or tooltip digit it doesn't know yet.
  - **Map objects:** how many objects have a recorded height, and **Behind crevice ⇄**, which marks the tagged and selected chest, safe or corpse as behind a crevice (or unmarks it). Tagging works from up to 20 tiles away, so you don't need to reach the object. Marks go to `crevices.csv`, which replaces the crevice flags in `data/objects.lua` once it exists.
  - the top 3 models from the last tag, with buttons to add the selected one to the catalogue. Added models go to `catalog.csv` and are recognised straight away.
  - **Before / after check:** tag an object, **Set as before**, change its state, tag it again, **Set as after**. The panel lists every value Bolt reports for both and highlights what changed.
  - **Watch object:** choose a centre (**Watch selected** or **Watch my tile**) and size the area with **−/+** (shown as a green square; it starts at 2 tiles around the centre, up to 16). **Watch maze** watches the whole section 4 centre room. Let it learn the background, **Open window**, trigger the change, then **Close window**. The panel lists everything on or next to it that appears or disappears, including one-frame flickers. `watch.log` also gets every frame's detail changes (draw count, position, scale, matrix, texture, colour, animation pose) while the window is open. In link step 3, **Use as after** turns a watched flicker into the link's trigger.
  - **Link an anchor:** a 3-step flow that ties a shadow anchor to the object it controls. Tag the unpowered anchor, tag the object, power the anchor, tag the object again, then save. After that the anchor is marked powered automatically when its object changes. Links are saved to `links.csv`.

### Controls

| Input | Action | Flash |
|---|---|---|
| **Alt + Middle Click** | *(off while tile markers are disabled)* Toggle a marker on the tile you're standing on | White = added, orange = removed |
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
| `core/objectmap.lua` | Object positions (relative to the arrival tile) and heights, and which are behind a crevice; seeded from `data/objects.lua` |
| `core/checkpoints.lua` | Barrier-side markers and dial directions that set your section |
| `data/checkpoints.lua` | Bundled checkpoint markers and which section each shadow dial leads to |
| `core/levels.lua` | The Thieving 102 and Agility 72 toggles and what each one gates |
| `core/probediff.lua` | Set differences and timestamped log lines, used by the recorder |
| `game/recorder.lua` | Automatic recording around unlinked shadow anchors into `record.log` |
| `core/recording.lua` | When the recorder starts and stops, and its snapshot format |
| `core/links.lua` | Anchor → object links, and the rules that decide when an anchor counts as powered |
| `core/linkwizard.lua` | The 3-step anchor link flow |
| `game/signature.lua` | Model identity (vertex count, fingerprint, animation flag, colour hash), shared by tagging and scanning |
| `core/compare.lua` | Field-by-field comparison for the before / after check |
| `core/nearby.lua` | Nearest object of a kind, and teleport detection |
| `core/watchlog.lua` | Baseline and change tracking for Watch object |
| `game/lootcounter.lua` | The loot bag counter: reads popups, pairs them with loot actions, reconciles from the tooltip, draws the total, keeps `loot.log` |
| `game/lootprobe.lua` | Pixel hashes and black-and-white bitmaps of 2D images |
| `core/rollinglog.lua` | Log buffer that keeps only the most recent lines |
| `core/lootpopups.lua` | Reads "N Loot Gained" popups from glyph images and counts each once as it rises |
| `data/popupfont.lua` | Pixel hash → character for the popup font |
| `core/tooltip.lua` | Reads "Loot Stored: N" from the loot bag's tooltip, for reconciliation |
| `data/tooltipfont.lua` | Pixel hash → character for the tooltip font |
| `core/digitfont.lua` | Tiny outlined pixel font rendered to RGBA |
| `gfx/lootoverlay.lua` | Draws the bag total over the loot bag icon |
| `data/icons.lua` | Default inventory icon identities for the battery and the loot bag |
| `core/mazepatterns.lua` | Builds each leg's known maze shapes and matches lit tiles against them |
| `data/mazeshapes.lua` | The three maze shapes from the wiki, and how each leg's frame maps onto the room |
| `ui/capture.html` | Hidden 1×1 page that reads the maze's lit tiles from screen captures |
| `core/maze.lua` | Barrier rows, lit-tile memory while the path shows, and the fastest running route |
| `game/mazeroute.lua` | Maze route in game: barrier row mapping, screen capture on in section 4, route and its drawing |
| `data/maze.lua` | Bundled barrier rows |
| `game/mazegrid.lua` | Screen positions of the tile corners around the maze, saved with each screen capture |
| `core/popups.lua` | The screen areas read around the character and around the mouse |
| `core/anchorclick.lua` | Click fallback: an anchor clicked and then stood next to with no batteries in view |
| `core/stacklabels.lua` | Stack numbers over inventory icons (as atlas glyph positions), their changes, and learning which icon is the battery |
| `game/inventory.lua` | Collects inventory icons and small 2D glyphs each frame |
| `core/watchdetail.lua` | Per-frame detail for Watch object (draw count, position, scale, matrix, texture, colour, pose) and what changed |
| `game/watch.lua` | Records models, particles and billboards around the watched tile |
| `gfx/area.lua` | Draws the Watch object area on the ground |
| `core/json.lua` | Minimal JSON encoder for panel status messages |
| `core/status.lua` | Builds the panel's status: what's left in your section and the vault, progress, object mapping coverage |
| `game/panel.lua` | Opens the panel or tab, remembers its position, passes button presses to their actions |
| `ui/panel.html`, `ui/tab.html` | The panel and its collapsed tab |
| `core/pips.lua` | Layout of the rummage-progress pips |
| `core/hull.lua` | Convex hull used for the model outlines |
| `data/links.lua` | Bundled anchor → object links, overridden per anchor by `links.csv` |
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
| `tools/simulate.lua` | Runs `main.lua` against a fake Bolt through a scripted scenario (`luajit tools/simulate.lua`) |
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
4. Add a local plugin and pick this folder's `bolt.json`. In the Windows file picker it's under `\\wsl.localhost\<distro>\<path to>\heist-helper` (run `wslpath -w .` in this folder to get the exact path).
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
