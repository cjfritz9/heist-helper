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
| Hazards (ghosts −20, wrong step off the maze path −5) | What a catch cost | Subtracted by the bag counter (same chat line for both: `You have been caught... You lose some loot.`; a wrong step is told apart by having just been on the maze) |
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
- **From the wiki:** you enter section 4 in the west room and go clockwise (west, north, east, south). Each leg through the centre (to north, east, south) is revealed by powering that room's shadow anchor and then **clicking its shadow crystal**. The wiki shows three example paths per leg, captioned "one of the possible paths", so three may not be all, and at least one of the nine images is a duplicate. Don't rely on the wiki for the number of variants. A wrong step off the path costs 5 and sends you back to the room's checkpoint.
- **Built:** reading the lit path from screen pixels works (Bolt screen capture in the panel, tile edges projected on screen). The route is drawn live. Still to confirm in game: mapping the north, east and south rows, and the route drawing.
- **Fixed (2026-09-29):** the "wonkiness" was 1-tile walk steps mid-route (the old step-by-step tie-break couldn't see ahead). Routes are now scored as a whole.
- **Identification threshold (2026-09-29):** lowered to 4 tiles (lead of 3). Replaying real bursts showed the remaining failures read almost no path tiles at all, so the bottleneck is reading tiles, not the threshold.
- **Open (2026-09-29):** detection is unreliable: several crystal clicks and camera changes before anything drew, with frames of 0–3 lit tiles. The burst is now longer (up to 16 frames, from about 1 s to 8.5 s after the click, stopping once identified). Next: tune the detector (`ui/capture.html`) on a real capture saved with the path lit, check the `view N of M` notes to see camera matching work in game, and pick a start delay per leg from the `maze: frames after the click:` lines (so far east → south shows shape tiles from 1.6 s; west → north from about 4.9 s).
- **Done:** the crystal-triggered burst below is built.
- **Next (planned with the user):** replace the continuous capture loop with a burst triggered by clicking a shadow crystal: wait 1.2 s, take 4 captures 0.6 s apart (now no wait, then up to 16 captures 0.5 s apart), merge the lit tiles, match them against the known mazes by confidence, then draw the route from the player's nearest barrier-row tile to the end row. Needs the crystal model in the catalogue for click detection. Decide how the route clears (reaching the end row, or one later check capture) so it still follows the game's path.
- **Probe result (2026-09-28): not visible to Bolt's models.** Two recordings over the centre room (clicking the crystal, then walking the lit path tile by tile) showed no model, particle or billboard for the lit tiles: only things moving with the player, the ghost, and edge scenery. Remaining cheap check: whether the minimap shows the path. Otherwise this idea is shelved.
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

### 10. Ghost detection area on true tiles

The game draws a guard's vision as a circle, but detection works on tiles. Draw each patrolling ghost's detection area as the tiles it covers, then map each ring to its patrol route.

- **Decided with the user (2026-09-29):**
  - Track only the vision ring (the 6,144-vertex static model). Its centre and radius are all we need; the ghost's body doesn't matter.
  - Patrol routes are 100% deterministic: static routes followed the same way every time.
  - Sync from a sighting, not from the vault starting: the loop may start with the instance, but another player in the instance could mean it didn't restart when you entered. One observed tile-to-tile step gives both the ghost's place in its loop and the tick timing. Once synced, the true tile comes from the route directly, so the drawn-position lag disappears.
- **Step 1: draw the ring as tiles (built and shape confirmed in game 2026-09-29, locked in as constants).** Find each ring, read its radius from its vertices (once per ring, not per frame), and outline the tiles it covers, using tiles whose centre is within the radius less half a tile: 49 tiles at the measured 4.52-tile radius, an octagon with one tile out from the middle of each flat side, as the user saw in game ("tile centre inside" gave 69 and poked past the ring; "entirely inside" gave 45 and missed the side tiles). Log every "You have been caught" with the player's tile and nearby rings' tiles to check the real detection rule (centre inside, any overlap, or square distance).
- **Step 2: record the routes (built 2026-09-29: `ghosts.log` for the detail, `ghostroutes.csv` as the permanent, growing route map; the offline tool to chain moves into loops is next). Ghosts use stairs in places, so the tool should treat tiles with the same x,z and nearby heights as one tile: a stair tile's recorded height depends on where the ghost was on it when it crossed in.** Log each ring's tile per tick automatically every run: buffered, written about once a second, and capped in size. The ring's drawn position lags by up to a tick, like the player's. An offline tool in `tools/` turns the samples into each ghost's loop (tile sequence, ticks, pauses), stitches runs together, and writes `data/ghostpaths.lua`.
- **Patrollers (user, 2026-09-29):** 4 in total: one for sections 1–2 (the stairs and the section 2 room are one route), two in section 3, one in section 4. The route tool should end up with exactly these four loops.
- **Spawns (built 2026-09-29):** ghosts spawned by rummaging are marked (next to a just-rummaged corpse, or not moving for 5 s since appearing), pinned so passing patrols keep their identity, and kept out of the routes and the tick clock. Still to decide: a leftover bugged spawn (left behind when you exit the instance) can't catch you but its vision tiles are drawn.
- **Route tool (built 2026-09-29):** `tools/ghostroutes.lua` stitches sightings into loops. First run: both section 3 loops closed (118 and 103 ticks a lap); sections 1–2 and 4 still open, blocked by corner variants in edge-based recordings. Recording switched to tile centres, and each run is saved to `ghosts-run-N.log`. Mixing edge-based and centre-based sightings breaks stitching at turns, so loops should be rebuilt from centre-based runs only (first one in `mapping/ghosts-centre-run-1.log`); one run gave 60 sightings, not enough to close them. Still to do: place each stall at its exact loop position using the stop events (a back-and-forth route passes a tile both ways; the stall may only happen one way), then write `data/ghostpaths.lua`.
- **Step 3 built (2026-09-29):** routes in `data/ghostpaths.lua`, synced true tile in `core/ghostsync.lua` (red when synced, amber on the estimate). Replays: 84–89% of tiles exact. Next: fine-tune `ARRIVAL_OFFSET_TICKS` by eye, use the `resynced` lines to adjust stalls around turnarounds, explain the 156–157-tick laps on sections 1–2, and decide whether to draw synced ghosts that are out of view.
- **Step 3: draw from the route.** Sync once from a sighting (match the last few centre tiles to a unique loop position), then advance one loop position per tick with the shared tick clock, independent of the ghost's movement; re-sync on each new sighting and tune any constant offset per loop. The current "heading to" true tile is the stopgap until then. After a sighting syncs a ghost, draw its true tile and detection tiles from the route, including upcoming ones. Re-sync if anything (a catch, a chase) knocks it off schedule. Showing upcoming or off-screen positions is the "guard patrol prediction" item under Leave out; the user is choosing to go ahead with it for testing.
- **Performance:** uses the model events already processed for chests and anchors, with a vertex-count check and one position read per ring per frame. It never reads all vertices per frame, and the dev panel gets a switch to turn recording off if lag appears.

### 14. Corpse ghost spawn timer

Done (2026-09-30): the countdown is a bar of 12 cells over the spawn's head, one emptying per tick, from the tick it appeared (seven-segment digits and dashes around its 3×3 were tried first; the user preferred the bar). Still open: confirm the 12 ticks at the two section 2 corpses, and whether the tick a spawn appears on needs the same 53 ms lateness allowance as ghost set-offs (assumed for now). Original idea: Show how long a rummage spawn has left before it despawns, as a countdown on its outline or the panel. The recordings already say how long they last: every spawn watched from appearing to disappearing lasted exactly 7.2 s, 12 ticks (6 times, at four different corpses); shorter ones had gone out of view, longer ones were leftovers from the leave-the-instance bug. Count the 12 ticks on the shared tick clock from the tick it appeared, and skip leftover bugged spawns (they don't despawn and can't catch you). Worth confirming the 12 ticks at the two section 2 corpses too.

### 13. Minimap overlays

Bolt reports the minimap's screen rectangle, rotation, zoom and centre (its terrain is 8 pixels a tile before zoom), so any world tile can be drawn on it. Built (2026-09-29): dots for loot left to take, in outline colours (`game/minimap.lua`). Ideas next: **icons instead of dots** for each kind of loot (chest, shadow chest, safe, rare chest, corpse), keeping the outline colours; Bolt can draw PNG images bundled with the plugin (`bolt.createsurfacefrompng`), sized to the minimap zoom. Also each synced ghost's true tile and vision area, including patrols out of camera view; the maze route; unpowered anchors, dials and barrier checkpoints. Drawing is clipped to the round minimap, and ghost areas may need to shrink to a dot at far zoom.

### 12. Maze on the shared tick clock

Done (2026-09-29): clicks now count for the first shared-clock tick they can reach, allowing for your measured round trip. `core/tickclock.lua` is still used to tell whether you're moving. Originally: the maze's true tile (`game/mazeroute.lua`) still keeps its own tick clock from your movement starts (`core/tickclock.lua`). Move it onto the shared tick clock (`game/ticksync.lua`: XP drops, ghost set-offs, your set-offs) so every true-tile display uses the same ticks, and drop `core/tickclock.lua`.

### 11. Shared tick clock

Where the game's ticks fall on our clock, from events that share the same tick timing, with re-syncing when they stop agreeing. Built as measurement only (2026-09-29): movement starts (yours and ghosts') feed it, chat lines are measured against it, and everything goes to `ticks.log`.

- **Next:** check in `ticks.log` that player and ghost starts agree (tight spread) and whether chat lands at the same point. Then add XP drops as a candidate (probe built: **Probe XP drops** in the dev panel, writing `xpprobe.log`): every tick while cracking a safe, every 2 ticks while pickpocketing manually (3 when not). They're interface images, so first probe what they look like at the user's interface scale, as with the loot popups.
- **Done (2026-09-29):** XP drops probed and added as a trusted source; loot popups added as a candidate. Chat is out (±170 ms). Ghost starts ±19 ms, player starts ±69 ms with outliers.
- **Done (2026-09-30):** XP drops are the clock's only source while they keep coming; it runs by itself between them (following the measured 600.055 ms tick) and falls back to movement starts after 10 minutes without one. Still open: the drift is a constant measured on one machine, so learn it live from XP drops for sharing; and keep the clock across a plugin restart.
- **Packaging:** interface images (XP drop "+", popup digits, bag tooltip) are recognised by pixel hashes that depend on interface scale, and XP drops can be anywhere or off. For sharing, find them automatically: images appearing on a steady 0.6 s beat while cracking a safe are the XP drops; popup digits can be learned from known values (a safe is 30). Inventory items are recognised by model fingerprints wherever they are drawn, so bundle the battery and loot bag defaults.
- **Then:** use the clock for the maze's true tile (replacing `core/tickclock.lua`), and record ghost routes in tick numbers instead of seconds.

### 15. Red exit until the section is looted

A setting (⚙, off or on) that outlines the way into the next section in red while the current section still has loot left, so you don't walk on and leave something behind. Once everything in the section is looted the red goes away (or turns green), matching the panel's "✓ Section complete".

- **Have already:** what's left per section (`core/status.lua`, `remaining`), the current section, and the barrier-side checkpoint tiles between sections (`core/checkpoints.lua`).
- **Need:** which object to outline for each section's exit. The checkpoints are tiles beside the barriers, not the barriers themselves, and the dial door is a different kind of exit. Either tag each exit object once (a new kind in the dev panel's **Tag object**) or outline the checkpoint tiles on the ground.
- **Open:** whether loot you can't get yet counts as left (shadow chests before their anchor is powered, objects above your Thieving or Agility level). Probably count only what the level settings already show.

## Leave out

- Guard patrol prediction beyond what's on screen (report F7).
- Predicting maze variants from partial observation.
- Any input automation.
