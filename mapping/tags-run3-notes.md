# Tag run 3 (2026-09-27)

Rows are from `tags.csv` in the 0.6.0 format, which adds `shape` (whole-model hash), `uv` (texture-coordinate hash) and `lastChat`. `dx`/`dz` are relative to the run-2 arrival tile (11299, 3243), so they're only meaningful for tags 1–6. Tags 7–9 were taken in other instances.

| Tag | Object | Rank 1 vertices | Animated | fingerprint | shape | Notes |
|---|---|---|---|---|---|---|
| 1 | Safe, before | 3456 | yes | d77d3421 | 93e1db91 | at -10, -43 |
| 2 | Safe, after | 3456 | no | d77d3421 | ed5d9406 | cracked 23:01:35 |
| 3 | Chest (shadow chest spot), before | 3444 | no | 9f69f595 | 23d533a3 | at 15, -73; same model as regular chests |
| 4 | Same chest, after | 3264 | no | 8eaac06a | 7328fcc7 | |
| 5 | Rare chest, before | 3411 | no | 6ea760dd | 24d36b08 | at 18, -88 |
| 6 | Rare chest, after | 3231 | no | fca0baf0 | fb0f6c11 | |
| 7 | Corpse, looted | 26187 | no | b940405f | 4286110c | instance at +576, +960 regions from run 2 |
| 8 | Corpse, before | 26187 | no | b940405f | 4286110c | instance at 6499, 4395 |
| 9 | Corpse, after | 26187 | no | b940405f | 4286110c | identical to before: corpses need chat |

Findings:
- Vault instances move between runs, but always by whole 64-tile regions: tile positions mod 64 stay the same.
- Corpses don't change model when looted. `You've taken everything you can from that target.` marks them done.
- `You fill your loot bag with loot.` appears at the rare chest, and `Completion Time: …` ends the run.
- `You have been caught... You lose some loot.` is the ghost penalty line.
