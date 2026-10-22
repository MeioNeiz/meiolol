# Plan: the data edge (data modes and the estimate mode)

This is the product's edge (J24, docs/plan.md "Our edge"): no other stat site
understands its numbers patch by patch, season by season and rank by rank. They show a
raw window; we show every window, honest about its scope, plus an estimate that uses
what we have learnt about how patches, seasons and ranks move numbers, and the models
are built on the same understanding.

Jacob 22 Oct (J23): every block should respect the filters it sits under, or say
clearly that it doesn't. Pages keep the raw modes, last 30 days and the newest patch,
and gain a third: one best estimate per number. That estimate uses every game we have:
the previous patch moved by what the patch changed, every rank adjusted to the rank
picked, and later every region. The goal is one trusted version instead of picking
between windows. Players have to trust it, so how each number is made must be plain on
the page. A rank pick should use all the data, adjusted for how ranks differ, rather
than only the games at that rank. Per region later ("for now I don't mind"). Builds on
docs/plan/patch-transfer.md (how champions move across a patch), the curves' shrinkage
(architecture.md "Lane curves") and the site's usualK. Research:
research/questions/patch-transfer.md and curve-statistics-method.md; partial pooling
(gelman-2006-multilevel-can-cant, gelman-hill-2007-ch12-13), patch-decay n_eff
(practools-design-effects ^f5).

## Why one estimate can beat both windows

- A matchup over 30 days and ~80 games is about a third real, two thirds luck; half
  real at ~300 games (learned.md 22 Oct). The newest patch alone is thinner still. A
  number that shrinks a thin cell toward a well-measured parent beats the raw cell; the
  site already does this for "vs usual" and the curves
- Patches move most champions little: on 16.21's first day 0.75 pp RMS, the 12 changed
  ones 1.9 pp, the rest 0.5 pp (learned.md 21 Oct). So last patch's numbers, moved for
  the changed champions, are a strong prior for the new patch, and the new patch's own
  games take over as they arrive
- Ranks differ in a few smooth ways (gold at 14 rises ~90-200 from Emerald to Master,
  learned.md 13 Oct). A rank's estimate is every rank's number plus a shrunk rank
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

- E0 Jacob's choices. (a) Name. Recommended: "Meio", as in meio.lol ("meio": the middle,
  the means). The switch would read `30 days | Patch 16.21 | Meio`, captioned "our
  estimate for today's patch, from every game". Others: "Now", "Best read", "Forecast".
  (b) The default stays 30 days until E2's gate holds for two patches, then becomes Meio
  (Jacob confirms). (c) Regions: EUW and every region now, one region each later
- E1 Scope chips, the cheap fix now. Each block's scope (region, period, rank) comes
  from one component, and filters.js marks a dimension the block doesn't follow, e.g.
  "Platinum+ · not by rank" or "patch 16.21 · not the 30 days picked". Done when every
  block on the champion, matchup, build and pool pages has one, pipeline_test checks
  it, and today's known mismatches are marked: the matchup builds strip (patch only),
  the lean line (every region, 30 days), and rank on the builds strip, players' win
  rates, pool and learning. Start: champion.zig variant(), static/filters.js
  showVariants(), builds.zig, lean.zig, spread.zig. Fits frontend-rework.md's ui.zig
  components if that goes first
- E2 The truth test, before anything ships. A rolling origin as in patch-transfer.md:
  for each day d of the newest patch, build each mode from games before d, then score
  its numbers against the next 7 days' games on that patch, per cell (champion-role,
  matchup, duo, gold at 14, build share), by rank bracket and day since the patch.
  Scores: binomial log loss for rates, squared error with the cell's noise subtracted
  for averages. Gate: the estimate beats both raw windows in every day-since-patch
  bucket for that cell kind; a cell kind ships only once it passes. Two boundaries to
  replay: 16.20 to 16.21 now, 16.21 to 16.22 live. Start: src/eval.zig's split code,
  patch-transfer Step 2 (day-since-patch scoring), meiolol-lab for anything heavy
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
  "not yet" list), brackets as today. Percentiles from E7's histograms
- E6 Builds: what people take is a fact, so shares stay raw. Meio shows the newest
  patch, falling back to the previous one for items and runes the patch left alone
  (builds.zig pick() does this for a whole build today); build win rates shrunk
- E7 Storage: day cubes, so that every mode, rank and region is a sum. Per day,
  platform, patch and rank bracket, mergeable aggregates: champion-role games, wins and
  bans; enemy and ally pairs; curve sums and sums of squares, plus fixed-bin histograms
  per minute for percentiles; build counts, per matchup too. A view becomes the sum of
  its days: no rescans of games or timelines, no fourfold stats, curves and builds
  passes, and memory per day instead of per window (today's per-matchup builds cost ~1.1
  GB a builder, which is why the 30-day builds files have no matchups). The estimate
  modes read the same cubes. Done when the views, curves --site and builds --site load
  from cubes, with sizes measured and percentile error at the chosen bins checked
  against exact percentiles. Start: partials.zig (already per-day game files, 1.2 GB on
  the box), curves.zig, builds.zig, stats.zig Slice. Box: 81 GB disk and ~9 GB of RAM
  free (22 Oct); measure a day's cube before choosing the bins
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
  16.21; seasons need either time or a backfill (patch-transfer.md "Older patches",
  Jacob's call after the key). Done when the champion page's period pick lists every
  patch we hold and the trend chart (site.md CH) reads from cubes
- E11 Models on the same understanding: the draft model, the app's reasons and the
  Daily Draft use E3-E5's terms (patch offset with the changed-champion prior, rank
  bracket, later region and season), so the site and the app agree on every number and
  the model gains what the windows can't give it. Measured in docs/model.md like any
  model change; lab-frontier.md and patch-transfer.md are where the terms are proved

Order: E1 now. E7 next, as the base: on its own it fixes the matchup builds strip per
period and rank in every block. Then E2, then E3-E5 as each passes the gate, then E9 and
the default switch (E0b). E10 follows E7; E11 follows each estimate that passes E2.

## Status

- Champion page blocks follow the region and period picks (0a88af7, 89c2a2c): players'
  win rates, the builds strip, how hard to pick up, the pool section and the patch line.
  Still fixed, each labelled: the matchup builds strip (region's patch), the lean line
  (every region, 30 days), and rank on the strips, spread, pool and learning
- Your games compares each game with EUW curves on that game's patch, whatever the
  player's region (labelled since 89c2a2c); the all-region curves for other regions
  would roughly double the service's mapped memory

## Later

- Region per region (E3's g term), once Jacob wants it
- Lean per period, once one patch has enough games past 20 min (today one daily file,
  1.19M games)
