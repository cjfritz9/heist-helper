# Changelog

## 0.6.0 (unreleased)

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
