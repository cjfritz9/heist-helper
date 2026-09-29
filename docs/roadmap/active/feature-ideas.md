# Feature ideas

A backlog to work through one at a time. The research behind many of these is in `../research/reports/vault-of-hereditas-plugin.md` (F1–F7). Session tracking has its own plan in `session-tracking.md`.

## Heist components

| Component | What matters to the player | Covered now |
|---|---|---|
| Loot sources (30) | What's left, what's worth the time | Outlines, looted state, per-section counts, level filters |
| Points / loot bag (cap 500, halved without the rare chest) | Am I at the cap? Is a detour worth it? | No |
| Batteries (10 per anchor) | Enough for the anchors left? | Stack changes detect powering |
| Seals (legionary: section 1; praetorian: random among section 3's 8 sources) | Which sources haven't been searched for it? | No |
| Shadow anchors, dials, crystals | Which are done | Outlines until powered or used |
| Hazards (ghosts −20, pylon misstep −5) | What a catch cost | No (chat: `You have been caught... You lose some loot.`) |
| Pylon maze (section 4 centre) | Crossing it before anchor 6 and the final crystal shut it down | No |
| Rewards (XP per point, commons per 25, rare bracket) | What the run is worth | No |
| Between runs | Averages, bests, what was missed | No (`session-tracking.md`) |

## Ideas

### 1. Loot sack overlay and running total

Draw the bag's running point total over the loot bag icon, like OSRS item-content overlays. Showing it is fine: the game lets you inspect the bag.

- **Source:** each loot gain shows a 2D "+N" popup near the character. Read those with the digit-glyph technique used for the battery stack, and keep a running total. This also catches bonus loot from pickpocketing, which loot tracking alone would miss.
- **Check:** our own loot detection (chest 10, shadow chest 15, safe 30, rare chest 50, corpse 10; −20 per catch).
- **Done (verified 2026-09-28):** the counter matched the bag's own "Loot Stored" for a full run and most of another with no corrections needed. It reads the popups, pairs each with a loot action that could produce its value, and reconciles from the tooltip on hover. A catch costs 20 (confirmed). Still unseen digits, logged with bitmaps when they appear: popups 4, 7, 8, 9; tooltip 7.
- **First step, a probe (built):** `loot.log` gets the glyphs around the character whenever they change (with pixel hashes), the bag's hover tooltip, chat, and detected loot. One run shows the popup format. Then map glyphs to digits by pixel hash.
- **Found:** the popup is white text, "N Loot Gained", on a dark strip beside the character. It's likely one pre-rendered image, so the number is read from its pixels: split into characters at empty columns, and match digits against shapes learned from known values (chest 10, shadow chest 15, …).
- **Reconciliation:** hovering the bag shows its real total. Compare it with our running count and correct it when they differ.
- **Drawing:** icon positions are already known (`game/inventory.lua`). Bolt has no text drawing, so we'd need a small bitmap digit font.

### 2. Pylon maze: persist the revealed path and draw the optimal route

The maze matters until anchor 6 is powered and the final crystal (one room past the rare chest) is clicked, which opens the centre. Only your true tile counts, and running moves 2 tiles per tick, so a route that lands only on safe tiles can skip tiles.

- **Compliance:** only re-display what the game has revealed, and never predict or derive unrevealed tiles (for example by matching the known variants). Whether the revealed path stays lit or only flashes decides whether persisting it is acceptable: if it's meant to be memorised, drawing it removes the intended challenge. Settle this before building anything that shows the path.
- **Match the game's lifetime:** draw our path only while the game's path is shown, and remove it when the game's path despawns. The overlay then never shows the path for longer than the game does, which keeps it on the right side of the line whether the path stays lit or only flashes. The optimal route adds the landing tiles on top, for the same period. This needs the probe to detect when the path disappears, as well as when it appears.
- **Optimal route:** a shortest path over the revealed safe tiles, where each tick's landing tile must be safe. Drawn from the player's position to the next barrier.
- **First step, a probe:** find out whether the lit path is visible to Bolt at all (the crystal's flash wasn't). Use Watch object over the centre room with the window open through section 4, raising the maximum radius from 8 to 16. Check whether the lit tiles show up as models, particles, billboards or big-mesh changes.

### 3. Point counter with projections (report F1)

Current points, points to the cap, projected XP, common rolls including the fractional extra roll, and the rare bracket. Builds on the running total from idea 1.

### 4. Cap warnings (report F3)

"Opening the rare chest now wastes N points" above 450, and "at the cap: skip the south room".

### 5. Catch log

Count `You have been caught... You lose some loot.` lines and show the points lost. Feeds ideas 1, 3 and session tracking.

### 6. Seal tracker (report F5)

Mark section 3 sources searched without finding the praetorian's seal. The seal is an inventory item, and icon recognition already exists.

### 7. Battery tracker (report F5)

Batteries held against batteries needed for the anchors left. Needs a glyph-to-digit map for the stack number, shared with idea 1.

### 8. Lobby mode and session tracking

See `session-tracking.md`.

### 9. Ghost warning

Rummaging shows "Spirit Disturbed | 33%", then 66% and 100%, then "Spirit Manifesting |", in the same popup font as the loot popups. Show the current level on the panel or over the corpse, so it's visible without reading the popups. It's on-screen information, so it's fine to re-display.

## Leave out

- Guard patrol prediction beyond what's on screen (report F7).
- Predicting maze variants from partial observation.
- Any input automation.
