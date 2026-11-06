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
- Thin, by range not games (J35, estimates.md Trust rules): every rate shows its ±,
  however wide, never hidden ("48% ±14" says more than a blank). Over ±6 points it is
  faded; raw modes take the binomial range from their games, Meio its own. Games stay in
  the leans-on line and the hover, not beside every number ("51.2% ±3.1"). A context
  with no games at all says so; a thin one shows its wide ranges
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

- L1 Rows table: pipeline_test builds it from the fixture games; the web loop writes it
  on C01 after curves (cubes current); renderer memory measured there
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

- L1 rows: `meiolol lockrows` (src/lockrows.zig) writes data/export/lockrows.bin from the
  cubes. Snapshot snap-20261023T2004Z on the Mac (19 days in the window, 1.57M games):
  15.7M rows, 60 B a row, 940 MB (456 MB gz), 865 champion-roles, rows p50 1.6k, p90
  63k, p99 164k, max 302k (all regions); 22 s after the cubes are current. At today's
  crawl (~33M rows a 30 days, every region) ~2 GB, shared by both renderers if mapped.
  Not yet: duration, end stats, lane minutes (L4, L5)

- L2 counting: src/lockanswer.zig answers a block's rows under a view (platform, patch,
  rank floor) and a lock stack (`lk=ks8010,c23071.6333,vs86`: keystone, rune page, rune,
  shards, shard, spells, start, boots, core 2/3, item 4-6, max order, levels, lane
  opponent, its reach `vr` 1 melee 2 ranged, its damage `vd` 1 AD 2 AP); the table
  carries the patch's Data Dragon data. Damage is Learn's magic share through
  ui.dailydata.dmgOf (under 0.35 AD, over 0.65 AP, else neither): Site.damage, every
  view's from Extras.damageFor (read once a round, the renderer's from the views file).
  An answer carries per lane opponent players and wins (Build.opponents), counted under
  every lock but `vr` and `vd`, for the panel's group counts. An Index codes each block
  once at load (builds.valuesOf per row, a u16 code per kind, ~64 B a row in memory;
  1.0 s for the snapshot's 15.7M rows on the Mac's cores, largest dict 6.2k values);
  answers count codes in arrays and load each group's top options into builds.Builder
  for its File. `reference` counts the decoded rows with builds.Builder. pipeline_test: no
  lock equals builds --site's build and splits, a keystone lock its by_keystone, an
  opponent lock its matchup, and every fixture block under each lock kind and a full
  stack equals the reference. `meiolol lockrows --bench`
  (Mac, the 20 largest blocks, 5 lock sets, EUW and every region, each answer checked
  against the reference): p50 1.5 ms, p99 9.3 ms, max 9.8 ms (Builder: p99 300 ms). Not
  yet measured on C01

- L2 route: the renderer and `meiolol dev` answer
  `<view dir>data/lock/build/<slug>/<role>/<rank>/<lk>.bin` (site/locks.zig; path from
  ui.champpage.lockPath; lock set in the path, as nginx caches by path) with a BuildData
  of that one role, counted under the view (platform, patch or 30-day window) and the rank
  floor. site.Loaded loads data/export/lockrows.bin and its Index on the first lock
  request (render: before listening beside a running one, and before each swap); the web
  loop writes it after curves. pipeline_test: a keystone lock's answer through
  Loaded.get is the builds file's by_keystone build

- L2 UI: `lk` in the champion page's query (ui/lockbar.zig Set: one value per kind, in
  lockanswer's order). Every build option and rune page is a chrome-less button (padlock
  on hover, accent outline locked); a rune or shard locks too, the keystone row as the
  keystone; an old `k` link reads as lk's keystone. ui-champbuild fetches the answer
  (one at a time, kept by path) and shows it in the panel. ui-champbuild's budget is 48 KB
  for it (stack.md, Jacob 4 Nov)

- L3 so far: the LockBar sits under the pickers, above every block (the build island's
  first child, outside its card): chips with ×, "N games · rate ±", "Build only" until
  other blocks follow, Clear; on phones the line wraps under the chips. The renderer
  renders `?lk=` into the page (site/champion.zig lockBuild: EUW 30 days at Platinum+,
  the rank being the fragment's), with the answer inline (data-ans) so the island
  hydrates without asking; nginx keys its cache by lk (hosting.md). An opponent chip
  names its champion (BuildData.vs, from the answer). Matchups follow the locks: the
  renderer answers `more/...` with a MoreData of the role (lockanswer.matchups counts
  each ally and enemy by role from the Index, which codes the nine others per row, +8 B a
  row; site/champion.zig relsOf with the locked counts, no lane gold as curves aren't
  locked), rendered into ?lk= pages too and fetched by ui-champmore. The StatStrip
  follows too (`top/...`: a TopData of the role with games and wins only,
  lockanswer.count): won ±, its share of the champion-role's games, games; pick, ban,
  rank and the patch's move are the champion's, so hidden. A lane opponent's brief has
  Lock / Unlock (a button beside "Matchup ›", not tapping the dot: a dot shows its
  brief first, and locking on every look would refetch the page). The bar says "Not
  Trends yet" until L4 and L5

- Thin (J35) in the build panel: every rate with its 80% range (fmt.range, Wilson),
  faded past ±6, whole numbers from ±10, none hidden; counts don't fade

- Keystone lock in the BuildPanel (builds.by_keystone, `k` in the hash); gold ahead or
  behind is a precomputed split of the build file's items only
- Lane opponent row at the BuildPanel's top: All | Melee | Ranged | AD | AP, each with
  its games under the other locks (bp.Data.vs from Build.opponents; empty disabled). A
  pick is a `vr` or `vd` lock, one at a time (a second tap or All unlocks); the LockBar
  names their chips (vs melee, vs ranged, vs AD, vs AP). Not on a matchup page; none on
  a base page until its builds file carries `opponents`
