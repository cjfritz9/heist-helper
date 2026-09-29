# Changelog

## 0.12.0 (unreleased)

- The panel shows what's left in your **current section** above the whole **Vault**.
- Sections change at checkpoints, both ways: arrival (1), the shadow dial (3 going, 2 coming back) and markers on each side of the legionary and praetorian barriers. The current section is saved in `run.csv`. Height isn't used for sections: parts of section 2 share heights with sections 3 and 4.
- Dev panel, **Section checkpoints:** four buttons, one per barrier side, saved to `checkpoints.csv`.
- Each object's section is learned when you loot it (once all four markers are set) and saved in `objects.csv`. `data/objects.lua` can carry sections too.
- Finding the run from a recognised object (after a restart) now also needs the object's height to match, within 32 units. This stops reused vault models elsewhere, like near the entrance, from being taken for vault objects and switching the plugin on outside the vault. Every object's height is bundled in `data/objects.lua`.
- Bundled: the four barrier markers (`data/checkpoints.lua`); sections for every loot object, checked against the wiki's per-section counts; crevice flags on the three crevice objects (`data/objects.lua`).
- **⚙ Your levels:** **Thieving 102+** and **Agility 72+** toggles, on by default, saved to `levels.csv`. Without 102 Thieving, safes drop out of the counts and lose their outline; without 72 Agility, so does anything marked as behind a crevice.
- Object heights are recorded as the plugin sees each object and saved in `objects.csv` (older rows without a height still load).
- Dev panel, **Map objects:** heights recorded so far, and **Behind crevice ⇄** to mark the tagged and selected loot object as behind a crevice. Tagging reaches 20 tiles, so it works from across the crevice. Marks are saved to `crevices.csv`.
- Removed **Powered ⇄** and the anchors-powered line from the panel. Linked anchors still update their outlines automatically.
- Watch object logs much more to `watch.log` while the window is open. Every frame, for each model on the watched tiles, it records how many times the model is drawn, its position, scale, full model matrix, texture ID, the summed colour of every vertex, and the animation pose of animated models. For particles and billboards it records their count and colours. Any change from the previous frame is logged as a `~` line. When the window opens, it writes a full snapshot and how many variants of each thing it saw during the background. This goes after a flash that changed none of the old signature fields.
- Watch object's area starts at radius 2 (5×5). It also includes models whose centre is elsewhere but whose geometry reaches into the area, like shared scenery meshes. Each such model is checked once per watch.
- Battery detection for anchors without a link (anchor 6). The plugin reads the stack number in the top half of each inventory icon as the positions of its digit images in the game's texture atlas, without reading the number itself. Pick the battery in dev (**Pick battery**, then middle-click the batteries in your inventory), saved to `battery.csv`. If none is picked, the one stack that changed while you stood next to a linked anchor as it was powered is learned instead. A battery change within 3 tiles of a shadow anchor marks that anchor powered. Changes while the mouse is over or near the batteries, or within a second of leaving them, are ignored, because the item tooltip draws text over the icon. Logged glyphs include their colour. The battery stack disappearing (the last 10 used on anchor 6) also counts, as long as other inventory icons are still drawn in that frame.
- Fixed: being caught in section 2 sends you back to the arrival tile, which was taken for a new run and cleared everything looted. Landing on the arrival tile now only starts a new run when you came from outside that vault; otherwise the run is kept and the section goes back to 1.
- **Loot bag counter:** the bag's running point total is drawn over the loot bag icon, and shown in the panel as **Loot N/500**. It reads the game's "N Loot Gained" popups: each character is its own image, identified by its pixel hash (`data/popupfont.lua`). Each popup is counted once as it rises, including overlapping ones. A catch subtracts 20 (the wiki's figure, not yet checked). Saved in `run.csv`. Popups animate in from the right with the number last, so each is tracked by position (either edge) and counted once, when its number is first fully readable. A popup partly out of view ("15LootGa") still counts as the same popup, the area around the character is wider (the popup is about 210 px wide), and a lost popup is kept for 1 second, which fixes a popup being counted again about 1.7 s later. Each popup is read every frame and keeps its best reading (the most digits), so a frame where part of it is missing can't count "5" for a 15; it's counted 0.3 s after it first reads, or when it disappears. Each popup is also paired with a loot action within 1.5 s either side: a corpse rummage (from the "You loot …" line with a corpse next to you), or a chest, safe or rare chest seen opening. A popup only pairs with an action that could produce its value: corpse 2, 4 or 6; chest 10 or 15; safe 30; rare chest 50. So a leftover chest "+10" can't take a rummage's place (that had made section 1 read 38 instead of 30). A popup reading with no action left to pair with is ignored and logged, which drops the extra readings of a popup covered by the cursor or flying to the bag at the end (those had added up to 11 extra +2s at once). Replaying two bad stretches from real runs gives exactly the true 60, where the old counting gave 236. A catch was confirmed to cost 20 by reconciliation. New popups appear below older ones, which only rise. Popups with a digit not in the font yet (4, 7, 8 and 9 so far) are logged to `loot.log` with their bitmaps, not guessed. The probe also logs the bitmaps of the small glyphs and larger images around the mouse over the bag, to read its tooltip for reconciliation.
- **Performance:** the loot probe's logging is removed (every change in text, images and billboards around the character, with a full pixel hash per glyph every frame, and a log rewritten in full on each line had grown to 13 MB). `loot.log`, `inventory.log` and `chat.log` now keep their last 2,000 lines. Pixel hashes are cached by atlas position, glyph centres use 3 vertices, only popup-sized images near the character and tooltip-coloured glyphs near the mouse over the bag are hashed, and bitmaps are only taken of glyphs neither font knows. **Mark** is removed. The loot counter moved out of `main.lua` into `game/lootcounter.lua`.
- Panel wording: the second block is **Vault**, the total reads **Loot N/500**, and the corpse rummage pips are only in game now (not in the panel).
- **Loot split by section:** the section title shows loot gained there against what's available (for example **45/90**), and the whole-vault block has a row for all four sections (**1 30/30 · 2 45/90 · 3 0/130 · 4 0/285**, the current one highlighted). What's available counts only what your level toggles allow. Each counted popup is credited to the section of the corpse, chest or safe it came from; a catch, and any reconciliation difference, to the section you're in. The seven shadow chests are marked in `data/objects.lua` (15 points each), which makes the section totals 30, 90, 130 and 285, as on the wiki. The panel is 137 px tall (204 with ⚙).
- **Reconciliation:** hovering the loot bag shows "Loot Stored: N" in its tooltip. The plugin reads it (`data/tooltipfont.lua`, `core/tooltip.lua`), and when the same value reads twice in a row and differs from the counter, the counter takes the bag's value. Each correction is logged to `loot.log` with the difference. The tooltip font now has 4 and 6, which blocked readings like "Loot Stored: 430".
- The battery and loot bag icons have defaults (`data/icons.lua`), so picking them is only needed if they don't match.
- Loot probe, towards a loot bag counter: `loot.log` gets every change in the small text glyphs around your character on screen (the "+N" loot popups), with a pixel hash per glyph; the glyphs around the mouse while it's over the loot bag (its tooltip); every chat line; and every loot event the plugin detects (containers opened, corpse rummages). Dev panel: **Pick loot bag**, saved to `lootbag.csv`. It also logs billboards within 3 tiles of you and 2D images larger than 24 px near your character (size, colour, pixel hash), since the first probe run showed the loot popups aren't small text. **Mark** writes `MARK` to `loot.log`, to press right as you loot. The first time each large image appears, its pixels are logged as a black-and-white bitmap (`bitmap <hash> WxH: rows`), to build a digit reader for the "N Loot Gained" popup.
- Fixed: looting the chest next to anchor 6 (at 4, −97) before powering it gives batteries, which marked the anchor powered. A battery change next to an anchor now waits 2 s before marking it: if a loot action (a corpse rummage or a chest, safe or rare chest opening) happened within 2 s either side, the batteries came from the loot (they can even arrive just before the chest is seen opening), and the anchor stays outlined. So an anchor's outline goes 2 s after powering it, and the reach is 2 tiles (was 3), the most seen when really powering one.
- Fallbacks for powering an anchor with the batteries out of view: a delayed check (if the battery stack went down or disappeared while the inventory was hidden, anchors you stood next to in that time are marked powered once it's drawn again), and click detection (left-clicking an anchor's outline, then standing within 2 tiles of it for 3 seconds without the batteries visible, marks it powered). Both are logged to `inventory.log`.
- Every unpowered shadow anchor is outlined, including anchor 6 (the `OUTLINE_UNLINKED_ANCHORS` switch is gone). Every stack change goes to `inventory.log`. The inventory must be open for this to work.
- Dev panel shows whether the battery stack is known, with a **Pick battery** button.
- The panel's height fits its content exactly (119 px, 186 px with ⚙ open), with every row always shown, so there's no empty space at the bottom.

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
