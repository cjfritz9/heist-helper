# Changelog

## 0.8.0 (unreleased)

- Corpses are finished after 5 `You loot …` lines instead of relying on `You've taken everything you can from that target.`, which only appears when you try an empty corpse. That message is still used as a backup.
- A loot line counts toward a corpse only when the corpse is the nearest recognised object within 3 tiles, so chest and safe loot isn't miscounted. Ties aren't guessed.
- Rummage counts are saved in `run.csv` and survive a plugin restart.
- Five pips above each corpse's outline show rummage progress.
- Shadow anchor probe: while you're within 3 tiles of a recognised shadow anchor, every model, particle and billboard drawn within 3 tiles of it is summarised each second, and changes are logged to `probe.log`, to find what shows an anchor is powered. Model entries include a vertex-colour hash (`c…`) to catch tint changes.
- Complete object map in `data/objects.lua`: 13 chests (including shadow chests), 8 safes, the rare chest, 8 corpses and 6 shadow anchors, recorded automatically across four instances.
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
