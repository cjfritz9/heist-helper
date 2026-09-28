# Tag run 2 (2026-09-27)

Rows are from `tags.csv` (the old format: `fingerprint` hashes only the first 16 vertices). Rank 1 is the smallest on-screen model under the cursor. The stale tag 1 from an aborted attempt was dropped.

| Tag | Object | Rank 1 vertices | Animated | Fingerprint | dx, dz |
|---|---|---|---|---|---|
| 2 | Corpse, before | 26187 | no | b940405f | 8, 4 |
| 3 | Corpse, after | 26187 | no | b940405f | 8, 4 |
| 4 | Chest A, before | 3444 | no | 9f69f595 | 11, -4 |
| 5 | Safe, before | 3456 | yes | d77d3421 | -2, -22 |
| 6 | Safe, after | 3456 | no | d77d3421 | -2, -22 |
| 7 | Chest B, before | 3444 | no | 9f69f595 | -22, -11 |
| 8 | Chest B, after | 3264 | no | 8eaac06a | -22, -11 |

Findings:
- Chests: two different chests have the same unopened model; opening one swaps it for a different model (3444 → 3264 vertices).
- Safe: same geometry before and after; animated while closed, static once cracked (one example).
- Corpse: no change visible with this fingerprint.
- The player model shows up as 21132 vertices, animated, `097a78c6`.

Chat lines (spaces are dropped by the chat reader):
- Corpse rummage: `You loot a …`; fully looted: `You've taken everything you can from that target.`
- Safe: `You crack open the safe!`, then `You loot …`
- Chest: `You loot …`. Clicking a looted chest gives `Looted.`
- Most loots are followed or preceded by `The following has been added to your currency pouch: N x Thieving Guild - Pilfer Points.`
