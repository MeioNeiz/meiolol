# Champion page locks (J34)

Jacob (J34): click almost anything on the champion page and it locks; every other block
then follows the lock (lock Conqueror: builds, matchups, win rate, curves, all for
Conqueror games). Locks stack, clear in one place, the URL keeps them. Raw numbers first;
Meio (estimates.md) fills thin cells once its cell kind passes E2. Thin cells say so:
games beside every number. Builds on contextual-builds.md (its keystone lock is live, its
data design is replaced here) and the J23 rule that every block follows its filters.

## What Jacob sees

- Lockable: role, region, period, rank (the subbar pickers, as now), and on the page
  any keystone or rune page, rune, shard row, spells, start, boots, core path, item in a
  slot, max order, an opponent or ally in Matchups, a patch point in By patch, a length
  bucket, a rank bracket, gold at 14 ahead or behind
- A lockable thing looks like data until hovered (no button chrome, frontend.md); the
  hover shows a lock glyph at its corner, a tap locks it: outlined in the accent with
  the glyph kept. Tap again unlocks
- LockBar: under the subbar, one Chip per lock ("Conqueror ×", "vs Sett ×", "Black
  Cleaver 1st ×"), then the games under all of them ("1,284 games") and "Clear". Hidden
  with no lock. A lock in the same slot replaces the old one (one keystone, one core
  path, one opponent per role)
- Every block follows the stack, or carries a scope chip saying what it ignores (E1's
  rule). A block's head shows its games when they differ from the page's
- Thin: a context under 20 games shows only "Too few games: 12" in each block. A cell
  under 100 games shows its number faded with its games; under 30 games no rate, the
  games only. With Meio for that cell kind: the estimate with its range, the raw rate
  and games beside it ("51.2% ±3.1, 84 games")
- URL: `/champions/ornn/top?lk=ks8010,vs86` style query (one key per kind, values by
  id), so a link opens the locked page and nginx caches per lock set. Same in the app's
  "why this pick" links

Phone: the LockBar scrolls sideways in one row; long-press is not needed, a tap locks.

## Data: an aggregates service (contextual-builds.md Q1: aggregates first, rows to
the browser only after the key)

- Rows: one row per player and game for every champion-role, from E7's cubes (seats:
  runes, spells, items with minutes, skill path, opponent, gold at 14, rank, patch,
  platform, start) plus the other nine champions of the game, duration and end stats
  from partials. Columns per champion-role, ids as small dictionary indices, no match
  id or player key. Written once per web round on C01 (`data/lockrows.bin`), loaded
  by the renderer beside views.bin, swapped with it
- Answers: the renderer (and `meiolol dev`) answers `GET
  /data/champion/<slug>-<island>.bin?v=<view>&lk=...` with the same ui.data files the
  islands read today (TopData, BuildData, MoreData, TrendsData, ChartsData), counted
  from the rows that match every lock. The islands keep their decoders; only the URL
  changes. nginx caches each answer until the next data swap
- Same counting code for the default files and the answers, so an answer with no lock
  equals the default file byte for byte (pipeline_test)
- Under a rank pick a lock counts the rows at that rank or above (E8), the period
  picks rows by patch or day, the region by platform
- Meio: the renderer carries the fitted model (src/meio.zig, meio-model's) and adds
  estimate, range and what it leans on to cells whose kind passed E2. Wish list in
  common.md

What a block needs from a row:

| Block | Columns |
| --- | --- |
| StatStrip, By patch, By day | won, patch, day, platform, rank |
| BuildPanel | rune page, shards, spells, start, boots, items 1-6 and minutes, skill path |
| Matchups (Against, With) | the nine other champions by role and side |
| By game length, End of game | duration, end stats |
| By rank | game bracket |
| First item done | first item minute |
| Lane, Won by lane gold, Lane kills | lane leads by minute, kills by phase (cube lanes) |
| Objectives | firsts |
| Players, Pick-up, Also play | player-level: stay unlocked (scope chip) until a player key that never leaves the box is decided |

## Steps

- L1 Rows table. `src/lockrows.zig`: build per champion-role columns from cube days
  and partials for a window, write and read `lockrows.bin`. Done when built on the
  snapshot with bytes a row, total for EUW and every region (30 days), build time and
  renderer memory measured here, and pipeline_test builds it from the fixture games
- L2 Build panel answers. Count BuildData from rows (shared with builds --site's
  panel or proven equal), the answer route in serve.zig, the LockBar, and lock taps on
  every build cell; the keystone lock moves onto it. Done when any stack of build
  locks answers on the dev server under 50 ms p99 and the no-lock answer equals
  -build.bin
- L3 Top and More: StatStrip and Matchups under locks; opponent and ally locks
  (selecting a matchup dot is its lock)
- L4 Trends: By patch (a patch point locks the period to that patch: E10), length,
  rank, First item done, End of game; their locks
- L5 Charts: lane leads per minute in rows (size measured first), comeback, kills,
  objectives
- L6 Meio in thin cells, per cell kind as it passes E2; the "how this was made" line
  (E9)
- L7 Components the page lacks (Jacob's notes 122 and 123: Also play, Lane kills and
  their kind are "a poor use of space", "more images, more specific components"):
  designs in the gallery, then onto the page

## How it is measured

- Sizes: lockrows.bin and renderer memory (EUW, every region), answer bytes per
  island (gz) for no lock, one lock and three, and answer time p50 and p99 over a lock
  mix, on the Mac on the full snapshot and later on C01
- Correctness: no-lock answers equal the default files (pipeline_test); a lock's
  counts equal a direct count over the cube seats (test)
- Meio cells: E2 per cell kind (meio-truth), nothing public before
- UI: gallery states of every new component, deploy/qa.sh, screenshots at 390 and 1440

## Status

- Keystone lock in the BuildPanel (builds.by_keystone, `k` in the hash); vs melee or
  ranged and gold ahead or behind are precomputed splits of the build file only
