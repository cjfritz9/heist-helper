# Changelog

## 0.11.0 (unreleased)

- Renamed to **Heist Helper**: plugin name, panel title, and the collapsed tab (now **H**). The folder and the GitHub repo are now `heist-helper` too, and Bolt's plugin entry points at the new folder, keeping its plugin ID and runtime files.
- Watch object keeps raw data in `watch.log`: when the window opens, every background signature with the share of frames it was seen in; while it's open, every frame's changes, including things also seen in the background. `watch.log` is written at most once a second.
- The 12-tile recorder is switched off (`RECORD_UNLINKED_ANCHORS` in `main.lua`) in favour of Watch object's small, user-set area and window.
- The recorder snapshots every frame while you're within 3 tiles of the anchor, which is where you power it, so brief animations can't fall between the 250 ms snapshots. `record.log` is written at most once a second.
- `tools/simulate.lua`: the fake-Bolt scenario used during development, now part of the project.

## 0.10.0

- Anchor links (dev panel): a guided 3-step flow links a shadow anchor to the object it controls.
  1. Tag the unpowered anchor.
  2. Tag the object before powering, or choose **Not visible yet**.
  3. Power the anchor and tag the object again, or choose **It disappeared**.
  Then review and save. Links go to `links.csv`.
- Linked objects are watched every frame, and the anchor is marked powered automatically when its object changes model, appears or disappears (the last only counts after about a second of absence while you're within 12 tiles). **Powered ⇄** stays as a manual fallback.
- Tags record each model's colour hash, and tagging and live scanning share the same model identity (`game/signature.lua`).
- Before / after check (dev panel): set a tagged object as **before**, change its state, tag it again and set it as **after**. A field-by-field table highlights what differs (model, animation, shape, UVs, colours, texture, tile, size on screen), with a one-line verdict.
- The panel scrolls when the dev section is taller than it.
- Tile markers are switched off (`SHOW_TILE_MARKERS` in `main.lua`), along with **Mark tile** and Alt + Middle Click. They'll come back as optional surge-tile and looting safe-spot markers, set up with dev tools (see `docs/roadmap/active/tile-markers.md`).
- Recorder: next to a shadow anchor with no link, the plugin records every model (with animation, colour and texture), particle and billboard within 12 tiles, 4 times a second, plus chat. A full snapshot comes first, then only what appears or disappears, all appended to `record.log`. It starts within 3 tiles of the anchor and stops beyond 15. It replaces the 3-tile anchor probe (`game/probe.lua` removed).
- Watch object results are written to `watch.log` whenever they change, not only on **Close window**.
- The plugin switches itself off outside the Vault of Hereditas: the panel closes, and nothing is drawn, read from chat, probed or watched. Middle-click shortcuts are ignored. Only position tracking and the cheap vertex-count check keep running, so it notices when you enter (by the arrival teleport, or by a recognised object after a mid-run restart). The panel reopens inside the vault.
- Watch object (dev panel): watches an area centred on the selected model or your own tile. **−/+** sets its size (1–8 tiles around the centre), and a green square shows it in game. It learns the background for as long as you let it, then records between **Open window** and **Close window**, and lists every model (with animation, colour, texture and tile), particle and billboard that appears or disappears, with frame counts. Closing the window also appends the list to `watch.log`. Things seen during the baseline are ignored, and only models present through the whole baseline can be reported as disappearing, so looping effects don't show up. During link step 3, a watched model entry can be used as the "after" state, so brief flickers work as link triggers.
- The model selected in the tag list is outlined in bright green in game while the dev section is open, so you can see which one you're about to use. A new tag selects rank 1.
- Five anchor links (the chest anchors) now ship with the plugin in `data/links.lua`. Anchor 6's link was removed: it was keyed to a 24-vertex model that can be present before the anchor is powered, so the anchor showed as powered straight away. A link saved in game (`links.csv`) overrides the bundled one for the same anchor.
- The partner shadow dial (at the dial's landing spot) is added to the object map.
- Used shadow dials lose their outline. Using a dial teleports you, so a jump of more than 8 tiles in one frame while you're within 3 tiles of a dial marks it used, along with its partner dial at the landing spot (if seen within 3 seconds). Saved in `run.csv`.
- Locked shadow chests: an unopened chest still showing the shadow texture (`bd02db92`) gets a grey outline and turns yellow once its anchor is powered. Only unopened chests have their texture read.
- Shadow anchors are outlined in teal only once they're linked, until their linked object changes. Unlinked anchors aren't outlined (`OUTLINE_UNLINKED_ANCHORS` in `main.lua`), since the plugin can't tell when they're done.
- Model identity also includes a texture hash (size and centre pixels of each texture image the model uses), since a shadow chest and a regular chest share the same geometry, UVs and colours. Tags record `colour` and `texture` columns. Tag run 4 saved in `mapping/tags-run4.csv`.

## 0.9.0

- On-screen panel (embedded browser): draggable, collapses to a small tab, and remembers its position.
  - Run status: in vault or not, current section, chests, safes, corpses and rare chest left, corpse rummage progress, shadow anchors powered.
  - **Powered ⇄** marks the shadow anchor next to you as powered. Unpowered anchors get a teal outline.
  - Dev section: **Tag object** (then middle-click an object, no modifier keys), **Mark tile**, **Log tile**, the top 3 models from the last tag with their known kind, and buttons to add the selected one to the catalogue as a corpse, chest (closed or open), safe, dial or anchor. Added models are saved to `catalog.csv` and recognised immediately.
- Looted chests, safes and the rare chest are remembered per run in `run.csv`, so the panel can count what's left.
- The modifier + middle-click shortcuts still work.
- Outlines fixed: they ignored each model's scale and sampled every nth vertex, so safes were outlined low and off-centre. Each model's extreme points (the furthest vertex in 26 directions) are now found once and projected with the model's scale every frame. That's tighter and cheaper. Tag boxes use scaled vertices too.

## 0.8.0

- Corpses are finished after 5 `You loot …` lines instead of relying on `You've taken everything you can from that target.`, which only appears when you try an empty corpse. That message is still used as a backup.
- A loot line counts toward a corpse only when the corpse is the nearest recognised object within 3 tiles, so chest and safe loot isn't miscounted. Ties aren't guessed.
- Rummage counts are saved in `run.csv` and survive a plugin restart.
- Five pips above each corpse's outline show rummage progress.
- Shadow anchor probe: while you're within 3 tiles of a recognised shadow anchor, every model, particle and billboard drawn within 3 tiles of it is summarised each second, and changes are logged to `probe.log`, to find what shows an anchor is powered. Model entries include a vertex-colour hash (`c…`) to catch tint changes.
- Complete object map in `data/objects.lua`: 13 chests (including shadow chests), 8 safes, the rare chest, 8 corpses and 6 shadow anchors, recorded automatically across four instances.
- Shadow dial (684 vertices) is recognised and always outlined in purple, since you don't return to it after using it.
- Object outlines are thicker (4 px instead of 2).
- A fourth corpse model (section 2 pose, 25818 vertices).
- Probe result: powering a shadow anchor changes nothing Bolt can see (model, colours, particles, billboards) and posts no chat line, so anchors can't be tracked automatically.
- A third corpse model (section 4 pose, 21867 vertices) and the shadow anchor model. Shadow anchors look the same powered or not, so they're only used for positioning, not highlighted.

## 0.7.0

- Object highlighting: unlooted chests, safes, the rare chest and corpses get an outline around their model, removed once looted (model change for chests and safes, chat line for corpses).
- Automatic anchoring per run: vault instances move between runs, so the arrival tile is detected on arrival or derived from any recognised object. Tile markers and chat logging follow the anchor.
- Anchor and looted corpses persist in `run.csv`. `Completion Time` in chat resets them.
- Object positions relative to the arrival tile are recorded to `objects.csv` as they're seen.
- The chat reader no longer re-records lines that were already in the chat box when the plugin started.
- Run 3 tag data and findings saved in `mapping/tags-run3.csv` and `mapping/tags-run3-notes.md`.
- A second corpse model (the section 3 pose, 15108 vertices), and support for several catalogued models sharing a vertex count.

## 0.6.0

- Tags now record a whole-model shape hash (`shape`), a texture-coordinate hash (`uv`) and the time of the latest chat line (`lastChat`), so model states can be compared and tags lined up with chat events.
- A `tags.csv` in the old format is started fresh instead of mixed with new rows.
- Run 2 tag data and findings saved in `mapping/tags-run2.csv` and `mapping/tags-run2-notes.md`.

## 0.5.0

- Chat logging inside the vault: new chat lines go to `chat.log` in the plugin config, as groundwork for counting corpse rummages. Needs chat timestamps turned on in game.
- Vendored bolt-chatmodule for reading chat text.

## 0.4.0

- Ctrl + Middle Click tags an object: the 3D models under the cursor are logged to `tags.csv` with vertex count, texture ID, world tile, on-screen size and a shape fingerprint, as groundwork for object highlighting.
- Tile markers now project with `togameview`, so they no longer shift if the game view doesn't start at the window corner.
- Draw and tag errors are saved to `error.log`.

## 0.3.0

- Alt + Middle Click toggles a marker on the tile you're standing on, with no restart needed. Edits are saved to `markers.csv` in the plugin config and override the generated markers.
- Distinct flashes: white for marker added, orange for removed, green for logged, red for unknown position.

## 0.2.0

- Tile markers for every spot logged on mapping run 1, drawn relative to the arrival tile, in white, with the arrival tile in yellow. Only markers within 48 tiles of the player are drawn.
- Marker data builder (`tools/build_markers.lua`) that turns a mapping CSV into `data/markers.lua`.
- Removed the floor column from the position log. Height follows the terrain, so it can't tell floors apart.

## 0.1.0

- Phase 0 position logger: Shift + Middle Click records your tile to `positions.csv`, with a green (logged) or red (position unknown) flash in the top-left corner.
- Reward projection maths: bag cap, rare chest halving, XP, common rolls with a fractional extra roll, and interpolated rare rates with luck.
- Static vault data with level- and crevice-based reachability (270 / 295 / 480 / 535 points).
