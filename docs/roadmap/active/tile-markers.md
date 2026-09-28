# Tile markers: surge tiles and looting safe spots

Tile markers are switched off (`SHOW_TILE_MARKERS = false` in `main.lua`). The drawing code (`gfx/markers.lua`), marker storage (`core/markerstore.lua`, `markers.csv`) and the run-1 data (`data/markers.lua`) are kept for this.

## Goal

Two optional marker sets, each switched on or off in the panel:

1. **Surge tiles:** the best tiles to surge from, including the setup tile you stand on before a surge.
2. **Looting safe spots:** tiles where you can loot a corpse without the ghost spawn detecting you.

## Plan

- Store markers relative to the arrival tile (as now), with a `kind` (`surge`, `surgeSetup`, `safeSpot`) and an optional link to an object (e.g. which corpse a safe spot belongs to).
- Give each kind its own colour, and a panel toggle to show or hide it.
- Dev tools to set them up:
  - **Mark tile as …** buttons for each kind, for the tile you're standing on
  - remove or retag the marker you're standing on
  - safe spot → corpse association (nearest corpse by default)
- Ship the finished sets as bundled data (like `data/links.lua`), with an in-game file that overrides them.
- Optionally, dim safe-spot markers once their corpse reaches 5/5.

## Open questions

- Should surge markers show direction (setup tile → landing tile)?
- Does a safe spot depend on which way the ghost spawns?
