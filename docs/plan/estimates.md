# Plan: the data edge (data modes and the estimate mode)

This is the product's edge (J24, docs/plan.md "Our edge"): no other stat site
understands its numbers patch by patch, season by season and rank by rank. They show a
raw window; we show every window, honest about its scope, plus an estimate that uses
what we have learnt about how patches, seasons and ranks move numbers, and the models
are built on the same understanding.

J23: every block should respect the filters it sits under, or say
clearly that it doesn't. Pages keep the raw modes, last 30 days and the newest patch,
and gain a third: one best estimate per number. That estimate uses every game we have:
the previous patch moved by what the patch changed, every rank adjusted to the rank
picked, and later every region. The goal is one trusted version instead of picking
between windows. Players have to trust it, so how each number is made must be plain on
the page. A rank pick should use all the data, adjusted for how ranks differ, rather
than only the games at that rank. Per region later ("for now I don't mind"). Builds on
docs/plan/patch-transfer.md (how champions move across a patch), the curves' shrinkage
(arch-stats.md "Lane curves") and the site's usualK. Research:
research/questions/patch-transfer.md and curve-statistics-method.md; partial pooling
(gelman-2006-multilevel-can-cant, gelman-hill-2007-ch12-13), patch-decay n_eff
(practools-design-effects ^f5).

## Why one estimate can beat both windows

- A matchup over 30 days and ~80 games is about a third real, two thirds luck; half
  real at ~300 games (learned.md). The newest patch alone is thinner still. A
  number that shrinks a thin cell toward a well-measured parent beats the raw cell; the
  site already does this for "vs usual" and the curves
- Patches move most champions little: on 16.21's first day 0.75 pp RMS, the 12 changed
  ones 1.9 pp, the rest 0.5 pp (learned.md). So last patch's numbers, moved for
  the changed champions, are a strong prior for the new patch, and the new patch's own
  games take over as they arrive
- Ranks differ in a few smooth ways (gold at 14 rises ~90-200 from Emerald to Master,
  learned.md). A rank's estimate is every rank's number plus a shrunk rank
  deviation. That is more accurate than the rank's own thin games, and it lets every
  block follow the rank pick
- Seasons are bigger boundaries: the preseason patch reworks items, objectives and
  the map at once, so more champions move and by more. The same patch-transfer method
  applies with a looser prior; how much carries over is measured, not assumed
- The raw windows stay. They are what happened, and that is what makes the estimate
  checkable

## Trust rules (for every step)

- Every estimated number is labelled an estimate, with its range. The games behind it
  are always beside it, and the raw numbers are one click away (the period switch)
- Each number can say what it leans on, in words: "52.3% (±1.1), estimate for 16.21,
  Emerald+. 58% from 4,100 games on 16.21, 34% from 31,000 games on 16.20 moved by the
  patch, 8% from other ranks." That needs no model names or nats
- Publicly scored: the method page shows how well each mode predicted the next week's
  games on the newest patch (E2), updated daily. If the estimate stops winning, it says
  so, and the default goes back to a raw mode
- Counts stay raw in every mode: games, pick rate, ban rate, players. Only rates and
  averages are estimated

## Steps

- E0 Jacob's choices. (a) Name: "Meio" (J34), as in meio.lol ("meio": the middle,
  the means). The switch would read `30 days | Patch 16.21 | Meio`, captioned "our
  estimate for today's patch, from every game". Others: "Now", "Best read", "Forecast".
  (b) The default stays 30 days until E2's gate holds for two patches, then becomes Meio
  (Jacob confirms). (c) Regions: EUW and every region now, one region each later
- E2 The truth test, before anything ships. A rolling origin as in patch-transfer.md:
  for each day d of the newest patch, build each mode from games before d, then score
  its numbers against the next 7 days' games on that patch, per cell kind, by rank
  bracket and day since the patch. Scores: binomial log loss for rates, squared error
  with the cell's noise subtracted for averages. Gate: Meio beats both raw windows in
  every day-since-patch bucket for that cell kind; a cell kind ships only once it
  passes. Plan (E2 below): Meio as a third mode, the locks' cell kinds, read from the
  cubes, scored daily on the box for the method page
- E3 Champion-role win rate, the first estimated number. logit p = a[c,r] (shared
  across patches) + d[c,r,patch] (shrunk toward 0, looser for changed champions: the
  winner of patch-transfer's A2-A6) + b[c,r,bracket] (shrunk toward a role-wide rank
  pattern) + later g[c,r,region]. Newer games weigh more within the window, with
  n_eff in the shrinkage. Closed form or a few ridge passes, seconds on the box. Done
  when it passes E2 and the champions table and tiles show it in Meio mode. Blocked
  by patch-transfer Steps 1-3 (which patch arm wins)
- E4 Matchups and duos: the pair's residual after both champions' strength (what "vs
  usual" shrinks today), with last patch's residual as the prior. E2 first measures
  how much a pair's residual moves across a patch, compared with noise; if residuals
  hold, pairs gain most, as they are thinnest
- E5 Lane curves: last patch's curve as a prior and patch-decay weights (curvefit's
  "not yet" list), brackets as today. Percentiles exact, from E7's per-game records
- E6 Builds: what people take is a fact, so shares stay raw. Meio shows the newest
  patch, falling back to the previous one for items and runes the patch left alone
  (builds.zig pick() does this for a whole build today); build win rates shrunk
- E7 Storage: day cubes (src/cubes.zig, data/cubes/days/<unix day>.bin), so that
  every mode, rank and region is a pass over its days. Per game records, not per-cell
  sums (measured below): platform, patch, start, the five curves lanes and the ten
  players' builds seats (participants row, picks, rank). Each game is decoded from its
  timeline once and kept; a changed day (late timelines, up to 9 days) decodes only its
  new and changed games. `curves` and `builds` (--site or not) read the days instead
  of every timeline, with the same output. The views write stays on data/partials
  (already per day, per game). Done when the views, curves --site and builds --site
  load from cubes, with sizes measured. Unlocks: with the pass cheap, the 30-day builds
  can count matchups (~1.1 GB a builder of C01's 62 GB), so the matchup builds strip
  can follow the period picked, and builds by rank are a filter over the seats (E8).
  Open: a later box curves run (a few days of cubes) and builds --site on cubes
- E8 Rank respected everywhere: with brackets in the cubes, filters.js sums every block
  by the rank picked (raw modes), and Meio uses E3-E5's bracket terms. Rank is the one
  at game start (rank_history, from 12 Oct), never the post-game one (learned.md Data
  quality)
- E9 Explain: a "how this was made" line per number (Trust rules) and a method page
  section with E2's daily scores per mode. Done before Meio becomes the default
- E10 History views, "show it all": any past patch, a season, and a champion's or
  matchup's number over patches as a line with each patch's range, from E7's cubes (a
  past patch is a sum of its days). Where the estimate moved a number at a boundary,
  say why ("changed in 16.21", "season start"). Today the crawl holds 16.19 (thin) to
  16.21; seasons need time (no backfill, J25). Done when the champion page's period
  pick lists every patch we hold and the trend chart (site.md CH) reads from cubes
- E11 Models on the same understanding: the draft model, the app's reasons and the
  Daily Draft use E3-E5's terms (patch offset with the changed-champion prior, rank
  bracket, later region and season), so the site and the app agree on every number and
  the model gains what the windows can't give it. Measured in docs/model.md like any
  model change; lab-frontier.md and patch-transfer.md are where the terms are proved

### Meio model (E3-E6, src/meio.zig)

What Jacob sees: in Meio mode every rate on the champion page is one number with an
80% range, and every lock (keystone, opponent, item, rank) gives one, even a combination
nobody played: the parts it is made of plus a shrunk "this pair is special" term, with a
wider range the fewer games it has. Each says what it leans on (Trust rules).

The model, per champion-role cr on the logit scale; every term a random effect shrunk
to 0, one variance per term kind, estimated from the fit (MacKay, as patch-transfer A2):
- E3: a[cr] + d[cr, patch] + b[cr, bracket] + g[cr] on EUW1. Newest patch's number: a +
  d[0]. Day 0 has no d[0] games, so a carries it; d[0] takes over as games arrive
- Conditional cells, cr with x: E3(cr) + m[x] + i[cr, x]. Opponent o (matchups, E4):
  m = minus o's own E3 number (both sides of one lane); duo: plus the support's.
  Keystone and item: m[x] the x's role-wide effect. i shrunk to 0 with its own sd per
  kind; an unseen x gets i = 0 and the prior sd in its range. Interaction patch offsets
  only if E2 shows pair residuals move across a patch (E4's question)
- Shares (build, rune): multinomial over a champion-role's options, last patch's shares
  as the prior for options the patch left alone (E6). Averages (gold at 14): the same
  additive form, Gaussian (E5)
- Item win rates carry their selection (items finished in longer games); Meio predicts
  "win rate with the item" as the raw windows do, not the item's effect

Data: truth's rows from the day cubes (meio.Row: champion-role, opponent, support,
keystone, finished items, gold lead at 14, bracket, EUW1, patch slot, day). Fit per
origin day; seconds per fit, so the box can refit daily.

Steps, each measured in `meiolol truth` (E2) with Meio as the third mode: per kind,
day bucket, region and bracket, Meio minus each raw mode paired on cells where both
have a number, Meio on cells the 30 days can't cover against the parent rate, and the
share of target rates inside the range (noise widened). A kind passes when Meio beats
both raw modes in every day bucket; boundaries 16.20 -> 16.21 (snap-2004Z) and
16.21 -> 16.22 (truth's fresh snapshot)
- M1 E3 as above: committed (ebb9ebaa), unit tested on planted moves
- M2 E3 variants: random-walk patches (d[0]'s prior centred on d[1]: last patch's
  number, not the window's); half-life 7 and 14 days; changed champions looser (A3);
  bracket sd per role. Keep the simplest that wins
- M3 Matchups and duos (E4): committed (d30cab86). M4 keystone win rate and M5 item win
  rate: committed (21fdd222), each champion-role centred by its own mix first (one that
  only takes a weak keystone gains the full gap on a strong one). Shares (rune, build)
  and M6 gold at 14 next
- M7 The locks' wish list (meio-locks): which combinations a page asks for, and which
  Meio can give (two locks at once: main effects plus both pair terms)

Order: E7 next, as the base: on its own it fixes the matchup builds strip per
period and rank in every block. Then E2, then E3-E5 as each passes the gate, then E9 and
the default switch (E0b). E10 follows E7; E11 follows each estimate that passes E2.

## Status

- E2 (meio-truth): `meiolol truth` reads the day cubes, scores Meio as a third mode
  over eight cell kinds (the locks' keystone, item and rank cuts), with unseen-combo and
  range checks and `--tsv` for the method page. First read: Meio passes on matchups,
  trails on champion-role (docs/model.md "Meio in the truth test"). 16.21 -> 16.22: day 0 only so far
- Champion page blocks follow the region and period picks: players' win rates, the
  builds strip, how hard to pick up, the pool section and the patch line
- Scope chips (E1, ui.scopechip) on every block of the champion, matchup, build and
  pool pages, marked where a block doesn't follow the page's picks; pipeline_test checks
  each champion page block has one. Marked: the lean line
  (every region, 30 days), the patch line (whole patches), the matchup builds cards (the
  region's patch), rank on every fixed block (builds strip, players' win rates, pool,
  learning, lean, patch line), pool (every patch or all time), learning (every region).
  The role tiles and opponents follow every pick
- Your games compares each game with EUW curves on that game's patch, whatever the
  player's region (labelled); the all-region curves for other regions
  would roughly double the service's mapped memory

### E7 day cubes, measured

Sums or records: on 15 Oct (all regions, timelined) 486,112 lanes fell in 86,445
cells of (platform, patch, role, pair), 5.6 lanes a cell before bracket (4),
experience (4) and split half (2): one or two lanes a cell. A cell's sums (games per
minute, sum and sum of squares per metric and minute) are ~2 KB against ~200 B for a
lane, and per-minute histograms more again, so a day of sums would be ~10x a day of
records and percentiles would carry bin error. Records keep percentiles and medians
exact; no bins to choose.

Snapshot snap-20261023T2004Z on the Mac (M-series, ReleaseFast; 24 days, 1.6M games,
1.23M with timelines in the 30 days), `--site --patch 16.21`:

| | curves | builds |
| --- | --: | --: |
| before (every timeline) | 707 s, 4.5 GB | 652 s, 4.7 GB |
| first run (builds 24 days) | 966 s, 4.3 GB | |
| after (days built) | 157 s, 1.8 GB | 118 s, 2.7 GB |
| 10 days changed (rewritten, 0 decoded) | 306 s, 1.5 GB | |

- Files: 1.75 GB for 24 days, ~115 MB a day at 100k games (~1.1 KB a game); 30 days
  ~3.5 GB of C01's 405 GB free. Days before the views' first game are dropped
- Same output: builds patch files byte for byte; curves game counts equal, values
  equal but the smoothing pick, as split halves now follow a hash of the match id
  rather than the query order (22 of 60 picks moved one step on the grid, support gold
  two)
- After the change, curves is mostly the fit (~110 s of the 157); builds is decoding
  every day's seats (~100 s)
- Late timelines: in 6 h on C01, 11.5k timelines for today's games, 1.5k for
  yesterday's, 0.9k down to 0.06k a day for days 2-9; a whole-day rebuild would redo
  ~10 days a run, hence the in-place update: a changed 100k-game day is read and
  written again in ~12 s (mostly the compression), plus ~0.5 ms a game decoded: ~2 min
  of cubes a box run
- Box (C01, 30 Oct, `curves --site --patch 16.21` in the web loop, beside the crawler
  and renderer): before, timelines ~8 min and fit and files ~9 min, ~17 min (06:43 to
  07:00; 23:30 the night before ~30 min). First cube run: 31 days built in ~17 min
  (2.66M games, 2.85 GB, ~95 MB a 100k-game day), then fit and files ~9 min, ~26 min.
  On C01 the fit, not the read, is the larger part

### E2 plan: Meio in the truth test, daily

What Jacob sees: one table per boundary (and, daily, the live patch) with, per cell kind,
rank bracket and day since the patch, how much Meio beats or trails each raw mode, how
it does on combinations the 30 days has too few games for, and whether its ranges are
honest. The method page (E9) shows the same numbers from a daily file.

- Modes: raw 30 days, raw patch, Meio (src/meio.zig: `fit(rows before d)`, then
  `rate(kind, region, bracket, a, b) ?Estimate`; interface in the team's common.md).
  Comparisons, each paired over the cells both sides have a number for: patch - 30d,
  Meio - 30d, Meio - patch; unseen: win-rate cells the 30 days has under 10 games for,
  Meio against the champion-role's 30-day rate (the site's fallback); in range: share of
  Meio's 80% ranges, widened by the target's noise, that hold the target's rate
- Cell kinds, for the champion page locks: champion-role, matchup (x opponent), duo,
  gold at 14, item share, item win rate (x item), keystone win rate (x keystone),
  keystone share; x rank is the bracket dimension of every kind
- Data: the day cubes (no player keys, kept current by the box's web loop), so a fresh
  "snapshot" is a copy of data/cubes/days (~3.3 GB); old snapshots need their cubes
  rebuilt by the same build (formatKey)
- Cost: each day's cells summed once, then each origin adds up its days; Meio fits once
  per origin. Daily on the box: `meiolol truth --patch P --tsv FILE` after the web
  loop's cube refresh, as a box job, while the patch is newest
- Boundaries: 16.21 -> 16.22 live (EUW1 from 4 Nov 06:40Z), scored as its days arrive;
  16.20 -> 16.21 (EUW1 from 21 Oct 05:12Z) on the box's cubes, which keep 31 days: its
  origins before day 15 see a raw window shorter than 30 days
- Done when: Meio's champion-role passes or fails the gate on 16.21 -> 16.22 with
  every bucket filled, the daily TSV is on the box, and each kind's verdict is in Status

### E2 baseline, raw 30 days vs raw patch

Tool: `meiolol truth --patch P` (src/truth.zig; read-only on a snapshot, ~40 s, 2.8 GB,
4 threads). Day d counts from the patch's first EUW1 game; at each d both modes are
built from every game before then, and scored on the patch's games of the next 7 days.
A cell is scored where both modes have 10 games; win rates and build shares by log loss
(milli-nats a target game, rate (k + 0.5) / (n + 1) for both), gold at 14 (lane gold
difference per matchup) by noise-corrected RMSE. Brackets by the stored rank (the
curves' brackets; E8's rank at start later). Snapshot snap-20261023T2004Z.

How much worse the raw patch predicts than the raw 30 days (every region, all ranks;
patch coverage in brackets: share of target games whose cell had a patch number):

| cell | day 0 | day 1 | days 2-3 | days 4-7 |
| --- | --: | --: | --: | --: |
| 16.20: champion-role | 3.35 (98%) | 0.09 | 0.03 | 0.01 |
| 16.20: matchup | 21.4 (39%) | 2.85 (90%) | 0.91 | 0.32 |
| 16.20: duo (bot+sup) | 20.5 (56%) | 2.05 | 0.66 | 0.21 |
| 16.20: gold at 14, RMSE 30 days / patch | 110 / 347 g | 136 / 175 | 119 / 135 | 103 / 110 |
| 16.20: build share | 2.61 | 0.06 | 0.01 | 0.00 |
| 16.21: champion-role | 2.14 (99%) | 0.15 | | |
| 16.21: matchup | 21.8 (55%) | 4.42 (93%) | | |
| 16.21: duo | 15.0 (70%) | 3.32 | | |
| 16.21: gold at 14 | 59 / 321 g | 67 / 166 | | |
| 16.21: build share | 1.71 | -0.03 | | |

Every gap is the 30 days ahead by more than 2 se, except build share on 16.21's day 1
and 16.20's days 4-7 (ties). Diamond+ gaps are 2-4x larger (thinner cells); EUW1 alone
has the same shape, larger (its day 0 has no patch games by definition). Full tables by
bracket and region: rerun `meiolol truth --data SNAP --patch 16.20 --until
2026-10-20T14:44Z` (and `--patch 16.21 --origins 2`).

Reading it:
- The raw 30 days is the bar the estimate has to beat: the raw patch never beat it in
  any bucket or cell kind. For champion-role win rates and build shares the patch
  catches up within 2-3 days; for matchups, duos and gold at 14 it still trails after a
  week, as those cells are thin and a patch's few days are thinner
- 16.19 -> 16.20 says little about old patches: the crawl was ramping up (16.19 has
  53k games, 16.20 70-100k a day), so from day 1 the 30 days is mostly 16.20 itself
- 16.20 -> 16.21 is the real boundary but provisional: 16.21 games are all inside the
  P3 test window (from 20 Oct 14:44Z; why this look is independent in e2-notes.md) and
  the snapshot ends 23 Oct, so targets are 2.6 days at most and only days 0-1 exist. On
  day 1, with the 30 days ~90% 16.20 games, it still beats a full day of 16.21 for
  every cell but builds. Next: the live 16.21 -> 16.22 boundary on a fresh snapshot,
  and E3's estimate as a third mode

## Later

- Region per region (E3's g term), once Jacob wants it
- Lean per period, once one patch has enough games past 20 min (today one daily file,
  1.19M games)
