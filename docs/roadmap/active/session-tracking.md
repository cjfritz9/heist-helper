# Session tracking and lobby mode

The design report's run log (F6), plus a panel near the entrance to show it. Started 2026-09-29: `runs.csv` records completion time and loot per run, and the panel shows runs this session and in total plus the session's average and best time. Lobby mode started 2026-09-30: the panel stays open in the entrance area with the last run and the run stats. The area is two corner tiles clicked in the game view from the dev panel (**Entrance area**, saved to `entrance.csv`); the user marked it (2487–2495, 7577–7584) and that rectangle is now the bundled default in `core/lobby.lua`. Next: gp, uniques and pilfer points per run, and what was left per section in the last-run summary.

## Goal

1. **Run log:** one row per completed run, kept across sessions.
2. **Lobby mode:** near the vault entrance, the panel shows last run's summary and session stats instead of switching off.

## What each run records

All of it is already seen by the plugin during a run:

- **Completion time:** the `Completion Time: …` chat line (captured inside the vault in every run so far).
- **Pilfer points:** the sum of `The following has been added to your currency pouch: N x Thieving Guild - Pilfer Points` lines.
- **Loot:** `You loot …` lines (item names), and counts per source type (chests, shadow chests, safes, corpses, rare chest).
- **What was left:** per section, from `run.csv` at completion time.
- Start time, date, and whether the run completed or was abandoned (left the vault without a completion line).

Saved to a runtime file (e.g. `runs.csv`), never the repo.

## Panel

- **Last run:** time, points, what was left per section (e.g. "Section 3: 1 safe").
- **Session:** runs this session, average run time, average points, best time. "Session" starts when the plugin loads, or after a long gap between runs.
- Optionally all-time averages and personal bests.

## Lobby mode

- The entrance is at a fixed world position (unlike the vault instance). The entrance area is tiles 2487–2495, 7577–7584, marked in game (the earlier guess of 3297, 3184 was Al Kharid).
- Within X tiles of it: show the panel with the summary and ⚙ levels. Keep outlines, object scanning, chat reading and the battery check off.

## Open questions

- What counts as a session: plugin load, a gap of N minutes, or a manual reset button?
- Which loot is worth averaging: points only, or specific items (e.g. figurines, flasks)?
- Should XP be tracked? It isn't in chat, so it would need the XP counter or skill levels, which Bolt can't read directly.
