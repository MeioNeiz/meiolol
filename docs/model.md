# Draft model: how good is it?

The lab record: every measured model and experiment since 11 Oct, never rewritten (the
curve over training size is evidence for the production key). Never read it whole:
`grep -n '^##' docs/model.md` for the map, `sed -n '/^## Shipped model/,/^## /p'
docs/model.md` for one section. Source comments cite sections by name, so keep headings.

- What the results mean, in plain words: docs/learned.md (read that first)
- Method, Baselines, Shared protocol: split, rows and outcomes every tool shares
- Experiments: dated `###` sections, oldest first; a new one goes at its end, and a line
  in learned.md when final
- Shipped model: the model the site and app use now, newest first
- Model files and tests: "Draft model file", "Lane model file", "In-game model file",
  "Model tests" (planted-effect and regression)
- Where results show (admin Models tab), Next steps

Measured with `meiolol eval` (src/eval.zig) on a read-only copy of the box DB.

```
meiolol eval --data DIR [--patch P] [--platform P] [--test-platform P]
             [--test-share 0.2] [--folds 5]
```

Copy of the box DB without touching the live one (python3 on the box, read-only source):
`sqlite3.connect("file:.../meiolol.db?mode=ro", uri=True).backup(sqlite3.connect(dst))`.

The box runs it daily (deploy/web-loop.sh, ~9 min) into data/eval-history.tsv. Watch it
from here: `deploy/box.sh model [ROWS] [-f]` (run state, AUC sparklines per model, last
runs with the best log loss vs coin flip; -f redraws every minute). Charts and the latest
report: the admin page's Models tab (https://meio.lol/admin/#models/win).

## Method

- Time split: newest 20% of games held out (test), models built only from older games
  (train). Never random: same-day games share meta and flatter every model
- Tuning (prior strengths, term weights) by 5-fold inside train only; test touched once
- Full draft: blue side's win chance. Log loss (lower is better, coin flip 0.6931),
  Brier, AUC, accuracy, calibration by decile. "± x" is the 95% interval of the paired
  per-game log loss difference to the current model: an improvement only counts when
  its interval excludes 0
- Pick metric: each test pick hidden in turn, the other nine known with roles;
  percentile of the champion actually picked among all candidates (champions with 10+
  train games in the role). If the model knows good picks, winners' picks rank higher
  than losers' (AUC above 0.5), and picks in its top 10% win more than 50%
- Role inference: all five roles of a test team hidden, share placed right
- Learning curve: same test games, models from the newest N train games
- Ceiling: published draft-only models reach ~55-57% accuracy on millions of games
  (research: loldraftai#^f6, #^f7, loldraftai-site#^f4); log loss ~0.68 at best.
  Small gains matter; honest intervals matter more

## Baselines, 2026-10-11 (6669 EUW games, patches 16.19-16.20)

Train 5335 games (27 Sep to 8 Oct), test 1334 (8 to 11 Oct, all 16.20).

| model | log loss | Brier | AUC | accuracy | log loss vs current |
| --- | --- | --- | --- | --- | --- |
| coin flip (50%) | 0.6931 | 0.2500 | 0.500 | 50.0% | +0.0002 ± 0.0032 |
| blue side rate (51.0%) | 0.6930 | 0.2499 | 0.500 | 51.0% | -0.0000 ± 0.0034 |
| champion base only | 0.6921 | 0.2495 | 0.527 | 51.6% | -0.0009 ± 0.0012 |
| current model (priors 1000/1000) | 0.6930 | 0.2499 | 0.520 | 50.5% | - |
| tuned priors (3200/800) | 0.6933 | 0.2501 | 0.512 | 50.9% | +0.0004 ± 0.0012 |
| tuned + term weights | 0.6930 | 0.2499 | 0.510 | 50.7% | +0.0001 ± 0.0020 |

- Nothing beats a coin flip measurably. Predictions span only 48-54% and calibration
  deciles are noise. Champion base rates alone are as good as anything (pair terms add
  noise at this size, not signal)
- Tuning (out-of-fold): wants heavy shrinkage, base prior 1600+ and pair prior 800+;
  pairs "off" is within 0.0001 of the best. Term weights 0.6-0.8 (shrink further),
  intercept 0.04 (blue side ~51%). None of it carried over to test measurably
- Newest patch only (481 train games, what `meiolol stats` builds by default) vs every
  patch: same test loss within noise (0.6925 vs 0.6930, ±0.0012)
- Pick metric (current model): winners' picks at the 53.3rd percentile, losers' at
  52.6th, AUC 0.506; picks in the model's top 10% won 50.6% (2771 picks). No signal
- Role inference: 91.6% of champions placed right, 81.5% of teams fully right; worst
  top (87.6%) and mid (88.2%), best bot (95.0%)
- Learning curve, 250 to 5335 train games: flat at 0.692-0.693 for every model

### Changes measured the same day (same split)

| model | log loss | AUC | log loss vs current | verdict |
| --- | --- | --- | --- | --- |
| empirical-Bayes priors (score.empiricalPriors) | 0.6922 | 0.527 | -0.0008 ± 0.0014 | opt-in, not default |
| joint ratings, L2 logistic (logreg.zig, l2 300) | 0.6920 | 0.527 | -0.0010 ± 0.0018 | eval only |

- Empirical Bayes (method of moments, unweighted over cells with 30+ games, needs 100+
  cells; meiolol-bb's research/questions/curve-statistics-method.md, Brown 2008):
  base prior 1226 games, every pair kind (duo, lane, other matchups) "off" (spread not
  measurable). It adapts as data grows and needs no grid. A 95%-lower-bound variant
  switched everything off (coin flip); with fewer than 100 cells the point estimate
  overfit (0.7235 at 250 train games), hence the cell floor
- Joint ratings: champion-role ratings fitted together (adjusts for teammates and
  opponents), the same form as a trained model will take. Out-of-fold L2 300 matches a
  ~1000-game prior. Level with marginal base rates here
- Neither beats the current model beyond noise, so app, site and Daily Draft keep
  `.{}` defaults. Switch to `empiricalPriors(...).apply(.{})` once eval shows a gain at
  volume
- `--test-platform EUW1`: test on one region, compare training on it alone with every
  scanned platform pooled (all-regions data from 2026-10-11)

- Role inference with pair evidence (log lift of two teammates' co-occurrence in those
  roles over play-rate independence, added to the brute-force score): 88.8% of
  champions right vs 91.6%, 75.8% of teams vs 81.5%. Sparse pairs add noise; reverted.
  Retry with pair shrinkage at volume
- All platforms (15, 7.9k games after the all-regions deploy), test EUW1: base-only and
  EB ~0.692, current 0.6936; training on EUW only vs pooled within noise. Lane gold
  section (lanegold.zig) waits for 500 train and 100 test games with timelines
- From 2026-10-11 the box appends a line a day to data/eval-history.tsv
  (deploy/web-loop.sh): the accuracy-vs-data curve

- Player experience (experience.zig, eval "Player experience"): a term per bin on top of
  the out-of-fold draft terms, every known player (upper bound) vs one player per game
  (the user, what the app can know), from crawled history game numbers (learning.zig
  bins) and mastery points (snapshot after the match: flattering). First run 2026-10-11
  after the rekey: 585 train / 0 test games with a crawled history, 0 with mastery;
  skipped (needs 300 / 100)

## Shared protocol, 2026-10-12 (meiolol-3c and meiolol-2a)

Both model agents score on the same rows so their numbers compare. Agreed between them;
outcomes and readings decided by Jacob the same day.

- Data: one snapshot of the three box DBs (VACUUM INTO), PUUIDs replaced by salted
  hashes, forgotten players dropped, deleted when a newer snapshot replaces it.
  Snapshot snap-20261012T2055Z (hashed; data/snap-20261012T2055Z on the Mac,
  ~/ml/snaps/ on the gpu-box): 224,910 games scanned, patches 16.19-16.20, 15
  platforms. Test from game_start 1791709711585 (11 Oct): 10,759 EUW1 games, 10,604
  reaching 15:00 with a timeline; train 174,575 games, 117,806 reaching 15:00. Every
  test game and its frame count in split.tsv, finished items per patch in
  legendaries.tsv (both in the snapshot dir). Win rows after duration_s >= 900 (player
  rows, ten per game): test 106,040 (10,604 games, the same games as the early
  outcomes), lab selection 84,820, lab dev-val 85,000; champion base rates call 51.2%
  of dev games right. snap-20261013T1954Z (13 Oct, 292,075 games): unpinned, learning
  curve only ("Data for nets" below)
- Split (from snap-20261013T2253Z, Jacob 14 Oct; rules by meiolol-33): eval's, one time
  cut over every platform, no EUW1 slice. Played = duration_s >= 900; only played games
  set cuts, fit or score; shorter games keep their start's window. Order by game_start;
  n played. Test cut T = start at sorted index n - round(0.15 n), dev cut D = at
  n - round(0.25 n); test = start >= T, dev-val = D <= start < T, dev-visible below D;
  ties go to the newer window. Folds: dev-visible played starts, b_k = s[floor(len (0.5 +
  0.1 k))], k 0-4, b_5 = +inf; fold k scores [b_(k-1), b_k), fits below b_(k-1). Finals
  fit below T; shipped exports on every played game. One function for all
  (eval.cutsOf, harness.cuts); an optional region filter (harness.Cuts.region,
  eval --test-platform) scores one platform's windows with the same cuts and fits.
  Leak note: fits for a window never see games at or after its cut, same-patch games on
  other platforms included. Before 2253Z: test = newest 20% of EUW1, train = older
  games, selection and dev-val 20% windows of EUW1
- Pin snap-20261013T2253Z, re-cut at 85fd62a (14 Oct, meiolol-73): 363,472 games
  scanned (432 skipped), 358,334 played, patches 16.19-16.20, 15 platforms. Cuts (ms):
  T 1791795719197, D 1791741249959; b_0-b_4 1791526007256, 1791574830751, 1791628507185,
  1791670472926, 1791711141905, b_5 +inf. Played games: dev_old 134,375 (16.19 52,604,
  16.20 81,771), folds 1-5 26,875 each, dev-val 35,834, test 53,750 (all 16.20); under
  15:00 4,738 more, in their start's window. Test by platform: KR 13,442, EUW1 13,407,
  VN2 9,261, NA1 4,593, BR1 3,959, rest 8,088; dev-val EUW1 6,741, KR 5,713, NA1 5,685.
  Codes 7-9 empty. Earlier tests landed: 2055Z's 10,759 (8 looks in its ledger) in fold4
  159, fold5 4,724, dev-val 3,991, test 1,885; 1954Z's 17,079 in dev-val 4,387, test
  12,692 (1954Z: never test-looked, nothing excluded). Scaling curves before the re-cut:
  0 test games. SNAP/test-exclude.tsv lists the 1,885 (2055Z's looked-at test games now
  in test). Rule: every --final reports two numbers from the same predictions, the full
  test and the test minus test-exclude.tsv; a look on a snapshot without the file says
  so (looks.record prints either). Leak note: fits for a window never see games at or
  after its cut, same-patch games on other platforms included. Seat stats: 2253Z's own
  plus 1954Z's and 2055Z's lines for games the box had pruned (0 of 5,179,830 shared
  seats differ), 372,317 games covered
- Rows: ranked solo, non-remake, complete roles (stats.scan rules). Continuous outcomes
  also need a compact timeline that reached 15:00: frames[15].t_ms >= 900000 (frame 15
  exists is not enough: games ending 14:09-14:59 have it as their end frame). Win also
  needs duration_s >= 900: earlier endings are remakes, leaver forfeits (surrender
  without the remake flag, ~1.5%) or aborts, likely decided by the leaver, not the draft
  (2026-10-12). Measured 2026-10-13 (meiolol-db, dev, same HEAD): fitting with or
  without them differs by +0.00003 ± 0.00025 nats/row on win, early outcomes
  bit-identical (already NaN), so kept for the cleaner definition. Harness and draft
  --export fit on 900 s+ games (07564cc, 3500fd3); stats.scan and eval keep them.
  Platinum IV+ only (crawl floor)
- Outcomes:
  - win: log loss, paired interval vs champion base rates
  - gold14: total_gold at frame 14
  - lanediff14: gold14 minus the lane opponent's gold14
  - cs10: minions + jungle_minions at frame 10
  - deaths15: CHAMPION_KILL events with victim = p and t < 900000 ms
  - first_item: minutes (fractional) of p's first ITEM_PURCHASED of an item in the
    patch's finished set (ddragon.legendaries: SR, purchasable, in store, cost >= 2200,
    builds into nothing, not boots/consumable/champion-only), not cancelled by an
    ITEM_UNDO (before = item, after = 0; take the next one). Sold or destroyed later
    still counts; quest/Ornn/transform upgrades don't. Never completed = censored:
    out of the MSE, censored share reported per champion-role beside it. Finished sets
    per patch in data/snap-<stamp>/legendaries.tsv (offline)
  - continuous outcomes: held-out MSE vs champion-role mean (train), paired per-row
    intervals clustered by game. Headline gain = % of base MSE in raw outcome units,
    pooled over roles (`meiolol-lab pairs`); per-role standardised gains (as in 3c's
    first table) only when labelled so, and always with test RMSE by role
- A gain counts only when its 95% interval excludes 0. Baselines to beat: champion base
  rates for everyone; 3c's additive models for 2a's interaction and embedding models
  (shared per-row prediction file, paired between any two models)
- Each model labelled with train-time features and champ-select (use-time) features.
  Use-time: champions, roles, the user's own rank and experience, aggregate facts only.
  Other players' stats and end-of-game stats: training covariates or post-game lessons,
  never champ-select inputs

## Experiments

Dated, oldest first; a new one goes at the end of this section.

### Team effects on early outcomes, 2026-10-12 (meiolol-3c)

`meiolol outcomes --data SNAP --platform all --preds DIR` (src/outcomes.zig; retired 23
Oct, code at 616e0a6) on
snap-20261012T2055Z. Train 117,806 games, test 10,604 EUW1 games (rows above, with the
game reaching 15:00: frames[15] at 900000 ms or later), ten rows per game.

Additive models, each group of effects fitted in turn on the others' residual
(backfitting) and shrunk toward 0 by a method-of-moments prior per group and role;
outcomes standardised per role on train. Groups: platform; champion; lane opponent
(own champion x opponent); bot lane partners (bottom and support, ally and enemy);
junglers (for laners); the rest of both teams; own class x enemy class counts (Data
Dragon first tag); own champion x enemy class counts; own champion x each non-lane
enemy champion. Train-time and use-time features: champions and roles only (all
champ-select legal). Preds: data/preds/snap-20261012T2055Z/ (base-champrole, 3c-*).

Gains are % of the champion-role-mean test MSE removed by each step over the one
before it, in per-role standardised units (the protocol's raw units, pooled over roles,
give 3c-team 2.75 / 4.31 / 7.70 / 3.65 / 2.00), ± 95% interval clustered by game:

| step | gold14 | lanediff14 | cs10 | deaths15 | first_item |
| --- | --- | --- | --- | --- | --- |
| platform + champion (shrunk) | 0.13 ± 0.04 | 0.03 ± 0.02 | 2.26 ± 0.16 | 0.18 ± 0.06 | 0.27 ± 0.06 |
| + lane opponent | 1.13 ± 0.15 | 3.47 ± 0.26 | 2.94 ± 0.21 | 1.62 ± 0.16 | 0.97 ± 0.13 |
| + bot lane partners | 0.80 ± 0.11 | 0.64 ± 0.13 | 0.94 ± 0.12 | 0.70 ± 0.10 | 0.52 ± 0.10 |
| + junglers | 0.23 ± 0.06 | 0.17 ± 0.06 | 0.06 ± 0.04 | 0.32 ± 0.08 | 0.06 ± 0.03 |
| + rest of both teams | 0.32 ± 0.08 | 0.24 ± 0.09 | 0.36 ± 0.09 | 0.78 ± 0.13 | 0.09 ± 0.05 |
| total, additive (3c-team) | 2.61 ± 0.22 | 4.55 ± 0.33 | 6.55 ± 0.31 | 3.60 ± 0.27 | 1.90 ± 0.19 |
| + own class x enemy classes | 0.03 ± 0.02 | 0.06 ± 0.04 | -0.00 ± 0.03 | 0.04 ± 0.03 | 0.02 ± 0.02 |
| + own champion x enemy classes | -0.02 ± 0.02 | -0.01 ± 0.02 | -0.03 ± 0.03 | -0.03 ± 0.03 | -0.04 ± 0.03 |
| + own champion x enemy champion (on 3c-team) | 0.00 ± 0.01 | 0.00 ± 0.00 | -0.02 ± 0.04 | 0.00 ± 0.00 | 0.00 ± 0.01 |

Test RMSE, champion-role mean -> 3c-team, by role (top, jungle, mid, bot, support):
gold14 898/784/820/982/567 -> 884/779/810/965/560 gold; lanediff14
1586/1201/1359/1647/807 -> 1551/1180/1330/1612/780 gold; cs10 13.0/9.8/11.8/11.6/4.8 ->
12.4/9.4/11.4/11.3/4.7; deaths15 1.8/1.5/1.7/1.8/1.7 -> 1.8/1.5/1.7/1.7/1.7; first_item
2.4/1.7/1.9/2.0/2.5 -> 2.3/1.7/1.9/2.0/2.5 minutes. Most of the spread is the game itself, not
the draft.

Spread of true effects (sd of shrunk-model effects, gold at 14): own champion 270-360;
lane opponent 74-196 (27 jungle vs jungle); bot partners 100-180 for bottom and support;
a jungler 20-65; anyone else 15-50 per champion; own class x enemy classes 0-33; own
champion x enemy classes 0-46 (2 of 5 roles), own champion x enemy champion 0-21 (off
in 3 roles). Upper 95% bounds on those three spreads (analysis.spreadBounds, 2026-10-13:
the uncut moment estimate, at least 0, + 1.645 sd over 200 resamples of train games),
gold at 14 by role top/jungle/mid/bottom/support: own class x enemy classes
24/13/22/51/31, own champion x enemy classes 55/53/77/84/73, own champion x enemy
champion 41/35/41/44/37. Deaths before 15, own champion x enemy champion under 0.07-0.09. Deaths before 15: lane 0.1-0.35, a jungler 0.1-0.17, anyone else
0.04-0.11 per champion; interactions under 0.13.

first_item censoring (no finished item by game end, games past 15:00): top 1.1%,
support 1.3%, others 0.4% or less. Supports do finish a legendary in nearly every game,
so their effects are usable.

Reading:
- Who is in the game matters beyond the lane: the bot lane partners, the junglers and
  the other three each shift gold, CS, deaths and item timing, all clear of 0. Deaths
  before 15 move most with the rest of the enemy team (0.78%, about half the lane's)
- It is additive: the same enemy shifts everyone in a role about equally. "Your
  champion against this enemy team" (by class or by champion) adds nothing detectable
  at 118k games; the shrinkage switches most of it off. So today "vs the five" can be
  shown as lane matchup plus the sum of each enemy's effect, not as a champion-specific
  team counter. 2a's embedding and interaction models must beat 3c-team to show more
- Gains are small in MSE terms (a lane matchup is ~1-3.5%) because one game's numbers
  are mostly the game. They are real: intervals are a tenth of the gains

### Champion embeddings against the enemy team, 2026-10-12 (meiolol-2a)

`meiolol-lab enemy SNAP preds` (src/lab/enemy.zig, fm.zig) on snap-20261012T2055Z, the
same rows; run 20261012T2210Z-enemy7 on the gpu-box (dcbd6f0). Nested models per
outcome, fitted by Adam with L2, grid (dim 4/8/16, L2) and epochs picked on the newest
20% of train, refit on all train, test once:

- additive: champion-role mean + platform x role + each enemy and ally champion-role's
  effect on my role
- lane: + an embedding interaction with the lane opponent only (both enemies for bot
  and support): w[my role][their role] * <u[me], v[them]>
- pairwise: the same interaction with all five enemies, each role pair weighted

Use-time features: champions, roles, platform (champ-select legal). Compared with
`meiolol-lab pairs` (src/lab/pairs.zig): gain as % of base-champrole MSE in raw outcome
units (3c's table above standardises per role first, so its % differ slightly; on raw
units 3c-team is 2.75 / 4.31 / 7.70 / 3.65 / 2.00), ± 95% clustered by game:

| comparison | gold14 | lanediff14 | cs10 | deaths15 | first_item |
| --- | --- | --- | --- | --- | --- |
| lane vs additive (lane interaction) | 0.41 ± 0.11 | 0.60 ± 0.16 | 0.77 ± 0.18 | 0.04 ± 0.07 | 0.44 ± 0.10 |
| pairwise vs lane (the other four enemies) | -0.13 ± 0.09 | -0.09 ± 0.06 | 0.02 ± 0.12 | 0.03 ± 0.05 | -0.06 ± 0.09 |
| lane vs 3c-team | 0.22 ± 0.13 | 0.79 ± 0.19 | 0.23 ± 0.19 | 0.46 ± 0.12 | 0.07 ± 0.30 |
| additive vs 3c-team | -0.19 ± 0.17 | 0.19 ± 0.25 | -0.54 ± 0.22 | 0.42 ± 0.13 | -0.37 ± 0.32 |

Interaction size in the pairwise model (RMS of the term on test rows), where it is free
to weight any role pair: gold14 top vs top 97 gold, mid vs mid 32, bot vs bot 9, every
other pair under 7; lanediff14 top 216, mid 104, bot vs bot 47 and vs support 42, off
the lane 0-27; jungle vs anyone ~0.

Reading:
- The answer to "your champion against the whole enemy team" is the same as 3c's:
  champion-specific interactions live in the lane. Letting every enemy interact adds
  nothing (pairwise vs lane within noise, slightly negative); the model itself puts
  its interaction weight on the lane diagonal. Beyond the lane the enemy team acts
  additively (3c's groups), at 118k train games
- A low-rank lane interaction (embeddings) beats 3c's shrunk lane-pair cells on
  lanediff14 (+0.79) and gold14 (+0.22): pairs with few games borrow from similar
  champions. Worth carrying into the lane curves where pair cells are thin
- deaths15: additive alone beats 3c-team (+0.42), so the gain is in the additive part
  (ally/enemy terms by my role, unshrunk), not interactions; worth checking which
  group with 3c
- Compute: each fit is 1-5 s single-threaded on 1.2M rows; a whole run (5 outcomes x
  4 models x grid) is ~5 minutes on one gpu-box core. No GPU needed at this size

Where the lane model's gain over 3c-team comes from (`meiolol-lab lanebuckets`,
src/lab/lanebuckets.zig): test rows bucketed by their lane pair's train rows (my
champion and role against the enemy champion in my role), gain as % of base MSE within
the bucket:

| pair train rows (test rows) | gold14 | lanediff14 | cs10 | deaths15 | first_item |
| --- | --- | --- | --- | --- | --- |
| <25 (16.4k) | 0.92 ± 0.48 | 2.37 ± 0.61 | 2.20 ± 0.71 | 1.10 ± 0.45 | 0.85 ± 0.44 |
| 25-99 (28.7k) | 0.40 ± 0.28 | 0.96 ± 0.40 | 0.11 ± 0.35 | 0.73 ± 0.25 | 0.43 ± 0.26 |
| 100-399 (44.7k) | -0.07 ± 0.17 | 0.24 ± 0.24 | -0.30 ± 0.23 | 0.24 ± 0.15 | -0.45 ± 0.69 |
| 400+ (16.2k) | 0.00 ± 0.24 | 0.33 ± 0.34 | -0.39 ± 0.31 | -0.08 ± 0.17 | 0.02 ± 0.20 |

- The gain is the thin pairs': under 25 games the embeddings beat the shrunk cells
  clearly on every outcome, 25-99 still on gold, lane diff, deaths and item timing; from
  100 games on the cells are as good (cs10 slightly better)
- For the site's lane curves: use the embedding estimate for matchups under ~100 games
  and the pair cells above, or blend by count. A sixth of test rows sit in pairs under
  25 games, so it matters on many pages

### 3c-team2: the lane opponent's own effect, 2026-10-12 (meiolol-b0)

2a's additive model beat 3c-team on deaths15 (+0.42) without interactions. The gap:
3c-team's lane group is only the own champion x opponent cell, shrunk hard where the
pair is thin, so an opponent's effect on everyone in the role was lost there. Two groups
added to `meiolol outcomes` (src/outcomes.zig): the lane opponent's champion in my role
(fitted before the pair cell) and role x patch (unshrunk, for the newer games' drift
meiolol-f2 found). The rest-of-team groups were already per my role x their role.

Raw units, % of base-champrole MSE pooled over roles (`meiolol-lab pairs`), ± 95%
clustered by game:

| comparison | gold14 | lanediff14 | cs10 | deaths15 | first_item |
| --- | --- | --- | --- | --- | --- |
| 3c-team-patch vs 3c-team (+ patch) | 0.00 ± 0.01 | 0.00 ± 0.00 | 0.06 ± 0.01 | -0.01 ± 0.01 | 0.01 ± 0.01 |
| 3c-team2 vs 3c-team (+ patch, + lane opponent) | 0.35 ± 0.08 | 0.64 ± 0.12 | 0.66 ± 0.11 | 0.60 ± 0.09 | 0.29 ± 0.07 |
| 2a-additive vs 3c-team2 | -0.53 | -0.45 | -1.19 | -0.18 | -0.66 |
| 2a-lane vs 3c-team2 | -0.13 ± 0.11 | 0.14 ± 0.15 | -0.42 ± 0.16 | -0.14 ± 0.08 | -0.22 ± 0.30 |

(2a-additive vs 3c-team2 is the difference of their gains over 3c-team, no interval.)
3c-team2 totals over base: gold14 3.09, lanediff14 4.95, cs10 8.35, deaths15 4.26,
first_item 2.29. Spread of the lane opponent's own effect: gold14 74-219 gold by role,
lanediff14 278-461, deaths15 0.18-0.41.

Reading:
- 3c-team2 is the reference now: it beats 2a's additive on every outcome and 2a's lane
  embeddings on cs10 and deaths15; lanediff14 and gold14 are within noise of them. Most
  of the embeddings' thin-pair gain was the opponent's main effect, which pair cells
  lose when they shrink to 0
- Patch adds nothing on the test games (all 16.20; train has both patches): f2's
  dev-val drift is within-patch time, not patch. Kept in 3c-team2, harmless
- Preds: 3c-team-patch.tsv, 3c-team2.tsv (3c-team.tsv unchanged, byte for byte)

### Objective value given the state, 2026-10-12 (meiolol-b0)

`meiolol objectives --data SNAP --platform all --preds DIR` (src/objectives.zig), same
split. One row per game and minute (10, 15, 20, 25, 30) for games still going after it:
blue's win from blue-minus-red state at that frame. Logistic regressions per minute:
gold and XP lead (with a curve term), then objectives held: towers taken, inhibitors
down now, elemental dragons, soul point (3 dragons, no soul yet), soul, elder buff
active, grubs, herald, baron buff active. Atakhan: none in 2026 games. Raw data note:
DRAGON_SOUL_GIVEN with teamId 0 is the soul element announced after the second dragon,
not a soul taken. Train-time and use-time features: in-game state (post-game lessons,
never champ select). Preds: 3c-obj-{lead,held,elements,x}.tsv (match_id, minute).

Test log loss gain, nats per game (EUW1 test games still going), ± 95%:

| minute | test games | gold and XP lead (vs win rate) | + objectives held | dragons by element instead | + objective x gold lead |
| --- | --- | --- | --- | --- | --- |
| 10 | 10,660 | 0.1031 ± 0.0080 | 0.0083 ± 0.0023 | 0.0002 ± 0.0003 | 0.0000 ± 0.0000 |
| 15 | 10,604 | 0.1703 ± 0.0096 | 0.0121 ± 0.0028 | -0.0000 ± 0.0003 | -0.0001 ± 0.0001 |
| 20 | 9,885 | 0.2214 ± 0.0106 | 0.0128 ± 0.0032 | -0.0001 ± 0.0003 | -0.0002 ± 0.0002 |
| 25 | 8,168 | 0.2576 ± 0.0121 | 0.0161 ± 0.0039 | -0.0003 ± 0.0003 | -0.0005 ± 0.0003 |
| 30 | 4,630 | 0.2260 ± 0.0148 | 0.0178 ± 0.0059 | -0.0001 ± 0.0005 | 0.0000 ± 0.0003 |

Value beyond the gold each brought, as the team gold lead worth the same at that
minute (log-odds weight / gold weight; "-" under 30 train games with it):

| held (one more than the enemy) | 10 min | 15 min | 20 min | 25 min | 30 min |
| --- | --- | --- | --- | --- | --- |
| 1000 gold lead, log-odds | 0.345 | 0.253 | 0.216 | 0.161 | 0.125 |
| 1000 XP lead | 522 | 400 | 401 | 565 | 625 |
| elemental dragon | 839 | 1034 | 997 | 1083 | 1071 |
| soul point | - | - | 927 | 763 | 787 |
| soul | - | - | - | 4291 | 3912 |
| elder buff active | - | - | - | - | 4800 |
| baron buff active | - | - | - | 406 | 970 |
| inhibitor down | - | (616) | 869 | 1447 | 2285 |
| tower | -310 | -216 | -74 | (40) | (88) |
| grub | 156 | 137 | 90 | 95 | 106 |
| herald | - | - | 198 | (-82) | -434 |

Brackets: 95% interval wider than the value. Otherwise intervals are about ±4% of the
value for dragons, XP and grubs at 10-15 min, ±20% for soul, ±40-60% for elder, baron,
herald and soul point, ±65% for inhibitors at 20 min and ±13-21% after.

Reading:
- A dragon is worth about 1000 gold of lead beyond its own gold, at every minute; soul
  about 4000; elder about 4800 (few games). Soul point adds ~800-900 on top of the
  three dragons. A grub ~100-150, a herald ~200 at 20 min then nothing
- Towers are worth their gold and no more (their plates and bounty are in the lead;
  early towers slightly negative beyond it: the gold came from the tower, not fights)
- Baron is worth ~400-1000 beyond its 1500 team gold while the buff is up; an
  inhibitor down grows from ~900 at 20 min to ~2300 at 30
- The value is the same whoever is ahead (objective x gold lead: nothing) and dragon
  elements differ (mountain and ocean highest, chemtech and cloud lowest, ~±200 gold)
  without improving prediction. Descriptive: teams that take objectives differ in
  ways the state misses, so these are upper bounds on what taking one causes

### Items given the state at purchase, 2026-10-12 (meiolol-b0)

`meiolol items --data SNAP --platform all --preds DIR` (src/items.zig; retired 23 Oct,
code at 616e0a6), same split,
games with a timeline (119,479 train, 10,759 test). Rows: each player's first three
distinct finished items (the first_item finished set and undo rule): 2.94M train,
268k test. Baseline: logistic win from the purchase's state per slot (minute, team gold
lead and lane gold lead at the frame before, with a lead x 1/minute term). On its
residual, additive shrunk effects in win probability (backfitting, method-of-moments
prior per group and role, as outcomes): champion in role; item in role and slot; item
on the champion. Train-time: the state at purchase; use-time: post-game lessons only.
Preds: 3c-items-{state,champ,item,champitem}.tsv (match_id, slot, k).

| model | test log loss | gain, nats per row ± 95% clustered by game |
| --- | --- | --- |
| train win rate | 0.6923 | - |
| state at purchase | 0.5219 | 0.17045 ± 0.00784 |
| + champion | 0.5203 | 0.00158 ± 0.00049 |
| + item in role and slot | 0.5202 | 0.00008 ± 0.00005 |
| + item on the champion | 0.5202 | 0.00000 ± 0.00000 |

Spread of true effects (sd, win pp): champion given the state 5.2-9.3 by role; item in
role and slot top 1.0, jungle 1.5, off in mid, bottom and support; item on the champion
off in every role (no detectable spread; upper 95% bound 2.7-3.3 win pp by role,
analysis.spreadBounds, 2026-10-13). Largest item effects (shrunk, 500+ rows):
jungle Edge of Night 2nd +2.9, Youmuu's 1st -2.9, Guardian Angel 3rd +2.8, Malignance 1st
-2.4, Death's Dance 2nd +2.0; top Sundered Sky 3rd -1.9, Frozen Heart 1st +1.6, Black
Cleaver 1st +1.5.

Reading:
- Which item a player finishes says almost nothing about the win beyond when they
  finished it and how far ahead they were: the item term is a twentieth of the
  champion's and the champion-specific item term is nothing at 118k games
- The state at purchase is most of it: an item finished late or behind loses
- So item advice from win rates ("best build") is not supported at this volume; item
  timing and the lead are. Item x enemy team is meiolol-2a's; with no main effect here
  it would have to be a pure interaction
- Champion given the state (5-9 pp sd) is large: champions convert the same lead
  differently (scaling, team fight value). Worth its own look as lesson material

### Win from the draft, dev only, 2026-10-12 (meiolol-88)

Candidate src/lab/cand/win-ratings: one logistic model per game (blue's chance), Adam,
L2 and dim picked on the newest 10% of visible games, refit on all. Variants are copies
with one `cfg` line changed: rates `.{ .kind = .rates }` (eval's base: marginal log-odds,
prior 1000), ratings (joint, eval's "joint"), lane, counters (all 25 cross pairs), full
(+ ally synergy), rank `.own_rank = true`, allranks `.all_ranks = true` (post-game),
euw `.platform = 6`, hl3/hl7 `.half_life = 3/7`. Dev only: fit on the ~90k games
older than dev-val, scored on dev-val (8,608 EUW1 games, 86,080 rows); Mac,
`meiolol-lab exp run` with a scratch --lab (no looks spent). Sub-15:00 forfeits still
in (harness filter pending, meiolol-39): rerun before final. Paired ± is clustered by
game, from each run's dev.tsv.

| model | log loss | AUC | vs ratings |
| --- | --- | --- | --- |
| coin | 0.6931 | 0.500 | |
| rates | 0.6898 | 0.549 | +0.0001 ± 0.0005 |
| ratings | 0.6897 | 0.550 | - |
| lane | 0.6902 | 0.547 | +0.0005 ± 0.0007 |
| counters | 0.6897 | 0.550 | +0.0001 ± 0.0005 |
| full | 0.6902 | 0.546 | +0.0005 ± 0.0007 |
| hl7 (recency) | 0.6898 | 0.549 | +0.0001 ± 0.0004 |
| euw (EUW1 games only) | 0.6921 | 0.526 | +0.0024 ± 0.0014 |
| rank (own rank) | 0.6891 | 0.552 | -0.0006 ± 0.0001 |
| allranks (post-game) | 0.6586 | 0.672 | -0.031 |

Learning curve (nested shares of the visible games; rates, ratings within noise of
each other):

| games | 4.5k | 9k | 18k | 31k | 45k | 67k | 90k |
| --- | --- | --- | --- | --- | --- | --- | --- |
| rates log loss | 0.6926 | 0.6925 | 0.6912 | 0.6912 | 0.6907 | 0.6898 | 0.6898 |
| ratings AUC | 0.522 | 0.522 | 0.536 | 0.538 | 0.543 | 0.548 | 0.550 |

Reading:
- Champions alone now beat a coin: ~0.6897 log loss, AUC 0.55 at 90k games. The
  curve fell from 4.5k to 67k (~0.0008 log loss and ~0.006 AUC per doubling over that
  range) but 67k to 90k is flat within the ±0.0005 paired noise, so a plateau can't be
  ruled out; extrapolating to ~1M games is not supported yet
- Data volume is the lever, not model form: interactions (lane, every enemy, ally
  synergy) add nothing detectable on win at 90k games, although lane embeddings do on
  gold and CS (2a). Pool every region (EUW1 alone is clearly worse); recency weighting
  within 16.19-16.20 gains nothing
- Ranks leak: participants.tier/division is the snapshot when the match was stored,
  after the game. allranks' -0.031 and part of own rank's -0.0006 are the result
  showing through. Rank needs rank_history at game time before it counts as a feature

### Playstyle given the state, 2026-10-12 (meiolol-b0)

`meiolol playstyle --data SNAP --platform all --preds DIR` (src/playstyle.zig), rows as
the protocol's continuous outcomes (games reaching 15:00; 117,806 train, 10,604 test,
ten rows each), outcome win. Style per player from minutes 0-13, standardised per
role: away (laners: position frames from minute 3 out of their own lane band and base;
junglers: in any lane), enemy_half (frames past the river diagonal), fights (kills +
assists + deaths), damage to champions, wards placed, control wards, wards killed,
off-role CS (laners: jungle camps; junglers: lane minions). Map zones are rough bands
on one position a minute. Logistic, L2 1: champion x role dummies, then style x role,
with and without the state at 14:00 (team gold lead, team XP lead, lane gold lead, by
role). Use-time: the user's own style, post-game only. Preds: 3c-style-*.tsv.

| model | test log loss | gain, nats per row ± 95% clustered by game |
| --- | --- | --- |
| champion in role | 0.6930 | - |
| + style | 0.6718 | 0.02119 ± 0.00174 |
| champion + state at 14:00 | 0.5314 | 0.16158 ± 0.00930 (vs champion) |
| + style, given the state | 0.5310 | 0.00038 ± 0.00015 |

Style weights given the state, win pp per +1 sd ± 95% clustered by game (sandwich,
logreg.clusteredStdErrors; 2026-10-13). The unclustered Hessian gave about the same
widths: a game's ten rows are half winners and half losers with mirrored state, so their
scores partly cancel rather than add:

| feature | top | jungle | middle | bottom | utility |
| --- | --- | --- | --- | --- | --- |
| away | 0.23 ± 0.23 | -0.85 ± 0.24 | 0.31 ± 0.22 | 0.69 ± 0.22 | 0.64 ± 0.22 |
| enemy_half | -0.23 ± 0.35 | 0.46 ± 0.26 | 0.16 ± 0.32 | -0.31 ± 0.33 | 0.98 ± 0.32 |
| fights | 0.39 ± 0.19 | -0.60 ± 0.30 | -0.20 ± 0.24 | -1.10 ± 0.24 | 0.91 ± 0.21 |
| damage | 0.44 ± 0.31 | 1.04 ± 0.36 | 1.65 ± 0.35 | 2.36 ± 0.34 | 0.65 ± 0.36 |
| wards | 0.57 ± 0.27 | 0.20 ± 0.29 | 0.70 ± 0.30 | 0.26 ± 0.28 | 0.65 ± 0.28 |
| control_wards | -0.41 ± 0.27 | 0.01 ± 0.28 | -0.66 ± 0.31 | -0.58 ± 0.28 | -0.29 ± 0.30 |
| ward_kills | 0.56 ± 0.24 | 0.32 ± 0.26 | 0.43 ± 0.24 | 0.53 ± 0.23 | 0.31 ± 0.25 |
| off_role_cs | 0.29 ± 0.26 | -0.15 ± 0.25 | 0.67 ± 0.26 | 0.77 ± 0.25 | 0.56 ± 0.25 |

Without the state the same features look large (enemy_half 5.5-8.9 pp per sd, damage
4.5-7.4, support fights 5.3): that is mostly being ahead, not style.

Reading:
- Early style says little about winning beyond the state it produced: a twentieth of
  its apparent value once the gold and XP leads at 14:00 are known. "Play in the enemy
  half" is a symptom of winning, not a recipe
- What survives, small: trading damage (bottom +2.4, mid +1.7 pp per sd), warding and
  clearing wards (+0.2-0.7), laners taking spare camps (+0.3-0.8), supports roaming and
  fighting (+0.6-1.0). Fighting more for the same gold hurts bottom (-1.1); junglers
  who spend more time in lanes than the state rewards lose a little (-0.85). Control
  wards bought for the same gold lead go with losing (-0.4 to -0.7 top, mid, bottom;
  not detected for supports or junglers): likely behind teams buy them, not that they
  hurt
- Lesson material at most, with intervals; one sd of any style is worth under 2.5 pp
  once the state is known
- Superseded in part (2026-10-13, meiolol-3f): with objectives held at 14:00 in the
  state too, these eight features' gain halves (test +0.00020 ± 0.00011) and nothing
  beyond them is detected; see "Playstyle clusters and sequence net"

### Champion given the state (scaling), 2026-10-13 (meiolol-b0's successor)

`meiolol scaling --data SNAP --platform all --preds DIR --table FILE` (src/scaling.zig;
retired 23 Oct, code at 616e0a6),
same split, games reaching 15:00 (117,806 train, 10,604 test), ten rows per game at the
draft (minute 0) and at 10/15/20/25/30 while still going. Baseline per minute: logistic
win from the own team's gold lead (with objectives' curve term) and XP lead. On top, in
log-odds: champion x role per minute (the scaling curve), and champion x role x team gold
lead (converts a lead / comes back), each shrunk by a method-of-moments prior per role,
fitted by IRLS backfitting (8 passes). A first version added the effects in probability
space and lost on test after 20 min (predictions pushed past 0/1 in decided games); the
log-odds fit fixed it. Effects reported as win pp in an even game (log-odds x 25) and as
the team gold lead worth the same at that minute. Train-time: the state; use-time:
lessons and aggregate facts only. Preds: 3c-scale-{state,pooled,champ,slope}.tsv
(match_id, slot, minute); every champion-role by minute in 3c-scale-table.tsv, full
report 3c-scale-report.md (same dir).

Test log loss gain, nats per row ± 95% clustered by game (state: log loss, [win pp per
1000 gold lead in an even game]):

| minute | test rows | state | champion, one effect for 10-30 min vs state | champion by minute vs state | by minute vs one effect (scaling curve) | + champion x gold lead |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | 106,040 | 0.6931 | - | 0.00028 ± 0.00018 | - | 0.00000 ± 0.00000 |
| 10 | 106,040 | 0.5914 [9.4] | 0.00138 ± 0.00044 | 0.00159 ± 0.00033 | 0.00021 ± 0.00018 | -0.00002 ± 0.00005 |
| 15 | 106,040 | 0.5229 [6.8] | 0.00198 ± 0.00040 | 0.00210 ± 0.00038 | 0.00011 ± 0.00011 | -0.00009 ± 0.00009 |
| 20 | 98,850 | 0.4718 [6.0] | 0.00223 ± 0.00039 | 0.00236 ± 0.00041 | 0.00013 ± 0.00010 | -0.00008 ± 0.00008 |
| 25 | 81,680 | 0.4353 [4.9] | 0.00205 ± 0.00042 | 0.00235 ± 0.00045 | 0.00030 ± 0.00016 | -0.00000 ± 0.00005 |
| 30 | 46,300 | 0.4668 [4.5] | 0.00194 ± 0.00057 | 0.00207 ± 0.00057 | 0.00013 ± 0.00032 | 0.00003 ± 0.00006 |

Spread of true effects beyond the state (sd across champions, win pp in an even game):

| role | draft | 10 | 15 | 20 | 25 | 30 |
| --- | --- | --- | --- | --- | --- | --- |
| top | 3.3 | 3.2 | 3.3 | 3.3 | 3.5 | 1.0 |
| jungle | 3.9 | 2.1 | 2.8 | 3.8 | 4.8 | 6.1 |
| middle | 3.7 | 4.3 | 4.0 | 5.4 | 5.3 | 5.4 |
| bottom | 1.0 | 3.7 | 4.8 | 4.4 | 5.1 | 8.5 |
| utility | 4.7 | 7.4 | 8.8 | 11.2 | 9.5 | 7.5 |

Lead slopes: spread 0 in most role-minutes, at most 2 pp per 1000 (jungle 10-20), and
never a test gain. Examples (shrunk, ± 95%, [gold lead worth the same]; 500+ train games):

| role | wins more than its gold says, at 25 | wins less | scaling (25 minus 10 min) |
| --- | --- | --- | --- |
| top | Kayle +13.9 ± 2.7 [2900], Ornn +9.5 ± 2.3 [1900] | Akali -6.2 ± 2.5 [-1300], K'Sante -5.5 ± 2.3 [-1100] | Kayle +7.6 ± 3.4, Ornn +5.1 ± 2.8; Warwick -6.4 ± 4.0, Urgot -4.3 ± 3.2 |
| jungle | Bel'Veth +11.8 ± 2.8 [2400], Rammus +9.1 ± 2.7, Cho'Gath +8.6 ± 1.6 | Hecarim -6.7 ± 2.1 [-1400], Zed -5.2 ± 2.6 | Bel'Veth +6.7 ± 3.4, Cho'Gath +6.3 ± 2.0; Talon -4.1 ± 2.3 |
| middle | Aurelion Sol +11.8 ± 3.0 [2400], Kassadin +8.3 ± 2.6 | Irelia -8.7 ± 2.6 [-1800], Locke -7.3 ± 1.7 [-1500] | Aurelion Sol +5.6 ± 3.7; Fizz -4.0 ± 2.2, Akali -3.2 ± 2.2 |
| bottom | Smolder +9.3 ± 1.8 [1900], Jinx +7.5 ± 1.1 [1500], Twitch +6.2 ± 1.8 | Draven -7.7 ± 2.2 [-1600], Ezreal -7.4 ± 1.3 [-1500], Varus -7.3 ± 2.5 | Aphelios +4.6 ± 1.9, Caitlyn +3.1 ± 1.3; Kai'Sa -5.9 ± 1.3 |
| utility | Sona +8.3 ± 2.8 [1700], Yuumi +7.8 ± 2.0, Milio +7.7 ± 1.8, Lulu +6.3 ± 1.3 | Pyke -12.7 ± 1.8 [-2600], Camille -10.4 ± 3.3, Sylas -8.1 ± 3.7 | Seraphine +4.6 ± 2.0, Yuumi +4.3 ± 2.4; Pyke -4.6 ± 2.2, Leona -3.5 ± 1.9 |

Reading:
- The same gold lead is worth very different amounts depending on who holds the
  champions: a typical spread (one sd) of 3-11 pp in an even game, worth 500-2300 gold
  of lead, about one or two dragons. Champions beat their draft win rate given the
  state because their team's gold usually says something else: Kayle wins at an average
  rate overall (draft +0.4) while usually behind on gold, so at equal gold it wins far
  more
- Not who holds the gold: with gold by role in the state (below) the champion effects
  barely move, so they are the champion's value at equal gold, not gold sitting on a
  low-value role
- Most of a champion's value beyond the state is the same at every minute (one effect
  for 10-30 gets 85-95% of the gain); a real but small scaling curve on top (+0.0001-0.0003
  nats at 10, 20, 25). Bottom laners' spread grows with the game (3.7 at 10 to 8.5 at
  30), top's shrinks after 25
- No champion converts a lead or comes back from behind measurably differently from its
  general value: "from 2k behind at 15" is the same effect as at even, at 118k games.
  The spread estimate is cut at 0 and reaches ~2 pp per 1000 gold (jungle 10-20).
  Upper 95% bound across champions (analysis.spreadBounds, 2026-10-13: the uncut
  moment estimate, at least 0, + 1.645 sd over 200 resamples of train games), pp per
  1000 team gold lead, top/jungle/mid/bottom/support: 10 min 3.2/4.4/3.0/4.5/3.4,
  15 min 2.0/3.4/2.5/2.8/2.6, 20 min 1.6/3.8/1.7/2.2/1.9, 25 min 1.8/2.0/1.6/3.2/3.0,
  30 min 1.5/1.9/1.7/2.2/2.0. So at 15:00 and 2,000 gold behind, a champion one sd from
  its role's average comes back at most ~4-7 pp better or worse than its even-game value
- Descriptive: who picks the champion and the rest of their team are not held fixed.
  Lesson material with intervals, never a pick reason

Who holds the gold, and objectives (sensitivity, 2026-10-13). `--state roles` replaces
the team gold lead with the gold lead at each role (plus the team curve term and XP);
`--slope own` makes the champion's slope its own gold minus its lane opponent's (is gold
on this champion worth more than on others in the role?). `--state objectives` uses
objectives' lead + held (winchance's state). Protocol note: all three variants were
scored on test after the first run, as sensitivity checks of one reported model, not to
pick one; nothing ships from them. Preds 3c-scale-*-{roles-own,roles-team,
objectives-team}.tsv, reports 3c-scale-report-{roles-own,objectives-team}.md, tables
3c-scale-table-*.tsv.

| minute | roles state vs team-gold state | objectives state vs team-gold state | champion by minute, roles state | champion by minute, objectives state | own-gold slope, roles state |
| --- | --- | --- | --- | --- | --- |
| 10 | 0.00180 ± 0.00138 | 0.00826 ± 0.00233 | 0.00157 ± 0.00032 | 0.00171 ± 0.00034 | 0.00006 ± 0.00010 |
| 15 | 0.00375 ± 0.00184 | 0.01190 ± 0.00276 | 0.00198 ± 0.00036 | 0.00225 ± 0.00040 | 0.00003 ± 0.00007 |
| 20 | 0.00448 ± 0.00190 | 0.01253 ± 0.00320 | 0.00217 ± 0.00039 | 0.00256 ± 0.00043 | -0.00004 ± 0.00006 |
| 25 | 0.00389 ± 0.00174 | 0.01581 ± 0.00388 | 0.00221 ± 0.00043 | 0.00259 ± 0.00048 | -0.00002 ± 0.00008 |
| 30 | 0.00345 ± 0.00210 | 0.01725 ± 0.00587 | 0.00197 ± 0.00055 | 0.00248 ± 0.00063 | -0.00000 ± 0.00005 |

Win pp per 1000 gold lead at each role in an even game (roles state): top 8.0 / 4.5 /
4.7 / 4.3 / 4.2 at 10/15/20/25/30; jungle 10.9 / 7.6 / 6.3 / 4.8 / 4.0; middle 10.6 /
6.8 / 5.5 / 4.5 / 4.2; bottom 12.0 / 9.0 / 8.1 / 6.5 / 5.7; utility 2.4 / 0.9 / 1.8 /
2.4 / 3.2 (XP 5.0 to 2.4 per 1000).

Champion effects, win pp in an even game at 15 / 25 (team gold state; roles; objectives):
Kayle top 10.3/13.9; 8.4/13.6; 9.9/15.7. Pyke support -9.7/-12.7; -8.6/-11.5;
-10.3/-12.1. Camille support -9.9/-10.4; -6.8/-7.8; -10.3/-10.0. Yuumi 5.6/7.8; 4.2/5.8;
6.7/10.2. Bel'Veth 8.6/11.8; 9.6/11.6; 10.4/15.1. Aurelion Sol mid 8.9/11.8; 9.1/11.2;
9.6/13.2. Draven -8.2/-7.7; -9.6/-10.1; -8.8/-7.8. Spreads by role move by under 2 pp
(utility 8.8 to 7.1 at 15 with roles).

Reading:
- Who holds the gold matters in general: gold on the support is worth a fifth to a
  third of gold on the bot laner, and bot gold is worth the most at every minute. That
  is in the baseline now, and the champion effects stay: Kayle's team still wins like
  one far ahead at equal gold by role, Pyke's still loses more. So the effects are the
  champion's value at equal gold (scaling, fighting), not gold on a low-value role. Only
  the support kill-takers shrink a little (Camille -10.4 to -7.8 at 25)
- No champion's own gold is measurably worth more than another's in the role (own-gold
  slopes: no test gain)
- With objectives in the state the champion effects hold or grow slightly: champions'
  value is not through the objectives their teams take

### Win chance by minute (Your games), 2026-10-13 (meiolol-8a's successor)

`meiolol winchance --data SNAP [--dev] [--knots 1,5,...]` (src/winchance.zig), weights
in src/winchance_weights.zig, read by Your games (win chance, turning minute, death
cost). State: objectives.zig's lead + held (gold, gold curve, XP, towers, inhibitors
down, dragons, soul point, soul, elder, grubs, herald, baron; blue minus red), ranked
solo games of 15:00+, every minute 1-40 while the game is going. Split: test = newest
fifth of EUW1 games in this set (cutoff 1791717443682, 9,648 games; the set needs a
timeline but not complete roles, so the cutoff is a little later than the protocol's),
train = older games, every platform (120,690). Dev: every fifth train game by match id.

Fix for a live bug (meiolol-47's review): one logistic fit per minute, no minimum
count, so rare features got wild weights (towers +0.08, +0.60, -0.81, -0.15 at minutes
6-9), and an early tower near 8:00 could move win chance ~13-20 pp and become the
"turning minute". Now one fit over every game-minute, each weight linear in minute
between knots (hat basis, L2 1), written out per minute so the file format and
winchance.blue are unchanged.

Chosen on dev (24,056 games), log loss summed over a game's minutes vs per-minute fits
(± 95% over games), and win chance moved by the next minute's weights alone with the
state held (pp over game-minutes, the artefact Your games shows):

| variant | log loss vs per minute | moved: mean / 99th pct / largest |
| --- | --- | --- |
| per minute (old method) | - | 0.64 / 2.42 / 31.3 |
| per minute, feature zeroed under 300 train games | +0.0001 ± 0.0002 | 0.64 / 2.42 / 18.0 |
| knots 1,3,5,8,11,14,17,20,24,28,32,36,40 | -0.0001 ± 0.0003 | 0.59 / 1.79 / 6.1 |
| knots every 5 min (1,5,...,40), chosen | +0.0002 ± 0.0004 | 0.57 / 1.75 / 5.4 |
| knots 1,2,3,5,7,...,36,40 | -0.0002 ± 0.0002 | 0.60 / 2.05 / 7.2 |

Log loss ties everywhere; every 5 minutes is the smoothest. The 300-game floor does not
fix it (a weight switching on is itself a jump). Test, touched once for the chosen knots
(the turning-minute and shipped rows were added to the report afterwards, same fit):

| model | log loss vs per minute | moved: mean / 99th / largest | turning minute: mean jump, differs from smooth |
| --- | --- | --- | --- |
| per minute, refit on train | - | 0.62 / 2.35 / 14.4 | 20.1 pp, 5.5% of games |
| smooth, every 5 min | -0.0000 ± 0.0006 | 0.56 / 1.73 / 4.4 | 20.1 pp, - |
| shipped file before this (per minute, 148,200 games) | -0.0024 ± 0.0021 | 0.62 / 2.29 / 19.2 | 20.1 pp, 5.5% |

The shipped file's small edge is not a fair comparison: it was fit on every fifth game
held out by match id, so most of these test games were in its training. Where the
turning minute moves it is the early-tower artefact, e.g. EUW1_7864005401808869: shipped
9:00 (+22 pp), smooth 3:00 (+8); EUW1_2012568456711544: shipped 8:00 (+23), smooth 12:00
(+18). Early towers given the gold lead now weigh about -0.2 to -0.26 at 5-10 min
(fitted from minutes 5-15 together) instead of swinging sign each minute. A test in
winchance.zig fails if adjacent minutes' weights differ by 0.3 or more.

#### Rich state and champions (richc), snap-20261013T2253Z re-cut, 2026-10-14

Owner meiolol-state (progress: docs/archive/2026-10-14-model-team/agent-state/progress-state.md; research:
research/questions/live-win-probability.md, correlated-importance.md); audited from the
run dir by the state shipping session. Run 20261014T032052Z-state-richc-2253Zr
(py/state/statemodels.py at 8e264cd, `--models wc,rich,richc`, gpu-box CPU, exit 0,
03:39-06:27Z). Data: SNAP/state from state-export run
20261014T004121Z-state-export-2253Z-recut (src/lab/stateexport.zig; 363,472 games,
290,825 with a 10-player timeline; game order and match ids equal to SNAP/nn's).

Models, each a logistic regression on blue-minus-red features with every weight and the
intercept linear in minute between knots 1, 5, ..., 40 (winchance's form; L2 1e-5 on
standardised weights), rows every game-minute 1-40 while the game is going (fitted on
every other minute, scored on every minute):
- wc: winchance's 12 features (objectives lead + held), refitted per block
- rich: 91 features (py/state/statecommon.py `features`): wc's 12; gold, XP, level, CS,
  seconds until respawn, completed items, unspent gold and deaths by role; players dead
  now, kills, damage to champions, total gold in the game; towers by lane and tier, nexus
  towers, plates; inhibitor respawn seconds, inhibitors ever; dragons and soul by
  element, elder and baron buff seconds left, barons, elders, grubs, heralds; wards,
  control wards, wards killed; and the draft logit (win-ratings refitted per block,
  cross-fitted in 5 parts on fit games)
- richc: rich plus a champion-role effect by minute (same hat basis, blue's five minus
  red's five, ridge picked from 1e-5, 3e-5, 1e-4, 3e-4 on the fit's newest 10%, then
  refitted on every fit game): what a champion is worth beyond the state, minute by
  minute, with no champion x state term

Log loss per game-minute, model minus wc, folds pooled (5 forward blocks, 100,848
games with a timeline) and dev-val (26,263); ± 95% clustered by game (statemodels'
sandwich; a 2,000-draw whole-game bootstrap of the same differences gave the same
widths, e.g. richc - wc folds [-0.0256, -0.0234], dev-val [-0.0287, -0.0245]):

| minute | games (folds) | wc | rich - wc | richc - wc | dev-val rich - wc | dev-val richc - wc |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 100,848 | 0.6920 | -0.0046 ± 0.0005 | -0.0047 ± 0.0007 | -0.0051 ± 0.0011 | -0.0061 ± 0.0013 |
| 5 | 100,848 | 0.6450 | -0.0098 ± 0.0009 | -0.0165 ± 0.0012 | -0.0100 ± 0.0017 | -0.0182 ± 0.0023 |
| 10 | 100,848 | 0.5783 | -0.0097 ± 0.0009 | -0.0221 ± 0.0013 | -0.0112 ± 0.0017 | -0.0254 ± 0.0026 |
| 15 | 100,847 | 0.5055 | -0.0111 ± 0.0009 | -0.0260 ± 0.0014 | -0.0116 ± 0.0018 | -0.0276 ± 0.0027 |
| 20 | 92,188 | 0.4602 | -0.0125 ± 0.0010 | -0.0281 ± 0.0015 | -0.0133 ± 0.0020 | -0.0299 ± 0.0029 |
| 25 | 76,456 | 0.4192 | -0.0135 ± 0.0012 | -0.0278 ± 0.0017 | -0.0145 ± 0.0023 | -0.0290 ± 0.0032 |
| 30 | 44,451 | 0.4546 | -0.0213 ± 0.0020 | -0.0336 ± 0.0025 | -0.0232 ± 0.0038 | -0.0366 ± 0.0047 |
| 35 | 17,259 | 0.5162 | -0.0414 ± 0.0042 | -0.0513 ± 0.0048 | -0.0408 ± 0.0079 | -0.0523 ± 0.0089 |
| all | 100,848 | 0.5351 | -0.0128 ± 0.0008 | -0.0245 ± 0.0011 | -0.0137 ± 0.0015 | -0.0265 ± 0.0022 |

Summed over a game's minutes, richc saves 0.70 nats a game against wc on the folds (rich
0.36). richc - rich: folds -0.0117 [-0.0125, -0.0108] per game-minute, every fold
(-0.0092, -0.0118, -0.0125, -0.0118, -0.0133), dev-val -0.0129 [-0.0145, -0.0113].
Better than wc in 5 of 5 folds, both. AUC at 10 / 15 / 20 / 25 / 30 (folds): wc 0.763 /
0.829 / 0.863 / 0.888 / 0.867, rich 0.773 / 0.838 / 0.871 / 0.896 / 0.880, richc 0.785
/ 0.849 / 0.880 / 0.903 / 0.887 (dev-val within 0.004). Calibration, ECE over 10
equal-mass bins, folds pooled: richc 0.0035-0.0078 from 1 to 30 minutes (wc 0.0026-0.0062,
rich 0.0037-0.0046), 0.0075 at 35, 0.011 at 40 (4,883 games); a single fold's minute
up to 0.013 (about 20,000 games a fold, so mostly noise).

Against the champion nets (meiolol-state's run 20261014T025645Z-state-neta-2253Zr: a
state net plus a separate champions-by-minute net), on the same game-minutes: gain over
rich, richc vs neta, dev +0.0129 vs +0.0117, folds +0.0092 / +0.0118 / +0.0125 / +0.0118
/ +0.0133 vs +0.0049 / +0.0086 / +0.0108 / +0.0092 / +0.0122. The owner's test ("if
richc gets most of neta's gain") holds in every block: the nets' gain is champion value
by minute, and a ridge on champion-role x minute takes all of it, explainably.

Champion effects (sd across champion-roles, logit, by knot 1 ... 40, dev-val fit): 0.10,
0.15, 0.16, 0.17, 0.16, 0.15, 0.12, 0.10, 0.05: largest from 10 to 20 minutes, fading
late, as draftpath's Q1 found (draft given state at 15 adds about 4x what it adds
before the game; "How drafts win").

Audit (the verifier's checklist, docs/archive/2026-10-14-model-team/agent-state/split-rules.md):
- Snapshot: snap-20261013T2253Z after the all-platform re-cut (85fd62a): nn/ written
  00:24Z with test_cut 1791795719197 and dev_cut 1791741249959, state/ 01:10Z, run
  03:39Z. Played games by code: dev_old 134,375, folds 26,875 each, dev_val 35,834, test
  53,750, codes 7-9 empty; code 10 = start >= T and code 6 = [D, T) exactly
- Test: no look. Every block's scored games equal nnsets' scored set with a timeline,
  codes only 1-5 or 6, none at or after T; fits use codes below the block (dev-val:
  0-5), every fit game older than every scored game. SNAP/test-looks.tsv does not
  exist on the gpu-box or the Mac: 0 looks on 2253Z by anyone
- Leak: features come from frame m (Riot's frame at m:00+) and events before it; respawn
  timers from the level at death; a game counts at minute m only while going (frame m
  is not the end frame), which is known at m; game-level columns (duration, firsts,
  shape targets) are not features. Champions and the ratings draft logit are known at
  draft; the logit is cross-fitted on fit games and full-fit for scored ones; richc's
  champion vocabulary comes from fit games only
- Tuning: ridge and ratings L2 picked on the fit's newest 10% only
- Pre-declared reading (progress-state.md, "if richc gets most of neta's gain"): met
- Intervals: game-clustered, confirmed by the whole-game bootstrap above (2,000 draws;
  ~/ml/analysis/stateaudit-ship.py on the gpu-box)

Verdict: cleared. richc is the best in-game model we have on dev, by a wide margin over
the shipped form (rich halves it, champions halve it again), and it stays calibrated to
30 minutes. Caveats: dev only (folds and dev-val; no test look); played games only
(15:00+), as wc, so minutes before 15 are conditioned on the game reaching 15; ranked
solo only, while Your games also shows flex, draft and Swiftplay; the ridge took the
smallest value on the grid in all six blocks (a weaker ridge may do slightly better).

### Player experience and everything pre-game, dev only, 2026-10-13

Scope internal (api.Scope: Jacob's research predictor, never the site or app; sees all
ten players' experience and ranks). rows.fillExperience: per player-row, that player's
ranked solo games in the snapshot that ended before this game's start (games under
15:00 left out): games and wins on the champion and on any, mean KDA, mean lane gold
diff at 14 and deaths before 15 (games reaching 15:00). Only what we crawled: 16 days
(2026-09-26 to 10-12). Coverage of rows: 1+ earlier games on the champion 26%, 10+
2.5%, 50+ 0.1%; 1+ on any champion 56% (every region alike). Mastery (0.5% of rows,
snapshot after the game) and rank at game start (rank_history begins 2026-10-12) are
not in yet.

win-ratings cfg (ratings kind plus): champ_exp (per role, blue minus red: log1p games
on the champion, its win rate's log-odds with 5 pseudo-games at 50%), form (the same on
any champion, plus KDA, lane gold diff and deaths, each times n / (n + 3) around the
training mean), skill (champ_exp plus each champion-role's own slope on log1p games,
shrunk by the ratings' L2). Same setup as above: fit on ~90k games older than dev-val,
scored on dev-val (8,500 EUW1 games over 15:00, 85,000 rows), paired ± clustered by
game.

| model | log loss | accuracy | AUC | vs champions |
| --- | --- | --- | --- | --- |
| champions (ratings) | 0.68969 | 53.70% | 0.549 | - |
| + experience on the champion | 0.68850 | 54.26% | 0.557 | -0.00119 ± 0.00139 |
| + form (any champion) | 0.68861 | 53.97% | 0.556 | -0.00108 ± 0.00163 |
| + both: everything pre-game | 0.68781 | 54.08% | 0.559 | -0.00189 ± 0.00184 |
| + per-champion skill slope (vs experience) | 0.68892 | 53.75% | 0.554 | +0.00042 ± 0.00079 vs experience |
| champions + post-game rank (leaky) | 0.65851 | 63.78% | 0.673 | -0.03118 ± 0.00498 |
| everything + post-game rank (leaky) | 0.65818 | 62.80% | 0.665 | -0.03152 ± 0.00523 |

Learning curve, everything minus champions at nested fractions of training games: 0.1
+0.0012 ± 0.0026, 0.35 -0.0019 ± 0.0019, 0.5 -0.0014 ± 0.0022, 0.75 -0.0020 ± 0.0023,
1 -0.0019 ± 0.0018. Experience alone: -0.0009 to -0.0018 at every fraction. The gain is
set by how much history we hold per player, not by training games (20-35 weights).

Reading:
- Experience and form point the same way at every size and each adds about 0.001
  nats; together they sit at the edge of noise on dev. More history per player may
  help (not yet tested: most players have no earlier game in our 16 days)
- Per-champion skill slopes: worse than one slope per role. Each champion's "0 to 50
  earlier games" effect has a ±7-10 pp interval, and 50 games is far past our data
  (0.1% of rows): effects-skill-<role>.tsv in the run dir, not a finding
- participants.tier is the rank when the match was stored, after the game. It lifts
  accuracy by 10 points, far beyond what draft-time data gives, so most of it is
  probably the result leaking (wins between the game and the store push rank up). Not
  separable until rank at game start exists (rank_history from 2026-10-12)
- Weights (experience-only fit, log-odds per unit, top/jungle/mid/bot/support): log1p
  games on the champion 0.065/0.062/0.090/0.067/0.010 (10 games vs none: about +4 pp
  for one player outside support); its win rate's log-odds 0.09/-0.02/0.06/0.03/0.03

Test finals (2026-10-13, go from meiolol-78; one look each, `exp final` into ~/ml/lab
on the Mac, accuracy and AUC from `exp preds` of the same fit; 10,604 EUW1 test games,
106,040 rows):

| model | log loss | accuracy | AUC | vs champion base rates | vs champions |
| --- | --- | --- | --- | --- | --- |
| champions (ratings) | 0.69064 | 53.20% | 0.544 | -0.00223 ± 0.00170 | - |
| everything pre-game (both) | 0.68834 | 54.52% | 0.562 | -0.00453 ± 0.00274 | -0.00230 ± 0.00217 |

Not our protocol (LoLDraftAI-style): champions-only on a random tenth of non-test
games as dev-val (EUW1 rows scored), fit on the rest: log loss 0.68824, accuracy
54.15%, AUC 0.556, against 0.68969, 53.70%, 0.549 on the time split. Skill slopes and
post-game rank: no final (rejected on dev; leaky).

### Field ranking, 2026-10-13 (meiolol-48)

`meiolol-lab fields SNAP OUT [--final LIST] [--ref PREDS]` (src/lab/fields.zig, Mac CPU,
ReleaseFast, ~50 s). Every number and bool of the raw summary per player: participant
fields (p.), challenges (c.), missions (m.), PlayerBehavior (b.), the team's objectives
(t.) and champ select fields worked out from it (d.: spell pair, keystone, primary and
secondary tree, shards, role assignment status from selectedRolePreferences, +10 when
played off the assigned role). 315 fields; ids (items, augments, champion id) skipped.
Rows: the protocol's games that reached 15:00 and ran 900 s+. Ranked on the harness's
dev cut (fit: 65k games before it, scored: 8,011 EUW dev games), then one test look
(fit: all train, 117,806 games; scored: 10,604 test games) at a list written before it
(OUT/final-list.tsv, below). Intervals 95%, paired, clustered by game; p from them,
Benjamini-Hochberg within each table. Each field has a class: early (a fixed window
before 15:00), game (whole game), result (end of game or losing it: nexus, inhibitors,
surrender, team objective totals, length), draft (set in champ select by the player).

- B, post-game: win log loss of a logistic model per field over a game-state base (team
  gold diff at 14, game length; base test log loss 0.4989). Field terms per role:
  within-champion-role z of the value and of the value per minute, a missing flag.
  Association, not cause: whole-game fields mostly record winning
- A2, draft forecast: each end-of-game stat as a target; % of its role-mean MSE (raw
  units, pooled) removed by shrunk champion-role means, then by shrunk (champion-role,
  lane opponent) cells on the residual. Never a champ-select input
- A1, champ select: the player's own seat fields; shrunk (role, category) effects, then
  (champion-role, category) on their residual, over the champion-role mean (win shrunk
  to the role's at 1000 rows, as the harness); on test also added to 3c-team2's preds.
  Use-time legal for the user's own seat only; docs/production-key.md before any is shown
  as advice

Dev: B ranks 220 game fields (144 clear after BH), 24 early (7 clear), 40 result (28);
champ select fields as numbers add nothing to win (account level -0.02 ± 0.03 mnats).
Pre-declared for test: B top 10 game and top 10 early (result left out: consequences),
A2 top 10 by draft share and top 10 more by lane share, A1 all six on all outcomes.

B on test (mnats per row; % of base log loss; winners minus losers in sd):

| field | class | gain, mnats | % | win - loss |
| --- | --- | --- | --- | --- |
| c.maxKillDeficit | game | 347.4 ± 7.8 | 69.6 | +0.99 |
| c.turretTakedowns (= p.) | game | 180.7 ± 5.1 | 36.2 | +1.24 |
| c.teamBaronKills | game | 131.1 ± 8.2 | 26.3 | +0.95 |
| c.earliestBaron | game | 128.7 ± 7.8 | 25.8 | -0.22 |
| c.baronBuffGoldAdvantageOverThreshold | game | 128.4 ± 6.3 | 25.7 | +0.22 |
| c.turretPlatesTaken | game | 114.9 ± 4.3 | 23.0 | +1.10 |
| p.champExperience | game | 114.0 ± 3.7 | 22.9 | +0.48 |
| p.damageDealtToObjectives | game | 103.5 ± 4.1 | 20.7 | +1.00 |
| p.champLevel | game | 99.6 ± 3.4 | 20.0 | +0.49 |
| c.firstTurretKilledTime | early | 2.43 ± 1.24 | 0.49 | -0.17 |
| c.firstTurretKilled | early | 1.94 ± 1.12 | 0.39 | +0.75 |
| c.takedownsFirstXMinutes | early | 0.91 ± 0.21 | 0.18 | +0.49 |
| c.takedownOnFirstTurret | early | 0.47 ± 0.20 | 0.09 | +0.29 |
| c.laningPhaseGoldExpAdvantage | early | 0.29 ± 0.12 | 0.06 | +0.35 |
| p.firstTowerKill | early | 0.24 ± 0.13 | 0.05 | +0.23 |
| c.earlyLaningPhaseGoldExpAdvantage | early | 0.07 ± 0.07 | 0.01 | +0.19 |
| c.jungleCsBefore10Minutes | early | 0.06 ± 0.09 | 0.01 | +0.09 |
| c.kTurretsDestroyedBeforePlatesFall | early | 0.03 ± 0.07 | 0.01 | +0.29 |
| c.laneMinionsFirst10Minutes | early | 0.02 ± 0.06 | 0.00 | +0.13 |

All but the last four clear after BH (q < 0.001); those four are not detected. The whole
game rows are the game's result seen from one player; the early ones are what the 14:00
state misses, at most half a percent of the log loss.

A2 on test (% of role-mean MSE; all 20 clear after BH):

| field | draft | champion | lane opponent |
| --- | --- | --- | --- |
| c.skillshotsHit | 82.4 ± 5.3 | 82.0 | 0.36 ± 0.19 |
| c.landSkillShotsEarlyGame | 81.0 ± 7.1 | 80.5 | 0.54 ± 0.41 |
| p.spell1Casts | 79.5 ± 2.2 | 79.4 | 0.08 ± 0.03 |
| c.enemyChampionImmobilizations | 77.8 ± 1.7 | 76.9 | 0.94 ± 0.11 |
| p.spell4Casts | 72.9 ± 3.4 | 73.0 | -0.08 ± 0.13 |
| p.spell2Casts | 72.0 ± 1.3 | 71.9 | 0.09 ± 0.04 |
| c.knockEnemyIntoTeamAndKill | 70.7 ± 1.5 | 70.7 | 0.08 ± 0.07 |
| p.spell3Casts | 70.3 ± 2.4 | 70.3 | 0.06 ± 0.04 |
| p.magicDamageDealt | 69.7 ± 1.3 | 69.7 | 0.04 ± 0.06 |
| p.totalTimeCCDealt | 69.5 ± 2.1 | 68.9 | 0.61 ± 0.20 |
| c.survivedThreeImmobilizesInFight | 45.1 ± 1.9 | 4.4 | 40.7 ± 1.7 |
| c.skillshotsDodged | 34.7 ± 1.8 | 2.7 | 32.0 ± 1.7 |
| c.wardTakedownsBefore20M | 34.4 ± 4.6 | 3.6 | 30.8 ± 4.6 |
| c.dodgeSkillShotsSmallWindow | 32.2 ± 2.2 | 1.3 | 30.9 ± 2.1 |
| p.physicalDamageTaken | 23.6 ± 0.9 | 18.6 | 5.0 ± 0.3 |
| c.wardTakedowns | 21.6 ± 2.4 | 5.7 | 15.9 ± 2.4 |
| p.trueDamageTaken | 21.5 ± 1.1 | 10.5 | 11.0 ± 0.8 |
| p.magicDamageTaken | 20.2 ± 0.8 | 8.3 | 11.9 ± 0.5 |
| c.laneMinionsFirst10Minutes | 13.4 ± 0.6 | 9.1 | 4.3 ± 0.3 |
| c.maxCsAdvantageOnLaneOpponent | 12.8 ± 0.6 | 8.1 | 4.7 ± 0.3 |

Your own kit sets what you deal; the lane opponent's sets what you dodge, survive and
take. Ward takedowns likely count traps (Teemo, Shaco, Nidalee and the like) as wards:
not checked per champion. Dev ranked the same way (dev-a2.tsv: 197 of 283 clear).

A1 on test (continuous: % of base MSE, over the champion-role mean, then over 3c-team2;
win: mnats; top and bottom: the largest shrunk category effects with 1000+ train rows):

| field | win | gold14 | lanediff14 | cs10 | deaths15 | first_item |
| --- | --- | --- | --- | --- | --- | --- |
| assignment | -0.03 ± 0.08 | 0.07 ± 0.04 / 0.05 ± 0.04 | 0.06 ± 0.03 / 0.05 ± 0.03 | 0.26 ± 0.06 / 0.10 ± 0.06 | 0.16 ± 0.05 / 0.06 ± 0.05 | 0.06 ± 0.04 / 0.01 ± 0.04 |
| keystone | 0.04 ± 0.12 | 0.56 ± 0.09 / 0.53 ± 0.10 | 0.19 ± 0.05 / 0.19 ± 0.05 | 0.48 ± 0.09 / 0.26 ± 0.09 | 0.26 ± 0.06 / 0.24 ± 0.07 | 0.48 ± 0.09 / 0.45 ± 0.09 |
| shards | -0.02 ± 0.09 | 0.38 ± 0.09 / 0.36 ± 0.09 | 0.15 ± 0.06 / 0.17 ± 0.06 | 0.57 ± 0.12 / 0.44 ± 0.12 | 0.10 ± 0.05 / 0.11 ± 0.05 | 0.50 ± 0.09 / 0.49 ± 0.09 |
| spells | -0.06 ± 0.09 | 0.19 ± 0.06 / 0.16 ± 0.06 | 0.09 ± 0.04 / 0.08 ± 0.04 | 0.49 ± 0.11 / 0.46 ± 0.11 | 0.16 ± 0.05 / 0.15 ± 0.05 | 0.23 ± 0.07 / 0.21 ± 0.07 |
| trees | 0.09 ± 0.13 | 0.81 ± 0.12 / 0.80 ± 0.12 | 0.27 ± 0.06 / 0.28 ± 0.06 | 0.58 ± 0.10 / 0.36 ± 0.11 | 0.25 ± 0.06 / 0.27 ± 0.06 | 1.08 ± 0.13 / 1.04 ± 0.14 |
| account level | 0.01 ± 0.11 | 0.13 ± 0.04 / 0.12 ± 0.04 | 0.10 ± 0.04 / 0.10 ± 0.04 | 0.11 ± 0.06 / 0.02 ± 0.06 | 0.00 ± 0.03 / 0.00 ± 0.03 | 0.06 ± 0.04 / 0.05 ± 0.04 |

Every continuous cell over the champion-role mean clears BH except account level on
deaths15; win clears for none (largest single category effects about 1.5 points either
way, not enough to improve held-out log loss). Largest effects: First Strike +118 gold
at 14; Inspiration with Domination +148 gold, Precision with Sorcery -69; Teleport and
Ignite +103 gold and +2.1 CS at 10; autofilled +0.22 deaths before 15; queued as Fill
first -102 lane gold diff; got their first choice but swapped in champ select +139 gold
at 14. Associations within champion and role (who takes a rune also differs), not advice.

What this says for compact rows (docs/fields.md): the champ select fields (spells,
keystone, trees, shards, assignment status) carry draft-time signal on every early
outcome and cost a few bytes per player; challenges add almost nothing to win beyond
the 14:00 state, and the whole-game ones mostly restate the result. Next: lens B over a
team end-state base (kills, towers, objectives) to find the player-level fields beyond
the team's result; per-champion check of the ward-takedown traps.

### Playstyle clusters and sequence net, 2026-10-13 (meiolol-3f)

`meiolol-lab style SNAP OUT [--final K] [--net all|N,..] [--net-offset champ]`
(src/lab/style.zig, src/lab/stylenet.zig). Harness dev cut (fit 64,931 games, dev 8,011),
then one test look (fit 117,806, test 10,604); ten rows a game, outcome win, games
reaching 15:00 and 900 s+. Use-time: the user's own style, post-game only.

- Style per player, minutes 0-13: share of position frames in 14 zones (bases, each
  lane's own and enemy half, river top and bottom, own and enemy jungle top and bottom
  side) in minutes 3-7 and 8-13, red mirrored across x + y = 14800 (keeps top lane top);
  mean step between minute positions; counts before 14:00 of damage dealt and taken, CC,
  lane and jungle CS, kills, deaths, assists, wards, control wards, ward kills, plates,
  epic monster takes, minutes with a purchase from 1:30 (backs), first such minute. 44
  dims, residualised within role on champion-role (mean shrunk to the role's, 20 rows)
  and linearly on the 14:00 state, standardised per role, clipped at ±4 sd
- State: team gold, XP and lane gold leads, plates, towers, dragons, grubs, herald (own
  side minus the other; objectives.stateAt). Objectives were added at meiolol-78's
  request after look 2. Base "b0": b0's model (champion x role, state x role, b0's eight
  style features x role) on this state
- Clusters: k-means++ per role on the residuals, k 3, 4, 6, 8, best of 5 restarts; the
  largest cluster is each role's reference. Components: 10 PCs per role of the same
  residuals, in sd units
- Net: f = MLP 433 -> H -> B -> 1 (ReLU, dropout after layer 1) on the per-minute
  sequence (14 minutes x zone one-hot, x, y, the minute's damage dealt and taken, CC,
  lane and jungle CS, kills, deaths, assists, wards, control wards, ward kills, plates,
  epics, purchases) plus role and state, standardised; logit = b0's log-odds + f. AdamW
  lr 1e-3, wd 1e-4, batch 512; epoch picked on the latest tenth of fit games
- Looks: dev 1 (gold/XP state: four k and the components), dev 2 (clip fix after rare
  zones standardised to 40-70 sd took whole clusters; component table), dev 3 (full
  state); net: the eight configs fixed beforehand plus one positive control. Test,
  declared before it: (a) b0 + 10 components vs b0, (b) b0 + clusters k=3 vs b0 (best
  on dev), (c) the component table with BH, (e) b0 vs champion + state. (d), the net,
  went to test only if its dev gain beat its interval: it did not. (c) as run is the
  final fit's table, so fitted on train; the same model refitted on the test rows was
  added after, at meiolol-78's question (same run otherwise, byte-identical results)

Win log loss gain, nats per row ± 95% clustered by game:

| comparison | dev, gold/XP state (look 2) | dev, full state (look 3) | test, full state |
| --- | --- | --- | --- |
| b0's style over champion + state | 0.00030 ± 0.00016 | 0.00014 ± 0.00013 | 0.00020 ± 0.00011 |
| b0 + 10 components over b0 | 0.00080 ± 0.00035 | 0.00004 ± 0.00012 | -0.00001 ± 0.00009 |
| b0 + clusters k=3 over b0 | 0.00003 ± 0.00005 | 0.00001 ± 0.00004 | -0.00000 ± 0.00003 |
| b0 + clusters k=4 over b0 | -0.00000 ± 0.00005 | -0.00001 ± 0.00004 | - |
| b0 + clusters k=6 over b0 | 0.00003 ± 0.00007 | -0.00004 ± 0.00005 | - |
| b0 + clusters k=8 over b0 | -0.00006 ± 0.00009 | -0.00009 ± 0.00007 | - |

Log loss of b0: dev 0.5408 on the gold/XP state, 0.5302 on the full state; test 0.51954
(champion + state 0.51974). On test, b0's style moves a player's win chance by 0.66 pp
on average (median 0.48, 90% under 1.6) against champion + state.

Net on dev, full state, over b0 (seconds per epoch on the Mac M5, 10 cores):

| config | hidden | bottleneck | dropout | emb | best epoch | s per epoch | gain over b0 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 64 | 8 | 0.1 | 0 | 1 | 0.8 | -0.00006 ± 0.00004 |
| 2 | 128 | 8 | 0.1 | 0 | 2 | 1.8 | -0.00002 ± 0.00010 |
| 3 | 256 | 8 | 0.1 | 0 | 3 | 3.3 | 0.00001 ± 0.00002 |
| 4 | 128 | 8 | 0.3 | 0 | 0 | 1.5 | 0 (offset kept) |
| 5 | 256 | 8 | 0.3 | 0 | 0 | 2.8 | 0 (offset kept) |
| 6 | 128 | 8 | 0.1 | 8 | 1 | 1.8 | -0.00000 ± 0.00001 |
| 7 | 128 | 16 | 0.1 | 0 | 2 | 1.6 | -0.00020 ± 0.00015 |
| 8 | 512 | 8 | 0.3 | 0 | 0 | 5.5 | 0 (offset kept) |
| control: 2 over champion + state | 128 | 8 | 0.1 | 0 | 2 | 1.4 | -0.00012 ± 0.00020 |

Component effects, win pp per +1 sd given b0's features and the state, fitted on train
(117,806 games, clustered by game): 18 of 50 pass BH (q < 0.05). Refitted on the 10,604
test games with the same components: signs agree 32 of 50 (25 by chance), correlation
0.50; of the 18, 11 keep their sign on test and 2 are also p < 0.05 there (jungle 1,
middle 6); none passes BH on the test fit alone (its intervals ±0.8-4.6 pp). Zones =
share of squared loadings on position dims; a component's sign is arbitrary:

| role | pc | train | test refit | zones | loadings (largest) |
| --- | --- | --- | --- | --- | --- |
| middle | 1 | 1.76 ± 0.70 | 1.09 ± 2.25 | 0.12 | taken -0.38, deaths -0.38, damage -0.34, kills -0.34, shops -0.33, lane CS 0.31 |
| bottom | 1 | -1.72 ± 0.65 | -1.49 ± 2.08 | 0.07 | taken -0.42, deaths -0.40, damage -0.37, shops -0.35, kills -0.35, lane CS 0.27 |
| bottom | 4 | 1.53 ± 1.06 | 2.62 ± 3.57 | 0.46 | wards -0.45, control wards -0.40, early bot own half 0.34, ward kills -0.27 |
| jungle | 1 | 1.15 ± 0.73 | 3.01 ± 2.43 | 0.04 | deaths -0.45, damage -0.43, taken -0.41, kills -0.31, jungle CS 0.31 |
| middle | 3 | 1.01 ± 0.58 | -0.31 ± 1.93 | 0.78 | mid enemy half early 0.55, late 0.45, mid own half early -0.44, plates 0.24 |
| middle | 7 | 0.90 ± 0.32 | -0.65 ± 1.09 | 0.51 | epics 0.45, base late -0.37, base early 0.33, first shop -0.29 |
| bottom | 2 | -0.85 ± 0.46 | 0.36 ± 1.53 | 0.67 | bot own half early -0.44, step 0.43, late -0.40, base early 0.31, late 0.29 |

Eleven more train survivors between ±0.3 and ±0.7 pp (top, jungle and support pathing
and assists); all, with the test refit, in the report (data/style/final/final-report.md
on the Mac).

Reading:
- Beyond the full state at 14:00 (leads and objectives held), early style adds almost
  nothing: b0's eight features are worth half of what they were over gold and XP alone,
  and nothing measured here adds to them. The look-2 gain of the components (+0.0008)
  and its largest effect (supports roaming to epic monsters, +4.6 pp per sd) were
  objectives held: both vanish once those are in the state
- No playstyle types: once champion and state are out, style has no cluster shape (the
  first component explains 7-13% of the variance by role, the rest is flat), so k-means
  cuts a continuum into arbitrary parts; clusters add nothing at any k on dev or test.
  The large clusters are "fights more" vs "fights less" and holding vs leaving the lane
- The net finds nothing nonlinear. Its positive control (over champion + state, where
  b0's features alone gain +0.00014) also finds nothing, and every config overfits after
  epoch 1-3: so not detected, with the net unable to resolve effects below about 0.0003
  nats, not "absent"
- Single directions are train-fit associations only, not confirmed: in training games
  mids and junglers who farm rather than fight win slightly more (+1.8, +1.2 pp per sd)
  and bot laners slightly less (-1.7), but the test refit confirms none on its own and
  agrees only loosely overall (signs 32 of 50, correlation 0.50), and together they
  predict nothing on test (component block -0.00001 ± 0.00009). Large training data
  makes tiny effects "clear"; they are too small to show on held-out games. Not lesson
  material
- Compute: Mac CPU throughout (the whole clustering run 30-40 s; the net 0.8-5.5 s an
  epoch at 0.6M rows): the GPU path is not worth new kernels at this size

### Comp features from champion profiles, 2026-10-13 (meiolol-2c)

Champion-role profiles (damage type mix, tankiness, armour vs MR, CC, utility, range,
split push) averaged from api.Row.stats on training rows, feeding win-comp's profile
prior, within-team and cross-team terms. Sessions: docs/archive/2026-10-14-model-team/model-agents.md.

#### Data: seat_stats.tsv (meiolol-ea)

SNAP/seat_stats.tsv (`meiolol-lab seat-stats SNAP SNAP/ddragon`, 25737aa; layout
docs/architecture.md "Packed rows"): match_id, slot, then api.SeatStat in enum order,
`nan` unknown; join on (match_id, slot); no line = unknown (NaN in Row.stats). rows.load
and the pack carry it as rows.Row.stats; the harness copies it into api.Row for visible
games only (test "seat stats reach fit on visible games only"), a Query has no stats.
- From the raw summary: minutes, damage to champions and taken from them by type,
  mitigated, cc_time (timeCCingOthers), immobilisations, heal (totalHeal, includes
  heal_allies: below it on 47 of 2.2M seats), heal_allies, shield_allies, dmg_buildings.
  Totals per game: divide by minutes for rates
- From Data Dragon of the game's patch (16.19.1, 16.20.1 in SNAP/ddragon/): armor_end,
  mr_end = base + growth at level 15 plus the flat armour/MR of the end-of-game items, no
  ability resists (Rammus W, Malphite's passive): the build's lean. Real minute-15
  resists need raw timelines, archived only from 2026-10-12. attack_range = base range
- snap-20261012T2055Z (gpu-box, 54 s with the repack): 2,303,750 lines from 230,375 of
  230,399 queue 420 games (24 without a summary), 0 unreadable, 0 champion mismatches.
  Seats with a value, games of 15:00+: train (dev fit) 99.97% of 887,530, dev-val 100%
  of 85,020, selection 100% of 84,730, test 100% of 106,040, same for every stat
- Role medians on dev-fit games (per minute unless stated): magic share of champion
  damage top 0.20, jungle 0.13, middle 0.86, bottom 0.09, support 0.79; CC time 0.77,
  0.73, 0.69, 0.39, 1.28; armor_end 126, 121, 94, 84, 103 and mr_end 59, 59, 56, 48, 55.
  Spot checks: Rammus jungle armour 265 vs MR 104, magic share 0.65; Brand support and
  middle magic share 0.92 and 0.95; Jinx physical 0.96; Soraka ally heals 657 a minute,
  Janna ally shields 206; Tryndamere and Jax lead building damage (455, 406)

#### Model: win-comp ablation (meiolol-0d)

Candidate src/lab/cand/win-comp (7a2de11): win-ratings' ratings plus terms on 12-number
champion-role profiles. Train-time: end-of-game stats of training rows, averaged into
profiles; use-time: champions and roles only (champ_select). Per row: magic and true
share of champion damage, damage/min, mitigated/(mitigated+taken), taken/min,
armor_end - mr_end, CC/min, immobilisations/min, ally heal+shield/min, own heal/min
(heal - heal_allies), attack range, building damage/min. Mean over the champion-role's
won and lost rows separately, each shrunk to the role mean by 20 pseudo-rows, profile =
the two halves' average (end-of-game stats lean to the winner: building damage, so a
plain mean would carry the win rate); z within role, unknown champion-role 0. Training
games see leave-one-out profiles; tuning builds them from the fit games only (49's
review). Terms (cfg flags, nested): prior (rating = beta_role . p + delta), balance (P_b'
S P_b - P_r' S P_r on team sums, S symmetric), team (explicit: frac = the team's
damage-weighted magic share, mix = (frac - 0.5)^2, or AD-heavy and AP-heavy halves;
frontline = soft max of mitigated share), cross (P_b' A P_r, A antisymmetric). Comp
weights fitted after the ratings (warm start; `freeze` keeps the ratings fixed), own L2
picked on the newest 10% of visible games, none if no L2 beats ratings there.

Profile correlations (champion-roles, game-weighted): none near-duplicate, all kept.
Largest: taken/min x own heal/min 0.66, mitigated share x armour minus MR 0.59,
mitigated share x range -0.55, CC/min x immobilisations/min 0.48.

Dev only, gpu-box, `meiolol-lab exp run` with a scratch --lab (no looks), each batch
from one clean clone of HEAD (61bff7f, c8d3317, e050551) with the reference rerun in
it. Dev-val: fit on 88,706 games, scored on 85,000 EUW1 rows (8,500 games). Folds
(cfg.folds = 5): the newest half of the dev phase's visible games in 5 time blocks,
each scored by models fitted on all older games (profiles rebuilt per fold), 44,353
games, every platform. Paired ± clustered by game; negative is better.

| model | dev log loss | dev AUC | dev vs ratings | folds vs ratings |
| --- | --- | --- | --- | --- |
| ratings (= win-ratings, bit-identical) | 0.68969 | 0.549 | - | - (0.69090) |
| + prior | 0.68999 | 0.547 | +0.00030 ± 0.00051 | +0.00020 ± 0.00021 |
| + cross, ratings frozen | 0.68981 | 0.549 | +0.00012 ± 0.00041 | +0.00012 ± 0.00025 |
| + balance + team, frozen | 0.69035 | 0.546 | +0.00066 ± 0.00108 | -0.00056 ± 0.00040 |
| + team (mix, frontline), frozen | 0.69006 | 0.547 | +0.00036 ± 0.00067 | -0.00061 ± 0.00029 |
| + AD-heavy, AP-heavy halves, frozen | 0.69011 | 0.547 | +0.00041 ± 0.00070 | -0.00065 ± 0.00031 |
| + mix, ratings refitted jointly | 0.69013 | 0.547 | +0.00043 ± 0.00081 | -0.00034 ± 0.00029 |
| **+ mix, frozen (committed cfg)** | 0.68999 | 0.547 | +0.00030 ± 0.00059 | **-0.00057 ± 0.00028** |
| all four, frozen | 0.69056 | 0.545 | +0.00087 ± 0.00136 | -0.00017 ± 0.00049 |

All four nested on the folds, each step vs the one before: prior +0.00013 ± 0.00021,
balance -0.00034 ± 0.00038, team -0.00021 ± 0.00016, cross +0.00025 ± 0.00041.

Train-fit effects (effects-comp-terms.tsv, blue's chance per 1 sd of the blue-minus-red
term at 50%): mix -1.50 ± 0.33 pp (frozen; -2.83 joint), AD-heavy -1.47 ± 0.33 and
AP-heavy -1.25 ± 0.33, frontline +0.13 ± 0.33 beside mix. Full model, largest S: magic x
magic -0.87 ± 0.28 (the mix again), damage/min x buildings/min -0.48, damage/min x
mitigated +0.39, taken/min x CC +0.37; largest A: magic x enemy immobilise -0.40 ± 0.28
(49: not seen model-free), true x enemy immobilise -0.38; my magic x enemy armour lean
+0.26 ± 0.28. Sanity (effects-comp-sanity.tsv; Garen, Ahri, Jinx, Thresh with Rammus or
Graves jungle into Mordekaiser Diana Syndra Ziggs Lux vs Darius Lee Sin Zed Caitlyn
Pyke): Rammus minus Graves, 5 AP minus 5 AD, ratings +0.09 pp (sigmoid curvature only),
mix +0.37, all four joint +2.95 (Rammus relatively better into AP: the wrong way). No
Rammus-into-AD effect.

Reading:
- One comp term carries anything: a team whose damage is lopsided (mostly AD or mostly
  AP) loses more often than its champions' ratings say. 44k fold games show it (-0.0006
  ± 0.0003), 49's model-free bins show it in every block; the 8.5k dev-val games don't
  (+0.0003 ± 0.0006), within their noise of the fold gain. Both halves, AD-heavy and
  AP-heavy, about equal
- Profile prior, cross-team terms (damage type x enemy resists, CC x mobility),
  frontline and CC: not detected; cross and prior slightly worse. Rammus into AP vs AD:
  not detected (my magic x enemy armour lean +0.26 ± 0.28 pp per sd)
- The inner validation (newest 10% of visible games) overstated every comp gain 2-3x
  (team -0.0011 there vs -0.0006 on folds): judge on the folds
- Freeze the ratings in the comp stage: refitting them jointly from a warm start loses
  about 0.0002 on the folds
- Run dirs ~/ml/runs/*-wc-{a,b,c}-* on the gpu-box

Test look (meiolol-2c's go, one look): committed cfg (ratings + mix, frozen) fitted on
all 172,144 train games, scored on the 106,040 EUW1 test rows, run
20261013T195118Z-final-win-comp on 7d2ae5a. For a per-row pair, exp final gained
test.tsv and AUC (c26ffa8); on c26ffa8 win-ratings `ratings` had its first look
(20261013T195618Z-final-win-ratings) and win-comp was rerun
(20261013T195708Z-final-win-comp), a reproduction of the 7d2ae5a look for per-row
output, not a second look: identical 0.69065 and -0.00222 ± 0.00182.

| model (test) | log loss | AUC | vs base rates | vs ratings |
| --- | --- | --- | --- | --- |
| champion base rates | 0.69287 | 0.514 | - | |
| ratings | 0.69064 | 0.544 | -0.00223 ± 0.00170 | - |
| ratings + mix (win-comp) | 0.69065 | 0.544 | -0.00222 ± 0.00182 | +0.00002 ± 0.00048 |

Reading: on test the damage-mix term adds nothing detectable over ratings (+0.00002 ±
0.00048, so a gain over ~0.0005 is ruled out); the folds' -0.00057 ± 0.00028 sits at
the edge of that interval, so the real gain is at most about half the folds' estimate.
Mix effect, train fits: -1.50 ± 0.33 pp per sd (dev phase); the final fit's weight isn't
printed (exp final writes no effect tables; its inner val kept the term at -0.00031).
Ratings alone beat champion base rates on test (-0.0022 ± 0.0017), win-ratings' first
test result

#### Model-free cross-check (meiolol-49)

`meiolol-lab compcheck SNAP` (src/lab/compcheck.zig, 71faf36; built with
-Dcand=src/lab/cand/win-ratings), dev only, run 20261013T191005Z-compcheck2 (gpu-box).
win-ratings' dev predictions are the offset (same build, same 8,500 dev-val games as any
candidate's dev run). Each game gives two team units, observed win minus predicted chance;
teams are binned by profiles: per-minute means of seat stats over the 88,706 visible
games before the dev cut (99.97% of rows with stats; 293 of 85,000 dev picks fell back to
the champion's all-role profile), never a scored game's own stats. Intervals 95%,
clustered by game. Per-team units in compcheck.tsv in the run dir.

Positive control (champion strength, a real effect): with a coin as the offset, dev teams
by their five champion-roles' summed training lifts (shrunk log-odds, prior 1000) minus
the enemy's:

| lift difference quartile | lifts say | observed | observed - 50%, pp | observed - win-ratings, pp |
| --- | --- | --- | --- | --- |
| Q1 | 45.4% | 44.4% | -5.59 ± 1.49 | -0.15 ± 1.49 |
| Q2 | 48.8% | 48.2% | -1.79 ± 1.50 | -0.43 ± 1.50 |
| Q3 | 51.2% | 51.8% | 1.79 ± 1.50 | 0.43 ± 1.50 |
| Q4 | 54.6% | 55.6% | 5.59 ± 1.49 | 0.16 ± 1.49 |

The check finds a training-derived team effect on dev at its predicted size, and
win-ratings absorbs all of it. With ~4,250 teams a bin, a quartile's ± is ~1.3-1.5 pp, so
effects of ~2 pp per quartile are within reach. (A plumbing check, a champion-role's
lift taken out of the offset and found again, matches to 0.05 pp.)

Pre-declared contrasts (observed minus win-ratings, pp; raw = observed minus 50%):

| hypothesis | contrast | raw | after win-ratings |
| --- | --- | --- | --- |
| team magic share (<20, 20-40, 40-60, 60%+) | lopsided minus balanced | 0.38 ± 2.48 | -0.32 ± 2.47 |
| physical share, iTero's bins (<20, 20-80, 80%+) | lopsided minus 20-80% | -4.52 ± 8.12 | -4.88 ± 8.12 |
| frontline count (taken + mitigated/min, top 20% of picks) | none minus some | -0.79 ± 1.79 | -0.08 ± 1.78 |
| team's best mitigated share (win-comp's frontline form) | lowest quartile minus rest | -2.40 ± 1.74 | -1.65 ± 1.74 |
| team CC time/min | lowest quartile minus rest | 0.02 ± 1.75 | 0.90 ± 1.74 |
| 2+ frontline x enemy magic share | edge into 50%+ magic minus into <30% | | 3.43 ± 5.84 |
| team armour lean (armor_end - mr_end vs role) x enemy magic | armour minus MR-leaning, into 50%+ minus <30% | | -4.83 ± 6.08 |

Reading (dev-val alone; the folds below supersede it):
- Not detected: none of the seven contrasts excludes 0, raw or after win-ratings. Of ~40
  single bins (full tables in the run's log) four are just past ±1.96 se (armour-leaning
  into <30% magic +3.5 ± 3.4, best mitigated Q1 -1.2 ± 1.3 and Q2 +1.7 ± 1.3, CC Q2
  -1.7 ± 1.3) with no pattern between neighbours: about the two expected by chance
- The largest effect the data allows (interval ends, after win-ratings): a lopsided
  magic/physical mix within ±2.8 pp of a balanced one on the 20/60 bins; no frontline
  at most -1.9 pp; the weakest-frontline quartile at most -3.4 pp; low CC at most
  -0.8 pp. The cross-team terms are wide (±6 pp): too few teams in the extreme cells
- iTero's gap (about -9 pp under 20% AD, -6 pp over 80%, unadjusted, research) can't be
  tested with profiles: averaged kits put only 76 and 69 of 17,000 dev teams in those
  bins (raw -5.3 ± 11.3 and -3.6 ± 11.9). iTero's shares are the game's own damage,
  which winning reshapes, so its gap mixes comp with result
- A bin holding both teams of most games (20-80% physical: 99%) has mean residual ~0 by
  construction (the two units cancel); compare minority bins against it, as above
- For win-comp: any claimed comp effect of a few pp at the team-quartile scale should
  show here; a claim this check can't see at all is either below ~2 pp per quartile or
  in a feature not binned here

Forward-chaining folds (`compcheck SNAP --folds 5`, c8d3317, run
20261013T192745Z-compcheck-folds5): win-comp's foldAblation blocks, the newest half of
dev's visible games (every platform) in five blocks by start, 44,353 games (88,706 team
units). Per block, win-ratings refitted and profiles, lifts and the frontline cut rebuilt
on the games before it (443k to 798k training rows). The dev mode reran bit-identical
(dev4 = compcheck2). Positive control: coin offset -4.43 / -0.72 / +0.72 / +4.42 ± 0.66
by strength quartile (lifts say -4.6 / -1.2 / +1.2 / +4.6), after win-ratings within
±0.46.

| hypothesis | contrast | raw | after win-ratings |
| --- | --- | --- | --- |
| team magic share (<20, 20-40, 40-60, 60%+) | lopsided minus balanced | -2.61 ± 1.08 | -2.96 ± 1.07 |
| same, by bin | <20% magic (2,984 teams) | -5.80 ± 1.75 | -5.30 ± 1.74 |
| same, by bin | 60%+ magic (6,231 teams) | -0.68 ± 1.20 | -1.38 ± 1.20 |
| physical share, iTero's bins | lopsided minus 20-80% | -8.81 ± 3.20 | -8.90 ± 3.20 |
| same, by bin | <20% physical (356 teams) | -8.71 ± 5.12 | -10.12 ± 5.13 |
| same, by bin | 80%+ physical (567 teams) | -8.73 ± 4.04 | -7.99 ± 4.04 |
| frontline count | none minus some | -1.01 ± 0.76 | -0.44 ± 0.75 |
| team's best mitigated share | lowest quartile minus rest | -1.36 ± 0.76 | -0.90 ± 0.76 |
| team CC time/min | lowest quartile minus rest | -1.58 ± 0.77 | -0.78 ± 0.76 |
| 2+ frontline x enemy magic share | edge into 50%+ minus <30% | | -1.13 ± 2.50 |
| armour lean x enemy magic share | armour minus MR-leaning, 50%+ minus <30% | | -2.48 ± 2.59 |

win-comp's train-fit claims (0d, run wc-a-full) against the residual's slope per 1 sd of
the same blue-minus-red feature: team magic share off 50%, squared, claimed -1.24 ± 0.28,
found -1.90 ± 0.46 (dev-val alone -0.25 ± 1.06); magic share x enemy immobilise/min,
claimed -0.40, found +0.30 ± 0.46 (not seen; the interval excludes the claim).

Reading:
- Damage balance is real at this size: lopsided minus balanced -3.0 ± 1.1 pp after
  win-ratings, pre-declared, and in every block (lopsided -2.4 to -3.6, under-20%-magic
  -2.9 to -6.4; scratch per-block split of compcheck.tsv), including block 4, whose
  ratings fit stopped at epoch 1. Raw and adjusted barely differ: it isn't which
  champions sit in those comps. Mostly the physical side: under 20% magic -5.3 ± 1.7,
  over 60% magic -1.4 ± 1.2. The enemy side mirrors it (teams facing <30% magic: +2.2 and
  +3.7 in the frontline table, +1.1 to +4.3 in the armour table)
- iTero's gap reproduces: -10 ± 5 and -8 ± 4 in their bins, against their unadjusted -9
  and -6, after win-ratings as before it
- EUW dev-val alone gave -0.32 ± 2.47 for lopsided, 1.9 sd from the pooled -2.96: chance
  or a smaller EUW effect, not separable here (compcheck.tsv has no platform)
- Frontline and CC: no frontline not detected (-0.4 ± 0.8); weakest-frontline and
  least-CC quartiles -0.9 and -0.8 ± 0.8, past 0 singly but not with seven contrasts
  (Bonferroni z 2.69); low CC overlaps with all-physical comps (marksmen, assassins), not
  separated here
- Cross-team: armour-heavy into magic -2.5 ± 2.6, frontline into magic -1.1 ± 2.5: not
  detected, at most about -5 and -4 pp
- Dev only, no test look. A final needs the test look agreed with meiolol-2c

By platform (same folds, 9e452b9, run 20261013T193312Z-compcheck-folds5-pf; pooled
numbers unchanged). Lopsided = profile magic share under 20% or 60%+:

| platform | games | lopsided teams | <20% magic | 60%+ magic | raw, pp | after win-ratings, pp |
| --- | --- | --- | --- | --- | --- | --- |
| EUW1 | 11,168 | 10.7% | 2.4% | 8.3% | -2.14 ± 2.12 | -2.60 ± 2.12 |
| rest | 33,185 | 10.3% | 3.7% | 6.6% | -2.77 ± 1.25 | -3.09 ± 1.25 |
| NA1 | 3,452 | 10.7% | 2.8% | 7.9% | -2.57 ± 3.84 | -2.72 ± 3.84 |
| BR1 | 2,389 | 13.1% | 4.1% | 9.0% | -3.13 ± 4.15 | -3.30 ± 4.14 |
| KR | 10,102 | 9.0% | 2.9% | 6.2% | -3.82 ± 2.38 | -4.18 ± 2.38 |
| VN2 | 8,757 | 10.0% | 5.0% | 5.0% | -4.49 ± 2.44 | -4.65 ± 2.43 |

EUW1 minus the rest +0.49 ± 2.46 pp: EUW is not detectably different, and dev-val's
-0.32 ± 2.47 sits within it. About one team in ten is lopsided, in EUW mostly the magic
side (8.3% vs 2.4%), while the larger cost per team is on the physical side.

Test-look plan (pre-declared 2026-10-13, before any look; one look, on meiolol-2c's go,
same build as 0d's win-comp look):
- Command: `meiolol-lab compcheck SNAP --final` (165895b or later with compcheck.zig
  unchanged), built with -Dcand=src/lab/cand/win-ratings, snap-20261012T2055Z. It prints
  the positive control and this contrast only
- Units: both teams of every EUW1 test game of 15:00+ (~10,600 games). Offset:
  win-ratings fitted by harness.score(.final) on every train game. Profiles: per-minute
  damage to champions by type, summed over the team's five champion-roles' profiles
  from every train game (all older than the first test game); champion fallback below
  30 rows. Lopsided: team magic share < 0.20 or >= 0.60; balanced otherwise
- Estimate: mean (observed - win-ratings) over lopsided teams minus over balanced
  teams, 95% interval clustered by game; raw (observed - 50%) beside it; the <20% and
  60%+ sides shown, not tested
- Reported whatever it shows, as an estimate, not pass/fail. Expected interval ~±2.2 pp
  (EUW folds ±2.1 on 11k games), so at the folds' -3.0 a z of about 1.4. Reading fixed
  now: the effect's existence rests on the folds (z ~5.4); the test says whether its
  size carries to new EUW games. Consistent if the interval covers -3.0; the size is in
  doubt if the interval lies wholly above -3.0 (then learned.md says so and gives both
  numbers); a sign flip (lower end above 0) would mark the fold result as not holding
- The positive control must show the strength gradient (raw Q1 and Q4 at least ±3 pp)
  and win-ratings absorbing it, or the look's contrast isn't read

Test look (2026-10-13, meiolol-4b; run 20261013T195844Z-final-compcheck, gpu-box, clean
clone of c26ffa8; 0d's win-comp look ran on 7d2ae5a, and compcheck.zig, harness.zig and
rows.zig are unchanged between the two, so one build): 10,604 EUW1 test games, 21,208
team units; profiles from 1,721,440 training rows (100.0% with seat stats), champion
fallback for 115 of 106,040 picks.

| lift difference quartile | teams | lifts say | observed | observed - 50%, pp | observed - win-ratings, pp |
| --- | --- | --- | --- | --- | --- |
| Q1 | 5,303 | 45.1% | 45.6% | -4.42 ± 1.34 | +1.44 ± 1.34 |
| Q2 | 5,302 | 48.7% | 48.0% | -1.98 ± 1.34 | -0.48 ± 1.34 |
| Q3 | 5,302 | 51.3% | 52.0% | +1.98 ± 1.34 | +0.48 ± 1.34 |
| Q4 | 5,301 | 54.9% | 54.4% | +4.42 ± 1.34 | -1.44 ± 1.34 |

| magic share | teams | win-ratings | observed | observed - 50%, pp | observed - win-ratings, pp |
| --- | --- | --- | --- | --- | --- |
| lopsided | 2,183 (10.3%) | 50.7% | 48.3% | -1.67 ± 1.98 | -2.40 ± 1.98 |
| <20% | 497 (2.3%) | 48.6% | 46.3% | -3.72 ± 4.33 | -2.28 ± 4.36 |
| 60%+ | 1,686 (7.9%) | 51.4% | 48.9% | -1.07 ± 2.29 | -2.43 ± 2.28 |
| balanced | 19,025 | 49.9% | 50.2% | +0.19 ± 0.23 | +0.27 ± 0.23 |

Pre-declared contrast, lopsided minus balanced: -2.67 ± 2.21 pp after win-ratings
(-1.86 ± 2.21 raw). Read by the plan: control holds (raw Q1/Q4 ±4.4; win-ratings takes
the gradient out, leaving a reversed +1.4 ± 1.3 at the ends, i.e. win-ratings a little
overconfident on test, small beside the gradient and not lopsided-specific: lopsided
teams' predicted 50.7% vs balanced 49.9%). Contrast **consistent**: the interval
(-4.9 to -0.5) covers the folds' -3.0, and also excludes 0. Folds and test together: a
lopsided damage mix costs about 3 points beyond the champions, in EUW too. The <20%
side is too small on test (±4.4) to check the folds' -5.3 on its own.

Calibration from the same look: win-ratings is slightly overconfident at the extremes on
EUW test (strongest and weakest lift quartiles each 1.4 ± 1.3 pp less extreme than
predicted; the two quartiles mirror each other, one game's two teams, so one number). On
the research lever list: temperature scaling (one scale on the logit, fitted on the
newest visible games). The dev side agrees: netcheck resid's learnt weight on
win-ratings' logit settles at ~0.9 on every block (a189f10), which is temperature
scaling fitted on fit games, and bought only -0.00005 ± 0.00007 nats/game on the 5
forward folds (weight fixed at 1: 0.00000). So expect it real but ~1e-4 in log loss;
it matters for the extreme picks shown to players more than for the headline number.

`meiolol-lab gains UNITS A B` (src/lab/gains.zig), the model-free check of where a
model's gain sits, first run on real files: UNITS from 20261013T195256Z-compcheck-dev5,
A = 0d's first win-comp dev run (20261013T190836Z-wc-a-full), B = win-ratings
(20261013T191733Z-wc-a-wr), 8,500 dev-val games, all matched. "All" gives A - B +1.09 ±
1.41 milli-nats/game, 0d's own +0.0011 ± 0.0014, so the tool reads exp's files right.
No group shows a gain for win-comp: lopsided team +1.9 ± 4.5, both balanced +0.9 ± 1.4,
strength mismatch Q1 to Q4 +2.3, +2.1, +0.1, -0.1 (each ±2.8), no frontline-ish pick
+1.3 ± 2.0. Dev-val is EUW only, so the EUW/rest split needs fold predictions.

On the 5 forward folds (44,353 games, units 20261013T205116Z-compcheck-folds5-units;
per-game preds from f1's netcheck runs in data/netcheck/f1, all games matched, every "all"
row equals the published number; milli-nats/game, negative = A better; 9 groups per
comparison, so a lone group just past zero is not a finding):
- win-comp vs ratings -0.57 ± 0.28, of which lopsided-team games -2.11 ± 1.08 (8,727
  games, about three quarters of the total), both balanced -0.19 ± 0.23. The gain sits
  where the model-free effect is: win-comp works through the damage mix as claimed.
  EUW1 -0.44 ± 0.53, other platforms -0.62 ± 0.33, not different
- big net vs ratings -0.28 ± 0.39: leans to lopsided teams (-0.96 ± 0.90) and the widest
  strength quarter (-1.06 ± 0.90), neither clear. Against win-comp +0.29 ± 0.49, lopsided
  +1.16 ± 1.43: it picks up less of the comp effect than win-comp's explicit terms
- small net vs ratings +0.66 ± 0.29 worse, worst in the widest strength quarter
  (+1.58 ± 0.72): it underfits the strong champion edges the ratings carry
- resid on ratings (cross-fitted) -0.05 ± 0.07; every group within ±0.25, strength Q3's
  -0.22 ± 0.13 the only one past zero, one of 9
Rows in docs/nn-results/gains.tsv.

Verifier audits, 2026-10-13 (meiolol-4b; same units and gains, folds):
- 97's pretrain (a88db2d, data/pretrain/d12): no leakage. Fit = nnexport split < block
  (dev: <= 5), scored = split == block (dev: dev_val), so test and newer games never fit;
  aux targets, vocab, base means, hand profiles and ratings L2 from fit games, inner/val
  split for tuning, refit on all. Minor: the aux z-norm is taken over all fit games, val
  included, while val picks the aux L2 and epochs (target scaling only, no outcomes).
  97's ratings equal win-ratings (-0.03 ± 0.08). Embedding prior -0.36 ± 0.27 (seed-mean
  preds; 3 seeds all below zero, -0.41 to -0.19), random control +0.10 ± 0.22, hand
  profiles -0.11 ± 0.32; vs win-comp +0.19 ± 0.36. Spread over groups, leaning to the
  widest strength quarter (-1.00 ± 0.58) and lopsided teams (-0.80 ± 0.68); dev-val
  alone +0.20 ± 0.52. One of several variants and more runs (d8, d16, targets) coming:
  pick the winner on folds before any test look and count the variants tried
- f7's playernet (8e28b3e, data/runs/playernet-20261013): no leakage. Experience from
  rows.fillExperience (games ended by this game's start), feature scaling on inner / all
  fit rows, offsets cross-fitted as winnet's resid; rank at start and mastery absent on
  this snapshot (mastery must be pre-game if added). Its win-ratings equal f1's exactly.
  Net on ratings -2.54 ± 0.65, the hand-made experience terms -2.61 ± 0.69, the net on
  top of them -0.02 ± 0.20: the net finds nothing beyond the hand terms. The gain is
  flat over draft types (lopsided -2.51, balanced -2.54, strength Q1 -2.85, Q4 -2.57),
  as a player effect should be, and over four times any draft model's. The r-exp
  candidate is src/lab/cand/win-exp (b274481, checked identical to the run's copy bar
  its name); mastery, when on, only from SNAP/mastery_pre.tsv (pre-game fetches)

Noise floor on the folds (A/A), 2026-10-13 (meiolol-4b; snap-20261012T2055Z, 885e879
`netcheck --resample N`: fit games and the candidate's fits on a seeded random 90%,
scored games unchanged; runs 20261013T213637Z-aa-small, 20261013T221157Z-aa-small2 (12
resamples, small, seeds 1-36 in disjoint threes), 20261013T221815Z-aa-big4 (4, big)).
Milli-nats/game on the 44,353 fold games:
- The same model refit on another 90% with other seeds differs from itself with sd
  0.22 (ratings), 0.28 (small), 0.29 (big): a 95% A/A spread of ±0.44 to ±0.57, and the
  per-game paired interval calls ratings r1 vs r3 (-0.47 ± 0.33) a "gain". Part of it is
  win-ratings' L2 pick, which flips between grid values across resamples
- A net against its own candidate on the same resample (how every netcheck row is
  made): the difference moves across resamples with sd 0.19 (small, 12) and 0.17 (big,
  4), on top of the per-game se 0.15 and 0.22. Honest 95% half-width about ±0.48
  (small) and ±0.55 (big), vs the reported ±0.30 and ±0.43: widen paired intervals ~1.6x
  (small-sized models) or ~1.3x (big)
- Single big seeds within a block spread with sd up to 4: never read one seed
- Ratings' own seed noise is small (meiolol-58's torch cross-check of Zig's procedure,
  gpu-box 20261013T224459Z-xratings-spread, 10 seeds: pooled-fold sd 0.06, per block
  0.09-0.26, dev-val 0.12), so most of ratings' A/A spread is which games it was fitted
  on and the L2 pick. Keeping the candidate at seed 1 is fine for pooled gains; name it.
  Per game, seeds move ratings' logit by 0.02-0.03 on average, which matters for
  per-game uses (resid offsets, stacking inputs, effects tables)
Rule from here: a gain under about 0.5 milli-nats/game on the folds is inside the floor
and needs sealed confirmation seeds and a second resample before a write-up. Today that
covers big (-0.28), resid (-0.05), pretrain d8 (-0.24), set net (-0.42), patch (-0.14);
win-comp (-0.57), the 4-input average (-0.61) and player experience (-2.5) are past it.

Leakage review (ea's 25737aa, 0d's win-comp working copy, 2026-10-13): the harness copies
Row.stats into Train for visible rows only (test "seat stats reach fit on visible games
only" covers dev, select, final); rows.load holds only eval's train (older than the first
test game) and test, so final's profiles are older than every test game; a Query has no
stats. win-comp built profiles for its inner validation from every visible game, the val
games included (their own stats in their profiles); fixed by 0d: tuning on fit-set
profiles, refit rebuilds them on all visible rows; forward-chaining folds rebuild
everything per fold (foldAblation calls fitWith on older games only).

### Comp discovery, 2026-10-14 (meiolol-c1)

Question (Jacob, 13 Oct): beyond "champions with higher win rates win", which team traits
and team-vs-team matchups make a comp good or bad? Answer on this snapshot: only the damage
mix. Hundreds of other traits, coaching win conditions and comp archetypes add nothing
detectable beyond ratings; three traits that passed the screen did not hold on sealed games.

Data: `meiolol-lab comp-stats SNAP DDRAGON` (src/lab/compstats.zig, 3ab7299) adds
SNAP/comp_stats.tsv beside seat_stats.tsv (per seat from the raw summary: vision, wards,
epic monster and turret damage, dragon/baron/herald takedowns, plates, late solo turrets,
lane CS at 10, kills, deaths, assists, kill share, damage and taken shares, pick, catch,
dive, defence and save-ally challenges, effective heal and shield, early takedowns and
roams, skillshots, CC dealt, time dead, gold; item flags held at the end from Data
Dragon's description: anti-heal "Wounds", armour pen, magic pen, lethality) and
SNAP/comp_teams.tsv (first and kills per objective). snap-20261012T2055Z: 2,303,750 seats,
460,750 teams, 0 unreadable. soloTurretsLategame is absent when 0 (never 0 in the data).

Method: `meiolol-lab comps SNAP` (src/lab/comps.zig, 3df16c6, e6588c1), built with
-Dcand=src/lab/cand/win-ratings. 63 champion-role profile values (seat stats, comp stats,
gold14/lanediff14/cs10/deaths15/first item, game length, scaling = win rate in 32+ min
games minus under 25), each the average of the cell's won-game and lost-game means, shrunk
to the role by 20 rows, z within role; fit games only, rebuilt per block. A team sum of a
profile is linear in the champions (ratings hold it), so candidates are non-linear: team
max and min per value (126), "1+"/"2+" picks in the top 20% (48), 8 sums as controls, 14
specials (mix, lopsided, <20% and 60%+ magic, 80%+ physical, damage concentration, 4+
ranged, 4+ melee, no win condition, power-curve shape, front-to-back, hard engage, no
objective champion), 21 cross-team coaching products (our X x their Y, centred,
antisymmetrised), 6 k-means archetypes (fitted once on teams before block 1) and their 15
pairings, 12 carry terms from meiolol-61's per-fold table (leverage at 10 and 25 minutes,
scaling): 252 in all, every one in the FDR count (12 rows came out NaN, untestable:
role-level flags every team has, e.g. 1+ top vision is always the support; still counted
in m, which is conservative). Per game: blue's residual (won
minus ratings' chance) on x = trait(blue) - trait(red), OLS slope, robust se; effects in
win pp per team sd (flags: pp for having it when the other team doesn't). Folds:
win-comp's blocks (nnexport.foldBounds), ratings and profiles refitted on older games.
Screen: blocks 1-3 (26,611 games), Benjamini-Hochberg. Sealed: blocks 4-5 and dev-val
(26,242 games), opened once for a list fixed beforehand (scratchpad progress-comps.md):
screen passes at q 0.05 with the same sign in 2 of 3 blocks, plus every coaching
hypothesis with a predicted sign; read by Holm over the list (27), a screen pass also
needing |z| >= 2 beside the mix term.

Controls (same build, same 252 candidates):

| control | run | BH passes (q 0.05) | reading |
| --- | --- | --- | --- |
| profiles permuted among a role's champions | 20261013T230807Z-comps-permuted | 0 | traits don't pick up ratings misfit |
| shuffled residuals, 20 shuffles | in each run | 3 passes in 3 of 20 (real screen run) | false passes ~0.15 per screen |
| planted mix -3 pp (synth) | 20261013T223736Z-comps-plant-mix3 | mix z -5.9, plus mix proxies | found |
| planted mix -2.25 | 20261013T230832Z-comps-plant-mix2p25 | mix -4.4, lopsided -4.6 | found |
| planted mix -1.5 | 20261013T224432Z (pre-fix build) | mix -0.15 ± 0.42 | missed |

The mix -3 and -1.5 plant runs' meta says "dirty 0" (2890cd9, a08ce85) but they were built
from a scratch tree before comps.zig was committed (3df16c6); the -2.25 plant and the
permuted control are on the committed build. Plants come back at about 60% of their
planted size, so the estimates below are likely shrunk towards 0.

Minimum detectable effect (screen): plants are in pp per sd of the blue-minus-red
difference (synth.zig), estimates in pp per team sd (that over sqrt 2, which assumes the
two teams' values are independent). In team-sd units: planted 2.12 (mix -3) came back as
1.26, planted 1.59 (-2.25) as 0.95 and was found, planted 1.06 (-1.5, earlier build) was
missed. So true effects of about 1.6 pp per team sd are found and 1.1 not; on the
estimate's scale the screen needs about 0.8-1 (z 3.7 at se 0.21). For a flag one team in
ten has (se 0.77 pp) it needs about 3 pp estimated, about 5 pp true if flags shrink like
the mix (not planted). The plant runs also showed proxies of a real effect pass too (armour
pen items, the enchanter archetype under a planted mix), hence the beside-mix column.

Screen, run 20261013T231749Z-comps-screen: 7 passes at q 0.05, 12 at q 0.10 (top rows;
all 252 in its screen.tsv with mechanism columns):

| trait | screen effect | z | blocks 1/2/3 | beside mix | sealed effect | sealed z | verdict |
| --- | --- | --- | --- | --- | --- | --- | --- |
| mix (team magic share off 50%, squared) | -1.22 ± 0.42 pp/sd | -5.67 | -1.7 / -1.2 / -0.8 | | -0.89 ± 0.42 | -4.13 | **confirmed** |
| lopsided (magic <20% or 60%+) | -3.01 ± 1.51 pp | -3.92 | -3.0 / -4.1 / -2.0 | -1.43 ± 1.67 | -1.98 ± 1.50 | -2.59 | mix family |
| magic <20% | -4.88 ± 2.55 pp | -3.75 | -6.8 / -5.7 / -1.9 | 0.04 ± 3.42 | -3.79 ± 2.60 | -2.86 | mix family |
| our AD share x their armour lean | -0.81 ± 0.42 pp/sd | -3.77 | -0.8 / -0.6 / -1.1 | -0.77 ± 0.42 | -0.30 ± 0.42 | -1.38 | not confirmed |
| 4+ ranged champions | -2.51 ± 1.43 pp | -3.43 | -0.5 / -3.8 / -3.1 | -2.90 ± 1.44 | +0.49 ± 1.46 | 0.66 | not confirmed |
| 1+ magic pen item champion | +1.69 ± 1.00 pp | 3.31 | 2.5 / 1.8 / 0.8 | 0.68 ± 1.08 | +1.25 ± 1.01 | 2.43 | mix proxy |
| 2+ catch-and-kill engagers | +1.65 ± 0.99 pp | 3.26 | 1.3 / 1.4 / 2.3 | 1.56 ± 0.99 | +0.75 ± 0.99 | 1.50 | not confirmed |

Coaching hypotheses on the sealed games (none passes Holm; the largest): our tankiness x
their penetration items +0.65 ± 0.42 pp/sd (z 3.0, opposite to the predicted sign), our
engage x their disengage +0.41 ± 0.43, our dive x their peel +0.37 ± 0.43 (predicted
negative), our sustain x their poke -0.35 ± 0.43, front-to-back +0.57 ± 0.90 pp, hard
engage -0.38 ± 0.92, no win condition -0.18 ± 2.44, healing x their anti-heal +0.20 ±
0.42, poke x their engage +0.19 ± 0.43; all within about ±1 pp per sd (flags ±2-5 pp).
Split push x waveclear, siege x waveclear and no objective champion were degenerate (no
estimate). Archetypes (range/siege, melee tank engage, AD pick, low-early, early
roam-dive, enchanter): no archetype or archetype pairing past |z| 2.3 of 21 on the
screen; cells within about ±2.5-3 pp (pairings) and ±1.1-1.4 pp (archetypes).

Mechanism (screen, after an additive champion baseline per block): the mix works neither
through lane gold (team gold at 14 +11 ± 37 per sd) nor first tower or dragons; its win
effect is the same in games under 25 and 25-32 minutes (-1.5) and smaller after 32 (-0.6),
so it works neither through lane gold, first tower nor dragons, and is weaker after 32
minutes (nothing here tested fights directly). The sealed estimate by block: block 4
-1.14, block 5 -1.29, dev-val (the newest games) -0.13: about nothing on the newest.

Logistic comp layer on ratings' logit (fit on blocks 1-3, scored on the sealed games,
nats/game, paired by game): ratings + mix -0.00028 ± 0.00042 (blocks 4-5 -0.00062 ±
0.00052, dev-val +0.00043 ± 0.00070); + the six non-mix screen passes +0.00043 ± 0.00066
(worse); all with mix vs mix alone +0.00067 ± 0.00058. The joint OLS column came out
empty: the list's three degenerate traits dropped every row (fix: leave NaN columns out).

Reading:
- Good and bad comps, as far as this data shows: balanced damage is good, lopsided is
  bad, and that is the only comp trait that holds (-0.9 pp per team sd, z -4.1). Under a
  fifth magic adds nothing beyond the curve (0.04 ± 3.42 beside the mix). It reproduces
  win-comp's term with a new pipeline; it is not a sealed find for the mix: win-comp is
  ratings + mix, a declared hypothesis already measured on blocks 1-5
  (compcheck-folds5, -1.90 ± 0.46), so blocks 4-5 were sealed only for the other 26.
  On dev-val alone it is about nothing (-0.13), and ratings + mix in log loss on the
  sealed games is not a measurable gain (-0.00028 ± 0.00042; dev-val +0.00043)
- Everything else is "not detected", bounded by the MDE above: no other team trait is
  worth more than about 1 pp per team sd or 3 pp as a one-in-ten flag. Coaching win
  conditions (front-to-back, dive vs peel, poke vs engage, scaling vs early, split vs
  waveclear, healing vs anti-heal, AD vs armour) are each within about ±1 pp per sd on
  sealed games. Comp archetypes beyond the champions: not detected
- Screen passes that failed sealed (AD share x armour, 4+ ranged, 2+ engagers) are the
  winner's curse a screen expects (about 0.15 false passes per screen by the shuffles, and
  screen effects near the threshold overstate): don't build on them
- For meiolol-08's additive CPU model and meiolol-35's set nets: the mix term only; the
  rest as candidates with the bounds above
- Audited by meiolol-33 (14 Oct): cleared with the wording above; learned.md line
  "2026-10-14: Screening 252 team traits". Rerun on snap-20261013T2253Z below

#### Rerun on snap-20261013T2253Z (meiolol-94, 14 Oct)

Same method on the re-cut pin (shared protocol: test the newest 15% of played games,
dev-val the next 10%, every platform, five forward folds below; 85fd62a), built at
0c3e486 with two fixes declared before any look (379a751: waveclear from minions per
minute, since twentyMinionsIn3SecondsCount is ~always 0; role-determined vision and
epic-damage flags dropped; no objective champion by role z >= 1; 244 candidates with
12 carry terms from a carry fold table on the same cuts; one carry row, "none above
median leverage10", came out NaN and stays in the count). comp_stats.tsv covers 81.5%
of games: dev_old 59.6%, folds 1-3 ~89%, fold 4 93.5%, fold 5 95.6%, dev-val 99.7%, test
100%; RU 1%, TR1 47%, the rest 73-87%; missing games don't differ in outcome or duration
(meiolol-53). None of 2055Z's comps-sealed games fall in the new sealed blocks (they
land in dev_old and folds 1-2); 27,552 sealed games were in 2055Z's test (8,874) or
selection windows (18,678), never used by the comps work. Rule declared before the
screen (scratchpad progress-comps.md, accepted by meiolol-33): sealed list = screen
passes at q 0.05 with the same sign in 2 of 3 blocks, every coaching hypothesis, and six
names carried from 2055Z; Holm at 0.05, coaching hypotheses one-sided in the predicted
direction unless also carried from 2055Z, the rest two-sided; a non-mix screen pass also
needs |z| >= 2 beside the mix.

| run | what | result |
| --- | --- | --- |
| 20261014T005415Z-comps-permuted-2253Z | profiles permuted within role | 0 passes at q 0.05 and 0.10 |
| 20261014T005437Z-comps-screen-2253Z | screen, blocks 1-3, 80,625 games | 15 passes at q 0.05; 20 shuffles: 0 at q 0.05, 8 at q 0.10 |
| 20261014T005906Z-comps-confirm-2253Z | sealed 4-5 + dev-val, 89,584 games, 32 names | three findings beside the mix (below) |

| finding | sealed effect | z | blocks 4 / 5 / dev-val | beside mix z | reading |
| --- | --- | --- | --- | --- | --- |
| mix (magic share off 50%, squared) | -1.06 ± 0.23 pp/sd | -9.1 | -0.8 / -1.2 / -1.1 | | replicates, now on dev-val too |
| magic 60%+ | -2.14 ± 0.93 pp | -4.5 | -1.8 / -2.1 / -2.4 | -4.1 | magic-heavy teams lose more than the mix curve says |
| our AD share x their armour lean | -0.63 ± 0.23 pp/sd | -5.3 | -0.7 / -0.6 / -0.6 | -5.1 | damage type into armour, theory's sign |
| our AP share x their armour lean | +0.56 ± 0.23 pp/sd | 4.8 | 0.6 / 0.6 / 0.6 | 4.6 | the same finding mirrored, not a second |
| our tankiness x their pen items | +0.62 ± 0.23 pp/sd | 5.2 | 0.6 / 0.7 / 0.5 | 5.2 | opposite to theory (declared two-sided) |

Lopsided (magic <20% or 60%+, -2.99 ± 0.78 pp, beside mix z -3.9) is magic <20% plus
magic 60%+, and magic <20% is the mix again (beside mix z -0.12): the same finding as
magic 60%+, not a second one. Holm passes that are the mix again (beside mix |z| < 2):
magic <20%, physical 80%+, max magic damage, max magic pen, 1+ magic pen champion. Not
confirmed: 4+ melee, 4+ ranged, 2+ catch-and-kill engagers, max late solo turrets, and
every other coaching hypothesis (healing x anti-heal, dive x peel, engage x disengage,
pick x vision, front-to-back, hard engage, no win condition, split or siege x
waveclear: all within ±0.4 pp/sd or ±1.4 pp).

Leads for the next pin (pre-declare two-sided there), not confirmed here:
- Our sustain x their poke -0.58 ± 0.23 pp/sd: the sign agrees between screen (z -3.24)
  and sealed (z -4.88, all three sealed blocks negative), opposite to theory. As a
  coaching hypothesis it was one-sided in theory's direction (p ~1); reading it
  two-sided was decided after the screen, so it doesn't count (meiolol-53)
- Our poke into their engage +0.37 ± 0.23 pp/sd (sealed z 3.2, screen z -0.04): one item
  entered twice (our range x their engage is exactly minus our engage x their range),
  opposite to both one-sided hypotheses. Next time drop exact duplicates before building
  the list

Mechanism (screen blocks): the armour and pen crosses move gold at 14 by under 20 ± 20
and objectives by ~0, and are a little larger in games under 25 minutes.

Prediction: the confirmed effects are associations beside the ratings offset; their
joint log-loss gain beyond the mix (logistic layer on ratings' logit, fit on blocks
1-3, all 31 listed terms + mix vs ratings + mix, sealed) is -0.34 ± 0.25 mnats/game,
under the ~0.5 floor, so no prediction gain is claimed; the pp sizes above are not model
gain. Ratings + mix vs ratings -0.46 ± 0.22 mnats (blocks 4-5 -0.41, dev-val -0.52). The
joint column came out empty again from exact collinearity in the list (lopsided = magic
<20% + 60%+; the duplicated poke/engage item); it is not in the decision rule.

Reading:
- The damage mix replicates on 89,584 unseen games, and on this pin's dev-val as well
  (-1.1, where 2055Z's dev-val showed -0.1); magic-heavy teams (60%+) lose a further ~2
  pp beyond the curve
- Damage type into armour matters a little: physical damage into a team of
  armour-leaning champions is worse, magic damage into it better (about 0.6 pp per team
  sd). Tanky teams do better, not worse, against penetration-item champions (0.6 pp per
  team sd), which needs a mechanism before anyone coaches on it
- For the CPU model and set nets: mix, magic 60%+, AD share x their armour lean and
  tankiness x their pen items as candidate terms; none has shown a prediction gain yet

### Neural draft models, 2026-10-13 (meiolol-2c)

Jacob's goal: the best draft predictor with neural nets, beside the simple models pushed
as far as they go. Research (research/questions/nn-draft-models.md) expects no net to beat
logistic ratings beyond noise at 100-300k games on a time split, so the nets are built to
be data-efficient: small, residual on ratings (cross-fitted offsets), structured over
teams (profiles, DeepSets/attention, antisymmetric), pretrained champion-role embeddings
from auxiliary targets, seed-averaged. Protocol: win-comp's 5 forward folds (44,353 games)
plus dev-val, log loss paired per game vs ratings and win-comp from one build, mean of 3+
seeds with their spread; hyperparameters chosen on inner validation, never on fold gains;
one test look per final model. The learning curve (25/50/100% of fit games, then the
~350k-game unpinned snapshot) says whether the gap to ratings closes with data. Sessions:
docs/archive/2026-10-14-model-team/model-agents.md. Read every table as log loss vs ratings, negative is better.

#### Big, small and residual nets (meiolol-f1)

`meiolol-lab netcheck SNAP --net big|small|resid` (src/lab/winnet.zig, c709ca4), built
with -Dcand=win-ratings or win-comp: per block (dev-val; win-comp's 5 forward folds,
compcheck's bounds) the candidate and the net fit on the same games and score the same
games. Ids (champion-roles with 10+ fit games, else the role's; big 30+), early stopping
(newest 10% of the fit games, 4 checks an epoch; big once an epoch) and the refit (all fit
games, a tenth more epochs) from fit games only. All antisymmetric: logit = (f(blue, red) -
f(red, blue)) / 2 + side intercept per platform.
- big: draftnet.zig as built (champion-role + role embeddings 10 x 32, MLP 320-512-256-1,
  ReLU, dropout 0.1, AdamW lr 1e-3 wd 1e-4, batch 1024)
- small: embeddings 16, one hidden layer of 64, dropout 0.2, AdamW wd 0.1 (decoupled),
  batch 512, gradient norm clipped at 1; small A (meiolol-ad's starting config):
  embeddings 8, two layers of 128, dropout 0.1, wd 3e-4, no decay on embeddings
- resid: small with the candidate's logit as an offset (trainable weight from 1, or
  `--fix-offset 1`), output weights from 0, so it starts as the candidate. Training
  games' offsets are cross-fitted (each from a candidate fitted without the game's
  hashed fifth of the fit games; again inside the inner games for early stopping),
  val and scored offsets from the candidate on all inner / all fit games. A first
  version with in-sample offsets (meiolol-49's audit) is discarded
- Pipeline audited (meiolol-49, recheck meiolol-4b): fit and scored games disjoint in
  every mode, no offset from a fit holding its game (test "cross-fit")

Mac, snap-20261012T2055Z (rows identical to the gpu-box: ratings 0.69090 on the folds as
0d's), 3 seeds, the ensemble is the seeds' mean chance. Folds: 44,353 games pooled; dev-val
8,500 EUW1 games. ± is 95%, paired per game (= clustered by game); seed sd is the sd of the
single seeds' differences.

| net | folds vs ratings | single seeds | dev-val vs ratings | folds AUC (ratings 0.5397) |
| --- | --- | --- | --- | --- |
| small | +0.00066 ± 0.00029 | +0.00078 to +0.00122 | +0.00060 ± 0.00052 | 0.5372 |
| small A | +0.00073 ± 0.00036 | +0.00131 to +0.00304 | +0.00016 ± 0.00057 | |
| big | -0.00028 ± 0.00039 | +0.00032 to +0.00054 | -0.00035 ± 0.00065 | 0.5396 |
| resid | -0.00005 ± 0.00007 | -0.00006 to +0.00001 | +0.00001 ± 0.00012 | 0.5399 |
| resid A | -0.00001 ± 0.00007 | -0.00001 to +0.00011 | +0.00002 ± 0.00016 | |
| resid, offset weight fixed at 1 | +0.00000 ± 0.00005 | 0 to +0.00006 | -0.00001 ± 0.00003 | |

Against win-comp (-Dcand=src/lab/cand/win-comp, the mix model; folds 0.69033, i.e.
-0.00057 vs ratings as 0d's; dev-val 0.68999, +0.00030 vs ratings): small +0.00123 ±
0.00040, big +0.00029 ± 0.00049, resid on win-comp's offset -0.00004 ± 0.00008 (dev-val
-0.00011 ± 0.00018).

Learning curve (each fold's fit games kept by harness.inFraction, nested; scored games
unchanged; folds pooled):

| share of fit games | 25% (11-20k games) | 50% | 100% (44-80k) |
| --- | --- | --- | --- |
| ratings log loss | 0.69203 | 0.69134 | 0.69090 |
| small vs ratings | +0.00028 ± 0.00024 | +0.00043 ± 0.00031 | +0.00066 ± 0.00029 |
| big vs ratings | -0.00004 ± 0.00028 | +0.00013 ± 0.00029 | -0.00028 ± 0.00039 |
| resid vs ratings | -0.00004 ± 0.00010 | -0.00005 ± 0.00008 | -0.00005 ± 0.00007 |

Reading (dev, no test look):
- No net beats ratings or win-comp. The best, the big net's 3-seed mean, is -0.00028 ±
  0.00039 on the folds: not detected, at most ~0.0007 nats/game better; each single big
  seed is worse (+0.0003 to +0.0005): the ensemble is what brings it level, as research
  predicts (seed averaging is most of a net's gain at this size). win-comp's mix term
  beats every net on the folds
- The small net from scratch is worse than ratings, and its gap does not close as data
  doubles (+0.0003, +0.0004, +0.0007): ratings gain more from more games than it does.
  The big net's gap wanders within noise (±0.0003) at every size. So nothing here
  suggests nets would overtake ratings at 2x or 4x our data; the 350k snapshot will say
- Residual on ratings (cross-fitted): adds nothing detectable, at most ~0.0001 nats/game,
  the tightest bound here. Early stopping picks 0.25-3 epochs; the learnt offset weight
  goes to ~0.9 (ratings a little over-confident), which is all it finds; fixed at 1 it is
  exactly ratings. On win-comp's offset the same
- Nets early-stop at 1-4 epochs (big at 1-2): they overfit almost at once at 40-90k games
- Next: hyperparameter sweeps on the 3080 (meiolol-1c, ranked on inner validation),
  pretrained embeddings (meiolol-52, `--emb-init`), more seeds for the big ensemble,
  the 350k-game snapshot for the curve

#### Big net: tuning, seed ensembles, confirmation (meiolol-0a)

f1's work continued on the gpu-box (snap-20261012T2055Z, -Dcand=win-ratings unless said).
Code: `--evals N` for big (val checked N times an epoch; refit = best epochs x 1.1 in
steps, as small; 9ace58d, which also fixed seed 3 refitting seed 1 when --threads <
--seeds; f1's runs used 3 threads for 3 seeds, unaffected); per-game prediction files
DIR/games-<cand>.tsv, games-<net>.tsv for gains and stacking (0696aad); `--net bigres`, the
big net as a residual on the cross-fitted offset (f996ce0, 521c004); `--shuffle-ids SEED`,
the control for nets on fitted offsets (f29a170).

| run | folds vs ratings | better in | single seeds | dev-val vs ratings |
| --- | --- | --- | --- | --- |
| big, val checked 4x an epoch, minus 1x (3 seeds, paired) | +0.00031 ± 0.00026 | | | +0.00051 ± 0.00059 |
| big, default config, seeds 1-10 | -0.00039 ± 0.00033 | 4 of 5 | +0.00060 to +0.00188 | -0.00006 ± 0.00070 |
| big, default config, sealed seeds 11-20 | -0.00012 ± 0.00036 | | +0.00084 to +0.00347 | -0.00001 ± 0.00050 |
| big, default config, all 20 seeds | -0.00034 ± 0.00032 | 4 of 5 | | -0.00014 ± 0.00053 |
| big, default config, 10 seeds, 90% resample (ratings refitted on it) | -0.00010 ± 0.00035 | 2 of 5 | | -0.00016 ± 0.00061 |
| big, sweep pick t23, seeds 1-10 | -0.00009 ± 0.00046 | 3 of 5 | +0.00082 to +0.00433 | -0.00006 ± 0.00061 |

- Default config: lr 1e-3, wd 1e-4, batch 1024, patience 5, val once an epoch. Seed
  ensemble size, folds: 1 seed +0.00116, 3 -0.00011, 5 -0.00019, 10 -0.00039
- Sweep big1b (meiolol-1c, deploy/lab-sweep.sh, data/sweeps/big1b/table.md): 32 random
  trials over lr 1e-4..3e-3, wd 1e-5..1e-1, batch 256..2048, patience 2|3|5, 5 seeds each,
  ranked on inner validation only. Every trial's single seeds are worse than ratings (-1.0
  to -3.2 milli-nats a seed); its 5-seed ensembles -0.6 to +0.2. The top 12 trials sit
  within 0.0002 of val loss, and val favours fast configs (high lr, batch 256, stopping at
  the first check) that do worse on the folds than slow ones. The pick by the rule fixed
  beforehand, t23 (lr 0.002159, wd 0.0002976, batch 256, patience 3), is level with
  ratings and +0.00031 ± 0.00038 against the default's 10 seeds (worse, not detected).
  The 8 trials of an abandoned first sweep (big1, val checks per epoch in the space) were
  left out of the pick
- More val checks an epoch didn't help: they stop at the same 1-2 epochs, and the min over
  4x as many noisy checks biases val loss low, so a sweep ranked on val would favour them
  for the wrong reason
- On dev-val, default seeds that stop after 2 epochs are ~0.003 worse than those stopping
  after 1: val (the newest tenth of fit games) and the next games disagree on how long to
  train. meiolol-fd's sweep big1c tries slower configs (lr 3e-5..3e-4, batch 1024-4096)
- Sweep big1c (meiolol-fd, data/sweeps/big1c/table.md; that table's gains are ratings
  minus net, so its signs are the reverse of these): slower training doesn't help. 24
  random trials over lr 3e-5..3e-4, wd 1e-5..1e-1, batch 1024|2048|4096, patience 2|3,
  plus the default config as a reference trial, 3 seeds each, on inner validation only.
  19 trials and the reference scored; the last 5 trials were stopped once the
  result was clear, to free the GPU for the new pin. The slow configs stop after 3-42
  epochs (no more first-check floor), but inner val is flat (0.69106-0.69117) and every
  trial is worse than ratings: single seeds +0.00093 to +0.00126 (in 0-1 of 5 folds
  better), 3-seed ensembles +0.00033 to +0.00051. The reference's 3-seed ensemble is
  -0.00012 ± 0.00040 (3 of 5 folds), the val pick t09 (lr 0.000275, wd 1.1e-05, batch
  1024, patience 3) +0.00033 ± 0.00038 (2 of 5); unpaired. What 3 seeds' average gains
  over a single seed falls with slower training: 0.56-0.59 milli-nats at lr 3e-5..6e-5,
  0.72-0.81 at lr 2.2e-4..2.8e-4, 1.06 for the reference (lr 1e-3, stops at 1 epoch).
  Slow fits make more alike predictions, so averaging helps less: ensembles need diverse
  fast fits. No trial beat the reference, so none went to a 10-seed check (meiolol-bd)
- Pretrained champion-role embeddings for the small net (meiolol-52/5b's d12, scratch vs
  init vs frozen): no form helps; numbers in that section

Reading (dev, no test look): the big net's seed ensemble is level with ratings, leaning
slightly better, at the noise floor (~0.5 milli-nats on the folds); not a usable gain.
The 20-seed pool just clears zero (upper end -0.00002), but each confirmation came in
smaller than the first ten seeds (-0.00039, then -0.00012 sealed, -0.00010 resampled),
which reads as the first ten being lucky. Tuning on inner validation finds nothing better
than the default. Every single seed is worse than ratings; only averaging seeds brings the
net level.

On win-comp (-Dcand=src/lab/cand/win-comp, folds 0.69033), t23's config, 10 seeds, pinned
9cee34a:

| run | folds vs win-comp | better in | single seeds | dev-val vs win-comp | offset weight, median of 60 fits |
| --- | --- | --- | --- | --- | --- |
| big, plain | +0.00033 ± 0.00055 | | | | |
| big as a residual on win-comp's offset (bigres) | -0.00034 ± 0.00035 | 3 of 5 | +0.00026 to +0.00286 | -0.00023 ± 0.00043 | 0.837 (0.62-1.13) |
| control: bigres, training games' champion rows shuffled (`--shuffle-ids 1`) | +0.00042 ± 0.00034 | 0 of 5 | +0.00054 to +0.00154 | +0.00052 ± 0.00061 | 0.882 (0.77-1.32) |

- bigres minus its control, paired: -0.00076 ± 0.00046 on the folds, but not a gain: the
  control is handicapped (below), so this partly measures the handicap. Against win-comp
  itself the residual is not detected (4b's floor for a net vs its candidate is ~1.3x the
  paired interval, ±0.00046 here). Audited by meiolol-4b: numbers reproduce
- A clean control needs the same stopping on both sides (both --evals 4, or one small
  fixed step budget), so the pair stays paired
- The control is worse, not ~0: early stopping checks val once an epoch, so even shuffled
  ids get a full epoch of fitting noise first (41 of its 60 fits stop at that first
  check). No sign of a leak (a leak would make the control better than win-comp). Both
  learn an offset weight under 1, the same shrink of the candidate's logit as resid's ~0.9

Reading: nothing tried here stacks on win-comp beyond noise; the big net as a residual on
it is at best ~0.3 milli-nats/game better, with every single seed worse.

#### Nets on the re-cut 2253Z: rescore and sealed check (meiolol-04 [79f90e])

snap-20261013T2253Z after meiolol-73's re-cut (one time cut over every platform, 85fd62a),
built at 0c3e486 (with 6cee99b: small and resid fits call the init-loss gate; every fit
here passed it). Folds 134,375 games (26,875 a block, fit 134k-242k), dev-val 35,834 (fit
269k); 2055Z had 44,353 and 8,500 (fit 88k). Ratings at seed 1. The game sets differ, so
compare levels across snapshots, not pairs. Runs (gpu-box ~/ml/runs/): 20261014T002905Z-
rb-ref-wr (small, resid), 003419Z-rb-big-wr (big 1-10), 003523Z-rb-big-wr-s11 (sealed),
003501Z-rb-aa-big (--resample 1-4, 3 seeds each). Win-comp runs wait for the verifier.

Ratings: folds 0.68901 (2055Z 0.69090), accuracy 53.71 ± 0.27% (52.91 ± 0.46%); dev-val
0.68780, 53.75 ± 0.52% (53.72 ± 1.06%); mean |p - 0.5| 0.037 (0.032).

| net vs ratings (milli-nats/game) | folds | better in | single seeds, mean | accuracy, folds | dev-val | accuracy, dev-val |
| --- | --- | --- | --- | --- | --- | --- |
| small, seeds 1-5 | -0.34 ± 0.14 | 5 of 5 | +0.08 | +0.04 ± 0.14 pp | -0.67 ± 0.33 | +0.20 ± 0.30 pp |
| resid, seeds 1-5 | -0.17 ± 0.08 | 4 of 5 | +0.11 | +0.09 ± 0.10 pp | +0.03 ± 0.05 | +0.05 ± 0.08 pp |
| big, seeds 1-10 | -0.39 ± 0.18 | 4 of 5 | +1.26 | +0.08 ± 0.16 pp | -1.78 ± 0.50 | +0.69 ± 0.38 pp |
| big, sealed seeds 11-20 | -0.35 ± 0.20 | 3 of 5 | +1.52 | +0.06 ± 0.16 pp | -1.48 ± 0.46 | +0.61 ± 0.36 pp |
| big, all 20 seeds | -0.48 ± 0.17 | | | | | |

- On 2055Z the small net was +0.66 ± 0.29 (0 of 5): with 1.5-3x the fit games it moves
  from clearly worse to slightly better. resid's offset weights (median 0.95, 0.68-1.01)
  say it mostly shrinks ratings' logit: recalibration, not detected
- Pre-declared rule for a big-net gain (fixed before any result): sealed 11-20 below 0 by
  more than 1.3x its half-width AND the mean over 4 resamples of ensemble minus ratings
  below 0. Sealed: -0.35 ± 0.20, past the -0.26 threshold. Resamples: +0.21, +0.12, -0.02,
  -0.26, mean +0.01 (sd 0.20). Not called by the rule, which is not the same as no gain:
  the resample leg has less power than the sealed leg (3-seed ensembles on 90% fits; on
  2055Z a 3-seed ensemble was ~0.3 milli-nats behind a 10-seed one). Audited by meiolol-53
  from preds.tsv: numbers reproduce, ratings preds identical across runs, blocks match
  nn/split.u8 by match id
- Sealed seed 17 is a bad fit: it stopped at 3 epochs on fold 1 with that block's best
  inner val (0.68960) yet scored +10.5 milli-nats there, +3.30 overall. Inner val doesn't
  reliably guard against over-training. An ensemble without it is post hoc and not quoted
- Exploratory: the gain grows block by block, in both independent seed sets and in the
  small net. Later blocks fit more games but are also newer, so this can't yet separate
  "nets gain with data" from "nets fit newer games better"; meiolol-30's 2253Z rerun
  (fractions of the fit games, fixed scored blocks) does

| block | fit games | big 1-10 | big 11-20 | small 1-5 |
| --- | --- | --- | --- | --- |
| fold 1 | 134,375 | +0.32 ± 0.40 | +0.20 ± 0.47 | -0.01 ± 0.28 |
| fold 2 | 161,250 | -0.26 ± 0.32 | +0.15 ± 0.32 | -0.35 ± 0.28 |
| fold 3 | 188,125 | -0.49 ± 0.46 | -0.55 ± 0.43 | -0.31 ± 0.33 |
| fold 4 | 215,000 | -0.56 ± 0.36 | -0.70 ± 0.50 | -0.46 ± 0.34 |
| fold 5 | 241,875 | -0.96 ± 0.45 | -0.85 ± 0.48 | -0.56 ± 0.33 |
| dev-val | 268,750 | -1.78 ± 0.50 | -1.48 ± 0.46 | -0.67 ± 0.33 |

Noise floor on 2253Z's folds (A/A, 4b's method; 20261014T003438Z-rb-aa-small: 12 resamples,
small, 3 seeds each; 003501Z-rb-aa-big: 4, big; ratings refitted on each 90%; checked by
meiolol-53), milli-nats/game on 134,375 games:
- Net minus ratings moves across resamples with sd 0.16 (small) and 0.21 (big), on top of
  per-game se 0.085 and 0.13: honest 95% half-widths ~0.35 and ~0.47, 2.1x and 1.9x the
  reported per-game intervals (2055Z: 1.6x and 1.3x). Three times the scored games shrank
  the per-game part, not the training noise, so the floor in milli-nats barely moved
- Ratings refitted on another 90%: log loss sd 0.07; paired rj - r1 from -0.21 to +0.04
- Small: all 12 resamples below ratings (-0.03 to -0.52, mean -0.27); they share scored
  games, so roughly -0.27 ± 0.19. Exploratory, not a call
- The test-look rule uses the additive form: pass when mean + 1.96 x sqrt(se_test^2 +
  0.21^2) < 0, 0.21 being big's resample sd (4 resamples, itself rough), fixed before
  the look; ~-0.52 needed on 53,750 test games

Reading (dev, no test look): with ~2x the data the nets are no longer behind ratings; the
big net's 10-seed ensemble is ahead on the folds by about the size of the noise floor, and
not called by the rule fixed beforehand. The gain growing with block is the first sign
pointing the nets' way, but it is confounded with time. A test look (seeds 21-30, rule
pre-declared with meiolol-53, no precondition on dev results) waits for the coordinator's
and Jacob's go.

#### LoLDraftAI's evaluation beside ours (meiolol-ba)

Why: LoLDraftAI reports 55-56% on a seeded random 90/10 file split, with in-game
filters, and the checkpoint picked on that same test split (research/sources/loldraftai
f19, f21, f23). Random splits inflate MOBA results (draft-predictor-methods C5), so its
number and ours don't compare. Here every model gets both: our time split and its random
split with its filters, on our games (C17). Dev only: the random split never replaces the
protocol, and never touches the test set.
- `meiolol-lab ldai-filter SNAP` (lab/randsplit.zig) writes SNAP/ldai_filter.tsv, one
  reason per game. It drops a game where any player at frame 15 has under 2400 total gold,
  over 10 deaths, under 25 CS (lane + jungle minions; supports exempt) or is under level
  4, in that order, as prepare_data.py. CS and deaths are as LoLDraftAI's
  matchProcessing.ts computes them (loldraftai f36): deaths from kill events up to that
  frame. Under 15:00 is `short`. A game of 15:00+ whose timeline doesn't reach 15:00
  can't be judged (`no_timeline`) and is dropped, as LoLDraftAI drops games missing the
  columns; that changes the population beyond its filters, so its share is reported
  by platform
- Not reproduced: its training window (52 patches, small patches merged), Clash games
  (queue 700), its elo buckets, and its checkpoint chosen on the test split (netcheck
  early-stops on the fit games' newest tenth, so our random-split number is the honest
  version of theirs)
- `netcheck --split random:SEED`: one block. Fit on the non-test games older than the
  selection cut outside the seed's random tenth; score the whole tenth, every platform,
  as LoLDraftAI (a75878b, meiolol-76's call: 3x the games; was EUW1 only, the EUW1 rows
  of the new runs equal the old runs' exactly). `--filter ldai` drops filtered games from fit and scored
  games of any block. The candidate (-Dcand: win-ratings, win-comp) and the net fit on
  the same games; preds.tsv carries match ids, so runs can be compared on common games
- Runs (gpu-box, snap-20261012T2055Z, `--net small --seeds 1,2,3` at defaults): per
  candidate, `--blocks dev` (runs *-ldai-{ratings,comp}-dev-*) and `--split random:1|2|3`
  (*-ldaiall-*, f09e507), each with and without `--filter ldai`. Table: the three random
  tenths pooled (36,909 scored rows, 33,331 games: the tenths overlap), intervals 95%
  clustered by game; the net is the 3-seed mean. Rows in docs/nn-results/ldai.tsv

Results (dev only; audited by meiolol-4b: every number reproduces from preds.tsv):

| ratings scored on | fit games | games | log loss | accuracy | AUC |
| --- | --- | --- | --- | --- | --- |
| time split, dev-val (EUW1) | 88,706 | 8,500 | 0.68969 | 53.72% | 0.550 |
| random split, EUW1 | ~110k | 10,222 | 0.69174 | 52.55% | 0.532 |
| random split, every platform | ~110k | 36,909 | 0.69025 | 53.07% | 0.543 |
| random split + filters, every platform | ~78k | 26,091 | 0.69167 | 52.51% | 0.535 |

| comparison (random split, every platform) | no filters | LoLDraftAI's filters |
| --- | --- | --- |
| small net - ratings | -0.00000 ± 0.00032 | +0.00003 ± 0.00044 |
| small net - win-comp | +0.00055 ± 0.00047 | +0.00050 ± 0.00057 |
| win-comp - ratings | -0.00055 ± 0.00037 | -0.00048 ± 0.00041 |

- The random split flatters (4b's audit, same games): on the 2,276 dev-val games that
  also fall in a random tenth (2,545 rows), ratings fit on the random split beat ratings
  fit on the time split by -0.00269 ± 0.00155 a game (accuracy +2.4 ± 1.5 points); with
  the random fit cut to the time fit's size (`--fraction 0.807`, 88.7k games, runs
  *-ldaiall-ratings-r*-size) still -0.00261 ± 0.00165. So the gain is from fitting on
  newer and same-period games, not more of them. Same direction as 1abb887's exp
  comparison (learned.md's "flatters by about half a point" stands). On the forward
  folds' games in the tenths (12,183 games, every platform) a tie: -0.00049 ± 0.00095.
  Fixed before looking: dev-val primary, upper bound < 0 reads as flatters
- Unpaired, the random tenth scores worse than dev-val (EUW1 0.69174 vs 0.68969, AUC
  0.532 vs 0.550): that gap reflects which games each scores (the tenth spreads over the
  whole dev era, dev-val is its newest EUW1 games), not the split. Every platform:
  53.07%, AUC 0.543. Nothing near LoLDraftAI's 55-56%
- The small net never beats its candidate: ties ratings on the random split, worse than
  win-comp there (+0.00055 ± 0.00047), and worse than both on dev-val (+0.00060 ±
  0.00052 vs ratings, +0.00030 ± 0.00078 vs win-comp). Single seeds: none below 0 by
  more than 0.00012
- win-comp beats ratings on the random split, every platform (-0.00055 ± 0.00037; EUW1
  alone -0.00013 ± 0.00064, a tie), consistent with the forward folds (-0.00057 ±
  0.00028) but at the ~0.0005 A/A floor ("Noise floor on the folds"), so not a separate
  confirmation; a tie on dev-val (+0.00030 ± 0.00059)
- The filters cost, not help: on the games both runs score, ratings with the filters
  are worse by +0.00064 ± 0.00041 (random) and +0.00014 ± 0.00077 (time, a tie). They
  drop 0.25% of games by LoLDraftAI's rules, and 29% for having no timeline to judge
  (11% on EUW1, 33-38% on other platforms), so fit games fall by 30% (110k to 78k) and
  the platform mix of fit and scored games shifts towards EUW1: fewer games and a
  different mix, not cleaner games
- So on our data the random split flatters by about 0.0027 a game on the same games,
  the filters don't help, and neither gets near LoLDraftAI's 55-56%. Left: its
  checkpoint picked on its test split, its larger window (52 patches), its own data
  mix; none reproduced here

#### Results dashboard (meiolol-2a)

Admin Models tab, "Neural nets" (#models/nn, src/site/static/admin-nn.js): per question a
one-line headline, a table (model, against, measured on, change in log loss ± 95%,
verdict, seeds with the single-seed range, games, source) and an interval chart; scaling
as log loss against fit games plus each model's gap at each size; the newest learned.md
"Win" lines since 2026-10-13. Verdict from the interval: better / tie (not detected) /
worse than the named model; test looks marked.
- Numbers come from docs/nn-results/<question>.tsv, not from this file: each session
  appends its rows with its write-up here (format: docs/nn-results/README.md; one file
  per question so commits by path don't sweep in others' rows). deploy/lab-push.sh sends
  them as training/nn/ with nn.txt; the page shows them on the next push (30 s)
- Seeded from f1's table and learning curve (a189f10) and win-comp's folds and test look

#### Data for nets (meiolol-ea)

- Tensor export `meiolol-lab nn-export SNAP` (563e063; layout docs/architecture.md, agreed
  with f1): SNAP/nn/, one game per index; split.u8 codes 0 dev's older half, 1-5
  win-comp's forward-chaining fold blocks, 6 dev-val, 7 other platforms in dev-val's
  period, 8 selection, 9 other platforms then, 10 test (tested against harness.visible/
  scored and the fold bounds); aux.f32 [10][22]: gold14, lanediff14, cs10, deaths15,
  first_item, then the 17 SeatStat, as multi-task targets only, with fit-only mean/sd per
  fit set and role in meta.json. snap-20261012T2055Z: 185,334 games, 173 champions, 1 s
- Guard (9b2d122): a candidate declaring `needs_stats` (win-comp) fails with
  error.NoSeatStats when its fit rows carry no seat stats, after a Mac copy of the pinned
  snapshot without seat_stats.tsv turned win-comp into plain ratings unnoticed
- More games: the box held 361,833 queue 420 games on 13 Oct vs 230,399 in the pinned
  snapshot (+57%, 108k of them older games backfilled since); ~17-20k new a day. The raw
  archive holds nothing beyond the box. Snapshot snap-20261013T1954Z (Mac data/, gpu-box
  ~/ml/snaps/): unpinned, learning curve only, different test set, no test looks. 363,120
  queue 420 games, 292,075 in rows (2,920,750 rows), seat_stats.tsv for 356,468 games
  (raw.db keeps 30 days), patches 16.19-16.20

#### Player-history nets, internal scope (meiolol-f7)

Question: does a net use player x champion interactions (experience on this champion,
form) better than win-ratings' hand-made experience terms ("Player experience and
everything pre-game" above: champ_exp + form, linear per role)? Internal scope only:
all ten players' pre-game history, never the site or app.

`meiolol-lab playernet SNAP` (src/lab/playernet.zig): per slot, the champion-role
embedding (+ role's; 8 wide, `--emb 0` drops it) beside that player's pre-game features
goes through one hidden ReLU layer (32, dropout 0.1, AdamW wd 0.1) to a number; a team's
value is its five slots' sum, logit = blue's - red's + platform intercept + a x the
-Dcand logit (antisymmetric by construction; output weights from 0, so it starts as the
candidate). Offsets, blocks, early stopping and refit as winnet's resid (cross-fitted
training offsets). Features (`--feats` groups), scaled on fit rows: champ (log1p games on
the champion, shrunk win rate log-odds, played before), any (the same on any champion,
share on this one), form (mean KDA, lane gold diff at 14, deaths before 15), rank (rank
at game start + known), mastery (log1p pre-game points + known, from SNAP/mastery_pre.tsv
when present). Writes coverage.tsv per block (test rows: features only, no outcomes).
Gradient and antisymmetry unit tests. Ratings + experience as a candidate: win-ratings
with `.champ_exp = true, .form = true`: src/lab/cand/win-exp (a copy, as a candidate
imports only std and api). Runs in data/runs/playernet-20261013.

Coverage of rows, snap-20261012T2055Z: 1+ earlier game (any champion) fit 24-36%,
scored 36-56% by block, test 73%; on this champion fit 10-15%, dev-val 26%, test 36%;
10+ on it ~1-4%. Rank at game start 0.0% (fit and scored), 0.06% of test rows; mastery
none (no mastery_pre.tsv in this snapshot). So on this snapshot the net sees experience
and form only.

Mac, 3 seeds, folds pooled (44,353 games) and dev-val (8,500); diff = log loss minus
the reference's, ± 95% paired per game; seeds: single seeds' range on the same block.
Reference pairs across two builds (ratings, ratings + experience) are joined on match
id (same fit and scored games; pair.sh in the run dir).

| model | vs | folds | seeds (folds) | dev-val |
| --- | --- | --- | --- | --- |
| hand-made experience terms (ratings + exp) | ratings | -0.00261 ± 0.00069 | | -0.00189 ± 0.00184 |
| player net on ratings | ratings | -0.00254 ± 0.00065 | -0.00237 to -0.00193 | -0.00143 ± 0.00184 |
| player net on ratings | ratings + exp | +0.00007 ± 0.00037 | | +0.00045 ± 0.00106 |
| player net on ratings + exp | ratings + exp | -0.00002 ± 0.00020 | 0 to +0.00033 | -0.00024 ± 0.00034 |
| same, no champion embedding (`--emb 0`) | ratings + exp | -0.00006 ± 0.00021 | +0.00003 to +0.00039 | -0.00024 ± 0.00043 |
| control: no player features (`--feats none`) | ratings | -0.00004 ± 0.00007 | -0.00001 to +0.00001 | +0.00015 ± 0.00018 |

Reading (dev, no test look):
- Pre-game experience is the clearest gain any model here has shown over ratings on the
  folds: -0.0026 nats/game, over 7 standard errors, from either the hand-made terms or
  the net. The net finds it by itself from raw counts and form, but no more: it ties the
  hand-made terms (+0.00007 ± 0.00037)
- On top of the hand-made terms the net adds nothing detectable: -0.00002 ± 0.00020,
  at most ~0.0002 nats/game. With or without the champion embedding alike, so champion
  x experience interactions (some champions rewarding experience more) are not found at
  this coverage; the per-champion skill slopes above said the same
- The control without player features is ratings (as f1's resid), so the gain comes
  from the player features, not the per-slot net. Early stopping at 1-3.5 epochs; the
  offset weight ~0.93 (ratings a little over-confident, as f1's)
- Limit: 16 days of history, most rows with no earlier game on the champion; rank at
  game start and mastery absent. The lever is history per player, not model shape

Rerun on snap-20261013T1954Z (unpinned, dev only, 76,041 fold games, 13,478 dev-val;
gpu-box from 22:07, Mac before; `--feats champ,any,form,rank`; mastery off, as
mastery_pre covers 0.15% of participants there). Coverage of rows: 1+ earlier game fit
34-48%, scored 52-68%, test 81%; on the champion fit 13-20%, test 43%; rank at game start
fit 0%, test 16% (rank_history from 12 Oct), so rank adds nothing to learn yet.

| model (1954Z, folds) | vs | diff | better in |
| --- | --- | --- | --- |
| hand-made experience terms (win-exp) | ratings | -0.00378 ± 0.00064 | 5 of 5 |
| player net on ratings | ratings | -0.00352 ± 0.00057 | 5 of 5 |
| player net on win-exp, seeds 1-3 | win-exp | -0.00027 ± 0.00015 | 5 of 5 |
| same, sealed seeds 4-6 | win-exp | -0.00018 ± 0.00014 | |
| same, one build with step-0 early stopping (9cee34a) | win-exp | -0.00025 ± 0.00012 | |
| same, offset weight fixed at 1 | win-exp | -0.00021 ± 0.00011 | |
| control: player features permuted within role (training sets) | win-exp | +0.00021 ± 0.00012 | |
| same control, offset fixed | win-exp | +0.00019 ± 0.00009 | |
| win-exp-first (+ played the champion before) | win-exp | -0.00012 ± 0.00017 | |

- The experience gain grows with history: -0.0026 on 2055Z (16 days), -0.0038 on 1954Z
- Beyond the hand-made terms the net shows -0.0002 to -0.0003 in every run, under the
  noise floor (~0.0005, 4b): not established. The permuted-feature control is worse, not
  better (no leak: 4b's pass rule); the learnt offset weight stays 0.90-1.00, so the gain
  isn't offset recalibration. A shuffled-label control was uninformative (the net learns
  to drop the offset: +0.0063)
- Calibration by history bucket (data/runs/playernet-20261013/calib.sh; blue minus red
  players with games on their champion): win-exp is off by +1.9 pp at <= -2 (blue wins
  44.5%), +1.0 at -1, -0.9 at >= 2, alike on both snapshots: log1p(games on the
  champion) under-reacts to who has played their champion. win-exp-first (a played
  before step, src/lab/cand/win-exp-first) narrows it to +1.25 / -0.3 pp but its log
  loss gain is not detected (2055Z -0.00019 ± 0.00016, 1954Z -0.00012 ± 0.00017)
- New inputs (abb57f3): Row.player (dense id, internal only) and history means over
  earlier games (gold, CS, damage per minute; off-role share; days since the last game),
  playernet's `prior` group (QuickSkill-style), and `duo` (cb19e68, d43fa92): teammates
  played with before on the same team and the most games with one of them (TrueSkill 2's
  premade signal; pairs from games ended before this one's start, no outcomes)
- Win-exp's gain over ratings by how many players have games on their champion (4a,
  milli-nats/game, 0 / 1-2 / 3-4 / 5+): 2055Z -0.4 / -2.1 / -4.1 / -3.7, 1954Z +0.2 /
  -3.5 / -5.1 / -5.1: nothing without history, flattening near -5 once 3+ have it
- First look (1954Z, cb19e68, seeds 1-3, not citable): prior + duo beyond the net on
  win-exp -0.00134 ± 0.00029, permuted control +0.00024 (runs 20261013T2259*-pd-*)

Prior and premade, sealed confirmation on the re-cut snap-20261013T2253Z (meiolol-51;
one global time cut, 134,375 fold games in 5 blocks of 26,875, dev-val 35,834 all
platforms; build 85fd62a, seeds 4-6, declared before any run and accepted by 33). A =
playernet on win-exp, `--feats champ,any,form,rank`; B = A + `prior,duo`. Statistic: B's
3-seed ensemble log loss minus A's per game, folds pooled, ± 95% paired by game. Pass:
full data mean + 1.6x half-width < 0, both 90% resamples (`--resample 1`, `2`, netcheck's
draws) < 0, 4+ of 5 blocks negative; void if the permuted-feature control beats its
candidate by more than 0.0005. Runs data/runs/20261014T0038*-c-* and 0039-0041*-c-*;
data/runs/playernet-20261014/confirm.sh prints every number below.

| B minus A (2253Z) | folds | blocks 1-5 | dev-val |
| --- | --- | --- | --- |
| full data | -0.00195 ± 0.00031 (1.6x: -0.00245 to -0.00145) | -0.00173 to -0.00217, 5/5 | -0.00284 ± 0.00067 |
| resample 1 | -0.00172 ± 0.00031 | -0.00143 to -0.00225, 5/5 | -0.00290 ± 0.00059 |
| resample 2 | -0.00197 ± 0.00031 | -0.00156 to -0.00234, 5/5 | -0.00306 ± 0.00074 |
| control: B's features permuted, vs win-exp | +0.00005 ± 0.00004 | | |

Passes on every leg: the first player term past the noise floor beyond the hand-made
experience terms. Candidate preds are identical across A, B, the control and the splits
within each draw; the init-loss gate is ok on every fit; offset weights 0.81-0.93 (B),
0.91-1.00 (control).

| descriptive (2253Z, folds) | vs | diff |
| --- | --- | --- |
| A + prior only | A | -0.00206 ± 0.00031 |
| A + duo (premade) only | A | -0.00007 ± 0.00012 |
| win-exp (hand-made experience terms) | ratings | -0.00507 ± 0.00055 (dev-val -0.00678 ± 0.00123) |

| B minus A by players (of ten) with any earlier game | games | diff |
| --- | --- | --- |
| 0-4 | 14,496 | -0.00130 ± 0.00066 |
| 5-7 | 52,329 | -0.00142 ± 0.00048 |
| 8-9 | 52,818 | -0.00236 ± 0.00053 |
| 10 | 14,732 | -0.00301 ± 0.00108 |

- The gain is the history means (gold, CS, damage per minute, off-role share, days since
  the last game): prior alone is as big as both; premade is not detected (duo alone
  -0.00007 ± 0.00012, so at most ~0.0001 nats/game), not shown to be zero
- "History" is what the crawl holds: having it follows crawl depth, not what a live
  lobby would know (as for the games-before terms). No leak unless coverage tracked
  outcomes, and nothing suggests that
- It grows with history, as a player effect should, and the hand-made experience terms
  keep growing with data: -0.0026 (2055Z), -0.0038 (1954Z), -0.0051 (2253Z) vs ratings
- Coverage grows with crawl depth, so later blocks have more history; per-block gains
  are flat (-0.0017 to -0.0022), so the pooled number isn't one late block
- The 1954Z first look used seeds 1-3 only; 4-6 were first run here
- Which history mean carries it (leave one out, 6769b8c `--drop`, seeds 1-3, one build;
  descriptive, no sealed rule; each minus B's own rerun, -0.00214 ± 0.00035 vs win-exp;
  folds, positive = worse without it): gold, CS and damage per minute together +0.00160
  ± 0.00030 (dev-val +0.00237): the per-minute rates are most of the gain. Alone:
  damage per minute +0.00066 ± 0.00020, gold +0.00004 ± 0.00008, CS -0.00002 ± 0.00010
  (gold and CS stand in for each other), off-role share +0.00000 ± 0.00011, days since
  the last game +0.00009 ± 0.00013 (neither detected). Damage per minute also reflects
  which champions a player plays (mages and marksmen deal more), so part of it may be
  champion pool, not skill. Runs data/runs/20261014T0132*-ab-* to 0134*-ab-*
- Data check (meiolol-53's ask; py/player/overlap.py, run 20261014T013134Z-overlap-2253Z):
  no player has two games overlapping in time (0 pairs over 1,241,856 players, 372,640
  games)
- History means as hand-made terms (meiolol-51, declared before any run and accepted by
  53; build fd39d1e): win-exp-rates = win-exp plus each player's gold, CS and damage per
  minute over earlier games, standardised by role on training rows and pulled to the
  role mean by n / (n + 3), per-role weights on blue's minus red's (k and the
  standardisation fixed before the runs). Not a fresh discovery test: the terms were
  chosen after the leave-one-out on these folds, so this is an engineering result. Pass
  (1.6x rule, both 90% resamples, 4+ of 5 blocks): win-exp-rates minus win-exp, folds
  -0.00191 ± 0.00036 (1.6x bound -0.00133), 5/5 blocks (-0.00163 to -0.00216); resamples
  -0.00177 and -0.00180 (5/5 each; spread across the three legs 0.00014); dev-val
  -0.00267 ± 0.00072. Descriptive: the hand terms recover most to all of the confirmed
  net-on-net gain (-0.00191 vs B minus A -0.00195, a point comparison with overlapping
  intervals) and ~81% of B's whole gain over
  win-exp's candidate (-0.00236); playernet B over win-exp-rates -0.00045 ± 0.00027, and
  playernet on win-exp-rates over its candidate -0.00049 ± 0.00015 (seeds 1-3), both
  under the ~0.0005 floor: a GLM with three averages per player captures most of the
  history means' gain (audited by meiolol-53). h-exp's candidate equals c-exp's per game (same win-exp, another build). Runs
  data/runs/20261014T0344*-h-exp to 0352*-h-rates-net; playernet-20261014/hand.sh
- Calibration by history bucket on 2253Z folds (calib.sh; descriptive; gap = mean blue
  chance minus blue's win rate, win rates ± ~0.6-0.7 pp): the rate terms leave it as
  win-exp had it. Champion history (blue minus red players with games on their
  champion) <= -2: +1.06 (win-exp) / +1.01 (win-exp-rates) pp, -1: +0.8, 1: -0.7, >= 2:
  +0.1; earlier games blue minus red <= -30: -1.42 / -1.39, -29..-10: +1.21 / +1.22,
  -9..9: +0.2, 10..29: +0.1, >= 30: +0.95 / +0.91. Not monotone in the games gap, so
  log1p(games) misses a shape (a lead for a declared run: a games-count spline or
  buckets per role), and the played-the-champion gap remains (win-exp-first narrowed it
  on 1954Z)
- Games-count shape (meiolol-51, declared before any run and accepted by 53, with
  dev-val as an extra judged leg since the folds had already chosen two designs; build
  6b997d2): win-exp-shape = win-exp-rates plus per-role one-hot buckets of earlier games
  (1-19, 20-59, 60-149, 150+) and games on the champion (1-2, 3-9, 10+), cut points fixed
  before the runs. FAILS: shape minus rates, folds +0.00016 ± 0.00021 (2/5 blocks
  negative), resamples +0.00006 and -0.00010, dev-val -0.00040 ± 0.00035. The buckets
  narrow calibration gaps (earlier games <= -30: -1.39 to -0.62 pp, >= 30: +0.91 to
  +0.12; champion history <= -2: +1.01 to +0.45) without a log loss gain: these
  buckets don't capture it, not "no effect". Counts are games in our crawl, so the
  thresholds encode crawl depth; live lobbies would need them redefined. Runs
  data/runs/20261014T0423*-s-rates to 0431*-s-shape-r2; playernet-20261014/shape.sh
- Tuning (pn1, meiolol-fd/37; 73be9fe, seeds 10-14, 12 random trials over lr, hidden,
  dropout, wd, emb, emb-wd, batch, patience, min-games, picked on inner val only): no
  trial beats the default (val 0.68200; best trial 0.68208; all 12 within 0.0007). The
  folds agree, context only: default -0.00182 ± 0.00037 vs win-exp (5/5, seed sd 0.00017,
  5-seed ensemble -0.00231), trials -0.00108 to -0.00165. The default stands; run dirs
  gpu-box ~/ml/runs/20261014T012811Z-pn1-j01, 012913Z-pn1-j02
- Audited by meiolol-53 (recomputed per game from the ten runs, blocks equal the nn
  split by match id, code read of abb57f3, cb19e68, d43fa92: no leak); learned.md line
  2026-10-14, internal scope (other players' history is never for the app). Folds: pick
  the winner 53.7% (ratings), 55.5% (win-exp), 55.6% (A), 56.1% (B); AUC 0.551, 0.576,
  0.578, 0.585 (53's check). Next: the prior as hand-made terms in win-exp (what an
  explainable CPU model would ship internally), which feature carries it, and averaging
  the cross-fitted training offsets over partitions (58: two valid implementations'
  training offsets correlate only 0.81-0.91 per game)

#### Pretrained champion-role embeddings (meiolol-97 [7beeb6], was meiolol-52)

`meiolol-lab pretrain SNAP` (src/lab/pretrain.zig, a88db2d; 74e059d). Per block (dev-val,
the 5 forward folds; nnexport's splits, so the same games as netcheck) and seed:
champion-role embeddings E (d 12; champion-roles under 20 fit games share their role's
vector) learnt from far richer signals than win: each seat's 22 aux targets (nn-export's
early outcomes, and SeatStats per minute; z per role over the fit games, clipped at 4),
predicted linearly from [E own; E lane opponent; mean E allies; mean E enemies] plus a
per-role won term (end-of-game stats lean to the winner; the won term keeps that out of
E). Adam, L2 on E and W, early stopping on the newest 10% of fit games, refit on all for
a tenth more epochs. Then E is tested frozen as a prior for the ratings: rating = w[role]
. P + delta, L2 on delta only, otherwise win-ratings' fit (L2 grid and epochs on the
newest 10%, P from the inner games there, refit with P from all fit games). Controls: P =
win-comp-style hand profiles (12), P = a random E (same shape: the content, not the extra
parameters). The no-prior ratings are win-ratings re-implemented: folds 0.69092 (0.69090),
dev-val 0.68978 (0.68969). Embeddings for nets: netcheck `--emb-init DIR [--emb-freeze 1]`
(d55e246), files in data/pretrain/d12 (Mac), ~/ml/pretrain/d12 (gpu-box). Audit (4b): no
leakage; the tuning pass's target scaling now uses the inner games only (74e059d).

Selection rule, fixed before the last variants landed (folds and dev-val are reported for
every variant but never used to choose): statistic = the embedding prior's ratings log
loss on the newest 10% of fit games minus the no-prior ratings' on the same games, mean
over the 6 blocks and 3 seeds. Lowest wins; within 0.00002 of the best, the smaller d,
then the default targets and won term. If no variant is below 0, "none" wins and there is
no test look. The winner is rerun on 74e059d (after the audit fix) before any test look,
and must stay below 0 there. Variants tried (all reported): d12, d12 without the won
term, d8, d16, d12 without the outcome-like targets (gold14, lanediff14, cs10, deaths15,
first_item, minutes, dmg_buildings).

Runs (snap-20261012T2055Z, 3 seeds each): d12 Mac data/pretrain/d12 and d12 no won term
Mac ~/ml/runs/20261013T211052Z-pt-nowin (both pretrain a88db2d, before the 74e059d fix);
gpu-box d8 20261013T213925Z-pt-d8, d16 20261013T215019Z-pt-d16, no outcome-like targets
20261013T215956Z-pt-noout, shuffled win labels (d12, `--shuffle 1`)
20261013T220812Z-pt-shuf (pretrain.zig as 26276f3, after the fix). Log loss minus
ratings (win-ratings re-implemented), seed-mean chance, 95% paired by game; rare = games
with a pick under 200 fit games (13,735 of 44,353 fold games, 1,850 of 8,500 dev-val);
inner val = the selection statistic.

| variant | inner val | folds | folds better in | rare, folds | dev-val |
| --- | --- | --- | --- | --- | --- |
| d8 (picked) | -0.00020 | -0.00024 ± 0.00025 | 5 of 5 | -0.00076 ± 0.00052 | +0.00004 ± 0.00040 |
| d12 no won term | -0.00019 | -0.00037 ± 0.00027 | 5 of 5 | -0.00088 ± 0.00055 | -0.00003 ± 0.00050 |
| d12 | -0.00017 | -0.00036 ± 0.00027 | 5 of 5 | -0.00079 ± 0.00056 | +0.00016 ± 0.00045 |
| d16 | -0.00015 | -0.00030 ± 0.00028 | 5 of 5 | -0.00081 ± 0.00059 | +0.00004 ± 0.00045 |
| d12 no outcome-like | -0.00015 | -0.00029 ± 0.00026 | 5 of 5 | -0.00079 ± 0.00054 | -0.00005 ± 0.00039 |
| hand profiles (control) | +0.00006 | -0.00011 ± 0.00032 | | -0.00048 ± 0.00062 | +0.00009 ± 0.00056 |
| random E, d8 (control) | +0.00004 | +0.00004 ± 0.00018 | | -0.00018 ± 0.00034 | +0.00006 ± 0.00040 |
| d12, shuffled win labels | +0.00032 | +0.00028 ± 0.00014 | 0 of 5 | +0.00011 ± 0.00026 | +0.00028 ± 0.00031 |

d8 vs random E d8, folds: -0.00028 ± 0.00027. Seeds, d8 folds: -0.00029 .. -0.00019.
Per fold, d8: -0.00015, -0.00026, -0.00011, -0.00056, -0.00014. Small net with the d12
vectors (meiolol-0a, emb 12, vs ratings, folds): scratch +0.00022 ± 0.00025, initialised
-0.00004 ± 0.00054, frozen +0.00049 ± 0.00068 (dev-val +0.00096 ± 0.00158); initialised
minus scratch -0.00026 ± 0.00057. Rows: docs/nn-results/pretrain.tsv.

Reading (dev, no test look):
- Rule: d8 wins (d12 no won term is within 0.00002, the tie goes to the smaller d). Its
  run is on post-fix code (pretrain.zig unchanged from 26276f3, which contains 74e059d)
  and inner val is below 0 there, so the rerun condition is already met. The rule chose
  the variant that is weakest on the folds, which is what fixing it in advance costs
- Every variant is better than ratings on all 5 folds, but each pooled gain is about
  the size of its CI (0.00024 to 0.00037 ± ~0.00027), and dev-val shows nothing
  (-0.00005 to +0.00016). Borderline, not detected on its own
- The gain sits in games with a rarely played pick (-0.00076 to -0.00088, 2 to 3x the
  overall), where ratings have least to go on: the prior lends a rare champion-role the
  strength of champion-roles that play like it. Same on every variant, so not tuned in
- Not from extra parameters: random E (same shape) is +0.00004, and E beats it by
  -0.00028 ± 0.00027. Hand profiles: nothing. With win labels shuffled the prior costs
  +0.00028 ± 0.00014 (worse on every fold): no spurious gain, a small overfit cost
- In nets the vectors add nothing (0a's rows): a net's own embedding already has what
  the in-game stats give, or the small net cannot use it
- Audit (4b, f5b5499): no leakage, the rule followed, all 5 variants counted. With the
  noise across 90% fit resamples (sd ~0.19 milli-nats on top of the per-game se) the
  honest 95% half-width is ~±0.00048, so d8's -0.00024 is well inside: not detected.
  The rare-pick gain is one subgroup of several looked at
- No test look (coordinator): borderline, and a test look at this size can't settle it.
  Next steps has the rerun on a bigger snapshot

#### Patch and rank context (meiolol-48)

Do champion strengths shift by patch or by lobby rank enough to predict better than one
stationary rating? `src/lab/cand/win-context` (3d11c31): win-ratings' joint ratings plus
offsets on a stationary rating (draft-predictor-methods C14): rating(c, patch) = r_c +
o[c][patch], o shrunk to 0 (to the champion-role's rating) by its own L2, a multiple of
ratings' L2 picked on the newest 10% of fit games; none when no multiple beats ratings
there (win-comp's rule). The rank version, o[c][bracket] from the lobby's median
rank_start (3+ known), is built but has nothing to fit (below). cfg.folds: win-comp's 5
forward folds, nested chain ratings, +patch, then a control: the same offsets with each
game's patch slot drawn from a hash of its start (shuffled labels; its gain must be ~0).

Runs, snap-20261012T2055Z, champ_select scope: gpu-box 20261013T214649Z-ctx-patch-ctl
(--head 3d11c31); the Mac runs before it (20261013T211837Z-ctx-patch-folds5b, dev-val
pair 20261013T205545Z-ctx-folds5 vs win-ratings 20261013T205856Z-ctx-wr-ref) gave the
same numbers. Ratings 0.69090 on the folds, as f1's and 0d's. One fit per model
(seed 1): ratings-type fits barely vary by seed.

| model | folds vs ratings (44,353 games) | folds better in | dev-val vs ratings (8,500) |
| --- | --- | --- | --- |
| +patch | -0.00014 ± 0.00020 | 2 of 5 (2 tie: no offsets chosen) | +0.00043 ± 0.00054 |
| shuffled patch (control) | -0.00008 ± 0.00012 | 1 of 5 | |

Per fold, +patch: -0.00027 ± 0.00043, -0.00064 ± 0.00072, +0.00023 ± 0.00058, 0, 0.
+patch vs the control: -0.00005 ± 0.00019. Largest offsets ~0.03 logit (under 1 pp).

Reading (dev, no test look):
- Per-patch offsets: not detected, and no better than shuffled labels. Weak test: our
  data has one patch boundary (16.19: 54,750 games, then 16.20; the 13 Oct snapshot
  adds only 16.20 games), and dev-val and folds 2-5 score 16.20 games from fits that
  hold plenty of 16.20 already. The question is really "does a new patch move
  champions": needs 16.21 in dev
- Rank brackets: no data yet. rank_start is 0 of 887,060 rows on the pinned snapshot:
  rank_history begins 12 Oct and rank_start takes a rank from a day before the game's,
  so only games from 13 Oct have one, and those are in test on every snapshot so far.
  rank_start is null below Platinum IV, so the brackets are Platinum, Emerald, Diamond,
  Master+. At a champ-select query only the user's own rank is known: predict uses it
  as the lobby's bracket
- Net embeddings of patch and rank (brief step 3): skipped, nothing to embed

#### Stacking, calibration and trees (meiolol-97 [5c523c])

`meiolol-lab stack NAME=FILE:COL... --ref A,B [--feat compcheck.tsv]... [--permute SEED]
[--shuffle-y SEED]` (src/lab/stack.zig, src/lab/gbdt.zig): per-game out-of-sample
predictions already made by netcheck, pretrain and f7's win-exp (fold 1-5 and dev-val
blocks, joined by match id, 52,853 games), combined with nothing refitted underneath.
Everything fitted here is fitted forward: fold k from folds 1..k-1, dev-val from folds
1-5 (all inside each block's fit games), so fitted rows score folds 2-5 (35,483 games)
and dev-val; fold 1 has nothing before it. Rows:
- temperature: one scale on each model's logit, no intercept
- average: the mean of the inputs' chances, nothing fitted
- stacker: logistic regression on the inputs' logits plus an intercept, L2 1e-4 x games
  (1e-2 was worse: -0.00034 vs ratings)
- trees: histogram gradient boosting (depth 3, rate 0.05, 32 quantile bins, Newton
  leaves, L2 1) on top of ratings' logit, over the inputs' logits and, with --feat,
  compcheck's six team profile features per side (magic share, frontline, CC, the
  enemy's magic share and frontline, armour lean; profiles built per fold from older
  games). Each game enters from both sides and predictions are the antisymmetric part;
  tree count by early stopping on the newest fit fold (fold 2: every fifth game of fold
  1), then a refit on all fit games
Inputs: ratings and win-comp (netcheck's cand columns, 0a's data/netcheck/f1 m-big and
w-big), big 3-seed ensemble (m-big), resid (x-resid), small (m-small), pretrained-prior
ratings (52's data/pretrain/d12 `emb`, seed mean), win-exp (f7's r-exp games-cand.tsv:
ratings plus champion experience and form, internal scope). Runs: data/runs/
20261013T21*-stk-* and 20261013T220*-stk-gb*. Dev only, no test look.

Log loss difference per game, 95% paired by game, folds 2-5 | dev-val; "k of 4": folds
better than the reference.

| model | vs ratings | vs win-comp | vs win-exp |
| --- | --- | --- | --- |
| ratings, temperature | -0.00002 ± 0.00014 \| +0.00006 ± 0.00037 (2 of 4) | | |
| win-comp, temperature | | +0.00005 ± 0.00014 \| -0.00009 ± 0.00034 | |
| average of 6 (no win-exp) | -0.00040 ± 0.00013 \| -0.00006 ± 0.00020 (4 of 4) | +0.00006 ± 0.00027 \| -0.00036 ± 0.00052 | |
| average of ratings, win-comp, big, prior | -0.00061 ± 0.00019 \| -0.00016 ± 0.00025 | -0.00015 ± 0.00027 \| -0.00046 ± 0.00048 | |
| stacker, 6 inputs (no win-exp) | -0.00079 ± 0.00047 \| +0.00009 ± 0.00070 (4 of 4) | -0.00034 ± 0.00035 \| -0.00021 ± 0.00044 (4 of 4) | |
| same, nets' single seeds 1/2/3 instead of the ensemble | -0.00052 / -0.00061 / -0.00082 | -0.00006 / -0.00016 / -0.00036 | |
| control: inputs but ratings shuffled within blocks (2 seeds) | +0.00005 ± 0.00022, +0.00010 ± 0.00024 | | |
| stacker, 7 inputs (with win-exp) | -0.00348 ± 0.00084 \| -0.00194 ± 0.00180 | -0.00302 ± 0.00078 \| -0.00224 ± 0.00174 | -0.00049 ± 0.00046 \| -0.00005 ± 0.00067 (4 of 4) |
| trees on the 7 logits | -0.00216 ± 0.00059 \| -0.00176 ± 0.00184 | | +0.00082 ± 0.00055 \| +0.00013 ± 0.00103 (1 of 4) |
| trees on the logits and team profiles | -0.00253 ± 0.00064 \| -0.00149 ± 0.00178 | | +0.00045 ± 0.00064 \| +0.00040 ± 0.00120 (1 of 4) |
| control: outcomes shuffled within blocks for every fitted row (2 seeds) | stacker +0.0026, +0.0018; trees +0.0013, +0.0010 | | |

For reference on the same games (folds 2-5 | dev-val vs ratings): win-comp -0.00046 |
+0.00030, big -0.00034 | -0.00035, prior -0.00040 | +0.00022, win-exp -0.00298 |
-0.00189.

Fitted temperatures (scale on the logit, fold 2..5 and dev): ratings 1.02, 0.79, 0.74,
0.82, 0.80; win-comp 0.83-1.08; win-exp 0.80-0.91; prior 0.76-0.85; big 0.87-0.99 (its
ensemble is calibrated; single big seeds 0.65-1.15); small 0.59-0.69. Calibration by
predicted chance (folds 2-5 and dev-val): ratings' top bin (60%+, 1,138 games) predicted
62.3%, observed 57.5 ± 2.9%; temperature moves it to 61.4%.

Reading (dev, no test look):
- Temperature scaling buys nothing measurable: ratings -0.00002 ± 0.00014 on the folds,
  though its fitted scale is ~0.8 every fold (it is overconfident, as the test look
  said). Most games sit near 50%, where a scale changes little; it matters for the
  extreme picks shown, not the headline. Same for win-comp, prior, win-exp
- Diverse weak draft models add up a little against ratings (average -0.0004, 4 of 4
  folds; stacker -0.0008), but against win-comp nothing is detected (stacker -0.00034 ±
  0.00035, dev-val -0.00021 ± 0.00044): what the stack finds over ratings is mostly
  win-comp's mix term plus the pretrained prior. Its weights put about -0.5 on ratings
  and +0.9 on win-comp, i.e. it scales the mix term up, plus ~0.5 on big and ~0.4 on
  prior
- With f7's win-exp the stack is -0.00049 ± 0.00046 vs win-exp on the folds (4 of 4) and
  -0.00005 ± 0.00067 on dev-val: at the noise floor, not detected on dev-val. If real,
  draft-only nets add ~0.0005 on top of player experience
- Trees lose to the logistic stacker on the same inputs (vs win-exp +0.0008 logits only,
  +0.0005 with team profiles, both worse than win-exp itself); team profiles help the
  trees a little (-0.0004 between the two tree rows) but no tree row beats win-exp. At
  ~35k fit games a depth-3 booster over a handful of dense logits is not a better
  combiner than a linear one
- Controls: shuffling every input but ratings gives ~0 (+0.00005, +0.00010), so the
  forward fit does not leak. Shuffled outcomes make every fitted row worse than ratings
  (it learns to pull ratings towards 50%), never better, as it must
- Next: rerun on 0a's sweep ensemble and f7's ~350k-game win-exp when they land; a test
  look only for the 7-input stacker vs win-exp, if the coordinator wants one
- Verifier (meiolol-4b, 2026-10-13): no leakage; forward fitting confirmed, every input
  an audited per-block out-of-sample prediction. The stacker's L2 (1e-4 over 1e-2) and
  the 4-input subset were picked on the scored folds, so the stacker's -0.00079 is
  optimistic. The honest number is the unfitted 4-input average, replicated
  independently: -0.00061 ± 0.00019 on folds 2-5 (35,483 games), past the A/A floor
  (~0.5 milli-nats, "Noise floor on the folds"). The leak control is inputs permuted
  within block with real outcomes (~0); the outcome-shuffled rows are worse by design and
  can't show a leak. stack.zig and gbdt.zig were uncommitted at audit: cite a hash

#### Interactions on pretrained embeddings (meiolol-ab)

Pair terms failed because pair cells are sparse. Instead: a d x d form over each
champion-role's frozen pretrained embedding E (d12: dim 12, meiolol-52's pretrain at
a88db2d, one E per block and seed, learnt on that block's fit games only), on top of
win-comp (ratings + damage mix), cand/win-embx (deecc3f, 815e201):
- lane: same-role opponents e_b' A e_r (A antisymmetric, 66) + bot-sup duo e' S e (S
  symmetric, 78); all: every blue x red pair (A, 66) + every teammate pair (S, 78);
  cross, within: one of all's halves; both: lane + all; shuffled: all on E permuted
  within role (control: content, not extra weights)
- Features standardised; mix's L2 as win-comp, then the E weights' L2 on the newest 10%
  of fit games (grid 1e-3..1; none if no L2 beats ratings + mix there). Seeds 1-3 pair
  with E seeds 1-3, predictions averaged per game
- E reaches the candidate through the harness (`meiolol-lab --emb DIR`, api
  Options.embeddings, lab/embfiles.zig): only the file whose fit games equal the fit
  set's per champion-role (and per role for the shared vector) is accepted, so E never
  saw a scored game (test: a file from other games fails). E did see the inner val
  games' stats, so L2 choice is optimistic (inner val gains of -0.001 vs mix didn't hold
  on folds); fold and dev-val scores are clean

Results (snap-20261012T2055Z; folds: the 5 forward folds pooled, 44,353 games, one
build, 20261013T215827Z-embx-all; per-block pairs and dev-val from netcheck's per-game
files, nc-win-embx, nc-win-comp, nc-win-ratings at 815e201 and nc2-*, nc-win-embx-shuf
at ec9224a/0c75817, `meiolol-lab compare`):

| model | vs win-comp, folds | vs ratings, folds | single seeds vs ratings |
| --- | --- | --- | --- |
| all | -0.00034 ± 0.00021 | -0.00092 ± 0.00035 | -0.00068 .. -0.00041 |
| within | -0.00020 ± 0.00018 | -0.00078 ± 0.00033 | -0.00067 .. -0.00047 |
| cross | -0.00005 ± 0.00014 | -0.00063 ± 0.00031 | -0.00052 .. -0.00035 |
| both | -0.00006 ± 0.00026 | -0.00063 ± 0.00039 | -0.00019 .. -0.00007 |
| lane | +0.00026 ± 0.00022 | -0.00031 ± 0.00036 | -0.00010 .. +0.00005 |
| shuffled E | +0.00012 ± 0.00015 | -0.00046 ± 0.00033 | -0.00044 .. +0.00011 |
| win-comp (mix) | - | -0.00058 ± 0.00029 | -0.00059 .. -0.00057 |

- all vs win-comp, per block (netcheck): negative in 5 of 5 folds (one detected),
  dev-val a tie (+0.00007 ± 0.00035, 8,500 games). Folds only (44,353 games, netcheck's
  win-comp, 4b): -0.00037 ± 0.00023; folds + dev-val -0.00030 ± 0.00020. all vs the
  shuffled-E control: folds only -0.00046 ± 0.00025 (folds + dev -0.00041 ± 0.00022),
  negative in all 6 blocks; shuffled vs win-comp a tie (folds only +0.00009 ± 0.00017).
  Two builds reproduced all's per-game file exactly
- Verifier (meiolol-4b, 2026-10-13): no leak sign. Per-block E fitted on that block's fit
  games only, scored games never in E's fit; training games' features use E learnt on
  them (no leave-one-out), a bias towards overfitting, not a fake scored gain, and the
  shuffled-E control shows none. d12 predates 74e059d's target-z fix (scaling only). By
  gains split: lopsided -0.71 ± 0.62, EUW -0.56 ± 0.48, rest -0.31 ± 0.26. At the floor
  (needs 1.6x widening, ±0.37)
- Pass rule, declared before the sealed seeds land: win-embx all with E seeds 4-6
  (seed_offset 3, pt-d12-s456) on the 5 folds only, vs win-comp from the same build:
  mean below 0 by more than 1.6x its paired half-width, and vs the shuffled-E control
  with seeds 4-6 below 0. No --resample run: a 90% fit set has no E learnt on exactly it,
  and embfiles refuses any other (pretrain on the resampled sets would be needed). 4b's
  caveat: seeds don't cover the main noise source (which games are fitted), so a pass
  would be "sealed seeds confirm", not "survives resampling"
- Sealed result (E seeds 4-6 from pretrain at 99bc305, 20261013T230928Z-pt-d12-s456;
  a88db2d no longer builds under lab-run, the only difference is 74e059d's target-z
  scaling): nc-sealed-all (99bc305), nc-sealed-shuf (e771256), nc-sealed-comp
  (99bc305), embx-sealed-cmp. Folds only: all vs win-comp -0.00037 ± 0.00024 (negative
  in 5 of 5 folds, 2 detected; dev-val -0.00005 ± 0.00044); vs shuffled -0.00052 ±
  0.00025; shuffled vs win-comp +0.00015 ± 0.00019. The size repeats exactly, but
  1.6 x 0.00024 = 0.00038 > 0.00037: the declared rule is not passed (by 0.00001).
  Reading: a consistent -0.4 milli-nats/game from all-pairs forms on pretrained E, real
  content (beats shuffled twice), not confirmed at the floor. Next: the new pin
  (snap-20261013T2253Z, about twice the games) with E per block and a pretrain
  --resample leg
- The gain is the seed average: single seeds tie with win-comp (about -0.0001 to
  +0.0002), mix gains nothing from averaging, all and shuffled gain ~0.0003-0.0004
  each from it. So the E content matters (all beats shuffled by the same averaging), but
  any one fitted form is noisy
- Lane-only forms lose (+0.00026): 144 weights on one lane pair each overfit; all-pairs
  sums average over 25 pairs. Within-team carries most of all's gain, as the set net
  found (meiolol-35)
- Reading: a small gain for all-pairs forms on E, -0.3 milli-nats/game vs win-comp,
  under the ±0.5 A/A floor (4b, "Noise floor on the folds"), dev-val a tie. Not
  confirmed: sealed E seeds 4-6 (pt-d12-s456 at a88db2d) are the confirmation, then the
  new snapshot (pairs gain most from more games). Nothing for learned.md before 4b's
  audit
- New pin (snap-20261013T2253Z after meiolol-73's seat_stats repack; meiolol-64),
  declared before any run: E from pretrain (daa56a0 or later) per block (dev, 1-5) on
  the repacked, re-cut snapshot. Development: win-embx all, E seeds 1-3, on meiolol-04's
  post-repack commit (pairs with its win-comp preds), plus shuffled E seeds 1-3;
  reported, not the decision.
  Pass needs all three on the 5 folds only, paired per game vs win-comp from the same
  build: (1) sealed E seeds 4-6 (seed_offset 3), mean below 0 by more than 1.6x its
  95% half-width; (2) sealed shuffled E seeds 4-6, all vs it below 0; (3) resample leg:
  pretrain --resample 1 (E on netcheck --resample 1's 90% fit sets, seeds 1-3), then
  netcheck --resample 1 for win-embx all and win-comp, mean below 0. Fold sign count
  beside each. Pass = detected, read as "sealed seeds and one resample draw agree" (one
  draw, not a resample spread); anything else = not detected, and the line closes
- New-pin result (snap-20261013T2253Z re-cut, 134,375 fold games, gate passed and audited
  by meiolol-53, who ran the legs from the per-game files; embx-2253-cmp reproduces them):
  detected by the pre-declared rule, at its margin. Runs on gpu-box: pretrain at 44ca8ee
  (20261014T004122Z-pt-2253-s123, 004141Z-pt-2253-s456, 004200Z-pt-2253-rs1); win-comp
  nc-2253-comp (= nc-2253-sealed-comp = rb-ref-wc, identical files); win-embx nc-2253-all,
  -shuf (ba9a21a), -sealed-all (e108ca6), -sealed-shuf (9f2b179), -all-rs1. Folds only:

  | leg | diff | folds negative |
  | --- | --- | --- |
  | (a) sealed E 4-6 vs win-comp | -0.00026 ± 0.00014 | 5 of 5 |
  | (b) sealed vs sealed shuffled E | -0.00032 ± 0.00014 | 5 of 5 |
  | (c) resample leg vs win-comp on the same 90% | -0.00052 ± 0.00018 | 5 of 5 |
  | development: E 1-3 vs win-comp | -0.00040 ± 0.00015 | 5 of 5 |
  | shuffled E vs win-comp (E 1-3; sealed) | -0.00000 ± 0.00007; +0.00006 ± 0.00009 | |
  | sealed vs ratings (win-comp vs ratings -0.00048 ± 0.00016) | -0.00074 ± 0.00021 | |

  (a) clears 1.6x by 0.04 milli-nats (mean + 1.6 x 0.00014 = -0.00004). The 1.6x came from
  2055Z's small-net A/A; on 2253Z meiolol-04 measured 2.1x for small nets, and at 2.1x
  (a) would miss (+0.00003). That doesn't change the declared rule's reading, but the
  pass is at its edge. Dev-val is not judged and covers 0 (sealed -0.00020 ± 0.00021).
  Reading: real but tiny, ~0.3 milli-nats/game beyond win-comp (sealed), under the nets'
  A/A floor on this pin (~0.35); the content is in E (shuffled E ties). No prediction
  gain claimed for the site. Consistent with 2055Z's sealed -0.00037 ± 0.00024 (same
  sign, which missed there), now confirmed with ~2x the fit games; it did not grow

#### Set net: DeepSets on champion profiles (meiolol-35 [397394], was meiolol-0d)

Question: does a net over each team's champion profiles find more than win-comp's one
damage-mix term? `meiolol-lab netcheck SNAP --net set` (src/lab/setnet.zig, 0696aad;
controls d8f1ebf), built with -Dcand=win-ratings or win-comp, on netcheck's blocks.
- Slot input: win-comp's 12 profile z-scores (won and lost halves shrunk to the role
  mean by 20 pseudo-rows, z within role, unknown champion-role 0) ++ role one-hot ++
  optional champion-role embedding (`--ids 1`). Profiles from the fit games' Row.stats
  only (inner games while tuning); fit games see their own slots leave-one-out, val and
  scored games the full profiles
- phi: u = ReLU(W1 x + b1), 16 units; team vector t = mean of its 5 u; rho: f = w .
  ReLU(V [t_own; t_other] + c), 16 units (`--cross 0`: t_own only); logit = (f(blue,
  red) - f(red, blue)) / 2 + c[platform] + a x candidate logit, the offset cross-fitted
  on training games as resid. w starts at 0, so the net starts as the candidate; early
  stopping also scores that start (0 epochs: the candidate alone). Dropout 0.2 on rho,
  AdamW lr 1e-3 wd 0.1, batch 512
- Controls: `--control permute` (each champion-role reads another of its role's
  profiles: no content), `--control shuffle` (fit games' results shuffled for profiles
  and labels, with `--fix-offset 1`: must not gain)

gpu-box, snap-20261012T2055Z, 3 seeds (1-3), seed-mean net, paired per game vs the
candidate from the same build. Folds: 44,353 games pooled; dev-val 8,500. Milli-nats per
game, negative is better; "k/5" = folds where the net is better.

| run | vs | folds | k/5 | single seeds | dev-val |
| --- | --- | --- | --- | --- | --- |
| set net | ratings | -0.42 ± 0.23 | 3 | -0.53 to -0.22 | -0.06 ± 0.74 |
| offset weight fixed at 1 | ratings | -0.24 ± 0.15 | 4 | -0.28 to -0.10 | +0.04 ± 0.07 |
| within-team only (`--cross 0`) | ratings | -0.49 ± 0.23 | 4 | -0.51 to -0.28 | -0.03 ± 0.53 |
| + champion-role embedding 8 | ratings | -0.31 ± 0.16 | 5 | -0.34 to -0.01 | -0.22 ± 0.32 |
| control: profiles permuted | ratings | -0.03 ± 0.05 | 3 | -0.06 to -0.01 | +0.01 ± 0.19 |
| control: results shuffled | ratings | +0.16 ± 0.23 | 2 | +0.18 to +0.77 | +1.49 ± 0.96 |
| set net on win-comp's offset | win-comp | -0.20 ± 0.17 | 4 | -0.19 to -0.11 | -0.03 ± 0.20 |

Runs 20261013T214152Z-set-wr, -set-wr-fix, -set-wr-nocross, -set-wr-ids,
-set-wr-permute, -set-wr-shuffle, 20261013T220534Z-set-wc. 4b's gains on set-wr
(audit: no leak; ratings equal f1's): lopsided-team games -1.20 ± 0.56 (8,727 games,
about half the gain), balanced -0.23 ± 0.25; vs win-comp +0.15 ± 0.33 (lopsided +0.91 ±
1.10): on ratings the set net is not better than win-comp and catches less of the
lopsided effect. Within-team only: lopsided -1.37 ± 0.59.

Sealed confirmation (declared to 4b before any run; pass rule amended with 4b before any
result): A = within-team on ratings, B = set net on win-comp; seeds 4-6 on all fit
games, and again on netcheck `--resample 1` and `2` (90% of fit games, the same draws as
4b's A/A runs). Pass: the full-data pooled seed mean stays below 0 with 1.6x its paired
95% half-width (the floor-widened interval, "Noise floor on the folds"), and both
resamples' means are negative.

| config | full data (k/5) | 1.6x interval | resample 1 | resample 2 | dev-val | verdict |
| --- | --- | --- | --- | --- | --- | --- |
| A: within-team, on ratings | -0.37 ± 0.21 (4) | -0.71 to -0.03 | -0.13 ± 0.14 | -0.16 ± 0.16 | -0.18 ± 0.45 | confirmed, barely |
| B: set net, on win-comp | -0.25 ± 0.17 (4) | -0.52 to +0.02 | -0.20 ± 0.15 | -0.17 ± 0.15 | -0.07 ± 0.31 | not confirmed |

Runs 20261013T223405Z-conf-a, 223644Z-conf-b, 224930Z-conf-a-r1, 225421Z-conf-a-r2,
225244Z-conf-b-r1, 225808Z-conf-b-r2 (the net and controls unchanged since d8f1ebf).
Audit (meiolol-33, recomputed from the games files): A confirmed, barely (mean + 1.6x
half-width -0.036); B not confirmed whatever its resamples say. Binaries: conf-a and
conf-b built before the broken build-lock window (22:48-23:05Z), all four resample runs
byte-equal to meiolol-a0's clean rebuilds; conf-a's ratings and conf-b's
win-comp preds byte-equal to the reference files. Caveats: the resample means are 35-45%
of the full-data one, so the honest size is ~0.15-0.4 milli-nats, not 0.37; block 5
carries most of it (-1.01, -0.75, -0.87 across the three runs), block 3 nothing; it sits
on lopsided games (-1.11 ± 0.53 vs balanced -0.19 ± 0.23). win-comp vs A's net on the
same folds: -0.20 ± 0.31, a tie (win-comp vs ratings -0.57 ± 0.28).

Reading (dev, no test look):
- The set net's gain is profile content: permuting profiles among champion-roles takes
  it to ~0, and shuffled results give no fake gain. About half the default gain was
  recalibration (offset weight learnt at 0.65-0.8; fixed at 1: -0.24)
- Within-team only is as good as with cross-team terms: the enemy's profile adds
  nothing, as in win-comp's ablation. Champion-role embeddings beside the profiles add
  nothing either
- The gain sits on lopsided-damage teams, the same effect as win-comp's mix term; on
  ratings the net does not beat that one hand-made term (+0.15 ± 0.33 vs win-comp)
- Within-team on ratings passes its sealed confirmation by the narrowest margin (audit
  meiolol-33): a real but small comp effect, ~0.15-0.4 milli-nats/game on folds, nothing
  on dev-val, about two-thirds of win-comp's gain from the same lopsided-damage games.
  On top of win-comp it is not confirmed (all point estimates negative, -0.17 to -0.25,
  the bound reaching +0.02). Not worth exporting; the 2253Z pin (about twice the games)
  is where to look again (rerun list item e). learned.md Win line 2026-10-14

#### Scaling curves: what more games buy, and does a net pass ratings? (meiolol-30)

Question: how much better does the draft predictor get with more games, and at what
fit-game count, if any, would a net pass ratings? Method: netcheck at nested shares of
each block's fit games (10, 25, 50, 100%, harness.inFraction), scored games unchanged, on
the pinned snap-20261012T2055Z (folds fit 44-80k games at 100%, 8.9k scored a fold) and
the unpinned snap-20261013T1954Z (folds fit 76-137k, 15.2k scored a fold; its test set
differs, no test looks). Candidate and net fitted on the same games from one build; nets
at netcheck defaults, a 3-seed ensemble (mean of probabilities; single seeds 0.1-2 mnats
worse). 2055Z 25-100% are f1's runs (data/netcheck/f1; big there is f1's training before
9ace58d), the rest gpu-box runs curve-*, curve350-* (big on the newer training: one
procedure only within 1954Z); fits curve-fit-two, -two-lower, -two-upper (`meiolol-lab
curve`, src/lab/curve.zig, 48a6b33). Old split (before 85fd62a); a 2253Z version on the
pre-re-cut split is withdrawn and gets rerun on the re-cut.

Folds pooled, by mean fit games over the 5 folds. Accuracy is the share called right
(± 95%); the net columns are vs ratings: log loss in milli-nats (negative: better), paired
per game, ± 95%:

| fit games | ratings accuracy | ratings log loss | small | big | resid | win-comp |
| --- | --- | --- | --- | --- | --- | --- |
| 6.1k (2055Z) | 51.09% ± 0.47 | 0.69376 | +0.83 ± 0.35 | -0.75 ± 0.39 | +0.60 ± 0.18 | -0.40 ± 0.24 |
| 10.5k (1954Z) | 51.45% ± 0.36 | 0.69261 | -0.15 ± 0.21 | -0.37 ± 0.25 | +0.43 ± 0.16 | -0.22 ± 0.20 |
| 15.4k (2055Z) | 51.72% ± 0.47 | 0.69203 | +0.28 ± 0.24 | -0.04 ± 0.28 | -0.04 ± 0.10 | -0.53 ± 0.29 |
| 26.3k (1954Z) | 52.41% ± 0.35 | 0.69142 | +0.02 ± 0.24 | +0.25 ± 0.32 | -0.00 ± 0.03 | -0.22 ± 0.15 |
| 30.9k (2055Z) | 52.15% ± 0.46 | 0.69134 | +0.43 ± 0.31 | +0.13 ± 0.29 | -0.05 ± 0.08 | -0.55 ± 0.34 |
| 53.1k (1954Z) | 53.05% ± 0.35 | 0.69030 | +0.26 ± 0.26 | +0.98 ± 0.45 | -0.03 ± 0.10 | -0.24 ± 0.12 |
| 62.1k (2055Z) | 52.91% ± 0.46 | 0.69090 | +0.66 ± 0.29 | -0.28 ± 0.39 | -0.05 ± 0.07 | -0.57 ± 0.28 |
| 106.5k (1954Z) | 53.35% ± 0.35 | 0.68962 | -0.04 ± 0.22 | +0.53 ± 0.39 | -0.12 ± 0.11 | -0.32 ± 0.17 |

Better than ratings in k of 5 folds at the largest size: 2055Z small 0, big 4, resid 4,
win-comp 5; 1954Z small 3, big 1, resid 4, win-comp 5 (win-comp 5 of 5 at 50-100% on both;
4 of 5 at 2055Z 10%, 3 of 5 at 1954Z 10% and 25%). Accuracy vs ratings is within ±0.6
pp for every net and size, mostly inside its interval. Rows of different snapshots score
different games, so compare within a snapshot.

Per doubling of fit games, fitted with an offset per block (± 95% from the points' scatter
about the fit, which holds seed noise and which fit games a share kept; the game bootstrap
alone is ~2x narrower). The ± treats the 12 blocks as independent, but 57% of 2055Z's
scored games are scored again in 1954Z and most fit games overlap, and it uses 1.96 where
the range splits below have ~5 dof (t 2.57): read every ± here as ~30% too narrow:

| model | accuracy, pp | log loss, mnats | gap to ratings, mnats |
| --- | --- | --- | --- |
| ratings | +0.58 ± 0.08 | -0.90 ± 0.15 | |
| small | +0.53 ± 0.09 | -0.87 ± 0.21 | +0.03 ± 0.10 |
| big | +0.42 ± 0.09 | -0.66 ± 0.15 | +0.24 ± 0.13 |
| resid | +0.58 ± 0.09 | -1.04 ± 0.23 | -0.14 ± 0.10 |
| win-comp | +0.54 ± 0.07 | -0.94 ± 0.15 | -0.04 ± 0.02 |

Flattening check (range splits at 40k fit games per block, not confidence bounds), ratings:
up to 40k fit games +0.53 ± 0.20 pp and -0.97 ± 0.33 mnats a
doubling; from 40k up +0.29 ± 0.20 pp and -0.78 ± 0.40 mnats. The last doubling on 1954Z
gave +0.30 pp against +0.6 to +1.0 for the earlier ones. Smaller gains at the top: not
established (accuracy difference 0.24 ± 0.28 pp).

Reading (dev, no test look):
- More games help ratings steadily: about +0.6 pp of accuracy and -0.9 mnats of log loss
  per doubling over 4k-152k fit games per block (pooled means 6k-106k; 51.1% at 6k, 53.4%
  at 106k on the folds)
- Projection from today's ~106k (1954Z folds), ratings: log-linear 2x +0.6 pp, 4x +1.2 pp
  (-0.9 / -1.8 mnats); with the upper range's slope (+0.29 ± 0.26 pp), 4x +0.1 to +1.1 pp.
  4x is ~425k fit games, ~3x past the largest block: extrapolated beyond the data, about
  +0.1 to +1.2 pp. Observed growth is ~60k fit games a day (2055Z to 1954Z; ~130k
  matches/day in docs/plan.md is the free key's all-region ceiling, not observed), and
  more crawling adds newer games, which these curves don't measure (patch drift: each
  curve's games share a window). Separate
  a*N^-b + c fits per model don't pin b and c down at these sizes (b runs to the grid's
  floor, so c, the ceiling, is meaningless); the per-doubling trend is the usable summary
- Nets don't close on ratings over 4k-152k fit games. Gaps per doubling, full range: small
  +0.03 ± 0.10 mnats, big +0.24 ± 0.13 (set by the smallest shares), resid -0.14 ± 0.10,
  win-comp -0.04 ± 0.02. Above 40k every net's gap slope points toward ratings (small
  -0.19 ± 0.39, big -0.47 ± 0.46, resid -0.07 ± 0.16), none established. resid's slope
  comes from its weak start (+0.4 to +0.6 mnats worse at 6-10k, when the offsets are
  poor), not from gaining at the top: in the upper range -0.07 ± 0.16. win-comp's
  damage-mix term is worth a steady 0.2-0.6 mnats at every size (5 of 5 folds at 50-100%)
- The big net: ahead of ratings at 6k (-0.75 mnats, when ratings has few games per
  champion-role) and behind at 106k (+0.53, 1 of 5 folds); its gap swings ±0.5 mnats
  between neighbouring sizes with 3 seeds, and above 40k it gains (-0.47 ± 0.46 mnats a
  doubling): its trend is not established. Config check at 1954Z 106k (curve350-bigcfg):
  val 4x an epoch with patience 10 +0.29, the same with lr 3e-4 +0.28, against the
  default's +0.53, each better in 1 of 5 folds. Tuning recovers ~0.2 mnats but not the
  gap. Open question: whether a big net tuned per size, with 0a's 10-seed ensembles (2055Z
  100%: -0.39 ± 0.33 vs the same run's 3 seeds' -0.11), keeps level with ratings as games
  grow
- Audit (meiolol-33): cleared with these wording changes. The 2253Z rerun below is on the
  re-cut with one training procedure; the withdrawn pre-re-cut 2253Z runs scored 0 of
  their 54,518 games in the new test (match ids vs split.tsv; fit games are older), so
  they exposed nothing

2253Z on the re-cut protocol (85fd62a; snap-20261013T2253Z repacked, one training procedure
for every net; folds 5 x 26,875 scored games, dev-val 35,834; runs curvercut-*, fits
curve-fit-rcut and -rcut-upper; win-comp held until its reference is checked). Mnats vs
ratings, ± 95% paired per game, better in k of 5 folds:

| fit games (folds mean / dev-val) | ratings accuracy (folds) | ratings log loss | small, folds | big, folds | resid, folds | small, dev-val | big, dev-val |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 18.6k / 27k | 52.09% ± 0.27 | 0.69257 | +0.46 ± 0.18 (1) | -0.47 ± 0.24 (4) | +0.40 ± 0.10 | -0.27 ± 0.25 | +0.64 ± 0.30 |
| 46.6k / 67k | 52.95% ± 0.27 | 0.69090 | +0.24 ± 0.18 (1) | +0.31 ± 0.25 (1) | -0.06 ± 0.05 | -0.44 ± 0.42 | -0.06 ± 0.40 |
| 94.0k / 134k | 53.30% ± 0.27 | 0.69005 | -0.18 ± 0.15 (4) | +0.05 ± 0.24 (2) | -0.30 ± 0.11 | -0.62 ± 0.32 | -0.34 ± 0.41 |
| 188k / 269k | 53.71% ± 0.27 | 0.68901 | -0.22 ± 0.16 (4) | +0.24 ± 0.25 (2) | -0.09 ± 0.09 | -0.73 ± 0.41 | -0.77 ± 0.52 |

- Ratings: +0.46 ± 0.07 pp accuracy and -1.05 ± 0.12 mnats a doubling (above 40k +0.38 ±
  0.10 pp, -1.01 ± 0.14 mnats)
- Gap to ratings per doubling (points' scatter): small -0.21 ± 0.07 (above 40k -0.19 ±
  0.16), big +0.06 ± 0.21 (above 40k -0.12 ± 0.31), resid -0.12 ± 0.10. On these fixed
  fold blocks the big net's gap does not grow with fit games; the small net's does, and it
  is ahead of ratings from ~90k fit games (4 of 5 folds at 94k and 188k). Accuracy vs
  ratings within ±0.4 pp for every net and size
- Dev-val (one block of the newest dev games) has the big net pulling ahead with size
  (+0.64 to -0.77): with one block, newer games and more data can't be told apart, and the
  folds don't show it. meiolol-04's big net (fit 134k +0.3, 242k -0.9, dev-val -1.6) moves
  scored games and fit size together; this curve holds the scored games fixed

### Effects and the CPU model, 2026-10-14 (meiolol-08)

Jacob (13 Oct): train heavy on the gpu-box, ship models that run on CPU and say what a
synergy, a counter, a comp or an objective is worth. Dev only, snap-20261012T2055Z, no test
look. Unit: win percentage points at 50% (logit x 25); gold for gold at 14.

#### One shrunk additive draft model

`meiolol-lab effects SNAP` (src/lab/effects.zig on src/src/additive.zig). Blue's logit =
platform side + champion strength per role (blue minus red) + 10 ally role-pair blocks
(one cell per champion pair) + 25 enemy role-pair blocks (my role r x their role q) +
win-comp's damage mix (blue minus red (f - 0.5)^2, profiles from the fit games, own rows
left out). Every champion-role and pair block is a random effect with its own variance,
estimated on the fit games (MacKay's fixed point with the diagonal posterior), all fitted
jointly by block Newton steps; ~80 table lookups per draft, CPU only. Same blocks and
games as netcheck (dev-val, win-comp's 5 forward folds), paired per game with win-ratings
fitted on the same games. Planted tests: a block's sd recovered within ~0.05 logit,
empty blocks shrink to ~0.

Run 20261013T225421Z-eff-d (4ace29b; built during the lab-run lock bug window, cleared by
meiolol-a0: its stripped binary equals a clean rebuild). Folds pooled, 44,353 games, log loss vs ratings, ± 95% paired
per game, folds better of 5:

| model | vs ratings | vs champion strength only |
| --- | --- | --- |
| champion strength only | -0.00006 ± 0.00034 | - |
| + damage mix | -0.00097 ± 0.00050 | -0.00091 ± 0.00037, 5 of 5 |
| + ally pairs | -0.00112 ± 0.00052 | -0.00106 ± 0.00039, 5 of 5 |
| + lane pairs (same role, bottom-support across) | -0.00116 ± 0.00052 | -0.00110 ± 0.00040, 5 of 5 |
| + every enemy pair | -0.00116 ± 0.00052 | -0.00110 ± 0.00040, 5 of 5 |
| full (all blocks + mix), better in 4 of 5 | -0.00129 ± 0.00054 | -0.00123 ± 0.00041, 5 of 5 |
| full without the mix | -0.00039 ± 0.00040 | -0.00033 ± 0.00019, 5 of 5 |
| team gold at 14, to win through its slope | +0.01798 ± 0.00188 | |

Audit meiolol-33 (14 Oct, from the games files; in-run ratings equals the reference to
1e-6, no leak found): reproduces. Clear (early, folds only; dev-val ties): the additive
model beats ratings on the folds, ~3/4 of it through the damage mix (strength + mix
-0.97 ± 0.50). Not established: beating win-comp (full vs win-comp -0.72 ± 0.44, 3 of 5,
bound under the 1.6x rule -0.02) and role pairs adding on top of the mix (full vs
strength + mix -0.32 ± 0.19, 5 of 5, under the ±0.5 floor). Both go to a pre-declared
resample test on snap-20261013T2253Z.

Dev-val (8,500 EUW1 games): full +0.00027 ± 0.00103 vs ratings, champion strength + mix
+0.00042 ± 0.00089 (ties; win-comp's dev-val was +0.0003 too). win-comp on the same folds:
-0.00057 ± 0.00028. Calibration on the folds (one temperature on the logit): ratings 0.80 ±
0.11 (top tenth said 58.6%, won 55.8%), full additive 0.94 ± 0.10 (58.6 vs 58.9).

Held-out drop-one (run 20261013T223330Z-eff-c, before the mix fix, so without a working
mix; the full model refitted without one block, pooled folds, positive = the block
helps): champion strength top +0.00020 ± 0.00019, jungle +0.00019 ± 0.00014, middle
+0.00034 ± 0.00020, bottom +0.00009 ± 0.00023, support +0.00031 ± 0.00026; ally
bottom-support +0.00013 ± 0.00011 (0 of 5 folds better without it); top vs their top
+0.00010 ± 0.00010 (0 of 5); middle vs their middle +0.00004 ± 0.00006; bottom vs their
bottom +0.00003 ± 0.00006; every other block within ±0.00002.

Shuffled-label control on the fixed mix (20261013T231223Z-eff-shuf2, 4f3d007, results
permuted across games, paired on the same folds): damage mix over strength only +0.00002
± 0.00003 (real -0.00091), full over strength only +0.00010 ± 0.00011 (real -0.00123):
the gains vanish, so they are not fitting noise.

Per-block spread of true effects: an earlier shuffled-label control
(20261013T223344Z-eff-shuf) gave held-out gains of ~0 (full vs strength -0.00000 ±
0.00012) and champion strength sd 0.00-0.01 pp, but pair blocks still 0.1-0.9 pp: with
1-3 games per cell the variance estimate finds spread in noise. A Poisson bootstrap made it worse (duplicated games look
consistent). So each block is read against a shuffled-outcome null (`--null 20`: the same
fit with results and gold permuted across games, drafts kept) with intervals from 30
half-samples (sd of the halves / sqrt 2). Corrected = sqrt(sd^2 - null mean square);
detected = the block's sd and its lower bound both above the null's 95th percentile.

Run 20261013T231222Z-eff-e (4f3d007), fitted on dev's 88,706 fit games (64,931 with gold at
14); matchup rows from 20261013T235224Z-eff-f (d1d22f1, same fit, block rows identical).
Spread of true effects across cells, corrected, [95%]; win in pp at 50%, gold at 14 in
team gold. A matchup X vs Y enters as cell(r vs q)(X, Y) minus cell(q vs r)(Y, X), and the
fit splits its effect between the two blocks by their variances, so a matchup's spread is
the two blocks' cell sds summed (a same-role block twice). One enemy block alone is not a
matchup: planted lane matchups of sd 4 pp came out at 2.0 per block (meiolol-tests).

| block | win pp | gold at 14 |
| --- | --- | --- |
| champion strength top | 1.48 [1.24, 1.72] detected | 376 [352, 399] detected |
| champion strength jungle | 1.00 [0.69, 1.31] detected | 321 [301, 340] detected |
| champion strength middle | 1.94 [1.72, 2.16] detected | 362 [345, 380] detected |
| champion strength bottom | 1.52 [1.33, 1.71] detected | 327 [305, 348] detected |
| champion strength support | 2.17 [1.83, 2.52] detected | 301 [280, 322] detected |
| ally bottom-support | 1.21 [0.83, 1.58] detected | 41 [17, 58] |
| ally top-bottom | 0.68 [0.43, 0.91] (null 95th 0.91) | 0 [0, 0] |
| ally jungle-bottom | 0.42 [0, 0.68] | 18 [0, 40] |
| other 7 ally pairs | 0 (upper 0-0.38) | 0-12 (upper 0-43) |
| matchup top vs top | 2.47 [1.98, 2.95] detected | 253 [196, 309] detected |
| matchup middle vs middle | 1.33 [0.76, 1.83] (null 95th 1.37) | 192 [153, 230] detected |
| matchup bottom vs bottom | 1.28 [0.69, 1.85] (null 95th 1.05) | 108 [62, 152] detected |
| matchup bottom vs support (both ways) | 0.52 [0, 0.83] | 96 [65, 125] detected |
| matchup jungle vs jungle | 1.08 [0.44, 1.58] (null 95th 1.40) | 78 [0, 139] |
| matchup support vs support | 0.82 [0, 1.33] | 75 [0, 135] |
| matchup middle vs bottom | 0.68 [0.34, 0.95] (null 95th 0.84) | 0 [0, 0] |
| other 8 cross-role matchups | 0-0.49 (upper 0-0.77) | 0-32 (upper 0-53) |

Planted checks at this size (meiolol-tests, effects on 2055Z with known effects): nothing
planted gives every pair block ~0 and no gain; the damage mix is recovered (planted -2,
fitted -1.69 ± 0.33); champion strength is unbiased at real pair sizes. But pair-block sds
run low: ally pairs planted at 2 pp came out 1.21 on average (0.6x; 1 of 10 intervals
covered 2), at 4 pp 2.99 (0.75x, 0 of 10), lane matchups at 2 pp 0.9x. So read the ally
and matchup sds as lower bounds and their upper ends as too low, by up to ~1.7x for the
ally blocks (bottom-support 1.21 may be ~2 pp). Cause (unit plant, 20k games, one pair
block; test "planted pair sd: gaussian recovered ..." in src/src/additive.zig, 4 seeds per
row in the numbers below, one in the test): the known downward bias of Laplace-type variance estimates on binary outcomes
with few games per cell, not the diagonal posterior. The same block planted on a
gaussian outcome comes back at 0.97-1.04x at 6-180 games per cell; on win it comes back
at 0.96x at 178 games per cell, 0.67x at 25, 0.23x at 6. So win pair sds are lower bounds
and gold-at-14 ones are not; fixing it changes the shipped shrinkage, so it gets its own
pre-declared check.

Damage mix: -1.94 ± 0.33 pp per sd of the term (-2.72 ± 0.33 per sd of blue minus red);
on gold at 14 -11 ± 27 (none: the mix is a late-game term). So the draft's information is
champion strength in every role (1-2 pp of spread each, 300-375 gold), the damage mix,
one ally pair (bottom-support, 1.2 pp or more) and the lanes: top vs top on both win
(2.5 pp) and gold (250), middle, bottom and bottom-support lanes on gold at 14 (100-190)
with at most ~1.8 pp on win. Not detected on win: ally top-bottom (0.68) and the middle,
bottom and jungle lanes sit under the null's 95th; the other 7 ally pairs and 8 cross-role
matchups are at most 0.5 pp as fitted (lower bounds, see above). Single pairs: not
reported (1-3 games per cell; the blocks are the answer).

The draft predicts gold at 14
(held-out R^2 5-8% of team gold's 3,600 sd), but the predicted gold edge carries no win:
-0.02, -0.04, +0.05, -0.02, -0.02, +0.04 logit per 1000 (± 0.05) on dev and the five
folds' scored games, against 0.405 for real gold at 14. Gold at 14 then to win through
the state model (+0.018 vs ratings) is ruled out: drafts that win early gold give it back.

#### Additive model on snap-20261013T2253Z: pre-declared test (audited by meiolol-53)

The 2055Z audit (meiolol-33) left two claims open, so they were declared with the verifier
before any 2253Z score was seen (rule and both amendments in the verifier's notes): H1
full minus win-comp, H2 full minus strength + mix (do role pairs add on top of the mix),
folds pooled; pass = full-data mean + 1.6 x 95% half-width < 0 and both 90% resamples
(`--resample 1`, `2`) < 0; void if the shuffled-label control gains; dev-val reported, not
judged. Re-cut 2253Z (one all-platform cut, 85fd62a), folds 134,375 games, dev-val 35,834,
the additive model unchanged from 2055Z; results unread until the verifier's gate passed.
Runs 20261014T002919Z-e53-A0..A2 (vs ratings), 003704Z-e53-B0..B2 (vs win-comp),
003812Z-e53-C (control), 003833Z-e53-T (table). Checks: in-run ratings and win-comp equal
the references (04's rb-ref-wr, rb-ref-wc) to 1e-6; the additive preds are identical in the
A and B runs.

| statistic | full data, 5 folds | resample 1 | resample 2 | dev-val | verdict |
| --- | --- | --- | --- | --- | --- |
| H1 full - win-comp | -0.00115 ± 0.00022, 5 of 5 | -0.00126 | -0.00116 | -0.00169 ± 0.00048 | pass (bound -0.00080) |
| H2 full - (strength + mix) | -0.00082 ± 0.00017, 5 of 5 | -0.00075 | -0.00076 | -0.00132 ± 0.00037 | pass (bound -0.00055) |
| H0 full - ratings | -0.00163 ± 0.00028, 5 of 5 | -0.00171 | -0.00162 | -0.00219 ± 0.00057 | reported |
| control, shuffled labels: full - strength | +0.00000 ± 0.00005 | | | | no gain, valid |

So the additive model beats win-comp by 1.15 ± 0.22 milli-nats per game on the folds (1.7
on dev-val, reported only; no test look), and its role pairs add 0.82 ± 0.17 on top of
strength + mix. Strength + mix alone vs win-comp: -0.34 ± 0.15. The model was designed on
2055Z, whose dev games overlap 2253Z's early folds; the gain is largest on fold 5 and
dev-val, mostly games 2055Z never had, so no sign of design overfit. Against 2055Z (pairs
-0.33, full vs ratings -1.29) the gains are larger, consistent with thin pair cells gaining
from more games; the two pins score different games and times, so that is not a measured
data effect (a same-games learning curve would be). Audit meiolol-53: every figure
recomputed per game from the games files, blocks equal the nn split by match id.

Per-block table (e53-T, 268,750 dev-visible games; corrected spreads [95%]; a value with an
interval is detected, above the null's 95th, unless marked; as on 2055Z, pair sds are
lower bounds, planted pairs came out 0.6-0.9x):

| block | win pp | gold at 14 |
| --- | --- | --- |
| champion strength top / jungle / middle / bottom / support | 1.84 / 1.68 / 2.45 / 1.63 / 3.37 | 370 / 359 / 375 / 317 / 343 |
| ally bottom-support | 1.28 [1.07, 1.48] | 83 [68, 98] |
| other 9 ally pairs | none detected, at most 0.27 (upper 0.39) | none detected, at most 31 (upper 41) |
| matchup top vs top | 2.51 [2.21, 2.80] | 303 [286, 319] |
| matchup middle vs middle | 1.90 [1.59, 2.21] | 189 [162, 215] |
| matchup support vs support | 1.26 [0.96, 1.55] | 131 [103, 159] |
| matchup bottom vs bottom | 1.18 [0.98, 1.38] | 85 [69, 100] |
| matchup jungle vs jungle | 1.14 [0.94, 1.34] | 38 [0, 71], not detected |
| matchup middle vs bottom | 0.89 [0.69, 1.08] | none |
| matchup bottom vs support (both ways) | 0.88 [0.68, 1.08] | 85 [73, 98] |
| matchup top vs middle | 0.61 [0.46, 0.74] | 26 [0, 42], not detected |
| other 7 cross-role matchups | not detected, 0-0.71 (upper 0.94) | at most 26 (upper 40) |

Cross-role matchup rows sum the two blocks' sds. Only the difference c = cell(r vs
q)(X, Y) - cell(q vs r)(Y, X) is identified, and the fit splits each c between the two
blocks in one proportion, so the fitted cells move together and their sds add (at the
variance estimate's fixed points the split is 0, 1/2 or 1, and the sum equals c's sd while
the root sum of squares understates it by up to sqrt 2). The verifier (meiolol-53) asks
for the root sum of squares if the blocks were independent, so learned.md gives the
cross-role sizes as the range between the two (mid vs bot 0.7-0.9, top vs mid 0.4-0.6)
until meiolol-tests' crossed-only plant (lanes=2) settles it.

Damage mix: -1.89 ± 0.19 pp per sd of the term (-2.75 per sd of blue minus red), on gold
at 14 -21 ± 15. Single cells: not reported.

#### Additive model v2: identified matchups (2253Z re-cut, pre-declared, cf4762d; audited by meiolol-53)

v1's enemy blocks weren't identified: a same-role matchup had two cells, cell(a, b) and
cell(b, a), of which only the difference enters a game, and "r vs their q" and "q vs
their r" held the same matchups twice with opposite signs. So a block's sd was not the
matchup's spread (hence the sum rule above), and simulation calibration had no target
(even gold-at-14 blocks calibrated up ~sqrt 2). v2 (additive.Variant.matchupGroups): one
signed cell per unordered same-role pair, cross-role the r <= q block only; 15 matchup
blocks whose sds are the matchups' spreads. On 2055Z block 1, v2's top vs top block was
2.35 pp against v1's summed 2.47 (the sum held). Also tried: block variances calibrated
by simulation (additive.calibrate, 8 sims x 8 damped rounds per block, fit games only;
plant: thin pair block 0.63x raw, 0.91x calibrated), refitted with them fixed
("full-cal"). `effects --param v1` reproduces the audited e53 runs.

Declared with meiolol-53 before any 2253Z v2 run (H4: v2 full minus v1 full at the same
resample index, ships if mean + 1.6 x half < +0.0002 and both resamples < +0.0002; H5:
full-cal minus full, ships if mean + 1.6 x half < 0 and both resamples < 0). Runs
20261014T041809Z-e53v2-V0, 041843Z-V1, 041920Z-V2 (resample none, 1, 2), 042003Z-T2
(table); v1 from e53-A0..A2. Checks: in-run ratings identical to e53-A0's; v2's full preds
differ from v1's on 170,176 of 170,209 games. The declaration also asked for v2's
strength + mix preds to differ, a slip: that variant has no matchup blocks and is the same
model in both (identical, as it must be).

| statistic | folds (134,375 games) | resample 1 / 2 | dev-val | verdict |
| --- | --- | --- | --- | --- |
| H4 v2 full - v1 full | -0.09 ± 0.05 mnats, 5 of 5 | -0.08 / -0.09 | -0.22 ± 0.10 | pass: v2 replaces v1 |
| H5 full-cal - full | +0.01 ± 0.10, 3 of 5 | +0.07 / +0.09 | -0.04 ± 0.18 | fail: calibrated variances don't ship |
| v2 full - win-comp (reported) | -1.24 ± 0.26, 5 of 5 | | -1.90 ± 0.54 | |
| v2 full - ratings (reported) | -1.72 ± 0.30, 5 of 5 | | -2.41 ± 0.62 | |
| v2 pairs over strength + mix | -0.91 ± 0.21, 5 of 5 | | -1.53 ± 0.45 | |

So the shipped additive model is v2 with its own (uncalibrated) variances: identified and a
little better than v1. Calibration stays for reporting sizes only.

Matchup and ally spreads, v2 (T2, 268,750 games), win pp: fitted, null-corrected [95%] /
calibrated [95%]; all detected above the null's 95th (fitted values are lower bounds where
the plant is under 1, i.e. thin blocks; calibrated ones are 0.91x in the plant):

| block | fitted | calibrated | gold at 14 (fitted) |
| --- | --- | --- | --- |
| top vs top | 2.23 [1.96, 2.50] | 2.47 [2.19, 2.75] | 277 [262, 293] |
| middle vs middle | 1.69 [1.41, 1.97] | 2.05 [1.73, 2.38] | 172 [149, 195] |
| support vs support | 1.15 [0.88, 1.40] | 1.47 [1.17, 1.78] | 121 [95, 147] |
| bottom vs bottom | 1.05 [0.87, 1.24] | 1.34 [1.11, 1.56] | 76 [61, 90] |
| jungle vs jungle | 1.04 [0.86, 1.21] | 1.42 [1.21, 1.63] | not detected |
| middle vs bottom | 0.79 [0.61, 0.97] | 1.14 [0.91, 1.38] | not detected |
| bottom vs support | 0.80 [0.60, 0.99] | 1.10 [0.86, 1.34] | 83 [71, 96] |
| top vs middle | 0.52 [0.40, 0.64] | 0.96 [0.81, 1.11] | not detected |
| ally bottom-support | 1.28 [1.07, 1.48] | 1.55 [1.31, 1.80] | 84 [68, 99] |

H5 failed, so calibrated sizes have no out-of-sample support (only the unit plant, 0.91x):
read the table's ranges as fitted (a lower bound) to plant-calibrated (not confirmed by
prediction). The other 7 cross-role matchups are not detected as fitted (0.2-0.6) but
calibrate up to ~1.1 (jungle vs support 0.74 -> 1.10). Ally calibrations other than
bottom-support didn't converge (last-round misfit 1.72 top-bottom, 1.87 middle-bottom;
factors 0.16-2.2), so no calibrated value is quoted for them; bottom-support's misfit was
0.99. Champion strength and the damage mix as in e53-T.

#### In-game events

`meiolol-lab eventvalue SNAP` (src/lab/eventvalue.zig, 706b2c4, on meiolol-4a's
SNAP/events.tsv), run 20261013T225443Z-ev-a (build cleared by a0, as eff-d). 130,229
games with a timeline, 3.55M game-minutes. Per game-minute (frame m to m+1): blue's win
chance change under winchance.zig's state model, and blue's gold lead change, regressed
on that minute's events (+1 blue, -1 red) by minute band, so events of one fight share
credit; 95% from 200 game bootstraps. Gold equivalent: the win points over what 1000 gold
of lead was worth in the same game-minutes.

Caveat first (meiolol-bd, effect-isolation C2): winchance's state has no draft terms, and
champions are worth 3-11 points at equal state, so these values are what the state model
credits, likely inflated; redo on meiolol-state's P(win | draft, state) before any line
goes to learned.md.

| event (taking team) | 10-14 min | 15-19 | 20-24 | 25-29 | 30-40 |
| --- | --- | --- | --- | --- | --- |
| dragon (any element), pp | 4.4-4.5 | 4.0-4.1 | 4.0 | 4.0-4.2 | 5.3-5.8 |
| dragon, gold equivalent | ~740 | ~950 | ~1230 | ~1490 | ~2260 |
| elder, pp (gold eq.) | | | | 6.0 (3,600) | 9.0 (4,900) |
| baron, pp (gold eq.) | | | 5.8 (1,960) | 6.7 (2,470) | 8.1 (3,490) |
| herald, pp (gold eq.) | | 0.7 (150) | | | |
| grub (1-9 min / 10-14), pp | 0.85 (110 / 125) | | | | |
| outer tower, pp (gold it brought) | 0.1 (520) | 1.4 (440) | 2.6 (580) | 3.2 (650) | 3.0 (590) |
| inhibitor, pp | | -0.8 | -0.1 | 1.2 | 3.4 |
| kill, pp (gold it brought) | 3.8 (520) | 3.2 (560) | 2.8 (590) | 2.6 (620) | 2.6 (660) |

Intervals: ± 0.1-0.2 pp for dragons, baron and kills; first blood adds 2.4 pp to its kill
at 1-9 min. Dragon elements (assigned by the game, so their differences are causal):
within ~0.3 pp of each other in every band (mountain lowest early, by 0.1-0.3). Inner,
base and nexus towers come out negative (-0.6 to -2.3 pp): the state model counts every
tower the same and weighs towers beyond their gold slightly negative early, so it can't
value the later ones; read only outer towers.

Cause or being ahead (realised.tsv): after a take, does the taking team win as often as
the model's next-frame chance says? Overall a little more (dragon +0.4 pp, baron +1.4,
inhibitor +1.1, elder +2.7): the state model under-credits objectives at the moment of
taking. Teams behind (chance under 50% before) beat it by more (dragon +1.8, baron +4.9,
inhibitor +8.6, elder +8.9): what the state misses, e.g. a late-game draft, shows up
here. Steals are not the coin flip hoped for: a team that stole a dragon then won 37.6%,
less than its 40.2% just before (herald 34.6% vs 40.4%; baron 42.0%, above its 33.4%
before but under the model's 44.4% after): a steal marks a fight the other team set up
and was winning. Contested takes (both teams
with a kill within 30 s) land close to the model (dragon +0.3, baron +0.3, elder -0.3).
So no clean causal split yet; the draft-aware state model is the next step.

#### In-game events on the draft-aware state (snap-20261013T2253Z re-cut; cleared as description by meiolol-53)

bd's C2: winchance's state has no draft, so event values might credit the draft. Rerun
with `eventvalue --preds` (2d9a8b4) on meiolol-state's cross-fitted chances
(SNAP/state/preds-wcd.tsv, run 20261014T020129Z-state-preds-2253Zr, block cf: 5-fold
cross-fit by game over 236,227 dev-visible games, 6.5M game-minutes; that run is
meiolol-state's, not audited here): wc = winchance's state, wcd = wc + the draft logit
(win-ratings, cross-fitted by game) with weights by minute, rich
= per-role gold, XP, levels, deaths and respawn timers, towers by lane and tier, dragons by
element and soul, buff timers, items, vision. Gold unit per model: what it gives a gold
lead change in minutes with no event (XP that came with the farm included). Runs
20261014T035939Z-ev53-p_wc, 035847Z-ev53-p_wcd, 035913Z-ev53-p_rich (f16367e), 200 game
bootstraps.

Win points for the taking team, wc / wcd [95%] / rich:

| event | 10-14 min | 20-24 | 30-40 |
| --- | --- | --- | --- |
| dragon (any element) | 4.5 / 4.4-4.5 [±0.07] / 3.2-4.8 | 4.1 / 4.0-4.1 / 2.1-3.0 | 5.2-5.5 / 5.3-5.5 [±0.13] / 0.0-1.7 |
| elder | | | 9.2 / 9.2 [9.0, 9.3] / 4.4 |
| baron | | 5.8 / 5.6 [5.6, 5.7] / 3.8 | 8.0 / 7.9 [7.8, 7.9] / 3.5 |
| outer tower | 0.1 / 0.2 / -0.3 | 2.6 / 2.7 / 1.4 | 3.0 / 3.0 / 0.0 |
| inhibitor | | -0.1 / -0.2 / -1.0 | 3.5 / 3.4 [3.3, 3.4] / 2.0 |
| kill | 3.8 / 3.8 / 3.8 | 2.8 / 2.7 / 3.7 | 2.6 / 2.6 / 6.7 |
| grub (1-9 / 10-14) | 0.8 / 0.8 / 0.6 | | |
| herald (15-19) | 0.75 / 0.61 / 0.21 | | |

wcd's gold equivalents (dragon ~570 gold at 10-14, ~1,200 at 30-40; baron 1,180-1,780;
elder 2,070 at 30-40) are not comparable with rich's, whose no-event gold slope falls to
0.7 pp per 1000 at 30-40 (its state already holds what the gold bought).

Findings:
- The draft term changes event values by at most ~0.15 pp (wc vs wcd, every event and
  band): C2's worry is not detected for a draft term that is fixed through the game. The
  champion-by-minute term (scaling) is the open part: meiolol-state is adding p_richc.
- Cause or being ahead (realised.tsv; excess = the taking team's results minus the
  model's next-frame chance; "behind" as each model sees it, so the groups differ, e.g.
  baron takes behind 58,737 under wc, 50,198 under rich, and part of the drop below is a
  different set of takes): the draft explains almost none of why teams behind beat the
  model after an objective (baron +4.7 -> +4.6 pp, inhibitor +8.2 -> +8.0, elder +8.1 ->
  +7.8, wc -> wcd); the rich state removes most of it (baron +0.6, inhibitor +1.6, elder
  +1.8) and is within ~0.3 pp at takes overall (baron, inhibitor, elder ~0; dragon +0.3).
  So what wc misses is mostly in-game state (items, levels, timers), not the draft.
- Values depend on what the state holds: rich credits a late kill 6.7 pp (respawn timers
  in the state open the map) and a late dragon little (soul and element counts already
  priced as the game goes), wc credits them through gold and counts. Comparisons between
  models are like for like (same code, different chances); absolute values are as fitted,
  as the regression on --preds has no planted check yet. Report wcd's as "what
  the event adds given gold and objectives", rich's as "given the whole board".
- Steals are not coin flips under any model: after a stolen dragon the stealing team wins
  9.7 pp less than the model's next-frame chance (wcd [-10.7, -8.5], rich -9.7), herald
  -8.2 / -8.6, baron -2.8 / -4.6. Interpretation, not measured: a steal marks a fight the
  other team set up and was winning, so steal "value" can't separate cause from being
  behind.
- Inner towers and early inhibitors still come out negative in wc and wcd (-2.4 pp inner at
  10-14): those models count towers alike, so read only outer towers there.

#### Distillation (parked)

Ready: `netcheck --fit-preds 1` (c2ec378) writes a teacher's chances on every block's
fit games, each from a fit without the game's hashed fifth; `effects --soft FILE` fits the
full additive model to the teacher's seed-mean logit by squared error (student-logit) and
to alpha x result + (1 - alpha) x teacher (student-mix), and tabulates the student's
blocks beside the label fit's. Gate (research C5): distil only from a teacher that beats
the shrunk label fit on the folds. Today no champ-select teacher does (best big-net
ensembles tie ratings; the additive model is at -0.0013), so it waits for one.

### Carry and impact, 2026-10-14 (meiolol-61)

Jacob (2026-10-13): which champions carry, and which have less effect on the game?
`meiolol carry --cuts ...` (src/carry.zig; retired 23 Oct, code at 616e0a6), pinned
snap-20261012T2055Z, run
20261013T223040Z-carry-a (64ada94); test look 20261013T231146Z-carry-final (3f8b9d6,
look 8 in SNAP/test-looks.tsv; the same models plus a per-role breakdown, folds and
dev-val identical). Rows: every player at the draft and at
10/15/20/25/30 of games reaching 15:00 while still going (117,806 train games, ten rows
per game and minute). Blocks: the lab's (compcheck --folds 5, c1's cuts): folds 1-5 fit
on train games before the block and score every platform's games in it, dev-val fits
before the dev cut and scores EUW1; test = the protocol's 10,604 EUW1 games, fit on every
train game, one look (go from meiolol-bd for Jacob, readings declared before: (a) gold
by role vs team gold at 15 and 25, (b) champion x own gold lead at 15 and 25, (c)
champion x experience at the draft).

Model, log-odds of the player's team winning, nested steps: team state at the minute
(team gold, gold curve, XP, held objectives as objectives.zig); gold split by role (each
role's own minus lane opponent's); + kills minus deaths and share of team damage to
champions so far, by role; + champion-role shift; + champion-role slope on the seat's
own gold lead over its lane opponent ("leverage": does this champion turn its own lead
into wins more than its role does); + slopes on its own kills minus deaths and damage
share. Champion terms shrunk per role by a method-of-moments prior (as scaling). Draft:
win rate; + a slope per role on log1p(the player's earlier ranked solo games on the
champion in the snapshot, 16 days; 1+ for 24% of player-games); + champion shift; +
champion-role slope on it ("skill sensitivity"). Outcome spread: how far from a coin
flip (|team-state chance - 50|, pp) the champion's teams stand at each minute, Gaussian
shift per champion-role vs the role mean. Train-time: the state and seat stats at the
minute; use-time: post-game lessons and aggregate facts only (docs/production-key.md).
Like with like: same minute, same team state; the before/after framing of meiolol-08's
event values (state just before vs with the event) here is "the same team state with the
gold on another seat".

Gains, nats per row ± 95% clustered by game; [k/5] folds better:

| minute | step | folds 1-5 [k/5] | dev-val | test |
| --- | --- | --- | --- | --- |
| 0 | + experience slope by role | 0.00009 ± 0.00002 [5/5] | 0.00005 ± 0.00007 | 0.00018 ± 0.00007 |
| 0 | + champion shift | 0.00015 ± 0.00012 [4/5] | 0.00022 ± 0.00021 | 0.00026 ± 0.00017 |
| 0 | (c) + champion x experience | -0.00006 ± 0.00003 [0/5] | -0.00013 ± 0.00009 | **-0.00001 ± 0.00004** |
| 10 | gold by role (vs team gold) | 0.00253 ± 0.00080 [5/5] | 0.00307 ± 0.00149 | 0.00173 ± 0.00135 |
| 10 | + kills, damage share by role | 0.00036 ± 0.00046 [3/5] | 0.00043 ± 0.00082 | 0.00077 ± 0.00068 |
| 10 | + champion shift | 0.00113 ± 0.00020 [5/5] | 0.00127 ± 0.00038 | 0.00166 ± 0.00033 |
| 10 | + champion x own gold lead | -0.00006 ± 0.00007 [1/5] | -0.00015 ± 0.00015 | -0.00014 ± 0.00015 |
| 10 | + champion x own kills, damage share | -0.00004 ± 0.00005 [1/5] | -0.00002 ± 0.00008 | -0.00000 ± 0.00004 |
| 15 | (a) gold by role (vs team gold) | 0.00413 ± 0.00100 [5/5] | 0.00401 ± 0.00184 | **0.00251 ± 0.00167** |
| 15 | + kills, damage share by role | 0.00064 ± 0.00050 [5/5] | 0.00108 ± 0.00092 | 0.00114 ± 0.00079 |
| 15 | + champion shift | 0.00145 ± 0.00022 [5/5] | 0.00151 ± 0.00040 | 0.00206 ± 0.00037 |
| 15 | (b) + champion x own gold lead | -0.00004 ± 0.00005 [1/5] | -0.00009 ± 0.00011 | **0.00003 ± 0.00007** |
| 15 | + champion x own kills, damage share | -0.00005 ± 0.00005 [1/5] | -0.00007 ± 0.00010 | -0.00004 ± 0.00006 |
| 20 | gold by role (vs team gold) | 0.00520 ± 0.00113 [5/5] | 0.00332 ± 0.00213 | 0.00393 ± 0.00187 |
| 20 | + kills, damage share by role | 0.00071 ± 0.00060 [5/5] | 0.00123 ± 0.00105 | 0.00107 ± 0.00092 |
| 20 | + champion shift | 0.00158 ± 0.00023 [5/5] | 0.00163 ± 0.00042 | 0.00228 ± 0.00040 |
| 20 | + champion x own gold lead | -0.00001 ± 0.00003 [1/5] | 0.00002 ± 0.00010 | 0.00001 ± 0.00005 |
| 20 | + champion x own kills, damage share | -0.00010 ± 0.00007 [0/5] | -0.00009 ± 0.00007 | -0.00002 ± 0.00004 |
| 25 | (a) gold by role (vs team gold) | 0.00473 ± 0.00121 [5/5] | 0.00212 ± 0.00232 | **0.00410 ± 0.00192** |
| 25 | + kills, damage share by role | 0.00126 ± 0.00073 [5/5] | 0.00073 ± 0.00139 | 0.00121 ± 0.00110 |
| 25 | + champion shift | 0.00135 ± 0.00024 [5/5] | 0.00171 ± 0.00045 | 0.00232 ± 0.00045 |
| 25 | (b) + champion x own gold lead | -0.00002 ± 0.00004 [2/5] | -0.00005 ± 0.00011 | **0.00001 ± 0.00008** |
| 25 | + champion x own kills, damage share | -0.00014 ± 0.00007 [0/5] | 0.00002 ± 0.00007 | 0.00007 ± 0.00006 |
| 30 | gold by role (vs team gold) | 0.00515 ± 0.00166 [5/5] | 0.00335 ± 0.00326 | 0.00421 ± 0.00264 |
| 30 | + kills, damage share by role | 0.00111 ± 0.00098 [4/5] | 0.00055 ± 0.00185 | 0.00118 ± 0.00156 |
| 30 | + champion shift | 0.00110 ± 0.00030 [5/5] | 0.00158 ± 0.00060 | 0.00227 ± 0.00059 |
| 30 | + champion x own gold lead | -0.00016 ± 0.00009 [0/5] | -0.00007 ± 0.00015 | -0.00004 ± 0.00007 |
| 30 | + champion x own kills, damage share | -0.00016 ± 0.00012 [1/5] | 0.00002 ± 0.00006 | -0.00006 ± 0.00007 |

Bold: the three pre-declared test readings; the other test cells are secondary
description (not readings). Decided (champion vs role mean of |chance - 50|, MSE in
pp^2): folds +0.004 ± 0.017, -0.002 ± 0.035, -0.016 ± 0.024, -0.000 ± 0.021, +0.005 ±
0.059 at 10-30 (2-3/5), dev-val alike; not scored on test. By role (the champion x own
gold step's rows of one role; in the run's carry.md): no role clears zero on folds at
any minute (best: support at 10, +0.00009 ± 0.00014, 4/5), nor on test.

Whose seat decides (every train game, team state fixed; win pp in an even game per
unit of a role's lead over its lane opponent, ± 95% clustered by game; per sd: times the
lead's spread at that minute; each cell top / jungle / mid / bottom / support):

| minute | per 1000 gold | per sd of gold lead (sd, thousands) | per kill minus death | per 10 points of damage share |
| --- | --- | --- | --- | --- |
| 10 | 7.6 / 10.2 / 9.6 / 11.4 / 1.4 (± 0.6-0.8) | 7.5 / 8.5 / 8.3 / 11.5 / 0.8 (1.0 / 0.8 / 0.9 / 1.0 / 0.6) | 0.1 / -0.2 / -0.2 / -0.3 / -0.2 (± 0.2) | -0.4 / 0.5 / 0.6 / 1.3 / -2.0 (± 0.3-0.4) |
| 15 | 4.5 / 6.9 / 5.9 / 8.2 / -0.1 (± 0.4-0.6) | 8.1 / 9.5 / 9.1 / 14.9 / -0.1 (1.8 / 1.4 / 1.5 / 1.8 / 0.9) | 0.1 / 0.0 / -0.3 / -0.2 / 0.0 (± 0.15) | -0.5 / 0.9 / 1.0 / 1.5 / -2.9 (± 0.4-0.5) |
| 20 | 3.9 / 5.3 / 4.3 / 7.0 / 0.1 (± 0.4-0.5) | 9.1 / 10.6 / 9.0 / 16.9 / 0.1 (2.4 / 2.0 / 2.1 / 2.4 / 1.2) | -0.1 / 0.0 / -0.3 / -0.3 / 0.0 (± 0.13) | -0.2 / 0.8 / 1.3 / 1.8 / -3.7 (± 0.4-0.6) |
| 25 | 2.9 / 3.5 / 3.0 / 5.3 / 0.2 (± 0.4-0.5) | 8.1 / 9.1 / 7.6 / 15.5 / 0.3 (2.8 / 2.6 / 2.6 / 2.9 / 1.5) | -0.2 / -0.0 / -0.3 / -0.4 / 0.1 (± 0.12) | 0.1 / 0.9 / 1.5 / 1.7 / -4.1 (± 0.5-0.7) |
| 30 | 2.2 / 2.2 / 2.2 / 4.2 / 0.5 (± 0.5) | 6.8 / 6.7 / 6.3 / 13.8 / 0.8 (3.1 / 3.0 / 2.9 / 3.3 / 1.7) | -0.2 / -0.0 / -0.3 / -0.4 / 0.1 (± 0.12) | 0.4 / 0.6 / 1.0 / 1.8 / -3.8 (± 0.7-0.8) |

Gold columns from the gold-by-role baseline (held objectives in it), kills and damage
share from the full one (so beyond gold). Spread across champions in a role (every
train game; shrinkage sd [upper 95% bound, analysis.spreadBounds], win pp per 1000 own
gold): mostly 0, at most 3.8 (jungle 10), 5.9 (support 10), 3.1 / 2.8 (bottom 10 / 15);
bounds 2.3-11.9 (tightest top and mid, 2.3-6.0). Kills minus deaths: 0-0.8 [0.9-2.8];
damage share 0-3.9 per 10 points [4.3-17.3]; experience at the draft 0 except jungle 3.0
[6.6-8.5] per log1p game. Champion shift beyond the full state: 2.6-8.9 pp in every
role and minute but jungle at 10 (0), as scaling. Per champion-role values:
carry-table.tsv in the run dir; per-fold leverage, scaling and skill for comp screens:
carry-folds.tsv (meiolol-c1).

Train-fit leanings (unshrunk, ± 95%; did not hold on held-out games, so not findings):
own gold worth more than the role's at 15 for Sivir (+3.1 ± 1.1 pp per 1000 over
bottom's 8.0), Aphelios (+2.4 ± 0.8), Bel'Veth jungle (+3.6 ± 1.8), Bard support
(+2.5 ± 2.1 over support's 1.8 in the full model); less for bot-lane mages Viktor and
Ziggs (-1.7, -1.6 ± 1.6-1.9), Alistar and Braum support (-2.5, -2.3 ± 2.0).

Planted checks (`--plant COV:SD`, winners redrawn from the full-state baseline plus a
champion-role slope drawn with sd SD in win pp per unit, summed over all ten seats; runs
20261013T2236..2237Z-carry-plant-*):

| planted | folds: champion slope step at 10 / 15 / 20 / 25 / 30 | recovery corr at 15 / 25 |
| --- | --- | --- |
| own gold, sd 0 (null) | -0.00009 / -0.00003 / -0.00005 / -0.00012 / -0.00004 (0-1/5) | - |
| own gold, sd 1 pp per 1000 | -0.00005 (2/5) / 0.00007 ± 0.00007 (3/5) / 0.00006 (3/5) / 0.00020 ± 0.00011 (5/5) / 0.00021 ± 0.00013 (5/5) | 0.57 / 0.72 |
| own gold, sd 2 | 0.00013 ± 0.00008 (4/5) / 0.00052 ± 0.00012 / 0.00073 ± 0.00014 / 0.00144 ± 0.00024 / 0.00213 ± 0.00033 (5/5) | 0.84 / 0.57 |
| own gold, sd 4 | 0.00119 / 0.00289 / 0.00466 / 0.00598 / 0.00811 (5/5) | 0.94 / 0.97 |
| experience, sd 2 pp per log1p game | 0.00004 ± 0.00004 (5/5, draft) | 0.44 |
| experience, sd 4 | 0.00020 ± 0.00007 (5/5) | 0.39 |
| experience, sd 8 | 0.00077 ± 0.00009 (5/5) | 0.84 |

Reading:
- Whose seat decides (clear on folds, dev-val and the test look): with the team's state
  held fixed, the gold lead on the bot laner moves the win chance most at every minute:
  per typical lead (one sd) 11.5 pp at 10 rising to 15-17 at 15-25, against 7-10.6 for
  jungle, mid and top and about 0 for the support. Per 1000 gold: bottom 11.4 at 10 to
  4.2 at 30; jungle and mid 10 to 2; top 7.6 to 2.2; support 1.4 at 10 and 0 after.
  The test confirms that splitting gold by role beats team gold (15 and 25); the
  ordering is from the train fit (± 0.4-0.6 pp), and at 10 bottom only narrowly beats
  jungle (11.35 ± 0.61 vs 10.21 ± 0.62); at 25 only games still going.
  This confirms learned.md's "the bot laner's gold counts most" (scaling, team-gold
  state with roles) by a different model (held objectives in the state too, a per-sd
  scale, lab fold blocks and its own test look): same order and sizes within ~1-2 pp
  per 1000 (scaling: bottom 12.0 / 9.0 / 8.1 / 6.5 / 5.7, support 2.4 / 0.9 / 1.8 / 2.4
  / 3.2; here lower, as objectives take part of it). No second learned.md line
- Beyond the gold, damage share by role (5/5 folds at 15-25, test consistent but not a
  reading): at equal gold, a team whose bot laner or mid does more of its damage wins
  more (+1.3 to +1.8 pp per 10 points of share), one whose support does more wins less
  (-2 to -4 pp per 10 points). Kills minus deaths add nothing beyond gold. Description:
  damage share also records who had to fight and who was ahead
- Leverage per champion (does a champion turn its own gold into wins more than its
  role?): not detected at any minute (pre-declared test at 15 and 25: +0.00003 ± 0.00007,
  +0.00001 ± 0.00008; folds 0-2/5), nor for its kills or damage share. Not ruled out: a
  planted spread (sd across a role's champions) of 2 pp per 1000 gold was detected (5/5
  folds at 15-30, 4/5 at 10, also on dev-val), 1 pp only at 25-30, and the data's own
  upper 95% bounds on the spread are 4.4-7.0 pp at 15 and 3.1-10.8 at 25; recovery is
  poor even when detected (corr 0.57 at 15 for sd 1-2, fitted spread 0 in three roles
  at 25). Roles by contrast (gold-by-role baseline): at 15 bottom 8.2, top / jungle /
  mid 4.5-6.9, support ~0 pp per 1000; at 25 bottom 5.3, others 2.9-3.5, support ~0.
  "Which champions carry" is answered by role here, not champion: the bot laner's lead
  is the carry lead; champion differences below the bounds are possible
- Skill sensitivity per champion: not detected (test -0.00001 ± 0.00004; folds 0/5). One
  slope per role does help (5/5, test +0.00018 ± 0.00007). Plant: a champion-to-champion
  spread of 4 pp per log1p game (about ±10 pp from 0 to 10 games for a champion one sd
  off its role, an extrapolation: 76% of player-games have no earlier game) shows on the
  folds (0.00020 ± 0.00007, 5/5; ~3x the test's games) but not on dev-val (0.00014 ±
  0.00017), so at test size it is marginal; 2 pp not (5/5 folds positive, within noise).
  Experience = earlier ranked games we stored, not real mastery. With 16 days of history (24% of player-games with
  an earlier game on the champion), "high skill ceiling" champions smaller than that
  can't be seen; same answer as the per-champion skill slopes in "Player experience".
  Mastery: 0.5% of rows and taken after the game, not used. Rerun on a snapshot with
  more history (1954Z has 43% of test rows with an earlier game on the champion)
- Outcome spread: no champion makes its games measurably more or less decided at any
  minute (folds 2-3/5, around zero). Early vs late carries: the champion's value beyond
  the full state is real at every minute (5/5, test +0.0017 to +0.0023) and changes with
  the minute (scaling's curve); "late carry" is that curve, not a bigger lead value
- Shrinkage spread estimates (tau) above 0 are not evidence on their own: the null plant
  gave 1-3 pp in some role-minutes; the held-out step gain decides
- Causal reading: everything here is at equal team state and the same minute, so "being
  ahead" is held fixed; what remains is description, with the player's own skill
  (unmeasured) behind both the seat's lead and the win. The role ordering is likely
  partly cause (gold on a carry buys damage), the damage-share signs partly record
  fights. In-game stats: post-game lessons only (docs/production-key.md)

#### Win conditions by champion type, new pin (meiolol-61, 2026-10-14)

Does what a state is worth depend on the kind of champion, where single champions were
below detection? Type = the champion's first Data Dragon tag (Assassin, Fighter, Mage,
Marksman, Support, Tank), cell = role x type, terms after the champion steps above, each
the deviation from the baseline's common weight, ridge 1 (no shrinkage prior: 30 cells,
thousands of rows each): type x own gold lead, x team gold lead, x XP lead, x towers, x
dragons, x baron held. f694030; cuts now computed in carry as the lab does (checked: the
2055Z run printed c1's seven cuts exactly). Runs 20261013T233827Z-carry-types-2055
(validation) and 20261013T234133Z-carry-types-2253 (snap-20261013T2253Z, 216,644 train
games, 30% of player-games with an earlier game on the champion; cuts
1791399920616,1791440035991,1791471516870,1791503426611,1791538594699, dev
1791565305815, select 1791667302145). Folds and dev-val only, no test look.

| step (2253Z) | 10 | 15 | 20 | 25 | 30 | dev-val at 15 |
| --- | --- | --- | --- | --- | --- | --- |
| + type x own gold lead | 0.00005 ± 0.00003 [5/5] | 0.00005 ± 0.00003 [5/5] | 0.00002 ± 0.00003 [4/5] | 0.00003 ± 0.00003 [5/5] | 0.00001 ± 0.00003 [4/5] | 0.00004 ± 0.00006 |
| + type x team gold lead | -0.00001 [3/5] | -0.00001 [1/5] | -0.00002 [2/5] | -0.00002 [2/5] | -0.00002 [2/5] | -0.00001 |
| + type x XP, towers, dragons, baron (each) | -0.00002 to 0.00000 [0-3/5] | -0.00001 to 0.00001 [0-3/5] | -0.00002 to 0.00001 [0-4/5] | -0.00002 to 0.00000 [0-2/5] | -0.00010 to -0.00002 [1/5] | within ± 0.00004 |
| champion x own gold lead (as above) | 0.00004 ± 0.00004 [5/5] | 0.00001 ± 0.00002 [3/5] | 0.00001 [2/5] | -0.00000 [2/5] | -0.00008 [2/5] | -0.00001 ± 0.00005 |
| champion x experience, draft | -0.00001 ± 0.00001 [0/5] | | | | | -0.00004 ± 0.00005 |

On 2055Z (118k games) no type step cleared zero at any minute (0-4/5 folds). The carry
results above hold on 2253Z: gold by role over team gold +0.0031 to +0.0051 (5/5 every
minute), bot-most ordering (per sd at 15: bottom 14.8, jungle 9.3, mid 9.0, top 8.0,
support -0.1), damage share beyond gold as before (bot +1.7, support -3.1 per 10 points).

Type x own gold lead, every train game of 2253Z, win pp per 1000 own gold beyond the
role's slope (± 95%; 3,000+ rows), minute 15 [25]: bottom Mage -1.7 ± 0.5 [-0.6 ± 0.4],
Marksman +0.6 ± 0.1 [+0.1 ± 0.1]; jungle Marksman +1.5 ± 0.5 [+1.1 ± 0.4], Tank -0.6 ±
0.5 [-0.4 ± 0.3], Fighter +0.4 ± 0.2; middle Fighter +1.0 ± 0.3 [+0.5 ± 0.2], Assassin
+0.7 ± 0.3 [+0.2 ± 0.2], Mage 0.0 ± 0.2; top Fighter +0.2 ± 0.1, Tank +0.3 ± 0.3;
support Support (enchanters) +0.6 ± 0.3 [+0.5 ± 0.3]. Full table: carry-types.tsv in
the run dir.

Reading (reworded after meiolol-33's audit):
- Champion type (Data Dragon's first tag) doesn't measurably change what a seat's gold
  or the team's objectives are worth. Type x own gold lead shows a tiny gain on the new
  snapshot (+0.00005 nats/row, 5/5 folds at 10, 15 and 25 min) that 2055Z, a subset of
  the same games, doesn't show and dev-val doesn't confirm. Minutes share games, so 5/5
  at three minutes is not three replications, and the type cells' ridge intervals are
  not clustered by game (a bit narrow). It is ~10x under the ±0.5 floor, with no
  resample. Type x team gold, XP, towers, dragons, baron: not detected on either
  snapshot
- The per-type leanings above (bot mages low, jungle marksmen high) are description of
  train fits, not established effects
- No plant for type cells, so no size is ruled out; dev only, no test look, no
  learned.md line. carry doesn't read seat_stats.tsv, so the 2253Z seat-stat gap does
  not touch these runs

### How drafts win, 2026-10-14 (draftpath: meiolol-41 [36c2ab], then meiolol-draftpath)

Jacob (2026-10-13): understand draft and game state together, and how much each matters.
Scripts py/draftpath/ (Python on the gpu-box via lab-run --python; nothing ships): dp.py
(loaders, blocks, designs, fits), info.py and infogbdt.py (Q1), shape.py and
archsplit.py (Q2), gmed.py and gmedhist.py (Q3), comeback.py (Q4). Pinned
snap-20261012T2055Z: nn-export (match_id.txt added 13 Oct, run 20261013T225137Z-dp-nnx,
every other column byte-identical; checked against events.tsv: 130,229 games, durations
and winners all match), meiolol-41 [701543]'s state-export (659e017; a clean rebuild
gave byte-identical files), c1's teams.tsv (20261013T230628Z-comps-export-teams). Dev
only, no test look. Blocks as netcheck: folds 1-5 fit on played games before the block
and score it (every platform, 8,870 each; 5,855 on average with a timeline,
5,322-6,684), dev-val fits on splits 0-5 and scores 8,500 EUW1 games; one row per game,
so per-game pairs are clustered by game; "k/5" = better in k folds. Draft = platform +
signed champion-role one-hot (blue +1, red -1; summed for game-level targets), ridge or
logistic with L2 picked on the newest 10% of fit games. State at t (blue minus red):
gold lead by role, gold curve, XP, kills, towers, inhibitors down, dragons, soul point,
soul, elder, grubs, herald, baron. Train-time: everything; use-time: none (description
and lessons only).

Rerun on snap-20261013T2253Z (meiolol-73's re-cut: one time cut over every platform, no
EUW1 slice; folds 1-5 26,875 played games each, dev-val 35,834; nn-export with
match_id.txt, meiolol-state's export 20261014T004121Z-state-export-2253Z-recut, 363,472
games, order identical): Q1 and Q3 below are 2253Z, read against readings pre-declared
with meiolol-33 before any run and audited by meiolol-53 (recomputed from the run files).
Q1 and Q3 use games with a 15-minute timeline: 100,847 of 134,375 fold games, 26,263
dev-val. The other parts (GBDT state, archetypes and damage mix, Q2, gold-only,
player history, the per-champion table, Q4) were rerun on 2253Z as replication, not
pre-declared: description, read beside the 2055Z values they repeat.

#### Q1: information over time (info.py, run 20261014T011058Z-dp-info-2253Z)

Games with a 15-minute timeline still going at t, the same games for every model at that
minute. Log loss gain per game (nats, ± 95%), folds pooled, 5/5 folds in every cell:

| minute | games | draft alone | state alone | draft given state | state given draft | min-0 draft logit given state | its weight |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | 100,848 | -0.0041 ± 0.0006 | - | - | - | - | - |
| 5 | 100,848 | | -0.0497 ± 0.0019 | -0.0100 ± 0.0009 | -0.0556 | -0.0058 ± 0.0006 | 1.00-1.30 |
| 10 | 100,848 | | -0.1173 ± 0.0026 | -0.0164 ± 0.0011 | -0.1296 | -0.0057 ± 0.0006 | 1.06-1.41 |
| 15 | 100,847 | | -0.1913 ± 0.0031 | -0.0201 ± 0.0012 | -0.2073 | -0.0051 ± 0.0006 | 1.09-1.51 |
| 20 | 92,188 | -0.0044 | -0.2373 ± 0.0034 | -0.0214 ± 0.0013 | -0.2543 | -0.0042 ± 0.0006 | 1.06-1.52 |
| 25 | 76,456 | -0.0050 | -0.2778 ± 0.0039 | -0.0200 ± 0.0014 | -0.2928 | -0.0032 ± 0.0006 | 0.96-1.41 |
| 30 | 44,451 | -0.0070 ± 0.0012 | -0.2428 ± 0.0051 | -0.0188 ± 0.0018 | -0.2546 | -0.0026 ± 0.0007 | 0.83-1.22 |

Dev-val (every platform) agrees: draft alone -0.0052 ± 0.0013; draft given state -0.0114,
-0.0193, -0.0216, -0.0238, -0.0219, -0.0215 at 5-30. The last two columns: state plus
the minute-0 draft logit (out of fold) with a free weight; weight by block (1-5, dev), 1
= the whole pre-game edge still counts at equal state. Each role's pick given state
(drop that role's champions from draft given state): 0.0026-0.0043 at 10, 0.0031-0.0050
at 15, 0.0031-0.0052 at 25, 5/5 in every cell; middle and bottom largest, top and
jungle smallest. Draft alone by role at minute 0: support -0.0012 ± 0.0003, middle and
bottom -0.0010, top and jungle -0.0005 (4/5 and 5/5).

2055Z (pinned before, EUW1 dev-val, 29,278 fold games with a timeline; run
20261013T225917Z-dp-info-a): draft alone -0.0011 ± 0.0010 (4/5), draft given state
-0.0061, -0.0130, -0.0163, -0.0176, -0.0169, -0.0163 at 5-30. Draft alone is larger on
2253Z, but on other games and fit sizes, so that is not a measured growth.

A flexible state model (infogbdt.py, run 20261014T011238Z-dp-infogbdt-2253Z: LightGBM on
all 218 state-export columns as blue minus red, early stopping on val; its out-of-fold
logit the offset for the draft layer) now edges the linear state: GBDT minus linear
-0.0008 ± 0.0005 at 10 (4/5), -0.0011 ± 0.0005 at 15 (5/5), -0.0034 ± 0.0009 at 25 (5/5;
2055Z: level or worse). The draft given GBDT state: -0.0146 ± 0.0011, -0.0164 ± 0.0011,
-0.0157 ± 0.0013 at 10/15/25 (5/5), 79-89% of the linear figure (2055Z 84-88%); but
GBDT state + draft predicts worse than linear state + draft (+0.0026 ± 0.0006 at 15,
0/5; +0.0009 ± 0.0008 at 25), so part of the drop is the combined model fitting the
draft less well, not the state absorbing it: at most a fifth is absorbed, possibly less.
No net was tried.

Shuffled-draft controls (info.py --shuffle-draft 1, state and outcome fixed; pre-declared:
|mean| <= 0.0015 or an interval covering 0, else Q1 void): whole drafts permuted across
games (run 20261014T011115Z-dp-info-shuffle-2253Z) draft given state at 15 -0.000012 ±
0.000101 (dev-val +0.00014 ± 0.00021); permuted only within patch x platform, so the
draft keeps what its patch and platform imply (--shuffle-within, run
20261014T011132Z-dp-info-shufwithin-2253Z) +0.000006 ± 0.000096 (dev-val +0.00013 ±
0.00017). The gain needs the real pairing of draft and game; a leak through
champion-specific state fields is excluded by the code check (meiolol-33's audit:
state-export reads frames before t only), not by these controls. 2055Z's whole-draft
shuffle: +0.00015 ± 0.00024.

By comp archetype and damage mix (archsplit.py, run 20261014T013356Z-dp-arch-2253Z;
meiolol-94's teams.tsv 20261014T005458Z-comps-export-teams-2253Z; games where either team
is in the group; description only: archetypes showed no win effect in the comps sealed
check, the damage mix did): draft given state at 15 is largest with a late scaling team
(-0.0276 ± 0.0024) or an early dive/roam team (-0.0235 ± 0.0025), against -0.0155 to
-0.0206 for tank/engage, range/siege, AD early dive and enchanter/peel; at 25 late
scaling -0.0301 ± 0.0028, early dive -0.0243 ± 0.0029, the rest -0.0156 to -0.0204. The
2253Z k-means differs from 2055Z's (wave fixed), but the same two groups lead (2055Z:
-0.0226 and -0.0208 at 15). By magic share of the team's damage: under 20% -0.0277 ±
0.0052 at 15, 20-60% -0.0201, 60%+ -0.0192 ± 0.0037 (overlapping subsets).

Reading:
- Before the game the draft says little (0.0041 nats on 2253Z). Once the state is known
  it says much more: 0.010 at 5 min, 0.016 at 10, 0.020-0.021 from 15 to 25, 0.019 at
  30; about 5x the draft alone on the folds at 15 (-0.0201 vs -0.0041) and about 4x on
  dev-val (-0.0216 vs -0.0052). The draft and the state are complements, not
  substitutes: the draft's gain grows with the state, so "how much each matters" has no
  single split; for two groups Shapley gives the draft about 0.012 of 0.211 at 15 (6%),
  the state the rest
- Nothing is absorbed into gold: the pre-game draft edge keeps its full weight (about 1,
  often more) beside the state at every minute. Most of the draft's value at equal state
  is a different signal from its pre-game edge (0.0051 of 0.0201 at 15): which champions
  turn the same state into wins, the scaling section's effects summed over ten seats
- It grows from 5 to 20 minutes and is about as large at 30 (0.021 at 20, 0.019 at 30)
  among games still going, longer games only: scaling, not fading, within this window
- The draft's gain at equal state is largest in games with a late scaling or an early
  dive team, on both snapshots (overlapping subsets, not tested against each other;
  description)

#### Q2: what a draft decides (shape.py, run 20261014T011216Z-dp-shape-2253Z)

Draft-only models of the game's shape, held-out gain over the fit mean or base rate, %
of base loss (R2 for continuous targets), folds pooled (5/5 for every target; dev-val
beside): gold lead by role at 10/15/20 (state-export, blue minus red) and at 14
(nn-export), firsts (taken by blue; minute, either team), length, kill pace.

| target | folds | dev-val |
| --- | --- | --- |
| team gold lead at 10 / 15 / 20 | 6.9% / 5.9% / 4.5% | 7.1% / 6.0% / 4.2% |
| lane gold lead at 15: top, jungle, mid, bottom, support | 6.6, 7.5, 6.6, 6.4, 13.7% | 6.5, 7.5, 6.7, 6.3, 12.9% |
| support gold lead at 20 | 17.9% | 17.4% |
| first tower (side) / its minute | 4.2% / 5.9% | 4.2% / 6.4% |
| first dragon / minute | 2.5% / 7.4% | 2.4% / 6.5% |
| first herald / grubs / baron / inhibitor / blood (side) | 1.6 / 0.8 / 0.7 / 0.5 / 1.2% | 1.4 / 0.8 / 0.8 / 0.5 / 1.3% |
| first baron minute / inhibitor minute / first blood minute | 7.7 / 5.2 / 7.1% | 8.4 / 4.8 / 7.4% |
| game length | 5.3% | 5.1% |
| kills per minute / kills by 15 | 22.6% / 20.5% | 22.2% / 20.7% |
| win (all played games, 134,375) | 0.61% | 0.78% |

2055Z (EUW1 dev-val, 29,278 fold games with a timeline): the same within about a point
in every row (lane gold 6-7%, support 13-17%, kill pace 21.7%, length 5.0%, first tower
4.2%, win 0.25%); only dev-val's kill pace moved (13.7% EUW1, 22.2% every platform).

Champion-role effects (dev block's fit games; ridge-shrunk, ± 95% from 40 game
bootstraps; 500+ games): team gold lead at 15: Draven +1031 ± 111, Tryndamere middle
+1002 ± 298, Irelia top +975 ± 96, Nidalee +952 ± 110, Heimerdinger top +940 ± 157;
Kayle middle -942 ± 216, Smolder middle -935 ± 160, Kayle top -836 ± 133, Aurelion Sol
middle -827 ± 124, Smolder top -824 ± 211. First tower (pp, an average team's chance):
Heimerdinger top +18 ± 2, Illaoi +17 ± 2, Irelia top +13, Yorick +13; Kayle top -13 ±
1, Shen top -10, Vayne bottom -10, Aurelion Sol middle -10. First dragon: Mordekaiser
jungle +16 ± 3, Nunu +15 ± 2, Udyr +14; Nasus jungle -16 ± 4, Bel'Veth -10, Smolder
middle -9. First herald: Nunu +10, Heimerdinger top +8, Warwick +8; Smolder top -12,
Smolder middle -9, Yuumi -9. Length (sd of true effects 0.42 min): Bel'Veth -1.4 ± 0.2
min, Kalista -1.0, Yuumi -1.0, Hecarim -1.0; Teemo support +1.4 ± 0.3, Teemo jungle +1.2,
Brand jungle +1.2, Ziggs +1.2. Kill pace (sd 0.06 a minute): Milio -0.26 ± 0.01, Soraka
-0.21, Janna -0.19; Briar middle +0.17, Briar top +0.16, Nunu middle +0.15. Table:
shape-effects.tsv in the run.

By group, team view, model-free (folds' scored games; win minus the draft-only model's
chance, pp, by game length): late scaling teams are 778 gold behind at 15 and win -5.5
± 1.1 under 25 min, +3.3 ± 0.9 over 32; enchanter/peel -339, -2.1 ± 1.3 and +3.0 ± 1.2;
early dive/roam +597, +2.5 ± 1.1 and -2.1 ± 1.0; AD early dive +301, +2.4 ± 1.1 and -2.2
± 0.9; range/siege +217, +1.9 ± 1.1 and -0.7 ± 0.9; tank/engage flat. Overall every
archetype is within ±0.7 of its champions' chance. By damage mix: teams with under 20%
magic win -3.9 ± 1.3 below their champions' chance, 60%+ magic -2.8 ± 0.9, 20-60%
+0.3 ± 0.2 (dev-val -3.4 ± 2.4, -2.5 ± 1.6, +0.3 ± 0.5): the mix effect the comps
sealed check found, seen here beside the draft-only model. Length is an outcome, so
the length bands describe when each group's wins come, not a cause.

Reading:
- The draft decides the shape of the game far more than who wins it: 6-7% of each lane's
  gold lead (support 13-18%), 22.6% of the kill pace and 5.3% of the length, and of the
  first-tower side 4.2% of log loss against 0.61% for the winner (both relative log
  loss; the win row is all 134,375 played fold games, the gold rows 100,848 with a
  timeline). The base is the fit mean, so these gains include the platform one-hot (on
  2055Z platform alone gave 9.5% of the kill pace and 1.7% of the length, meiolol-33;
  not re-measured on 2253Z)
- Early and late drafts are real and big in gold (a typical one sd of champion effects
  is several hundred gold at 15), and early-gold champions take first towers, dragons
  and heralds; none of it shows up in the winner, which is Q3

#### Q3: mediation, what runs through the early lead (gmed.py, gmedhist.py)

Method per meiolol-research's decision (research/questions/draft-mediation, adopted by
meiolol-bd): interventional direct and indirect effects by g-computation on the
probability scale; the logistic difference method and the product of coefficients are
invalid at a 50% outcome and dropped (a first difference-method run,
20261013T225931Z-dp-mediate-a, is superseded). Draft score d = the draft-only logit out
of fold (K-fold inside fit games, the block's model for scored games), in sd units of
the fit games. Outcome model Q: logistic on state at t, d and d x state, fit on the
block's fit games going at t. Mediator: real states of the block's scored games with d
within 0.25 sd of the contrast point (no parametric generator). Contrast d = +0.5 vs
-0.5 sd: total = Q(d1, M1) - Q(d0, M0), indirect = Q(d1, M1) - Q(d1, M0), direct = Q(d1,
M0) - Q(d0, M0). Folds pooled by game count; ± 95% from 40 bootstraps (refit Q on
resampled fit games, resample scored games). 2253Z run
20261014T011149Z-dp-gmed-state-2253Z (joint state); 2055Z runs 20261013T231454Z-dp-gmed-state, 20261013T235130Z-dp-gmed-gold
(gold by role and curve only).

2253Z, games with a 15-minute timeline:

| minute | total, pp per sd | indirect (through the state) | direct (equal state) | observed total (model-free) |
| --- | --- | --- | --- | --- |
| 5 | +4.45 ± 0.38 | -0.55 ± 0.38 | +5.00 ± 0.11 | +4.82 |
| 10 | +4.65 ± 0.48 | -0.05 ± 0.46 | +4.70 ± 0.09 | +4.82 |
| 14 | +4.63 ± 0.57 | +0.31 ± 0.58 | +4.32 ± 0.09 | +4.82 |
| 20 | +4.46 ± 0.69 | +0.77 ± 0.68 | +3.69 ± 0.10 | +4.83 |
| dev-val, 10 / 14 / 20 | +3.8 / +4.1 / +4.4 (± 0.8-1.5) | -1.04 / -0.29 / +0.80 (± 0.8-1.5) | +4.9 / +4.4 / +3.6 | +4.2 / +4.2 / +4.2 |

Pre-declared reading (with meiolol-33; cells + or - past 2 bootstrap sd, minutes 10/14/20,
legs folds and dev-val): folds 0/0/+, dev-val -/0/0. Both legs 0 at 2 of 3 minutes and
neither "both legs - at 2+" nor "both legs + at 2+" fires, so: indirect not detected,
|indirect| under 2.3 pp per sd (largest |mean| + 2 sd over the six cells, dev-val at
20), against a total of about 4.6. The bound is about half the total, so this rules out
only a large indirect part. Each leg has one cell past 2 sd, with opposite signs (folds
+0.77 at 20, dev-val -1.04 at 10). Both legs drift from negative at 5 to positive at 20:
description, not a finding. Dev-val with EUW1 and the other platforms apart is printed
in the run (gmed.py 422a528) and not read (no EUW slice). Curve at 14 against the middle
fifth: worst fifth total -6.2 ± 0.8 (indirect -0.8 ± 0.8, direct -5.4), best fifth +5.4
± 0.6 (indirect +0.0 ± 0.6, direct +5.4). Skill bias at 14 (folds), k 1, 0.9, 0.75, 0.5:
indirect +0.31, +0.28, +0.25, +0.18; direct +4.32, +4.53, +4.87, +5.46.

2055Z (EUW1 dev-val), for the record:

| minute | total, pp per sd | indirect (through the state) | direct (equal state) | observed total (model-free) |
| --- | --- | --- | --- | --- |
| 5 | +3.39 ± 0.52 | -0.79 ± 0.52 | +4.18 ± 0.24 | +4.54 |
| 10 | +3.38 ± 0.95 | -0.79 ± 0.97 | +4.18 ± 0.20 | +4.54 |
| 14 | +3.71 ± 1.02 | -0.32 ± 1.02 | +4.03 ± 0.22 | +4.54 |
| 20 | +3.32 ± 1.26 | -0.20 ± 1.23 | +3.52 ± 0.17 | +4.65 |
| dev-val, 10 / 14 / 20 | +6.0 / +6.1 / +7.0 (± 1.9-2.5) | +1.6 / +1.9 / +3.3 (± 1.9-2.5) | +4.5 / +4.2 / +3.7 | +7.0 / +7.0 / +8.2 |

Gold alone as the mediator (run 20261014T011301Z-dp-gmed-gold-2253Z): the same within
0.4 pp (folds indirect -0.10 ± 0.45 at 10, +0.22 ± 0.54 at 14, +0.57 ± 0.66 at 20;
dev-val -1.09, -0.50, +0.39). Observed total = win rate near +0.5 sd minus near -0.5 sd;
g-computation's total sits within about 0.4 pp of it on the folds.

Player skill (gmedhist.py, run 20261014T012247Z-dp-gmed-hist-2253Z; internal scope; Q is
cross-fitted over all five folds, so it fits on later folds too, not forward): a history
score per game h = logit(win-exp) - logit(win-ratings), meiolol-51's 2253Z candidate
preds (20261014T003827Z-c-exp, 20261014T004141Z-c-rat; out of fold, fitted on games
before each block, inputs from games ended before each game), with h and h x d,
mediator draws matched within h tercile. Without vs with h, same games: indirect at 10
-0.15 ± 0.48 vs -0.17 ± 0.50, at 14 +0.26 vs +0.22, at 20 +0.69 vs +0.62; direct +4.86
vs +4.76, +4.39 vs +4.31, +3.66 vs +3.61. Measured history moves nothing beyond 0.15 pp
(sd 0.21 logit; 2055Z the same with sd 0.15).

Per champion-role (gmed.py --champions, run 20261014T011323Z-dp-gmed-champ-2253Z; dev
block's fit games, train-fit description, 20 bootstraps): swap champion j for its role's
average pick (draft weight to 0, d minus j's draft weight) with each game's real state
shifted by j's estimated state effect (ridge of every state column on the draft);
indirect = through that state shift, direct = at the shifted state; j's team's view, pp.
Spread of true effects (bootstrap noise removed) at 15 by role, total / indirect /
direct: top 1.8 / 1.9 / 2.6, jungle 1.4 / 2.4 / 2.6, middle 2.5 / 2.6 / 3.5, bottom 1.8 /
2.3 / 3.2, support 2.5 / 1.8 / 3.2; correlation of indirect and direct -0.50 to -0.81 by
role and minute (10, 15, 20; 2055Z -0.68 to -0.82). Examples at 15 (indirect, direct,
total; gold shift at 15):

| | champion | indirect | direct | total | gold at 15 |
| --- | --- | --- | --- | --- | --- |
| early, give it back | Draven bottom | +7.0 ± 0.6 | -8.1 ± 1.1 | -1.2 | +918 |
| | Irelia top | +5.2 ± 0.6 | -3.6 ± 1.1 | +1.6 | +862 |
| | Pyke support | +5.3 ± 0.5 | -4.6 ± 0.8 | +0.7 | +804 |
| | Hecarim jungle | +5.1 ± 0.6 | -5.6 ± 0.7 | -0.5 | +608 |
| | Irelia middle | +5.3 ± 0.7 | -7.2 ± 0.7 | -2.0 | +733 |
| late, win it back | Kayle top | -5.8 ± 0.9 | +7.8 ± 1.5 | +2.0 | -873 |
| | Smolder bottom | -6.0 ± 0.7 | +5.8 ± 0.9 | -0.2 | -733 |
| | Bel'Veth jungle | -7.0 ± 0.8 | +7.7 ± 1.2 | +0.7 | -918 |
| | Aurelion Sol middle | -6.7 ± 1.0 | +8.3 ± 1.3 | +1.6 | -837 |
| | Kassadin middle | -6.0 ± 0.7 | +8.1 ± 1.5 | +2.1 | -743 |
| direct only | Rammus jungle | -2.0 ± 0.9 | +6.1 ± 1.2 | +4.1 | -141 |
| | Ornn top | -3.3 ± 0.5 | +5.5 ± 0.9 | +2.3 | -475 |
| | Mel bottom | +4.2 ± 1.2 | -7.8 ± 1.6 | -3.6 | +496 |
| | Tristana middle | +1.8 ± 1.0 | -5.1 ± 1.6 | -3.3 | +329 |

Same champions as 2055Z, every sign kept; Mel bottom now has a clear indirect part.
Cross-checks: the direct effect at 15 against meiolol-61's champion shift beyond the
full state (carry-table.tsv, 20261013T223040Z-carry-a, 2055Z) correlates 0.91 on both
snapshots (234 champion-roles on 2055Z, 337 on 2253Z); the same champions lead the scaling section (Kayle, Bel'Veth, Aurelion Sol,
Kassadin above, Pyke, Draven, Irelia below). Indirect vs 61's own-gold leverage
(lane_raw): 0.07 (none; leverage was not detected anyway). meiolol-08's "the
draft-predicted gold edge carries no win" is this table summed: per sd of the draft
score the indirect part is not detected at 10-20, because early and late champions
cancel.

Reading:
- A champion's win effect is two large opposite parts: what it does to the early state
  (early-gold champions' teams are ahead, which is worth up to ~7 pp) and what it does
  at equal state (the same champions win less from that state, by about as much). The
  net, the champion's win rate, is half the size of either part. This is why the draft
  predicts gold (Q2) but not the winner
- For the draft as a whole, no part of its +4.6 pp per sd was detected running through
  the early lead (2253Z, folds and every-platform dev-val): under 2.3 pp per sd, so only
  a large indirect part is ruled out. 2055Z's positive dev-val (EUW1 only) did not
  repeat on every-platform dev-val. The bootstrap holds d and the L2s fixed, so the
  intervals are slightly narrow
- The per-champion table is the dev block's fit games (train-fit, not held out). The
  anti-correlation survives noise removal (about -0.9 for top), but kit gold (Draven's
  passive, Pyke's ultimate, support gold items) can read as "early, gives it back"
  through how gold measures being ahead
- Description, not cause: the state at t also carries who plays better, so "direct" is
  the draft's edge among games equally far ahead, and part of each champion's early lead
  may be who picks it. Measured history moved nothing (weak measure), and scaling the
  state's weight down only shrinks the indirect part. Gold and objectives measure "being
  ahead" with noise, which biases the indirect part toward 0: the indirect share is a
  lower bound

#### Q4: comebacks, mixed teams, lane-only matchups (comeback.py)

Run 20261014T011344Z-dp-comeback-2253Z (2055Z: 20261013T230201Z-dp-comeback-a). Per
block from fit games only: each champion-role's effect on the gold lead at 15 (early_j),
its draft weight at equal state at 25 minus at 10 (late_j, log-odds) and the state+draft
model at 15 (DS15) as offset; team late z = blue minus red sum of late_j in fit-team sd.
Pooled over the folds' scored games, sandwich se (one row per game), sign by fold.

- Comebacks at 15 (offset DS15): team gold lead x late z +0.0045 ± 0.0059 log-odds per
  1000 gold x sd (+0.07 pp; signs +++++, 2055Z -0.07 with -+---); late z beyond DS15
  +0.12 pp; gold x early-gold draft +0.05 pp. Teams 1,500+ gold behind at 15 by late
  tercile: won 16.6%, 18.9%, 21.1% against DS15's 17.3%, 18.8%, 20.8% (differences
  -0.6 ± 0.5, +0.1 ± 0.5, +0.3 ± 0.5 pp; 23,450 teams each); dev-val -0.2, +0.1, +0.4
  (± 0.9). Late drafts do come back more from behind, but almost exactly as much as
  their equal-state value says: an extra comeback slope not detected (under about 0.16
  pp per 1000 gold per sd for this lateness measure; late_j is a difference of two ridge
  weights, noisy, which biases interactions toward 0)
- Two early champions on a late team (offset: draft-only): early champions x team late z
  +0.20 ± 0.29 pp, "2+ early champions on a team with late z > 0.5" -0.25 ± 1.0 pp;
  dev-val -1.0 ± 2.1. Not detected
- Lane matchups (per lane, canonical champion pair one-hot beside the draft, 30+ fit
  games, own L2 on inner val): lane gold at 14 MSE gain top 1.10% (5/5), middle 0.55%
  (5/5), bottom, support, jungle 0.03-0.08%; win log loss: top -0.00021 ± 0.00006 (5/5;
  dev-val -0.00033 ± 0.00014), bottom -0.00010 ± 0.00006 (5/5), middle -0.00008 ±
  0.00006, support -0.00005, jungle 0. Matchups beyond the two champions move the lane's
  gold, top most; on the win, top lane pairs now clear 0 on the folds and dev-val but
  stay about half the folds' noise floor (~0.4 milli-nats, the nets' 2253Z A/A; this
  model's own floor not measured): not confirmed (2055Z: -0.00007 ± 0.00005). The same
  signal as learned.md's audited matchup line (top vs top the largest detected matchup,
  about 2.5 pp spread, meiolol-1d), seen here beside the draft and in lane gold, so a
  pre-declared check would be a replication, not a new discovery

#### Summary for Jacob

The draft decides how a game goes far more than who wins it. It sets about 7% of each
lane's gold lead (support about 14%), a fifth of the kill pace with the region, and
which side takes the first tower and dragon, but well under 1% of the winner. Each
champion has two opposite effects: early champions put their team ahead, then win less
from equal states (Draven, Irelia, Pyke, Hecarim). Late champions fall behind, then win
more from equal states (Kayle, Smolder, Bel'Veth, Aurelion Sol; dev block, train-fit).
These cancel, so draft win rates are small. Once you know the state, the draft is worth
far more than before the game (about 5x on the folds, 4x on dev-val at 15 min), rising
to 20 minutes and about as large at 30 among games still going; a flexible state model
takes at most a fifth of that. For the draft as a whole, no part of its edge was detected running through
getting ahead early, though the data rule out only a large part (over about half). No
draft comes back from behind beyond its equal-state value, mixing early and late picks
costs nothing measurable, and lane counters move lane gold with at most a tiny win part
(top lane a lead, under the noise floor). Everything is 2253Z: Q1 and Q3 pre-declared
and audited (meiolol-53), the rest replication of 2055Z, every reading repeated. Dev
only, no test look.

### Early and late champions, 2026-10-14 (meiolol-lean)

Ships "How drafts win" Q3 per champion as a champion page line, computed on the box.
`meiolol lean` (src/lean.zig): played games (900 s+) reaching 15:00 with a compact
timeline, one row per game. Gold: team gold lead at 14 min (blue minus red) = fit mean
+ sum of blue champion-role effects - red's, Gaussian backfitting. Win: logistic of the
state at 20 min (objectives.zig's lead and held: team gold, gold curve, XP, towers,
inhibitors, dragons, soul point, soul, elder, grubs, herald, baron) + the same additive
champion-role effects in log-odds, IRLS backfitting; games still going at 20. Both
shrunk toward the role's average pick by a method-of-moments prior per role, one role at
a time (Gauss-Seidel), 12 passes. Clear: 200+ games at 20 and |effect| >= 2 posterior
sd. Early: gold clear > 0 and win clear < 0; late the reverse. Shown in pp (log-odds x
25) and gold, ± 1.96 sd. Check: `meiolol lean --check --prior-rows 100 --cuts
1791526007256,1791574830751,1791628507185,1791670472926,1791711141905,1791741249959,1791795719197`
on snap-20261013T2253Z, games before T only (236,227), folds 1-5 fit before their block,
dev-val before D. No test look.

Prior floor: with analysis.Prior's own floor (cells of 10+ games) the jungle and bottom
spreads came out 0 (the many rare off-role picks' noise swamps the moment estimate;
run 20261014T212022Z-lean-check-2253Z) and support's was inflated (10.7 pp). Chosen on
the dev fit's spreads alone, before any held-out score of it: cells of 100+ games set
the prior (20261014T213205Z-lean-check-prior-2253Z: spreads top / jungle / mid / bottom
/ support 4.6 / 3.7 / 5.3 / 4.2 / 7.2 pp at 100+, 4.0 / 4.2 / 5.8 / 4.8 / 6.3 at 500+).
The 500 floor (20261014T213648Z-lean-check-p500-2253Z) matches 100 within 0.0001 nats
everywhere below.

Run 20261014T213709Z-lean-check-p100-2253Z. Gains over the state alone (win, nats per
game) and over the mean (gold, % of its MSE), ± 95%; calibration = slope of each
block's own per-cell estimate (one Newton step from the fit) on the fitted effect,
information-weighted (1: the shrunk sizes hold); same sign = clear cells whose block
estimate has the fitted sign, against the count expected if the fit were the truth:

| | folds 1-5 (92,188 games at 20) | dev-val (24,135) |
| --- | --- | --- |
| win, every effect | 0.02203 ± 0.00131 (5/5) | 0.02443 ± 0.00259 |
| win, clear effects only (what the site shows) | 0.02110 ± 0.00128 (5/5) | 0.02364 ± 0.00254 |
| win, cost of hiding the unclear | -0.00092 ± 0.00027 | -0.00078 ± 0.00047 |
| gold, every effect / clear only | 6.15% ± 0.30 / 5.94% ± 0.30 (5/5) | 6.27% / 6.04% ± 0.60 |
| calibration, win / gold | 1.02 ± 0.03 / 0.99 ± 0.02 | 1.05 ± 0.06 / 0.99 ± 0.05 |
| clear win effects, same sign | 815 / 907 (819 expected) | 197 / 212 (191.5) |
| clear gold effects, same sign | 1031 / 1132 (1033.5) | 233 / 258 (235.6) |
| early or late, both parts same sign | 583 / 656 (567 expected) | 138 / 153 (132.9) |

Dev fit (209,964 games before D): 429 champion-roles with 200+ games at 20; gold clear
253, win clear 212, early 77, late 76 (top 14 / 16, jungle 16 / 17, mid 18 / 19, bottom
7 / 9, support 22 / 15). Gold spread 276-372 by role. Against draftpath's per-champion
g-computation (20261014T011323Z-dp-gmed-champ-2253Z, 327 champion-roles with 500+
games): win vs its direct part r 0.94 at 15, 0.96 at 20; gold vs its gold shift r 0.98,
0.93; our early/late classes have its sign pattern (indirect +, direct - for early) in
93% and 90%. Across champion-roles gold and win correlate -0.74 (-0.71 to -0.82 by
role). Examples (dev fit, ± 95%): Draven bottom +897 ± 74 gold, -7.6 ± 1.5 pp; Pyke
support +747 ± 63, -10.8 ± 1.2; Irelia mid +643, -10.7 ± 1.7; Hecarim jungle +425, -6.4
± 1.4; Kayle top -824 ± 102, +14.1 ± 1.9; Bel'Veth -941, +14.3 ± 1.8; Aurelion Sol mid
-827, +13.2 ± 2.0; Smolder bottom -703, +9.3 ± 1.2; Jinx -243 ± 37, +6.5 ± 0.7.

Site-mode run on the snapshot (20261014T214444Z-lean-site-2253Z): 286,721 games (every
region, its last 30 days), 34 s, peak RSS 2.7 GB (SQLite's mmap of the DB files; the
fit itself is tens of MB), 859 rows.

Reading:
- Each champion-role's early lean (team gold at 14) and its win from an even game at 20
  replicate on newer games at the sizes fitted, and the numbers the site shows (clear
  ones only) carry nearly all of the gain. The two parts are opposite for most
  champions, as Q3 found; 153 of 429 champion-roles are clearly early or late
- Description, not cause: who picks a champion and the rest of the draft beyond the
  additive terms are not held fixed, and "even" is even by these measures (kit gold such
  as Pyke's and Draven's reads as "ahead"). The site says so and never makes it a pick
  reason (docs/production-key.md)
- No test look; the site fits on the box's last 30 days, every region

### Champions into comps, 2026-10-17 (champcomp)

Question (Jacob, 17 Oct): beyond each champion's own strength, does a champion win more
or less into some enemy comps (more melee, more CC, more AP) or beside some allies, and
can we say why for a given draft? Comp discovery (above) asked it of whole teams and
found only the damage mix; the Rammus check asked it of one champion and one trait and
missed. This asks it of every champion-role at once, with ~3x the games.

Data: snap-20261017T1320Z (made 17 Oct, every game on the box then). Seat stats and comp
stats come from raw summaries, which the box keeps only since 15 Oct 12:25Z, so lines
for older games are merged in from snap-20261014T2137Z (seat and comp stats),
snap-20261013T2253Z and snap-20261012T2055Z (comp stats), first source wins per seat;
14 Oct 21:37Z to 15 Oct 12:25Z has none (in the raw archive only). Profiles need only
enough rows per champion-role, so missing seats thin them, they do not bias them.

Method: `meiolol-lab champcomp SNAP` (src/lab/champcomp.zig), built with
-Dcand=src/lab/cand/win-ratings (its chance is the offset). Profiles are comps' (fit
games only, won and lost halves averaged, shrunk to the role by 20 rows, z within role).
Eight traits of a set of seats: AP share of its damage (magic damage over all), melee
count (base attack range under 300), CC (cc and immobilisations per minute), engage
(immobilise and knock-up kills), dive (dive kills, outnumbered kills), tankiness (tank
share, damage taken), sustain (own and ally healing), early power (gold and lane gold at
14, early takedowns). Effects in win pp per sd at 50%.
- Team terms: each team's enemy five and own five (16 features, standardised on fit
  teams), one logistic step from the offset over every team. Sums of profiles are linear
  in the champions, so ratings should hold most of this (comps); it is here so that a
  team-wide slope is counted once, not once per seat
- Champion terms: each seat sees the enemy's five and its four allies (16 features).
  Every seat of a team shares the enemy's traits, so per seat only a champion's
  difference from its role's average is identifiable (a constant added to every top
  laner and taken from every jungler predicts the same). Per champion-role with 300+ fit
  games: one logistic step from the offset (ratings plus team terms), features centred
  on the cell's own mean (its overall win rate stays with ratings), model-based se; per
  role and feature the precision-weighted mean comes off and the deviations are shrunk
  to 0 by empirical Bayes, spread by DerSimonian-Laird and 0 unless its Q test passes at
  1% (chi-squared, k - 1). Smaller cells get no terms. Two passes (the second's offset
  adds the other nine seats' terms). A normal prior shrinks a lone true effect hard (a
  single planted cell came out with no spread to borrow), so detection also has a raw
  count: deviation z = (slope - role mean) / se, Benjamini-Hochberg at 5% over every
  cell and feature
- Breakdown of a seat in a draft: its 16 parts, deviation x (feature - cell centre), in
  pp: what the champion gains or loses into this comp beyond its role's average
- Smoke runs on planted data (snap-20261014T2137Z, winners re-drawn): a first version
  shrank each cell to its role's mean and so counted a team-wide slope five times (log
  loss 0.06 worse than ratings); a second used sandwich se and an unweighted moment
  spread, which came out positive with no spread planted (champion terms 0.0011 worse).
  A third (model-based se, DerSimonian-Laird) still cost 0.00021 ± 0.00011 on the folds
  with nothing but one cell planted: chance-positive spreads let noise through, hence
  the Q gate. The planted cell (Milio support, 2 pp per sd of enemy melee, 21k games)
  came back raw at 1.17 ± 0.47, shrunk to 0. With the gate (run
  20261017T135009Z-champcomp-plant-smoke4): folds +0.00007 ± 0.00006 (team terms about
  half of it), dev-val -0.00000 ± 0.00008, 0 clear and 0 BH passes of 7,456. All before
  any run on real outcomes

Splits: comps' (harness.Cuts). Fold k fits on dev games before its block (ratings
in-sample there, fitted on those games) and scores the block with ratings fitted on the
same older games; dev-val fits on every dev game. Paired per-game log loss against
ratings alone. Reported effects: the dev-val fit. No test look.

Pre-declared (17 Oct, before any run on real outcomes; plants re-draw the winners, so
they don't count as looks):
- H1, the terms predict: pooled over folds 1-5, the per-game log loss difference vs
  ratings has its 95% interval below 0 and is below 0 in at least 4 of 5 folds.
  Confirmed if dev-val's mean is also below 0; "folds only" otherwise
- H2, more clear effects than noise: clear = |posterior deviation| / posterior sd >=
  2.58 on the dev-val fit, cells with 300+ fit games. Detected if the real count is more
  than twice the larger of two controls' counts, for the posterior count and for the BH
  count (H2b) each: --permute-profiles 1 (profiles shuffled among a role's champions:
  traits become arbitrary champion groupings, so this also absorbs plain matchup effects
  ratings miss) and --shuffle-traits 1 (each seat's features from another seat of its
  role: no link left)
- H3 for BH passes too (H3b): same rule
- H3, clear effects replicate: of the cell-features clear in fold 3's fit (games before
  bounds[2]), more than half have the same sign in a raw refit on the newer dev games
  ([bounds[2], D); slope minus that refit's role mean), one-sided binomial at 5%; mean
  signed z reported
- H1 is reported split as well: team terms over ratings, then champion terms over that
- Power: plants champ_melee 2 and 4 pp per sd on the 50th most common champion-role and
  2 on the 5th (synth.zig) on this snapshot, read as the recovered deviation, raw z and
  BH pass (the role mean takes a share of a single champion's plant, about 1 / the
  role's cells). Raw se per
  cell is about 50 / sqrt(games) pp per sd for one feature alone (more beside the other
  15): ~0.5 at 10,000 games, ~1 at 2,500
- Reported only: Rammus jungle into enemy melee and AP share (fresh games since 14 Oct
  are now in the fit), and the role means (team-level trait effects, as comps tested)
- Site: nothing from this until read; what it could show goes in the reading

Data as run: 832,841 games, 812,306 packed (ranked solo, roles complete), 15 platforms;
seat stats on 607,805 of them after the merge (box's own 249,397), comp stats on
731,618. Cuts (ms): b_0-b_4 1791646802503, 1791712005644, 1791767687406, 1791831702945,
1791909023875, D 1791975252100, T 1792057078076. Folds score 60,022-60,023 games each
(fits 300,113 to 540,203), dev-val 80,031 (fit 600,226). Built at b332b86 (0ad6bee for
the win-comp offset), ~3 min a run.

| run | folds 1-5 vs offset (nats/game) | better | dev-val | clear (posterior) | BH 5% | replicated (clear / BH) |
| --- | --- | --- | --- | --- | --- | --- |
| real, 20261017T144201Z-champcomp-1320Z-real | -0.00139 ± 0.00018 | 5/5 | -0.00194 ± 0.00040 | 47 of 8,352 | 28 | 25/25 (mean z 2.44) / 13/14 |
| team terms alone (same run) | -0.00001 ± 0.00004 | | -0.00003 ± 0.00011 | | | |
| permuted profiles, ...-permuted | +0.00012 ± 0.00006 | 0/5 | +0.00000 ± 0.00011 | 1 | 0 | 0/0 |
| shuffled traits (Mac), 20261017T152101Z-...-shuffled | +0.00002 ± 0.00003 | 1/5 | -0.00002 ± 0.00005 | 0 | 0 | 0/0 |
| post hoc: offset win-comp (mix), 20261017T152341Z-...-wincomp | -0.00094 ± 0.00019 | 5/5 | -0.00172 ± 0.00041 | 37 | 24 | 21/23 / 11/12 |

Plants (winners re-drawn; recovered raw slope and z on the dev-val fit):

| plant | champion-role (games) | raw | z | BH | shrunk deviation |
| --- | --- | --- | --- | --- | --- |
| 2 pp per sd enemy melee, cell 50 | Katarina middle (35,398) | +1.00 ± 0.37 | 2.6 | no | 0 |
| 4, cell 50 | Katarina middle | +2.97 ± 0.37 | 7.9 | yes | 0 |
| 2, cell 5 | Thresh support (89,044) | +1.89 ± 0.24 | 7.6 | yes | +1.54 ± 0.22 (clear) |

So a single champion's effect is found by the BH count from about 4.3 raw se: raw se
is about 69 / sqrt(games) pp per sd, so ~3 pp at 10,000 games, ~1.6 at 35,000, ~1.0 at
90,000. The shrunk count is stricter: it needs its role and trait to show a spread over
many champions (26 of 80 role and trait pairs passed the Q test on the real dev-val fit),
so a lone effect in a role with none (Katarina at 4 pp) stays at 0.

Pre-declared readings:
- H1 confirmed: -0.00139 ± 0.00018 on the folds, every fold, dev-val -0.00194 ± 0.00040;
  all of it is champion terms (team terms -0.00001 ± 0.00004). For scale, eval's tuned
  pairs and matchups over champion base rates: -0.0024 ± 0.0004 (17 Oct)
- H2 and H2b detected: 47 clear and 28 BH passes against at most 1 and 0 in the controls
- H3 and H3b: 25 of 25 clear effects fitted before bounds[2] kept their sign on the
  newer 180,068 dev games (one-sided binomial p < 1e-7), mean signed z 2.44; 13 of 14 BH
  passes
- Rammus jungle (14,213 games): enemy melee raw -0.56 ± 0.59 pp per sd, not detected
  (the data still allow about -1.7); AP share +0.07 ± 0.46; tankiness -1.4 ± 0.6 raw
  (shrunk -0.7 ± 0.4, not clear)
- Role means and team terms: all within ±0.3 pp per sd (team.tsv, roles.tsv)

Clear effects by feature (posterior / BH): ally AP share 15 / 6, enemy tankiness 11 / 6,
enemy AP share 8 / 6, ally tankiness 4 / 0, enemy dive 4 / 3, enemy melee 3 / 3, ally
dive 2 / 0, enemy early power 1 / 1. Largest (shrunk, pp per sd of the trait, ± 95%):

| champion-role | trait | shrunk | raw | games |
| --- | --- | --- | --- | --- |
| Malphite top | enemy AP share | -1.87 ± 0.46 | -2.28 ± 0.51 | 44,091 |
| Malphite middle | enemy AP share | -1.73 ± 0.87 | -3.92 | 5,816 |
| Galio middle | enemy AP share | +1.49 ± 0.60 | +2.17 | 23,639 |
| Kassadin middle | enemy AP share | +1.19 ± 0.71 | +2.04 | 14,119 |
| Vex middle | enemy AP share | -1.13 ± 0.63 | -1.47 | 20,629 |
| Nautilus support | enemy tankiness | -1.34 ± 0.52 | -1.55 | 61,274 |
| Lillia jungle | enemy tankiness | +1.40 ± 0.64 | +2.02 | 31,129 |
| Brand support | enemy tankiness | +1.46 ± 0.80 | +2.23 | 19,320 |
| Senna support | enemy tankiness | +1.27 ± 0.67 | +1.69 | 31,536 |
| Viktor middle | enemy tankiness | +1.02 ± 0.54 | +1.22 | 53,967 |
| Rengar jungle | enemy tankiness | -1.10 ± 0.73 | -1.85 | 20,444 |
| Lulu support | enemy dive | +1.48 ± 0.61 | +1.83 | 67,218 |
| Malzahar middle | enemy dive | +1.10 ± 0.71 | +1.73 | 35,723 |
| Yasuo middle | enemy dive | -1.02 ± 0.61 | -1.49 | 57,290 |
| Syndra middle | enemy melee | -1.12 ± 0.57 | -1.54 | 40,151 |
| Lissandra middle | enemy melee | +1.01 ± 0.63 | +1.64 | 30,354 |
| Yone middle | ally AP share | +1.15 ± 0.44 | +1.16 | 54,803 |
| Yasuo middle | ally AP share | +1.05 ± 0.44 | +1.05 | 57,290 |
| Qiyana middle | ally AP share | +1.14 ± 0.71 | +1.55 | 15,944 |

BH passes the shrinkage left at 0 (their role and trait show no spread): Wukong jungle
into melee +1.44 ± 0.64 raw, Yasuo middle into early power +1.38 ± 0.64, Fiddlesticks
jungle with ally CC -3.0 ± 1.5; and small cells (Rumble jungle into engage, 802 games;
Lillia top, 468) that are likely noise at that size.

Examples (examples.tsv, the scored game where the champion's own term is largest):
Malphite top into Zac, Shyvana, Ahri, Swain, Alistar -7.7 pp beyond his role's average
(enemy AP share -4.9, enemy tankiness -2.4); Galio middle into Rumble, Sejuani, Akali,
Viktor, Xerath +5.8 (enemy AP share +5.1); Lulu support into Renekton, Master Yi, Locke,
Kalista, Pantheon +7.9 (enemy dive +6.1); Nautilus support into Trundle, Sejuani, Yasuo,
Sion, Swain -8.1 (enemy tankiness -8.4). Extreme comps by construction: typical drafts
move a champion by a fraction of that.

Reading:
- A champion's fit with the comp predicts the winner beyond champion strength, on
  newer games, in every fold, with both controls at zero. Most effects match the kits:
  Malphite's armour is wasted into magic damage, Galio's and Kassadin's magic shields
  pay off into it; percent-health and tank-shredding damage (Lillia, Brand, Senna,
  Viktor) gains into tanky teams while Nautilus (another frontliner, little damage)
  loses; Lulu's peel gains into divers, Yasuo loses to them; Lissandra's and Syndra's
  answers to melee point opposite ways (Lissandra up, Syndra down)
- Ally AP share is mostly the damage mix seen per champion: AD carries (Yone, Yasuo,
  Qiyana, Viego, Graves, Master Yi, Zed) gain more from AP allies than their role's
  average, AP junglers (Zac, Malphite) less. With win-comp's team mix in the offset these
  shrink by about a third (Yone 1.15 to 0.71) and the gain is -0.00094 ± 0.00019 (5/5),
  so most of it is not the mix
- Not tested: whether this adds beyond pair and matchup terms (eval's tuned model, the
  additive v2). Some of "Malphite into AP" is surely specific matchups; the permuted
  control (arbitrary champion groupings) gained nothing, so the traits carry what
  groupings don't, but the overlap with a full matchup table is open
- Description, not cause: profiles come from end-of-game stats of who played the
  champions; "into a tanky team" means into champions whose games look tanky
- Dev only, no test look; one snapshot. The effects files feed the admin Models tab
  (effects-champcomp-enemy.tsv, -ally.tsv)

What the site could show (not done; production-key.md rules first): on a champion page,
the clear effects as plain lines with their range ("Malphite top: about 2 points worse
per step towards a magic-damage enemy team"); in the app's suggest reasons, a seat's
breakdown into this draft (profiles.tsv and champcomp.tsv give every part) when its
total is clear, beside the existing matchup reasons. Both need the deviations to be
refitted on the box (or shipped as a file) and an eval-side check against the shipped
pair terms first

#### Beyond the shipped model (declared 2026-10-17 ~16:20Z, before the run)

Same champcomp, snapshot and folds; offset win-draft (src/lab/cand/win-draft: the
shipped score.zig model, base prior 50, pair prior 3200, term weights, every ally pair
and cross-team matchup counted on the fit games). Reading: folds pooled champion terms.
Comp terms add beyond the shipped model when the pooled interval excludes 0 and they are
better in at least 4 of 5 folds; dev-val reported only. Also reported: clear and BH
counts, and how many of the 47 clear effects over ratings stay clear (same sign, z over
2.58) here. Ship nothing on a miss

Result (run 20261017T160236Z-champcomp-1320Z-windraft, Mac): pass. Folds pooled
-0.00068 ± 0.00012 nats/game, better in 5 of 5 (team terms -0.00001 ± 0.00005); dev-val
-0.00072 ± 0.00025; clear 22 of 8352, BH 9; replication 8/8, BH 3/3. About half the gain
over ratings (-0.00139) is in the shipped pairs and matchups. All 22 clear effects were
among the 48 clear over ratings, same sign, at 60-90% of their size; none new. Kept:
enemy AP share (Malphite top -1.14 ± 0.21, mid -1.16; Galio mid +1.04; Kassadin +0.94;
Vex -0.82), enemy tankiness (Lillia jungle +0.96, Brand support +0.93, Senna +0.91,
Nautilus -0.81) and ally AP share (Yone mid +1.04, Qiyana +1.03, Yasuo +0.97, Rengar
+0.97, Viego +0.79, Master Yi +0.77, Yone top +0.72, Zed +0.69, Graves +0.67; Malphite
jungle -1.38, Zac jungle -1.11, Viktor bottom -0.96, Mordekaiser top -0.71). Gone: dive,
melee, CC and sustain effects (Lulu, Malzahar, Yasuo into dive, Lissandra and Syndra into
melee), so those were specific matchups. The duo weight (0.765 under a 3200 prior) leaves
ally pairs mostly unexplained, which is where the ally AP terms live

#### Armour tanks into AD (kit prior; declared 2026-10-18 ~00:55 BST, before the run)

Question (Jacob, 18 Oct): Rammus and other armour tanks should do better into AD-heavy
teams and worse into AP-heavy ones; the Draft tester never says so for Rammus. Already
seen (exploratory, so the per-champion numbers below aren't a test): Rammus jungle's
enemy AP share deviation is +0.07 ± 0.89 pp per sd in the 16-feature fit beyond the
shipped model (shrunk -0.01, so the tester has nothing to say), and -0.45 ± 0.81 with
AP share alone (`--only enemy:ap_share`, run 20261017T233658Z-champcomp-1320Z-windraft-
onlyap: folds -0.00023 ± 0.00006, 5/5, 9 clear). In that one-trait fit armour tanks lean
the same way, mostly unclear one by one: Malphite top -1.79 ± 0.46, Wukong jungle -1.08
± 0.47, Braum -1.05 ± 0.59, Sejuani -1.05 ± 0.84, Amumu -0.95 ± 0.84, Jax top -0.86 ±
0.52, Nautilus -0.49 ± 0.40; MR builders the other way (Galio mid +1.48, Kassadin +1.84,
Mundo top +0.70 ± 0.71). Ratings as the offset gives the same within 0.2 (run
20261017T233934Z-...-ratings-onlyap). A lone champion at 14k games is found from about 2
pp per sd, so the question is whether the group carries it.

Method (`champcomp --kit-prior`, 16 features as shipped, offset win-draft): enemy AP
share deviations shrink towards g x the cell's armour lean (profile armor_end - mr_end,
items and base stats at level 15, no ability resists; z within role, centred on its
role's precision-weighted mean) instead of 0; g one weighted slope over all roles' cells,
weights 1 / (se^2 + spread), spread by DerSimonian-Laird around the line, twice; the
posterior sd counts g's se. Other features unchanged. Same run fits the plain terms and
scores both on the same games.

Pre-declared:
- K1, the kit prior predicts: kit vs plain terms, folds pooled per-game log loss, 95%
  interval below 0 and better in at least 4 of 5 folds; dev-val reported only
- K2, control: `--kit-shuffle 1` (armour leans shuffled within role) must not pass K1;
  if it does, K1 doesn't count
- Reported: g with its 95% range, on dev-val; Rammus jungle's posterior, clear or not;
  clear count; g without Malphite's cells is not run (post hoc if wanted)
- Ship (draft-comp.json for the tester, tester reason for kit-driven leans) only on K1
  with K2 clean; a miss is recorded in docs/learned.md and nothing changes

Result (runs 20261017T235146Z-champcomp-1320Z-windraft-kit, control
20261017T235411Z-...-kitshuffle, gpu-box): K1 missed. Kit vs plain terms, folds
pooled -0.00002 ± 0.00004 nats/game, better in 4 of 5, dev-val 0.00000 ± 0.00006; the
control 0.00000 ± 0.00000 (3/5; g near 0, as it should be). g is real but small: -0.14 ±
0.05 pp of AP share slope per sd of armour lean (every fold -0.12 to -0.14), i.e. a
champion 2 sd armour-heavy does about 0.3 pp better per sd towards an AD team than its
role's average, so the group effect is too small to predict better. Rammus jungle under
the kit prior: -0.47 ± 0.53 (95%), not clear (raw +0.03 ± 0.89). Clear count rose to 333
(replication 114 of 199, mean z 0.29): in roles with no spread left (top, support) every
cell's posterior is g x its lean with sd from g's se alone, so "clear" there tests g, not
the champion; don't read `--kit-prior`'s clear counts as champion effects. Nothing
shipped; the tester keeps the plain terms (Rammus: nothing to say)

#### Kit groups and a property scan (champgroups; declared 2026-10-18 ~01:40 BST, before any run)

Question (Jacob, 18 Oct, after the Rammus miss): which kinds of champion do better or
worse into which kinds of enemy team? One champion is too thin (about 2 pp per sd at
14k games); a group of champions sharing a kit trait, one slope for the group, can see
about 0.5. Two parts: groups listed by hand from the kits (below, before any run), and
a scan of every own profile stat against every enemy team stat for groups nobody named.

Method (`meiolol-lab champgroups SNAP`, src/lab/champgroups.zig, offset win-draft, the
shipped model; snap-20261017T1320Z dev games only, no test look):
- Profiles: comps' champion-role profiles (buildProfiles) from dev games before
  bounds[2] ("older"), z within role, plus aa_build: completed crit or attack-speed
  items held at the end (Data Dragon item stats, legendaries.tsv), per champion-role mean
  of its won and lost games' means, the same games, from participants (data/
  champgroups/aa_build.tsv)
- Enemy traits, per seat from the enemy five: the sum of their role z for every profile
  stat and aa_build, AP share of their damage, melee count, and champcomp's composites
  (cc, engage, dive, tank, sustain, early); standardised over older seats
- Offset: win-draft fitted on older games, predicting older (in-sample) and the newer
  dev games [bounds[2], D) (out of sample)
- Per champion-role and enemy trait: one logistic step from the offset on the centred
  trait alone (as `champcomp --only`), cells with 300+ games; deviation = slope minus its
  role's precision-weighted mean; spread tau^2 by DerSimonian-Laird per role and trait
- Group effect: weighted mean over the group's cells (any role, 300+ games) of slope
  minus the mean of the role's other cells, weights 1 / (se^2 + tau^2); pp per sd of the
  enemy trait at 50%
- Scan: for every own stat V and enemy trait T, the weighted slope of deviations on the
  cell's own z of V (centred within role), same weights: pp per sd of T per sd of V
- Control: `--shuffle-own 1` shuffles cells' own profile vectors within role (scan and
  group memberships keep their champions, so groups are not controlled by it)

Groups (declared sign: + better into more of the trait):
| # | champions (any role) | enemy trait | sign | seen before |
| --- | --- | --- | --- | --- |
| G1 | Rammus, Jax, Shen, Teemo, Fiora, Malphite (auto-attack punishers) | aa_build | + | no |
| G2 | Aatrox, Vladimir, Dr. Mundo, Warwick, Sylas, Swain, Fiddlesticks, Soraka, Yuumi (self-heal) | antiheal | - | no |
| G3 | Olaf, Gangplank, Sivir, Morgana, Nocturne, Malzahar, Fizz (CC answers) | cc | + | no |
| G4 | Zed, Talon, Kha'Zix, Rengar, Qiyana, Naafiri (lethality assassins) | tank | - | Rengar |
| G5 | Vayne, Fiora, Gwen, Kog'Maw, Vel'Koz, Brand, Lillia (true and %HP damage) | tank | + | Brand, Lillia |
| G6 | Galio, Kassadin, Sivir, Malzahar, Morgana (MR kits, spell shields) | AP share | + | Galio, Kassadin |
| G7 | Evelynn, Twitch, Shaco, Akali, Kha'Zix, Rengar, Pyke (stealth) | control_pm | - | no |
| G8 | Xerath, Ziggs, Vel'Koz, Lux, Jayce, Varus (long-range poke) | engage | - | no |
| G9 | Poppy, Janna, Gragas (dash stoppers, disengage) | dive | + | no |
| G10 | Kayle, Kassadin, Veigar, Smolder, Vayne, Kog'Maw (hyper-scalers) | early | - | no |
| G11 | Rammus, Malphite, Braum, Poppy (armour kits) | AP share | - | all |
| G12 | Rammus, Malphite, Braum, Poppy, Ornn (armour kits) | armour_pen | - | no |
| G13 | Darius, Garen, Mordekaiser, Nasus, Illaoi, Sion, Dr. Mundo, Trundle, Volibear (juggernauts, no dashes) | range | - | no |

Pre-declared:
- Groups: estimate on all dev games (older plus newer); a group is detected when its
  two-sided p passes Benjamini-Hochberg at 5% over the 13 and the sign is the declared
  one. Older and newer halves reported. Detected groups (G4, G5, G6 and G11 partly seen,
  so weaker) go to the held-out look already planned on games after 17 Oct 13:20Z
- Scan: discovery on older games, BH 5% over every V x T pair; replicated when the newer
  games give the same sign at one-sided p < 0.05. Read: replicated count against the
  shuffled control's discoveries; pairs that are the same stat (own V = enemy V) or plain
  mirror effects are reported, not removed
- Ship nothing from this; site lines only after the held-out look

Result (runs 20261018T003617Z-champgroups-1320Z-real, control 20261018T003830Z-...-
shuffled, and 20261018T004251Z-...-real-apheld, which adds the post-hoc AP-share-held
column and otherwise reproduces the first; gpu-box, ~4 min each). Pp per sd of the enemy
trait, all dev games, ± 95%; older and newer halves; "AP held" is post hoc (declared
after the first run): the same slope with enemy AP share in the cell fit too.

| group | effect | older / newer | p | read | AP held |
| --- | --- | --- | --- | --- | --- |
| G1 auto-attack punishers into aa_build | +0.89 ± 0.33 | 0.87 / 0.90 | 2e-7 | detected | +0.69 ± 0.34 |
| G2 self-heal into antiheal | +0.34 ± 0.24 | 0.38 / 0.26 | 5e-3 | wrong sign | +0.33 |
| G3 CC answers into CC | +0.58 ± 0.30 | 0.47 / 0.86 | 1e-4 | detected | +0.58 |
| G4 lethality assassins into tank | -0.93 ± 0.41 | -0.93 / -0.85 | 1e-5 | detected (Rengar seen) | -0.90 |
| G5 true and %HP damage into tank | +0.72 ± 0.37 | 0.83 / 0.46 | 1e-4 | detected (Brand, Lillia seen) | +0.75 |
| G6 MR kits into AP share | +0.49 ± 0.37 | 0.48 / 0.62 | 9e-3 | detected (Galio, Kassadin seen) | |
| G7 stealth into control wards | +0.16 ± 0.28 | | 0.26 | not detected | |
| G8 long-range poke into engage | +0.13 ± 0.27 | | 0.33 | not detected | |
| G9 dash stoppers into dive | +0.57 ± 0.55 | 0.57 / 0.51 | 0.04 | not past BH | |
| G10 hyper-scalers into early | -0.24 ± 0.31 | | 0.12 | not detected | |
| G11 armour kits into AP share | -1.51 ± 0.41 | -1.62 / -1.46 | 5e-13 | detected (seen) | |
| G12 armour kits into armour pen | +0.99 ± 0.36 | 0.94 / 1.17 | 7e-8 | wrong sign | +0.36 ± 0.36 |
| G13 juggernauts into range | -0.30 ± 0.29 | | 0.04 | not past BH | |

- Six of 13 detected (BH 5% over the 13, declared sign), each the same size in both
  halves. G2 and G12 pass BH the wrong way: self-healers do slightly better into teams
  that build antiheal (those teams build it because the game goes long or against
  healing they lose to? not tested), and armour kits do better into armour pen because
  armour pen means an AD team: with AP share held it falls to +0.36 ± 0.36
- G1 is not the AD share again: with AP share held it keeps +0.69 ± 0.34. Members (all
  dev, AP held): Rammus jungle +1.41 ± 0.89 (raw +1.31 ± 0.79, 14,213 games), Jax top
  +1.12 ± 0.57, Teemo top +1.12 ± 0.63, Shen top +0.72 ± 0.82, Malphite top +0.59 ± 0.51
  (+1.30 raw: half of his was the AD share), Fiora top -0.70 ± 0.70 (the other way:
  riposte is one parry, and she is an auto-attacker herself). So Jacob's Rammus question
  was the right question with the wrong trait: Rammus answers auto-attackers, not AD
  damage, and casters like Zed, Talon and Jayce are AD without being auto-attackers
- Scan: 508 of 4,608 own x enemy pairs pass BH on older games and 337 replicate on newer
  ones; the shuffled control finds 0 (so the se are honest enough for BH). The pairs are
  a few families of correlated stats, each about 0.15-0.2 pp per sd per sd: tanky own
  profiles (mitig_pm, tank_share, taken_pm) better into enemy early, roaming, lethality
  and melee teams and worse into objective-taking ones (herald_td, dragon_td, baron_td);
  armour lean better into physical damage and armour pen, worse into magic damage
  (the kit prior's g again, about -0.2); ranged own profiles worse into lethality and
  roaming teams. aa_build as an own stat finds nothing: the build stats don't know that
  Rammus's W or Jax's E stop basic attacks, which is what the hand-made kit list adds
- Dev only (one snapshot, no test look); G4, G5, G6, G11 partly seen. Next: the
  detected groups and Rammus jungle into aa_build go into the held-out look on games
  after 17 Oct 13:20Z, with these numbers as the predictions

Follow-up, carry traits (declared 18 Oct ~02:30 BST, before the run; Jacob: "adding a
random AP champ to an otherwise all AD team might not help much, but a very high damage
AP carry might"). AP share already weights each champion by its typical damage, but a
share averages: one big AP carry with four AD picks and five lightly mixed picks can
both be 30%. New enemy traits, from the profiles' raw per-minute numbers: carry:ap_max
(the enemy seat with the most magic damage), carry:ap_total (the five's magic damage,
not a share), carry:aa_max (the seat with the most crit and attack-speed items). Groups
F1-F5, their own BH family: armour kits (G11's list) into ap_max and ap_total (-), MR
kits (G6's) into ap_max and ap_total (+), auto-attack punishers (G1's) into aa_max (+).
Read: each against its share or sum version by effect / se, and the AP-held column: for
F1-F4, whether the strongest carry or the total adds beyond the share

Result (run 20261018T005354Z-champgroups-1320Z-carry, gpu-box; the 13 groups as before;
scan now 4,800 pairs, 520 found, 347 replicated): the whole team's mix beats its strongest
carry. Armour kits: share -1.51 ± 0.41, total magic damage -1.52 ± 0.42, top AP threat
-1.05 ± 0.37; with the share held the top AP threat is -0.14 ± 0.35 (nothing left) and
the total is too collinear with the share to separate (± 1.9). MR kits: share +0.49 ±
0.37, total +0.43, top AP threat +0.08 ± 0.35 (not detected). Auto-attack punishers: the
five's summed auto-attack build +0.89 ± 0.33, the top auto-attacker +0.66 ± 0.29. So for
these kits a team's damage counts as a whole, weighted by how much each champion
usually deals (which AP share already does), and one big AP carry among four AD picks
doesn't add beyond it. Profiles are typical damage, not who gets fed in a game, which a
draft can't know. Nothing changes in the traits the tester uses

#### Kit groups into champcomp (multilevel prior; declared 2026-10-18 ~02:45 BST, before any run)

Question (Jacob): the Draft tester should be able to say "Rammus does better into an
auto-attack team like this one, like other auto-attack punishers", counting nothing
twice. Recipe: research/questions/hierarchical-comp-terms.md.

Method (`champcomp SNAP --aa aa_build.tsv --groups`, offset win-draft, snap-20261017T1320Z
dev games, comps' folds):
- A ninth trait, auto-attack build (data/champgroups/aa_build.tsv, games before
  bounds[2]; z within role over each window's fit seats; a set's value is the sum), enemy
  and allies: 18 features. Folds 1 and 2 take it from games after their fit games: a
  build habit with won and lost halves averaged, so the leak is small
- Groups: champgroups' detected six on their declared enemy traits: G1 auto-attack
  punishers (Rammus, Jax, Shen, Teemo, Malphite; Fiora dropped post hoc) into aa, G3 CC
  answers into cc, G4 lethality assassins and G5 true and %HP damage into tank, G6 MR kits
  and G11 armour kits into AP share. A champion counts in every group it is in, any role
- Prior: a cell's deviation on a group's feature ~ N(sum_g gamma_g (member_g - share_rg),
  tau_r^2), share_rg the role's precision-weighted member share, so a role's deviations
  still average 0 (nothing moves into team terms). gamma: weighted least squares per
  feature over every role's cells, weights 1 / (se^2 + tau^2), tau^2 by DerSimonian-Laird
  around it, twice (two-stage form of the joint fit); gamma's covariance enters each
  posterior sd. Posterior = group part (gamma x centred membership) + own part, summing
  to the total by construction. The same run fits the plain 18-feature terms on the same
  games

Pre-declared:
- P1, log loss: groups vs plain, folds pooled, on games with a member in either team:
  95% interval below 0 and better in at least 4 of 5 folds; every game and dev-val
  reported
- P2, leave one member out (fit before bounds[2], raw refit on [bounds[2], D)): each
  member's group guess with its own cell left out of gamma against its newer raw
  deviation; pass when the weighted squared error sum is below the role mean's (sse < 0)
  and the newer deviations' slope on the guesses is above 0 at one-sided p < 0.05
- C: `--group-shuffle 1` (memberships shuffled within role) must pass neither, else that
  check doesn't count
- Reported: gamma per group (dev-val, pp per sd, 95%), tau per role and group feature
  plain and with groups, Rammus jungle's group and own parts, the plain 18-feature fit
  against the shipped 16 (folds -0.00068)
- Planted: unit tests "kit groups" and "a planted kit group" (champcomp.zig) recover a
  planted coefficient, parts sum back, the role stays centred
- Ship draft-comp.json version 2 and the tester's "like other ..." reasons (admin only,
  marked not yet confirmed) when P2 passes with C clean and P1's every-game interval is
  not above 0. Caveat: the six were picked on all dev games, so P2 holds the member and
  newer games out of the fit, not out of the group's choice

Result (runs data/runs/20261018T0915Z-champcomp-1320Z-groups, -groupshuffle and
-plain-noaa, Mac, a scratch build of 6ebb450 plus this change; ~5 min each; the first
lab-run on 277661c's comp_stats cache is void, and the groups numbers came out the same):
pass, shipped to the admin tester.
- P1: groups vs plain 18-feature terms, games with a member, folds pooled -0.00021 ±
  0.00010 nats/game over 250,399 games, better in 5 of 5; every game -0.00017 ± 0.00008
  (5/5); dev-val -0.00010 ± 0.00016 (member games), -0.00011 ± 0.00013 (all). Per fold
  the gain shrinks with more fit games (fold 1 -0.00030, fold 5 -0.00004), as expected
  where the group helps thin champion-roles most
- P2: leave one member out, 82 member cells: weighted squared error -35.9 against the
  role mean, newer deviations' slope on the guesses 0.86 ± 0.28 (z about 6); closer for
  41 of 82. By group: G1 -11.5 (slope 0.95 ± 0.55), G11 -17.9 (1.23 ± 0.56), G4 -7.1
  (0.85 ± 0.61); G3 -0.7, G6 +0.3, G5 +1.0 (no help on their own)
- C: shuffled memberships fail both (member games -0.00003 ± 0.00004, dev-val +0.00001;
  sse +8.6, slope -0.00 ± 0.67); gammas near 0 (G1 0.25 ± 0.24, G11 0.28 ± 0.36)
- gamma, dev-val, pp per sd of the enemy trait: G1 auto-attack punishers into aa +0.93 ±
  0.28; G3 CC answers into cc +0.26 ± 0.34 (not clear here, unlike champgroups' +0.58,
  which had no other traits held); G4 lethality assassins into tank -0.80 ± 0.32; G5
  true and %HP damage into tank +0.70 ± 0.33; G6 MR kits into AP share +0.38 ± 0.37 (not
  clear); G11 armour kits into AP share -1.20 ± 0.36. Steady across folds
- tau: aa and cc have no spread left in any role, plain or with groups, so every member's
  lean on them is its group's alone (Rammus jungle into aa: +0.90 group, 0 own; raw +1.15
  ± 0.97). Tank: jungle 0.44 -> 0 pp, middle 0.57 -> 0.49, support 0.50 -> 0.44 (the
  groups explain jungle's spread). AP share: middle 0.48 -> 0.42, others unchanged.
  Rammus jungle into AP share: -0.62 (group -1.18, own +0.56, z 1.87)
- Clear counts now test the champion's own part (`zOf`: the shrunk residual over its sd;
  plain fits unchanged): 10 of 9,396 clear with groups (the first run counted 1,064 by
  the posterior, where a non-member's small centring term -gamma x share is as clear as
  its group in a role with no spread); replication 3/3
- Beyond the plan, the aa trait costs the plain terms: 18 features about -0.00056 over the
  offset (the groups run's -0.00073 less its -0.00017) against 16 (no aa file, which
  reproduces the shipped run: -0.00068 ± 0.00012, clear 22, replicated 8/8). Top's AP
  share spread goes from 0.36 pp to 0 with aa in (Malphite top's -1.14 lean was the
  clearest there), so the groups model mostly wins back what the
  trait costs. Paired by game against the shipped 16-feature terms: folds -0.00005 ±
  0.00009, better in 4 of 5; dev-val -0.00001 ± 0.00014. So the tester's numbers barely
  move; what it gains is the named reasons. Next (post hoc, not run): the enemy's aa
  only (17 features), or aa only in the group prior
- Exported (draft-comp.json version 2, groups, dev-val fit) to ~/ml/runs/
  20261018T0950Z-draft-windraft-1320Z-groups with the same draft-model.json, chosen with
  `deploy/lab-push.sh use draft`. The tester names a group's part ("does better into an
  auto-attack-heavy team like this one, like other auto-attack punishers", marked not
  yet confirmed on fresh games) when its gamma is clear (G1, G4, G5, G11) and the team is
  that way, and the champion's own part beyond it only when that is clear

### PyTorch cross-check, 2026-10-14 (meiolol-58)

Question: does each Zig model train as written? A second implementation in Python
(py/xcheck, PyTorch, scipy, sklearn), run on the same games, ids, hyperparameters and early
stopping, must land within seed noise of the Zig one. A code check, so on the pinned
snap-20261012T2055Z (the Zig references live there), dev-val and the 5 forward folds only.
- nnsets.py reads SNAP/nn and rebuilds netcheck's sets; it reproduces every block's fit,
  inner, val and scored games and ids (counts, labels, order, match ids). Set net and
  player net train on their commands' own input dumps (`--dump 1`, 35 and 51), so there
  only the net and its training are reimplemented
- Agreement: each side's mean single-seed gain over its own candidate, 10 seeds a side;
  agree if the two differ by at most 2 x sqrt(sd_a^2/10 + sd_b^2/10) (sd over seeds).
  Single seeds, not ensembles: ensembles of different sizes don't compare
- Runs: gpu-box ~/ml/runs, *-x* (torch), *-z*10 (Zig, 10 seeds), *-fin-* (comparisons)

Folds pooled (44,353 games); diff = 10-seed ensemble minus its candidate, ± 95% paired:

| model | torch | Zig | single-seed gains, torch - Zig | verdict |
| --- | --- | --- | --- | --- |
| win-ratings (torch: Zig's procedure) | 0.69092 | 0.69090 | +0.00002 ± 0.00010 (log loss) | agree |
| small net | +0.00021 ± 0.00023 | +0.00034 ± 0.00024 | -0.00014, tolerance ±0.00021 | agree, 6 of 6 blocks |
| big net | -0.00015 ± 0.00035 | -0.00039 ± 0.00033 | +0.00027, ±0.00037 | agree, 5 of 6 |
| set net (--cross 0) | -0.00043 ± 0.00017 | -0.00045 ± 0.00019 | -0.00001, ±0.00012 | agree, 6 of 6 |
| player net (on win-exp) | -0.00019 ± 0.00012 | -0.00014 ± 0.00013 | -0.00007, ±0.00013 | agree, 5 of 6 |
| resid, Zig's offsets | +0.00007 ± 0.00009 | -0.00007 ± 0.00006 | +0.00019, ±0.00015 | block 2 only |
| resid, torch's own offsets | +0.00021 ± 0.00016 | -0.00007 ± 0.00006 | +0.00045, ±0.00019 | differs |

Reading (dev, no test look):
- No bug found in the Zig models. Ratings, small, big, set and player nets reproduce
  within seed noise; the set net's gain over ratings (-0.00043 vs -0.00045) and the
  player net's over win-exp reproduce in an independent implementation
- win-ratings is not the L2 optimum: Adam stops after 1-17 epochs, so early stopping does
  the regularising (its l2 pick is always the smallest, 3e-4). The exact optimum with l2
  chosen on the same newest 10% ties it (+0.00013 ± 0.00018, better in 2 of 5 folds); at
  Zig's l2 it is worse (+0.00042 ± 0.00051). So the baseline stays
- Ratings' own seed noise (10 shuffle seeds): sd of log loss 0.00006 on the pooled folds,
  0.00009-0.00026 per block, 0.00012 on dev-val; per-game logits move 0.020-0.033 between
  seeds. Small beside the ±0.5 milli-nat floor; netcheck keeps the candidate at seed 1
- Resid: given Zig's cross-fitted offsets it agrees in 5 of 6 blocks; block 2 stays apart
  with 30 seeds a side (+0.00031, tolerance ±0.00027; torch trains ~0.6 epochs longer,
  twice the seed sd; gradient clipping never fires, norms ~0.03). With torch's own
  offsets it is worse by ~0.0005 over 3 offset seeds (+0.00045, +0.00061, +0.00044). My
  first offsets were wrong: fifths from a hash of the row index gave optimistic
  out-of-fold offsets (lab-constraints 2026-10-14); a random partition matches Zig's
  offset losses. Either way resid ties ratings, as f1 found
- Why the offsets matter (py/xcheck/offcmp.py, run 20261014T004223Z-offcmp, blocks dev-4):
  per game, torch's and Zig's val and scored offsets (one fit on all inner or fit games)
  correlate 0.95-0.997, but the cross-fitted training offsets (five fits on 80%) only
  0.81-0.91, scale ratio 0.70-1.03, at equal log loss. Two valid runs of the same
  cross-fit give quite different training offsets, so the residual net partly learns
  their noise and its result moves by ~0.0005 with the realisation. Cheap fix for the
  residual nets (resid, set, player, bigres): average the cross-fitted candidate over a
  few seeds or partitions
- Offset averaging tested (xnets --offset-avg K, snap-20261013T2253Z re-cut, 10 seeds a
  side, runs 20261014T0125*-oavg-*, compares 20261014T0327*-cmp-oavg-*): training offsets
  averaged over K partitions and ratings seeds, val and scored offsets unchanged (same
  candidate). Ensemble gain over the K = 1 run, folds pooled: K 5 +0.00001 ± 0.00004
  (offset seed 1), -0.00010 ± 0.00005 (seed 11); K 10 +0.00004 ± 0.00005. Nothing
  near the noise floor: not worth building for resid. On 2253Z (2-3x the fit games) the
  realisation matters little anyway: torch's own offsets now agree with Zig (ensembles
  -0.00003 ± 0.00010 and +0.00004 ± 0.00010 for two offset seeds), both resid ensembles
  -0.00017 to -0.00019 vs ratings. The 2055Z gap above was small data
- Tried in torch (cheap there): an exponential average of the weights (EMA 0.99) helps a
  single small net (-0.00024) but not a 10-seed ensemble (-0.00002 ± 0.00010): no

### Nets on the shipped model, 2026-10-18 (meiolol-2b)

Question (Jacob): where do neural nets stand against the model the site and app use
(win-draft: "Shipped model, 2026-10-17"), and can one beat it? Every earlier net table
compares with ratings (champion strength only), which stopped being today's model on 17
Oct. Read every table as log loss vs win-draft, milli-nats a game, negative is better.
For scale: win-draft beats a coin by 6.3 milli-nats a game on these folds (ln 2 -
0.68687), so -1.45 is about a quarter of its edge.

Before the new runs, the 14 Oct reference reruns on snap-20261014T2137Z (361k games,
folds 180,533 scored; runs 20261014T223405Z-big-wr-2137Z, -s11, 224148Z-big-wc-2137Z,
224438Z-add-v2-2137Z; never written up, pulled to data/runs): big net, 10 seeds, vs
ratings -1.06 ± 0.20 on the folds (dev-val -1.97 ± 0.56), vs win-comp -0.57 ± 0.24, and vs
additive v2 (the model then in the Draft tester) +1.10 ± 0.26, worse in every block, the
gap closing from +1.72 (fold 1) to +0.82 (fold 5) and +0.74 (dev-val).

snap-20261017T1320Z (made 17 Oct, every game on the box then): folds 5 x ~60,000 scored
games (300,113; fit 300k-540k), dev-val 80,031 (fit 600k). Built with
-Dcand=src/lab/cand/win-draft at aca652b (dev runs at the HEAD of 23:35Z, same netcheck
and candidate); win-draft's preds are identical in every run. gpu-box runs
20261017T23*-nd-* and 20261018T00*-nd-*; champcomp per-game preds from
20261018T003024Z-cc-windraft-preds (ddc5b49 adds preds.tsv). Nets at netcheck defaults;
set = setnet's phi 16, rho 16, offset cross-fitted as resid's.

Today's model against ratings on the same folds: win-draft 0.68687, ratings 0.68855
(-1.68 milli-nats; with dev-val -1.94 ± 0.22), accuracy 54.5% against 53.8% (all blocks).

| net vs win-draft | folds, dev seeds | sealed seeds | resample 1 / 2 | control | k/5 | single seeds (sealed) | dev-val (sealed seeds where run) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| set net + champion-role embedding 8 (`--ids 1`), seeds 1-3 / 4-6 | -1.36 ± 0.19 | -1.45 ± 0.18 | -1.33 / -1.33 | permuted profiles -0.14 ± 0.07; real minus it -1.30 ± 0.15 | 5 | -1.27 to -1.10 | -1.55 ± 0.33 |
| same, offset weight fixed at 1 | | -1.48 ± 0.19 | | | | | -1.69 ± 0.35 |
| set net, within-team (`--cross 0`) | -0.82 ± 0.13 | -0.77 ± 0.12 | -0.73 / -0.77 | permuted -0.13 ± 0.07; real minus it -0.61 ± 0.09 | 5 | -0.80 to -0.52 | -0.78 ± 0.26 |
| same, offset fixed at 1 (seeds 1-3) | -0.81 ± 0.12 | | | | | | -0.79 ± 0.26 |
| set net with the enemy team (`--cross 1`, seeds 1-3) | -0.92 ± 0.13 | | | | 5 | | -1.03 ± 0.28 |
| big net as a residual on win-draft (bigres), seeds 1-10 / 11-20 | -0.64 ± 0.12 | -0.58 ± 0.11 | -0.45 / -0.50 | shuffled champions -0.06 ± 0.09; real minus it -0.60 ± 0.09 | 5 | -0.13 to +0.95 | -1.06 ± 0.25 |
| big net from scratch, seeds 1-10 / 11-20 | -0.37 ± 0.20 | -0.38 ± 0.20 | -0.19 / -0.22 | | 4 (sealed 5) | +2.03 to +3.73 | -1.29 ± 0.45 |
| big net from scratch vs ratings (seeds 1-10) | -2.10 ± 0.24 | | | | 5 | +0.32 to +2.71 vs ratings | -3.04 ± 0.42 |

Declared before any 1320Z net result was read (two amendments, each before its runs): a
net whose dev seeds are below 0 on the folds passes when (1) sealed seeds (big 11-20, set
4-6) pooled over the folds have mean + 2.1 x paired 95% half-width < 0 (2.1x: 2253Z's
measured A/A widening for nets), (2) netcheck --resample 1 and 2 means are both < 0,
(3) real minus its control (bigres --shuffle-ids 1, set --control permute) < 0. Big from
scratch: (1) and (2) only. `--ids 1` was an exploratory dev run after the declaration; it
got the same rule before its confirmation ran.
- Set net + embedding: pass (bound -1.45 + 2.1 x 0.18 = -1.07; resamples -1.33, -1.33;
  control -1.30 ± 0.15)
- Set net within-team: pass (bound -0.52; -0.73, -0.77; -0.61 ± 0.09)
- bigres: pass (bound -0.35; -0.45, -0.50; -0.60 ± 0.09)
- Big from scratch: not passed ((1) -0.38 + 0.42 = +0.04; resamples pass)

Beside the comp terms in the admin Draft tester (champcomp on win-draft, same games,
offsets equal to 1e-6; champcomp alone -0.68 ± 0.12 on the folds, sealed seeds for the
nets, descriptive):

| model vs win-draft, folds | alone | net minus champcomp | net and champcomp, mean chance | logit gains correlate |
| --- | --- | --- | --- | --- |
| set net + embedding | -1.45 ± 0.18 | -0.78 ± 0.16 | -1.32 ± 0.13 | 0.52 |
| set net within-team | -0.77 ± 0.12 | -0.10 ± 0.13 | -0.89 ± 0.10 | 0.47 |
| bigres | -0.58 ± 0.11 | +0.09 ± 0.15 | -0.85 ± 0.09 | 0.20 |

Set net + embedding and bigres averaged: -1.28 ± 0.13, no better than the set net alone.

Against the best non-net model, additive v2 ("Additive model v2"; run
20261018T010025Z-add-v2-1320Z, Mac, same 380,144 games and blocks by match id; its
strength-only variant is -0.29 ± 0.07 vs netcheck's ratings, as on 2253Z; dev-val and
folds pooled, descriptive):
- additive v2 vs win-draft: -1.08 ± 0.18, better in all 6 blocks (-0.59 to -1.59): the
  model the site ships is ~1.1 milli-nats behind the one the Draft tester used before 17
  Oct, more than champcomp adds to it (-0.68)
- set net + embedding (sealed) vs additive v2: -0.39 ± 0.17; blocks -0.49, -0.25, -0.24,
  -0.78, +0.07, dev-val -0.59 (3 of 6 detected). Under the nets' A/A floor (~0.35-0.5):
  not established. Next: the set net on additive v2's offset (additive is not a netcheck
  candidate yet), and why win-draft trails it (eval's tuned priors vs per-block variances)

Reading (dev, no test look):
- A net now beats today's model. The set net with champion-role embeddings, on top of
  win-draft, is 1.45 ± 0.18 milli-nats a game better on 300k held-out games, in every
  fold, with sealed seeds, on both resamples, and against its control; the gain is the
  profiles' content (permuted profiles give -0.14) and none of it recalibration (offset
  fixed at 1: -1.48). About a quarter of today's model's edge over a coin; accuracy
  54.5% to 55.0%, AUC 0.564 to 0.570 (all blocks, dev included). Single seeds are
  already -1.1 to -1.3: unlike the big net, it does not need an ensemble
- It contains the comp terms the Draft tester adds (champcomp): better than them by
  -0.78 ± 0.16, and adding them makes it worse. Within-team only it is level with them
- What changed from 2253Z (set net within-team on ratings -0.37, on win-comp -0.25, not
  confirmed): 2-4x the fit games, the shipped pair terms in the offset, and the
  embedding beside the profiles (on 2055Z the embedding added nothing)
- The big net keeps gaining on ratings with data: -0.39 (2253Z, fit 134-242k), -1.06
  (2137Z, 180-325k), -2.10 (1320Z, 300-540k). From scratch it is at the shipped model's
  level (-0.38 sealed, not passed); every single big seed is 2-4 milli-nats worse, the
  10-seed average is the gain. As a residual on win-draft it passes (-0.58)
- The gain does not grow with block (set + embedding -1.25 to -1.45 in each fold, dev-val
  -1.55): not a newer-games effect
- Against additive v2, the best non-net model, it is only -0.39 ± 0.17: a test look
  should compare with both
- The `--ids 1` net runs with cross-team on (setnet's default); the within-team rows
  are `--cross 0`

On additive v2 as the base (src/lab/cand/win-additive, d968495: additive v2's full model
as a candidate, a copy of src/additive.zig and addinputs' mix; reproduces `effects --param
v2` within 1e-6 on all 60,022 fold 1 games, fit 8.8 s on 300k games). Declared before any
run on it: same rule as above (sealed seeds 4-6 with 2.1x, resamples 1 and 2, permuted
control). Development (seeds 1-3, run 20261018T014345Z-nd-setid-wa, Mac; reported, not
the decision):
- set net + embedding on additive v2: -0.82 ± 0.14 on the folds vs additive v2, better in
  5 of 5 (-1.03, -0.80, -0.72, -1.03, -0.53), dev-val -1.01 ± 0.27; single seeds -0.57 to
  -0.45 (averaging matters more on this base than on win-draft's)
- all blocks pooled: 0.68470 against additive's 0.68556 (accuracy 55.1% vs 54.8%, AUC
  0.572 vs 0.569); against the same net on win-draft (seeds 1-3) -0.58 ± 0.16: the better
  base carries into the net
- Confirmation (gpu-box, d968495, 18 Oct): **passed**. Sealed seeds 4-6 -0.78 ± 0.12
  (2.1x bound -0.53), better in 5 of 5 folds (-0.81, -0.59, -0.72, -1.20, -0.58), single
  seeds -0.28 to -0.66 (run 20261018T050921Z-nd-setid-wa-s456); resamples -0.58 ± 0.11
  and -0.62 ± 0.10 (-r1, 20261018T082526Z-nd-setid-wa-r2); permuted-profile control
  -0.00 ± 0.01 (20261018T082543Z-nd-setid-wa-perm), real minus control -0.77 ± 0.12
  paired. Accuracy 55.0% against additive's 54.7% (folds); dev-val -0.50 ± 0.10,
  reported
- Reported only: the within-team set net without embedding on additive v2 -0.07 ± 0.03
  (20261018T060117Z-nd-set-wa), the big net as a residual -0.27 ± 0.07 (10 seeds, single
  seeds +0.08 to +1.71; 20261018T060136Z-nd-bigres-wa). On this base nearly all of the
  gain needs the embedding and the enemy team; within-team profiles alone add little
  beyond additive v2's damage mix
- How far the net moves a draft (sealed run, folds, 3-seed mean vs additive v2): mean
  |change| 1.24 pp, median 0.91, 90th percentile 2.79, 99th 5.16; 20% of drafts move
  over 2 pp. Additive v2's own mean distance from 50% is 4.66 pp: about a fifth of a
  typical draft's lean would come from the part with no named terms

Export for the Draft tester (e8a2e2f): `netcheck --net set ... --blocks dev --export 1`
writes each seed's dev-block fit as setnet-s<seed>.json (format meiolol-setnet v1, in
setnet.writeExport's doc comment). An independent forward pass from the file matches its
200 reference logits within 6e-8 and netcheck's preds within 5e-7 (win-draft, seed 1:
14,353 params, 823 vocab ids, 865 profiles). The tester reads it through
src/site/static/admin-setnet.js, on additive v2 fitted on the same games (`draft
--model additive --fit dev --export`); its parts are swaps (a pick for its role's
average, a trait zeroed across a team, every embedding row for its role's), not terms
- Not yet: a test look (needs Jacob's go; rule to declare first) and `meiolol eval`'s view

### Scoring draft models against the in-game win chance, 2026-10-20

Question: can a draft comparison be scored against q = P(blue wins | state at minute m,
draft) instead of the result, for narrower intervals? Per-game log loss is linear in the
outcome, so the paired difference d(q) has the same mean as d(y) when q is the true
conditional chance, and drops the outcome noise left after minute m. The catch:
d(y) - d(q) = (q - y)(logit pB - logit pA) exactly, so d(q) is unbiased only if q's
error is uncorrelated with the two models' logit difference.

`py/xcheck/rbscore.py`, run 20261020T215512Z-rbscore-2253Zr (gpu-box, 13 s): richc's
out-of-fold chances (20261014T032052Z-state-richc-2253Zr, fitted per netcheck block on
its fit games) joined by match id to 16 archived per-game draft pairs on the same 2253Z
re-cut blocks (effects, netcheck, pretrain runs of 14 Oct; blocks and results checked
equal on every joined game). Folds pooled, games with a timeline (100,847 of 134,375 at
15:00), milli-nats a game, B minus A:

| pair (B vs A) | y, all games | y, timeline games | q at 15:00 | bias d(y) - d(q) | games saved |
| --- | --- | --- | --- | --- | --- |
| additive v2 vs ratings | -1.72 ± 0.30 | -1.75 ± 0.35 | +0.10 ± 0.21 | -1.86 ± 0.28 | 2.8x |
| damage mix over strength | -0.77 ± 0.21 | -0.80 ± 0.24 | +0.49 ± 0.14 | -1.30 ± 0.19 | 2.8x |
| win-comp vs ratings | -0.48 ± 0.16 | -0.49 ± 0.19 | +0.33 ± 0.11 | -0.81 ± 0.15 | 2.7x |
| embx vs win-comp | -0.40 ± 0.15 | -0.43 ± 0.17 | +0.08 ± 0.10 | -0.51 ± 0.14 | 2.8x |
| additive, temperature-scaled | +0.01 ± 0.10 | -0.01 ± 0.12 | +0.30 ± 0.07 | -0.31 ± 0.09 | 2.8x |
| bigres vs win-comp | -0.66 ± 0.18 | -0.59 ± 0.21 | -0.49 ± 0.13 | -0.11 ± 0.17 | 2.8x |
| big net 1-10 vs ratings | -0.39 ± 0.18 | -0.36 ± 0.21 | -0.28 ± 0.13 | -0.08 ± 0.17 | 2.8x |
| small net vs ratings | -0.34 ± 0.14 | -0.33 ± 0.16 | -0.24 ± 0.10 | -0.09 ± 0.13 | 2.8x |
| resid vs ratings | -0.17 ± 0.08 | -0.14 ± 0.09 | -0.15 ± 0.06 | +0.01 ± 0.08 | 2.8x |
| strength only vs ratings | -0.05 ± 0.08 | -0.04 ± 0.09 | +0.04 ± 0.06 | -0.08 ± 0.07 | 2.8x |
| random embedding prior vs ratings | +0.17 ± 0.12 | +0.14 ± 0.13 | +0.14 ± 0.08 | +0.01 ± 0.11 | 2.8x |
| team gold at 14 vs ratings (reads state) | +20.40 ± 1.14 | +21.31 ± 1.32 | +21.46 ± 0.80 | -0.16 ± 1.05 | 2.7x |

At 10:00 intervals shrink more (4.2x games) and biases grow (additive v2 -2.36); at
20:00 less (2.3x) and smaller (-1.55); report.md in the run has every row. A synthetic
check (q from the true model: bias +0.24 ± 0.49, 3.2x; q missing a pair effect the
candidate has: sign flipped, bias -3.59 ± 0.49) behaves the same.

Reading (dev, no test look):
- Not usable for what we need. q-scoring is unbiased where the two models differ in
  champion strength, which richc knows (nets on ratings, embedding priors, strength
  only), and saves ~2.8x games there; where they differ in damage mix, pairs, comp
  terms or calibration (richc's draft input is ratings plus champion-role effects) it
  loses nearly all of the real gain, often flipping its sign. New draft effects are
  what experiments look for, so it would reject them
- No fix inside the method: recalibrating q with both models' logits, fitted on other
  folds' results, makes the bias's direction a fitted one and gives back d(y) with its
  noise (synthetic: equal to d(y), 1.0x games). q can only cut variance on effects it
  already contains
- Also rules out soft-label training on q (idea A2 of 20 Oct): its targets carry richc's
  draft view, so the pair and comp effects get pulled toward zero in proportion to q's
  weight
- On the data, not the method: additive v2's edge over ratings (-1.75) is not in how
  the game stands at 10-20 minutes as richc reads it (+0.60, +0.10, +0.01), nor is the
  damage mix's. That agrees with "How drafts win" Q3 (no part of the draft's edge
  detected running through the early lead) and narrows it: the comp and pair part of
  the edge shows up only in who wins

### Pool and expertise replay, 2026-10-20

Question: does ranking the lane card's pool by the player's own mastery as well as by
the draft help, and with what weight? Layer 3 of the pool tests (data/team/
2026-10-20-pooltest/notes.md). `meiolol eval --replay` (src/replay.zig) on
snap-20261018T1007Z, every platform, the eval time split (train 746k games 26 Sep to
15 Oct, test 132k games 15 to 18 Oct). Data: mastery_pre.tsv (points on the game's
champion and on every champion, from the player's latest fetch before the game) and
mastery_pre_pool.tsv (that fetch's top 15, the pool the app sees; `meiolol-lab
mastery-pre`, 8aca7cb). Only seats with a pre-game fetch.

Term (lanecard.Expertise): logit += beta * (log10(points + 1000) - 3), own seat only
(all the app knows). Fit: logistic regression of each known seat's team result on the
draft's four terms from that side (out-of-fold on train, empirical-Bayes priors), side
and a constant, plus the expertise features; 977k train seats. Test: 944k seats in
130k games, terms from the full-train model; ± paired by game.

| model | log loss | vs draft alone | 10k to 300k points (pp, even game) |
| --- | --- | --- | --- |
| draft alone | 0.68679 | | |
| + log points, one beta | 0.68645 | -0.00034 ± 0.00006 | 2.7 |
| + log points, beta per role | 0.68644 | -0.00034 ± 0.00006 | 2.7 2.7 2.7 2.6 2.7 |
| + bands (<10k, 10-30k, 30-100k, 100-300k, 300k+) | 0.68645 | -0.00034 ± 0.00006 | vs <10k: 1.1 2.0 3.2 4.2 |
| + log points, one beta, beside log total points | 0.68626 | -0.00052 ± 0.00007 | 3.7 (total: -0.103 a tenfold) |

EUW test games only (24k games, 114k seats, same train): -0.00052 ± 0.00017 one beta,
-0.00087 ± 0.00021 beside total points.

Lane card hit rate: for each test seat with a pool, the card (shipped options, train
stats, no curves) from the pre-game top 15; hit when the champion picked is among the
options shown. 65.4% of picks are in the top 15 at all (EUW 70.8%).

| draft known | hit, draft only | hit, + expertise (beta 0.1022) | difference | win rate, hit / missed |
| --- | --- | --- | --- | --- |
| other nine (as the pick metric) | 38.6% | 46.9% | +8.32 ± 0.07 pp | 51.9% / 48.5% |
| blind | 37.0% | 47.5% | +10.48 ± 0.08 pp | 51.7% / 48.6% |
| EUW, other nine | 40.8% | 51.7% | +10.89 ± 0.22 pp | 52.1% / 47.9% |

Reading:
- Shipped: one beta 0.1022 for every role (lanecard.Expertise.fitted), from the row
  beside total points: within one player's pool total points are fixed, so that
  coefficient is the one that ranks. Per role adds nothing; log points match the
  bands' shape. A toggle in the window ("Count your mastery points") turns it off
- Players with more points overall win slightly less once their points on the champion
  are known: the gain is the share of a player's play on this champion, not experience
  in general
- Win rate by hit is descriptive only: comfort picks confound it
- Not tried: a per-champion slope shrunk to the role's (d1's per-champion gap, true sd
  ~2 points, split-half r 0.33); a pick-order-aware draft (which picks the player had
  seen); persisting the toggle across restarts

### Patch 16.21's first day: how far champions moved, 2026-10-21

Question: how big is a patch-day jump on our games, against within-patch noise, and is
it in the champions the patch touched? Sizes the prize for patch-aware training
(docs/plan/patch-transfer.md). Data: the box's drafts table, ranked solo, read-only
export (16.20: 1.32M games; 16.21: 51,852 games, 21 Oct, KR and VN2 heavy). Old = 16.20
days 13 to 18 Oct (632k games); new = all 16.21; control = 16.20's last two days, 19
and 20 Oct (134k games). Cells: platform x champion x role (rates within platform, as
16.21's first day is 35% KR against 23% on 16.20), 200+ old picks and 20+ new and
control picks. True jump spread tau = sqrt(pick-weighted mean of d^2 minus its sampling
variance), d = new rate minus old. "Changed": 12 champions whose Data Dragon 16.21.1
championFull differs from 16.20.1 (stats, spell cooldowns, costs, ranges, tooltips:
Varus, Viktor, Darius, Sion, Jinx, Azir, Yuumi, Xin Zhao, Orianna, Wukong, Lee Sin,
Locke); patch notes change more than Data Dragon shows. SQL on the export, no model.

| cells | n | new picks | tau, 16.21 vs old | tau, control vs old | slope of d on old - 50% (control) |
| --- | --- | --- | --- | --- | --- |
| all | 2,421 | 496k | 0.75 pp | 0.00 pp | -0.32 (-0.31) |
| unchanged champions | 2,247 | 451k | 0.50 pp | 0.00 pp | -0.31 (-0.31) |
| changed champions | 174 | 45k | 1.92 pp | 0.29 pp | -0.42 (-0.27) |

Pooled over platforms instead (mix not matched): tau 0.70 pp vs control 0.27 pp.

Reading:
- The patch moved champions, the control didn't: within a platform two later days of
  16.20 differ from the week before by sampling noise only, while 16.21's first day
  differs by 0.75 pp per pick (RMS). The changed champions moved about 4x as far as the
  rest (1.9 vs 0.5 pp); the rest still moved (other champions' changes, C6 in
  frontier-dynamics, and who plays on patch day)
- Cost of ignoring it: a team's logit moves by the sum of ten seats' shifts, about
  4 x d each, so last patch's ratings lose roughly 20 tau^2 nats per game: ~1.1
  milli-nats on 16.21's first day, against the shipped model's whole edge over a coin
  of ~7.6 milli-nats (0.6855 vs 0.6931)
- How much a day of new games can win back: with a cell's noise 0.25/n, a shrunk
  per-patch offset recovers tau^2 / (tau^2 + 0.25/n) of a cell's jump. At 1,000 new
  picks: 9% for an unchanged cell, 60% for a changed one. So one shared shrinkage
  learns almost nothing on day one; a looser prior for patched champions is where the
  early gain is
- Mean reversion (E3's prior): no sign of it overall (slope = control's: the -0.3 is
  the old rate's own noise). Changed champions -0.42 vs -0.27: a hint, 12 champions
- Eval noise: paired per-game log loss differences between models this close have an
  sd of ~0.022 nats (from Patch and rank context: ± 0.00020 on 44,353 games), so one
  day of 16.21 (52k games) gives ± 0.19 milli-nats at 95%. Evaluating only on the
  newest patch costs little precision after day one
- Caveats: one boundary, day one only, raw rates (no draft adjustment), Data Dragon
  only as the changed list. Rerun by day since patch as 16.21 fills
- Rerun: the SQL in docs/plan/patch-transfer.md "Step 0"

### Lab frontier wave 1, 2026-10-22 (docs/plan/lab-frontier.md)

Phase 0 and wave 1 of the frontier programme. Dev only, no test look.

P1, seat stats for every game (3091e18): the box keeps match summaries ~2 days before
the archive takes them, so `seat-stats` on a snapshot's raw.db covered its newest games
only (1007Z: ~24% of seats; profile models then fall back to ratings without a word).
lab/summaries.zig reads raw.db, then the raw archive's summaries files (complete from
the first export, 12 Oct); `seat-stats` and `comp-stats` take ARCHIVE and the weekly
snapshot passes it to both. P4: netcheck and champcomp already write per-game preds.tsv
keyed by match id (fold, match_id, y, cand, seeds, ens), so ensembles read those.

A2, ensemble selection over the 1320Z preds (py/xcheck/ensel.py; 380,144 games, the
"Nets on the shipped model" runs and the set nets on additive v2 of 18 Oct, pulled to
data/runs, spec and output in data/runs/ensel-1320Z/). 12 members: win-draft, additive
v2, set net + embedding on v2 (setid-wa), set net on v2, bigres on v2, set net +
embedding, set net, cross set net, big, bigres (all on win-draft), champcomp and
champcomp with kit groups. Weights fitted forward: block b (folds 2-5, dev-val) is scored
with weights fitted on the blocks before it; nets with sealed seeds are picked on dev
seeds and scored with sealed ones. Logit space. Milli-nats vs setid-wa (sealed), the best
single model, on 320,122 games:

| method | pooled | fold 2 | 3 | 4 | 5 | dev-val | loss | accuracy |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| win-draft (shipped) | +1.79 ± 0.23 | +1.78 | +1.86 | +1.78 | +2.17 | +1.45 | 0.68654 | 54.5% |
| additive v2 | +0.70 ± 0.11 | +0.59 | +0.72 | +1.20 | +0.58 | +0.50 | 0.68545 | 54.9% |
| setid-wa | 0 | | | | | | 0.68475 | 55.1% |
| best single, chosen forward | 0 (always setid-wa) | | | | | | 0.68475 | 55.1% |
| greedy (Caruana, 20 bags) | -0.11 ± 0.08 | -0.14 | -0.03 | -0.00 | -0.02 | -0.30 | 0.68464 | 55.2% |
| logistic stack on logits | -0.49 ± 0.09 | -0.42 | -0.42 | -0.47 | -0.12 | -0.88 | 0.68426 | 55.2% |

Stack weights hardly move between blocks (dev-val: setid-wa +0.68, bigres-wa +0.30,
setid-wd +0.26, big +0.18, bigres-wd +0.16, champcomp with groups +0.35, plain
champcomp +0.01, additive v2 -0.31, win-draft -0.41, set-wd -0.23; sum 1.00). The
negative offsets mean the residual nets are under-scaled: the stack turns their residual
up, which a convex blend (greedy) cannot. The kit-group champcomp keeps weight next to
every net. So stacking is worth ~0.5 milli-nats here, in the -0.3 to -0.8 the research
expected; against the shipped model the stack is -2.28.

B1, draft ceiling by variance accounting (py/xcheck/ceiling.py, provisional): held-out
residuals r = y - p, cells of four blocks (champion-role, ally role pairs, lane
matchups, cross-role enemy pairs); per block the summed within-cell residual covariance
(S_c^2 - sum r^2) over its expected size, solved jointly as games sharing a pair cell
share its two mains. Milli-nats a perfect estimate of each block would still gain
(V/8), blocks 2-5 and dev-val, 20 Bernoulli nulls:

| model | main | ally | lane | cross | total | null sd of total |
| --- | --- | --- | --- | --- | --- | --- |
| win-draft | -0.01 | 0.93 | 0.53 | 1.09 | 2.54 | 0.35 |
| additive v2 | -0.14 | 1.49 | 0.48 | 1.85 | 3.68 | 0.60 |
| setid-wa | -0.08 | 1.17 | 0.33 | 1.33 | 2.74 | 0.64 |
| stack | -0.00 | 0.66 | 0.30 | 0.83 | 1.78 | 0.57 |

Reading, with care: mains are used up in every model; what is left sits in ally pairs
and cross-role enemy pairs, lane matchups little. Total s ~0.12-0.17 left on top of the
model's ~0.25, so a draft-only ceiling near s 0.28-0.29 (~56%) at perfect knowledge of
~250k pair cells, which ~1M games can't estimate. Not yet a gate: the null sd is
0.35-0.64 per model, the planted 10% flips came back 0.78-2.15 against 1.14-2.36
expected, and additive v2 shows more left than win-draft though it predicts 1.1 better
(the estimate also counts the model's own cell noise, and v2's pairs are less shrunk).
Rerun on the new pin with ~2x the games.

B4, how much of each site table is signal (py/xcheck/reliability.py, 1320Z, 800,354
played games, descriptive): per band of cell games, the true spread tau by method of
moments and split-half reliability (halves hashed by game, Spearman-Brown), which agree:

| table | games in the cell | cells | tau | reliability |
| --- | --- | --- | --- | --- |
| champion-role | 500-2,000 / 2,000+ | 169 / 334 | 3.8 / 1.5 pp | 0.77 / 0.93 |
| lane matchup (raw rate) | 50-150 / 150-500 / 500-2,000 / 2,000+ | 7,004 / 5,220 / 3,516 / 584 | 3.6 / 2.9 / 2.5 / 2.2 pp | 0.31 / 0.44 / 0.68 / 0.83 |
| bot-support duo | 50-150 / 150-500 / 500-2,000 / 2,000+ | 933 / 692 / 501 / 178 | 4.3 / 3.4 / 2.4 / 2.2 pp | 0.36 / 0.51 / 0.67 / 0.86 |

A matchup's raw win rate at the median cell (~80 games over 30 days) is about a third
signal, two thirds luck; half and half near 300 games. Rare cells spread more (off-role
picks, odd matchups), so one pooled tau understates them. The site already shrinks
matchup "vs usual" by a per-role method-of-moments k (site/champion.zig usualK) and fades
under 10 games: B4 confirms that design rather than changing it. One patch alone (16.19
here, ~1/3 of the games) halves most cells' reliability.

D1, first pass (1007Z mastery_pre: 21.9% of 8.65M seats have a pre-game fetch;
champion-roles with 300+ such seats): a champion's raw rate mixes its strength with how
practised its players are. With the replay's +0.1022 logit per tenfold points
("Pool and expertise replay"), the bias is 0.1022 x (the champion-role's mean log10
points minus everyone's) x 25 pp: sd 0.59 pp over champion-roles (players' mean log10
points sd 0.23). Underrated: Locke every role (-2.0 to -2.2 pp: released recently, all
players new to him), Corki top, Renata support, Zaahen top (-1.5); overrated: Neeko,
Riven, Singed, Gangplank and Katarina mid (+1.3 to +1.5), Katarina and Vel'Koz bot. So
for a new champion or a one-trick favourite a tier list should show strength at a fixed
mastery. Next: the refit itself (strength with seat log mastery in the model, not this
correction) on the new pin, and the slope's own interval; the lane card's expertise
bonus counts this twice for one-trick champions.

### Set net on additive v2 in the tester and eval, 2026-10-23 (net, prepin run)

The set net + champion-role embedding on additive v2 (setid-wa, passed its rule on
1320Z: "Nets on the shipped model, 2026-10-18") refitted on snap-20261018T1007Z for the
admin Draft tester, with a Zig reader for `meiolol eval`. Dev only, seeds 1-6, no test
look.

Data: 1007Z's own seat_stats.tsv covers 60,662 of 651,521 dev-visible played games (9%;
dev-val 24%, test 91%: the box keeps summaries ~2 days), so profiles would come from the
newest days only. Runs use ~/ml/lab/1007Z-ss: the snapshot's files by symlink and a
seat_stats.tsv of 1007Z's lines then 1320Z's for missing seats (6.90M seats; 72% of
dev-visible, 78% of dev-val, 99.7% of test games), packed there. P1's archive merge
makes this unneeded on the next pin (snap-20261023T2004Z: 16.5M seats for 1.59M played
games); 1007Z and the view were removed 23 Oct night, the exports stay.

Format (3c3b77d): meiolol-setnet version 1 as before (setnet.writeExport;
draftfile.SetNetFile) plus `fit_newest` (unix ms of the newest fit game) and `platforms`
(ids in the c intercepts' order; the tester falls back to EUW1 at 6 without it).
draftfile.SetNet reads it and runs the forward pass in f64; netcheck --export 1 reads
its own file back through it and stops unless it matches the net on 500 scored games
within 1e-4 (as draft --export checks its scorer).

Runs (Mac, 3c3b77d, -Dcand win-additive, 18 Oct options: emb 16, phi 16, rho 16;
dev block: fit 648,631 games, dev-val 86,485): 20261023T195617Z-nx-setnet-wa-1007Z
(seeds 1-3), 20261023T200032Z-nx-setnet-wa-1007Z-s456 (4-6), base
20261023T195855Z-nx-additive-dev-1007Z (`draft --model additive --fit dev`: scorer
1.1e-8 on 500 games, dev log loss 0.68436). Set net vs win-additive on dev-val,
milli-nats a game:

| seeds | seed mean | single seeds | epochs |
| --- | --- | --- | --- |
| 1-3 | -0.72 ± 0.19 | -0.65, -0.50, -0.02 | 4.75, 6.74, 0.50 |
| 4-6 | -0.94 ± 0.24 | -0.59, -0.81, -0.86 | 5.00, 5.99, 6.99 |

Seed 3 stopped at half an epoch (its validation loss never improved after the first
evaluation), so it is nearly the base alone. 1320Z's dev-val was -1.01 ± 0.27 (1-3) and
-0.50 ± 0.10 (sealed 4-6): same size.

Tester: data/runs/setnet-tester-20261023 (the base export's draft-model.json and
draft-ref.json, draft-setnet.json with seeds 1-6), the lab pick since 23 Oct ~20:10Z
(it replaced 20261018T0950Z-draft-windraft-1320Z-groups, win-draft with the kit-group
comp terms). Checked in node through the page's own code: draft-ref exact, the page's
forward pass against the files' references 6.5e-8, base check 0.029 on 73 EUW1
references (tolerance 0.05, pair floor), a full breakdown 6 ms.

Eval port (2f40706, c1ad052): `meiolol eval --setnet FILE` (once per seed) adds "current
model + set net (lab)": the nets on the shipped model's logit (additive v2 shipped form:
no damage mix, no side term, f16 cells), blue's chance the seeds' mean. It refuses a
file without fit_newest, one that saw a game of the scored window, or one missing a
scanned platform. `--dev` scores the protocol's dev-val window, fitting below the dev
cut; on test, `--setnet` needs `--test-look`, which records the look in
DATA/test-looks.tsv. On 1007Z (`eval --platform all --dev`, seeds 1-6, run
20261023T200824Z-eval-dev-setnet-1007Z, 87,842 dev-val games):

| model | log loss | AUC | accuracy | vs current model |
| --- | --- | --- | --- | --- |
| current model (additive v2 shipped form) | 0.6853 | 0.571 | 54.9% | |
| counts model (17 Oct) | 0.6857 | 0.569 | 54.9% | +0.0004 ± 0.0003 |
| current model + set net (lab) | 0.6844 | 0.575 | 55.2% | -0.0009 ± 0.0002 |

Reading (dev): the net, fitted on the lab's additive v2 (damage mix, side terms), keeps
its gain on the shipped form's logit: -0.9 milli-nats, about what it gains on its own
base, so it can sit on the shipped model as fitted (its offset weight and platform
intercepts absorb the differences). Next: the test look under P3 (docs/plan/lab-frontier.md "P3
proposal", Jacob's go), seeds 7-9.

### The latest patch day by day: PT2-PT3 dry run on 16.20, 2026-10-23 (pt, prepin run)

docs/plan/patch-transfer.md PT2 and PT3 as a tool, run with 16.20 as "the latest patch"
so the 16.21 pin is one command. Dev only: test games are neither fitted nor scored.
`meiolol-lab patchdays SNAP` (lab/patchdays.zig, eceb666): day d = days since the
patch's first game on the game's platform; day d's games are scored by fits on every
played game starting before day d's first scored game (harness.PatchDays, any platform
and patch); preds.tsv per game (match id, platform, day, bucket, any changed champion,
blue won, each arm's chance), curve.tsv by bucket 0, 1, 2-3, 4-7, 8+ and the patch mean
with days weighted equally, days.tsv. Arms on additive v2 without the damage mix (the
shipped terms), each refitted per day:

- A0 latest patch only; A1 pooled, no patch term (the bar)
- A2 pooled + a champion-role offset per role on latest-patch games (new offset groups in
  additive.zig), variance estimated (MacKay) or fixed (--offset-sd)
- A3 A2 with the changed champions' offset variance x16 (Step 0: 1.92 vs 0.50 pp)
- A4 latest only, L2 prior centred on a fit of the older patches (old games' cells kept
  at the prior), jump variances estimated
- A7:a pooled, latest-patch games weighted a (weights scaled to sum to the games)
- C A2 with the latest flag on a hashed share of fit games (A2's share): the control

Data: snap-20261018T1007Z. 16.20 day 0 is there on every platform (first games 6 Oct
20:53Z TR1 to 7 Oct 11:41Z NA1; KR 22:40Z, EUW1 7 Oct 05:29Z). Dev-visible 16.20 games:
days 0-7 whole (67-91k a day), day 8 part (55k), 682,512 scored; 129,726 later ones are
the test window. The old patch is 16.19 alone with 51k played games (the crawl was
small then), against 16.21's 1.3M of 16.20. Changed 16.19 -> 16.20 (Data Dragon
championFull, Step 0's rule, which gives Step 0's 12 for 16.21): Cassiopeia, K'Sante,
Mordekaiser, Swain, Vayne (22% of games have one). Run 20261023T201251Z-pt-dry-1620,
3.5 min on 4 Mac cores; fixed-sd runs ...201750Z (0.02) and ...201815Z (0.05).

Milli-nats a game vs A1, 95% paired (A1 row: its log loss), all games:

| arm | day 0 | day 1 | days 2-3 | days 4-7 | day 8 | patch (days equal) |
| --- | --- | --- | --- | --- | --- | --- |
| games | 67,249 | 70,883 | 157,564 | 331,804 | 55,012 | 682,512 |
| fit games (latest) | 51k (0) | 103k (51k) | 173-247k | 327-568k | 659k (607k) | |
| A1 pooled | 0.69070 | 0.68871 | 0.68786 | 0.68628 | 0.68439 | 0.68718 |
| A0 latest only | +2.45 ± 0.58 | +1.70 ± 0.38 | +0.49 ± 0.14 | +0.23 ± 0.06 | +0.21 ± 0.12 | +0.70 ± 0.09 |
| A2 offsets, estimated | 0 | 0.00 ± 0.02 | 0 | 0 | 0 | 0 |
| A2, sd 0.02 | 0 | -0.02 ± 0.05 | +0.00 ± 0.02 | +0.01 ± 0.01 | +0.01 ± 0.01 | +0.00 ± 0.01 |
| A2, sd 0.05 | 0 | +0.08 ± 0.17 | +0.07 ± 0.06 | +0.08 ± 0.03 | +0.06 ± 0.06 | +0.07 ± 0.03 |
| A3 changed x16, estimated | 0 | -0.00 ± 0.00 | 0 | 0 | 0 | 0 |
| A3, sd 0.02 | 0 | -0.05 ± 0.07 | +0.01 ± 0.03 | +0.01 ± 0.01 | +0.01 ± 0.01 | +0.00 ± 0.01 |
| A4 warm start | 0 | +0.66 ± 0.21 | +0.49 ± 0.12 | +0.14 ± 0.05 | +0.16 ± 0.09 | +0.26 ± 0.04 |
| A7 x3 | 0 | +2.34 ± 0.58 | +0.31 ± 0.17 | -0.05 ± 0.05 | +0.03 ± 0.10 | +0.31 ± 0.08 |
| A7 x10 | 0 | +17.06 ± 1.48 | +2.43 ± 0.39 | +0.05 ± 0.10 | +0.07 ± 0.15 | +2.48 ± 0.19 |
| C control, estimated | 0 | -0.00 ± 0.00 | 0 | 0 | 0 | 0 |
| C, sd 0.02 | 0 | +0.04 ± 0.04 | +0.01 ± 0.02 | +0.01 ± 0.01 | +0.01 ± 0.01 | +0.01 ± 0.01 |
| C, sd 0.05 | 0 | +0.28 ± 0.15 | +0.07 ± 0.06 | +0.05 ± 0.02 | +0.06 ± 0.05 | +0.08 ± 0.02 |

On the changed champions' games (148,739) the same order: A3 at sd 0.02 -0.21 ± 0.23 on
day 1, -0.01 ± 0.04 over the patch; A0 +0.70 ± 0.19; A4 +0.33 ± 0.09. On day 0 every arm
but A0 is A1 (no 16.20 game fitted yet: A0 is a coin, A4 the old fit).

Reading (dev, a dry run of the tool, not the answer for 16.21):
- The shuffled control gains nothing in every form (0 estimated, +0.01 and +0.08 when its
  offsets are forced): the mode doesn't leak, and noise offsets cost what they should
- Old patches never stop helping here: A0 is still +0.21 ± 0.12 behind on day 8 with 607k
  of its own games. But 16.19 is only 51k games, so this is mostly "more games help" (A1
  has 8% more on day 8), not patch transfer; with 1.3M games of 16.20 behind 16.21 the
  crossover question is real
- No patch jump is detectable at 16.19 -> 16.20 with these data: the estimated offset
  sd is 0.006 logit on day 1 and at its floor from day 2, and forced offsets (sd 0.05)
  lose as much as the control's noise offsets, except on day 1 (A2 +0.08 vs C +0.28). A
  champion-role rate on 51k old games is ~2 pp of noise against Step 0's 0.75 pp jump, so
  the old side can't separate it; 16.21's old side can
- A4 and A7 lose to pooling: a prior centred on a noisy 51k-game fit is worse than pooling
  those games, and up-weighting the new patch cuts the effective sample (x10: +17 on day 1)
- Speed: 72 additive fits on up to 660k games in 210 s, so the 16.21 run is minutes

For the 16.21 pin (after PT1): `meiolol-lab patchdays SNAP --changed
changed-16.21.tsv` (latest = the newest patch; the list from `meiolol-lab patchdays
changed 16.20.1/championFull.json 16.21.1/championFull.json`, kept in
data/team/2026-10-23-prepin/pt/), then `--arms A1,A2,A3,C --offset-sd 0.02` and `0.05`
if the estimated offsets collapse again. One catch: the protocol's test window is the
newest ~15% of games, which on a pin a few days into 16.21 is nearly all of 16.21, so
dev scores almost nothing; the pin needs its test cut moved for this (say 16.21 days 4+)
or the run is `--final`, a test look (Jacob's call).

### Pair cells that borrow strength (A4), 2026-10-23 (meiolol-a4)

Lab frontier A4 (docs/plan/lab-frontier.md; research frontier-tabular-ensembles C5):
inside additive v2, shrink each pair cell toward a structured part instead of 0, since
B1 ("Lab frontier wave 1") left most of the draft's unused signal in ally pairs and
cross-role enemy pairs. Dev only, snap-20261018T1007Z (877,814 games), Mac CPU, no test
look. Pre-declared in data/team/2026-10-23-prepin/a4.md before any code or run.

Method (`meiolol-lab pairprior SNAP`, src/lab/pairprior.zig, 0d4dec0 and 40197e9): v2 full
(mains, 10 ally and 15 matchup blocks, damage mix) plus extra random-effect terms, each a
function of a v2 cell, fitted jointly with it (v2's block Newton passes, then one
diagonal Newton step per extra part on the cells' summed gradient and curvature; MacKay
variances per extra block). Without extras it is additive.fit exactly (1e-15 on 1007Z).
- kit x kit: a parent cell per (kit(a), kit(b)) in each of the 25 pair blocks, signed as
  the child. Kit maps: tag (Data Dragon tag string such as "Fighter,Tank", 26 classes,
  role-free) or prof:K (k-means on 13 seat-stat kit features of the champion-role from
  the block's fit games: damage mix, damage and damage taken a minute, tank share, CC,
  immobilisations, self-heal, ally heal and shield, building damage, armour lean, range,
  gold at 14)
- pair: the same two champions in any role slots: one parent over the 10 ally blocks
  (unordered), one over the 15 matchup blocks (signed, the blue champion against the red
  one). pair:multi keeps only parents whose pair met in 2+ slots; pair:ident gives every
  cell its own parent sharing the kind's variance (no pooling, a looser prior only)
- rank:k: u_a . v_b per block (same-role u_a . v_b - u_b . v_a), a field-aware FM with
  fields = role slots inside v2; factor sd by MacKay (capped) or fixed

Protocol: per game log loss minus v2's on the same fit games, paired. Folds 1-2 for every
choice; one candidate frozen before anything was scored on folds 3-5 or dev-val; pass =
sealed folds 3-5 mean + 1.6 x 95% half-width < 0, --resample 1 and 2 means < 0, real minus
the shuffled-group control < 0 with the control not below v2; worth shipping at -0.10 or
better.

Development, folds 1-2 (129,726 games; runs 20261023T200222Z-a4-pp-dev1, 205804Z-dev2,
210025Z-dev3), milli-nats a game vs v2, both folds better unless marked:

| variant | folds 1-2 | its shuffled control |
| --- | --- | --- |
| kit:tag | -0.08 ± 0.06 | +0.003 ± 0.002 |
| kit:prof:8 / 16 | -0.04 ± 0.05 / -0.02 ± 0.05 | +0.003 ± 0.003 (8) |
| pair | -0.34 ± 0.12 | +0.009 ± 0.004 |
| pair:multi | -0.34 ± 0.12 | |
| pair:ident | +0.06 ± 0.02, 0 of 2 | |
| pair + kit:tag | -0.44 ± 0.14 | pair:shuf + kit:tag -0.07, pair + kit:tag:shuf -0.36 |
| pair + kit:prof:8 | -0.40 ± 0.14 | |
| rank:2 / 4 / 8, MacKay | +2.8 / +3072 / +6152 (ran away) | |
| rank:2 / 4, MacKay capped at sd 0.22 | +3.0 / +5.7 | |
| rank:2 / 4, sd 0.1 | -0.06 ± 0.18 (1 of 2) / -0.08 ± 0.19 | |
| rank:2, sd 0.2 / rank:4 and 8, sd 0.05 | +4.8 / 0.00 (factors collapse to 0) | |

pair:multi equals pair (nearly every champion pair meets in 2+ slots, through off-role
picks and flex champions) and pair:ident loses: the gain is pooling the same two
champions across slots, not a looser prior for thin cells. Frozen at 21:05Z:
`pair+kit:tag` at 40197e9; control `pair:shuf+kit:tag:shuf`. (d), a field-aware FM
residual as an offset, is the rank form outside the fit; with no rank gain at any sd on
development it had no room shown and was not run.

Sealed (runs 20261023T210252Z-a4-pp-sealed, 210647Z-r1, 210823Z-r2, 211000Z-shuf; folds
3-5 194,590 games, fit 454k-584k; dev-val 86,485, fit 649k):

| statistic | folds 3-5 | fold 3 / 4 / 5 | resample 1 / 2 | dev-val | verdict |
| --- | --- | --- | --- | --- | --- |
| candidate pair + kit:tag - v2 | -0.53 ± 0.14, 3 of 3 | -0.59 / -0.37 / -0.63 | -0.47 ± 0.12 / -0.50 ± 0.13 | -0.63 ± 0.23 | pass (bound -0.31) |
| control (both shuffled) - v2 | +0.010 ± 0.003 | | | +0.008 ± 0.004 | not below v2 |
| candidate - control | -0.54 ± 0.14 | | | -0.63 ± 0.23 | < 0 |
| shuffled labels: candidate - v2 | +0.002 ± 0.009 | | | | no gain |
| pair alone (reported) | -0.41 ± 0.11, 3 of 3 | | | -0.54 ± 0.18 | |
| kit:tag / kit:prof:8 alone (reported) | -0.09 ± 0.05 / -0.15 ± 0.06 | | | -0.08 / -0.10 | |
| pair:ident (reported) | +0.04 ± 0.01 | | | +0.04 | |
| rank:4, sd 0.1 (reported) | +0.04 ± 0.21 | | | +0.19 ± 0.35 | |

Log loss on folds 3-5: v2 0.68569, candidate 0.68516. For scale, v2 over win-draft was
-1.08 and the set net on v2 -0.78 (1320Z): about two thirds of the set net's gain, from
a CPU model with named terms.

Planted power check (fold 3's games; outcomes drawn from v2's real fit plus a planted
kit:tag part of cell sd 0, 0.25 or 0.5 pp in every pair block; runs 211136Z-plant0,
211251Z-plant25, 211433Z-plant50, 211549Z-plantr50):
- kit plant 0: candidate +0.01 ± 0.02, kit:tag +0.01 ± 0.02 (no gain from nothing)
- kit plant 0.25 pp: -0.01 ± 0.07, not seen; fitted parent sd 0.07 (mean over blocks)
- kit plant 0.5 pp: -0.39 ± 0.20 (seen, bound -0.08); fitted parent sd 0.26
- rank-2 plant 0.5 pp: rank:4 +0.39 ± 0.31, rank:2 +0.29 ± 0.28 (worse than v2)
So kit parents are seen from about 0.5 pp a cell and their sds come back at a third to a
half of the plant (the binary-outcome bias of "Effects and the CPU model" again, and v2's
own cells take part of the plant). Real kit:tag parents fit 0.12 pp on average (fold
3), between the 0.25 and 0.5 plants. Low rank failed its power check: this fitter can't
use a planted rank-2 part, so (c)'s null says nothing about low-rank structure.

Where the gain sits (fold 5 fit, cell sds in win pp at 50%, v2 -> candidate): the
matchup parent ("this champion against that one, in any roles") fits 0.82 pp and takes
most of the cross-role blocks (top vs jungle 0.72 -> 0.09, jungle vs bottom 0.52 -> 0.01,
middle vs bottom 0.64 -> 0.02, jungle vs jungle 1.15 -> 0.27, bottom vs bottom 1.12 ->
0.18) and part of the lanes (top 2.36 -> 1.99, middle 1.95 -> 1.36). The ally pair
parent fits 0.06. Kit parents of 0.3-0.6 pp sit in middle vs middle, jungle vs jungle,
jungle-support, jungle-middle and bottom-support allies, bottom vs support, top vs top.

Reading (dev, no test look): a counter is mostly a fact about the two champions, not
their roles. Letting a pair's cells share across role slots, plus kit-class cells,
predicts held-out games 0.53 ± 0.14 milli-nats a game better than additive v2 (3 of 3
sealed folds, both resamples, controls clean, dev-val -0.63). The B1 residual in
cross-role enemy pairs was this: thin cross-role cells shrunk to 0 where the same two
champions' other meetings knew their sign.

Shipping it in src/additive.zig (not done; needs Jacob's go, and P2's same-split view):
- Fit: pairprior's cell-level steps move into additive.zig (kit and pair parents only;
  low rank stays in the lab): two parent tables, their MacKay variances, ~150 lines;
  four more sweeps over the pair entries a pass beside v2's ~40 group sweeps (not timed
  alone; a whole pairprior block of 8 fits on 4 threads took 46-54 s at 454k-649k games)
- Kit map: Data Dragon tags, already in the champions table (ddragon.zig stores them),
  so no new data on the box
- Stats file: no format change. statsfile v2 holds dense n x n tables per role pair, so
  fitted.attach writes child + kit parent + pair parent into every cell, including pairs
  never seen in that slot (the parents' gain for unseen cells comes free). The pair
  floor (20 games) should apply to the child part only
- Then `meiolol eval` on the shipped form (no damage mix, f16, floor) against today's
  model before switching, as for v2 on 23 Oct
- Explanations: a matchup's reason can say "X counters Y in any role" when the pair
  parent carries it; C5's purification applies (parents vs cells)

### The new pin, snap-20261023T2004Z: coverage and wave 1, 2026-10-23 (w1g, prepin run)

The pin for Phase 0 and wave 1 (docs/plan/lab-frontier.md), 1,611,151 games 26 Sep to
23 Oct, every platform. Dev only, no test look: the test window below is counted, never
scored.

P1, coverage per protocol window (`meiolol-lab coverage SNAP`, lab/coverage.zig: counts
from the pack and mastery_pre.tsv, no outcomes; data/team/2026-10-23-prepin/w1g/
coverage-2004Z.tsv). Played games (15:00+); inputs as the share of played seats, then of
played games with all ten seats known. Seat stats: SNAP/seat_stats.tsv through rows;
mastery: a pre-game fetch in mastery_pre.tsv; rank: rows' rank_start (rank_history
starts 12 Oct, so the old window has none):

| window | from (UTC) | games | played | 16.19 / 16.20 / 16.21 | seat stats | mastery seats / all ten | rank seats / all ten |
| --- | --- | --- | --- | --- | --- | --- | --- |
| old (fit only) | 26 Sep 23:26 | 603,985 | 595,230 | 52,604 / 542,626 / 0 | 100% | 0.04% / 0% | 0% / 0% |
| fold 1 | 12 Oct 22:12 | 120,894 | 119,046 | 0 / 119,046 / 0 | 100% | 25% / 1.0% | 78% / 45% |
| fold 2 | 14 Oct 07:14 | 120,997 | 119,046 | 0 / 119,046 / 0 | 100% | 50% / 5.9% | 85% / 54% |
| fold 3 | 15 Oct 09:59 | 120,893 | 119,046 | 0 / 119,046 / 0 | 100% | 64% / 15% | 87% / 55% |
| fold 4 | 16 Oct 13:05 | 120,775 | 119,046 | 0 / 119,046 / 0 | 100% | 70% / 19% | 87% / 56% |
| fold 5 | 17 Oct 13:36 | 120,732 | 119,047 | 0 / 119,047 / 0 | 100% | 76% / 24% | 88% / 57% |
| dev-val | 18 Oct 14:13 | 161,124 | 158,728 | 0 / 158,728 / 0 | 100% | 84% / 35% | 89% / 59% |
| test | 20 Oct 14:44 | 241,751 | 238,092 | 0 / 13,961 / 224,131 | 100% | 88% / 42% | 91% / 61% |

Fit games per dev block (played, before the block): dev 1,190,461 (scores dev-val), fold
1 595,230, 2 714,276, 3 833,322, 4 952,368, 5 1,071,414; 119k scored per fold. Per
platform, all ten known (seat stats / mastery / rank):

| platform | dev-visible played | all ten | dev-val played | all ten | test played | all ten |
| --- | --- | --- | --- | --- | --- | --- |
| EUW1 | 285,206 | 100% / 0% / 25% | 30,898 | 100% / 7% / 61% | 50,820 | 100% / 16% / 64% |
| KR | 272,121 | 100% / 1% / 27% | 36,974 | 100% / 14% / 57% | 61,257 | 100% / 23% / 61% |
| VN2 | 181,867 | 100% / 13% / 27% | 29,158 | 100% / 59% / 62% | 43,252 | 100% / 66% / 63% |
| NA1 | 118,019 | 100% / 6% / 29% | 15,467 | 100% / 34% / 60% | 19,147 | 100% / 44% / 64% |
| BR1 | 95,079 | 100% / 6% / 28% | 12,128 | 100% / 32% / 58% | 16,134 | 100% / 48% / 62% |
| LA1 | 58,635 | 100% / 6% / 31% | 7,917 | 100% / 34% / 63% | 10,172 | 100% / 54% / 65% |
| LA2 | 51,867 | 100% / 5% / 29% | 7,049 | 100% / 29% / 59% | 10,027 | 100% / 48% / 62% |
| SG2 | 37,327 | 100% / 23% / 26% | 6,084 | 100% / 88% / 53% | 8,255 | 100% / 91% / 55% |
| JP1 | 32,974 | 100% / 25% / 24% | 4,065 | 100% / 88% / 50% | 6,057 | 100% / 89% / 54% |
| TW2 | 27,770 | 100% / 25% / 22% | 4,362 | 100% / 88% / 49% | 6,991 | 100% / 87% / 47% |
| OC1 | 26,651 | 100% / 33% / 25% | 4,336 | 100% / 90% / 52% | 5,785 | 100% / 91% / 51% |
| EUN1, TR1, RU, ME1 | 2,945 | | 290 | | 195 | |

Reading against P1's asks:
- Seat stats for every game: met (100% of played seats in every window; 1007Z had ~24%)
- Mastery for all ten: not in dev. 6.5% of dev-visible games (28% of seats), 35% of
  dev-val, EUW1 the thinnest (0% / 7%). A
  model on all ten masteries fits on fold 4-5-era games or imputes; seat-level mastery
  (84% of dev-val seats) is usable
- rank_start: from fold 1 on, ~87% of seats and ~55% of games all ten; none before 12 Oct
- 16.21 in dev: not met. Every 16.21 game is in the test window (none starts before
  the 20 Oct 14:44Z cut), so dev scores 16.20 only and any 16.21 question waits
  for the P3 look or the next pin

#### P2: same-split head-to-head, 2026-10-24 (dev only)

Every model on the protocol's blocks of this pin (folds 1-5 fit on every played game
before them, dev-val on the 1.19M before the dev cut), compared game by game on the
753,959 scored games (py/xcheck/h2h.py: per-game preds keyed by match id, paired
differences, ± 1.96 se over games). Runs on the gpu-box, queue.sh p2 at ed17798
(setid-wd) and 1db246e (the rest; 1db246e only silences two test prints):
20261023T232808Z-setid-wd, 20261023T234438Z-setid-wa, 20261023T235036Z-setid-wa-s456,
20261024T002326Z-setid-wd-s456, 20261024T000446Z-set-wr, 20261024T003414Z-add-v2
(effects --param v2, cand win-draft), 20261024T004458Z-bigres-wa (+ 005551Z s11),
20261024T010643Z-big (+ 015013Z s11), 20261024T020047Z-bigres-wd; all `-2004Z`, in
data/runs. v2's shipped form here is effects' full-nomix: no damage mix, but it keeps
the platform side terms and unfloored f64 cells, which the stats file drops (worth
~0.3 on 1007Z: "Shipped model, 2026-10-23").

The ladder, milli-nats a game (negative better):

| model | dev-val loss | vs win-draft | vs row above | folds loss | vs win-draft | vs row above | folds accuracy |
| --- | --- | --- | --- | --- | --- | --- | --- |
| win-draft (17 Oct form) | 0.68566 | | | 0.68603 | | | 54.7% |
| additive v2, no damage mix (shipped form) | 0.68474 | -0.92 ± 0.22 | | 0.68540 | -0.63 ± 0.11 | | 54.9% |
| additive v2 full (damage mix) | 0.68422 | -1.44 ± 0.28 | -0.52 ± 0.18 | 0.68480 | -1.23 ± 0.15 | -0.59 ± 0.09 | 55.1% |
| set net + embedding on v2, seeds 1-3 | 0.68365 | -2.01 ± 0.33 | -0.57 ± 0.17 | 0.68406 | -1.97 ± 0.16 | -0.74 ± 0.08 | 55.3% |

Per fold, vs win-draft (v2 shipped form / v2 full / set net on v2): fold 1 -0.49 / -1.18
/ -1.86, 2 -0.48 / -1.00 / -1.76, 3 -0.63 / -1.23 / -2.03, 4 -0.59 / -1.09 / -1.94, 5
-0.95 / -1.63 / -2.23. Every step gains in every block.

The other nets, against their own base (folds pooled; dev-val):

| net | base | vs base, folds | dev-val |
| --- | --- | --- | --- |
| set net + emb, sealed seeds 4-6 | v2 full | -0.80 ± 0.09 | -0.68 ± 0.15 |
| bigres, seeds 1-10 | v2 full | -0.37 ± 0.05 | -0.43 ± 0.09 |
| bigres, seeds 11-20 | v2 full | -0.39 ± 0.06 | -0.22 ± 0.05 |
| set net + emb, seeds 1-3 | win-draft | -1.43 ± 0.12 | -1.43 ± 0.23 |
| set net + emb, seeds 4-6 | win-draft | -1.47 ± 0.13 | -1.27 ± 0.22 |
| big, seeds 1-10 | win-draft | -1.52 ± 0.19 | -2.10 ± 0.41 |
| big, seeds 11-20 | win-draft | -1.46 ± 0.20 | -2.00 ± 0.41 |
| bigres, seeds 1-10 | win-draft | -1.50 ± 0.14 | -1.89 ± 0.30 |
| set net + emb, seed 1 | win-ratings (+2.48 ± 0.21 vs win-draft) | -2.16 ± 0.17 | -2.50 ± 0.32 |

Reading (dev):
- Why the shipped model trails v2 (inventory gap 5): the damage mix. Without it v2 is
  -0.63 on win-draft; with it -1.23. So half of v2's gain is the mix, which needs
  champion-role profiles on the box (the seat stats decision)
- The set net on v2 is the best single model: -1.97 on win-draft, -0.74 on v2, sealed
  seeds -0.80; the same size as on 1320Z (-0.78) at twice the fit games, so it hasn't
  grown with data. On v2 it gains twice what bigres does
- Nets on win-draft land at -1.4 to -1.5 whatever the architecture (set, big, bigres),
  just above v2 full: they relearn what v2's identified pair blocks have. On dev-val big
  reaches -2.1, as good as set on v2, but its folds don't follow (-1.5)
- Seed groups agree within 0.1 (set 1-3 vs 4-6, big 1-10 vs 11-20)

#### E1: drift or noise at equal N, 2026-10-24 (dev only)

Each dev block's additive v2 (win-additive) and set net + embedding on it (seeds 1-3)
fitted on N = 297,000 of its fit games (half of fold 1's 595,230; netcheck --window):
its newest N, its oldest N, or a hashed N spread over every day; same scored games
(runs 20261024T021423Z-e1-newest, 022546Z-e1-oldest, 023624Z-e1-spread, all -2004Z,
1db246e). For fold 1 the oldest N is 26 Sep to 9 Oct 22:08 (all of 16.19) and the newest 9
Oct 22:30 to 12 Oct 22:12 (the crawl grew, so the newest days are dense); for dev-val,
N is a quarter of its 1.19M. Milli-nats a game (h2h.py):

| fit window | v2 dev-val | v2 folds pooled | vs spread, dev-val | vs spread, folds | set net on it, folds |
| --- | --- | --- | --- | --- | --- |
| all fit games (P2) | 0.68422 | 0.68480 | -2.27 ± 0.31 | -1.68 ± 0.14 | -0.74 ± 0.08 |
| spread N | 0.68649 | 0.68649 | | | -0.52 ± 0.05 |
| newest N | 0.68657 | 0.68659 | +0.08 ± 0.27 | +0.10 ± 0.14 | -0.16 ± 0.03 |
| oldest N | 0.68651 | 0.68652 | +0.02 ± 0.28 | +0.03 ± 0.14 | -0.36 ± 0.04 |

Newest vs spread per fold: +0.09, -0.22, +0.02, +0.13, +0.49 (each ± ~0.3).

Verdict (dev): noise, not drift, for the draft model within 16.20 and the 16.19 tail.
At equal N the newest games are no better than the oldest or a spread (all within 0.1,
inside the expected ~0.3 tie), while doubling N gains 1.7. So older history is not dead
weight and strength doesn't need time terms on this span; more games is what helps. Not
yet tested across a big patch (16.21 is all test). One thing not understood: the set net
gains less on the newest window (-0.16 against -0.52 spread), so the newest-window
model with its net is worse by 0.46 in total; worth a look before the net is refitted
on recent games only.

#### A1: scaling curves at 1/16 to all fit games, 2026-10-24 (dev only)

Each family refitted per block on a hashed share of its fit games (netcheck --fraction,
harness.inFraction: nested, the same games at every size; base and net both), scored on
the same 753,959 games. Fit games: dev-val 74k, 149k, 298k, 596k, 1.19M; fold 1 37k to
595k, fold 5 67k to 1.07M. Runs queue.sh a1 at 1db246e (`*-setid-wa-f*`, `*-big-f*`,
`*-set-wr-f*`, all -2004Z; fraction 1 is P2's runs): ratings and set net + emb on it
(seed 1), win-draft and big on it (seeds 1-10), v2 full and set net + emb on it (seeds
1-3). Log loss:

| fraction | ratings | set on ratings | win-draft | big on win-draft | v2 full | set on v2 |
| --- | --- | --- | --- | --- | --- | --- |
| folds pooled | | | | | | |
| 1/16 | 0.69064 | 0.69049 | 0.69130 | 0.69083 | 0.68975 | 0.68985 |
| 1/8 | 0.68984 | 0.68968 | 0.68968 | 0.68975 | 0.68848 | 0.68839 |
| 1/4 | 0.68899 | 0.68847 | 0.68830 | 0.68847 | 0.68708 | 0.68680 |
| 1/2 | 0.68862 | 0.68727 | 0.68717 | 0.68685 | 0.68601 | 0.68557 |
| 1 | 0.68850 | 0.68635 | 0.68603 | 0.68451 | 0.68480 | 0.68406 |
| dev-val | | | | | | |
| 1/16 | 0.69001 | 0.68975 | 0.69009 | 0.69008 | 0.68886 | 0.68872 |
| 1/8 | 0.68921 | 0.68919 | 0.68880 | 0.68890 | 0.68775 | 0.68763 |
| 1/4 | 0.68855 | 0.68758 | 0.68765 | 0.68791 | 0.68648 | 0.68629 |
| 1/2 | 0.68840 | 0.68687 | 0.68663 | 0.68542 | 0.68544 | 0.68493 |
| 1 | 0.68837 | 0.68587 | 0.68566 | 0.68356 | 0.68422 | 0.68365 |

Last doubling (1/2 to all, folds, milli-nats): ratings -0.12, win-draft -1.14, v2 full
-1.21, set on v2 -1.51, set on ratings -0.92, big on win-draft -2.34. Big against v2
full (paired, folds): +0.85 ± 0.17 at 1/2, -0.29 ± 0.20 at all; set on v2 against big
at all: -0.45 ± 0.18 (dev-val +0.09 ± 0.35).

Reading (dev):
- Ratings have plateaued (0.1 per doubling); every pair model and net is still gaining
  1.1 to 2.3 per doubling at 1.19M games, so the plateau question is answered for the
  draft models: no plateau yet
- Nets need data: under 1/4 (~300k games) a net adds nothing over its base (set on v2
  +0.10 at 1/16), and its gain grows with each doubling (set on v2 over v2: -0.28 at
  1/4, -0.44 at 1/2, -0.74 at all)
- The big net passes v2 between half and all the games and gains the most per doubling;
  set on v2 is still 0.45 ahead. If both keep their last slope, big passes set on v2
  within the next doubling (~2.4M fit games), which is a forecast, not a measurement
- Train loss isn't logged (netcheck prints its inner-validation loss only), so the
  train/test bracket per family the plan asked for is still to do

### Strength at fixed mastery (D1), 2026-10-24 (w1c, prepin run)

Question (docs/plan/lab-frontier.md D1): a champion-role's raw win rate mixes its
strength with how practised its players are; the "Lab frontier wave 1" first pass
corrected it after the fact. Here the refit itself, dev only, no test look.

Data: snap-20261023T2004Z, 1,369,400 played games before the test cut (dev's visible
games and dev-val), every platform, 865 champion-roles; 35.0% of seats have a pre-game
mastery fetch (mastery_pre.tsv; dev-val 83.9%: fetching grew). Script:
py/xcheck/mastery_strength.py (Mac, `uv run --no-project --with numpy --with scipy
--with pandas`), output data/runs/d1-2004Z/ (out.md, d1-strength.tsv per champion-role).

Model: one logistic regression per game (blue's win): platform side + champion-role
strength theta (blue minus red, Gaussian prior sd 0.1 logit) + beta * m per seat,
m = log10(points + 1000) - 3 (lanecard.Expertise.feature). A seat without a fetch gets
its champion-role's mean m among fetched seats (shrunk to the role's by 50 seats), so an
unknown player counts at the champion's usual mastery and beta comes from fetched seats
within a champion-role. Newton fit, beta's interval from the Hessian. Beside it the raw
fit (no mastery term) and one with log10 total points as well.

| model | beta a tenfold points | 95% | 10k to 300k points, even game |
| --- | --- | --- | --- |
| + log points | 0.0798 | 0.0773 to 0.0824 | 2.87 pp |
| + log points + log total points | 0.1150 | 0.1121 to 0.1179 | 4.13 pp (total: -0.1285 ± 0.0052) |

Time halves of the games, refitted: older 0.0830 ± 0.0141 (few fetches then), newer
0.0796 ± 0.0026. The replay's 0.1022 beside total points ("Pool and expertise replay",
seat level, 1007Z, draft terms fitted) sits between the two rows.

Strength at 50k points vs the raw fit, champion-roles with 300+ fetched seats (502),
each against its role's games-weighted mean (beta * m at 50k is the same for all, so
ranking at any fixed mastery is the same ranking): the move has sd 0.45 pp and is almost
exactly beta x (the champion-role's mean m minus the role's) (r 0.991), so the first
pass's correction was the right shape (its sd 0.59 used beta 0.1022). Rank correlation
raw vs fixed mastery per role 0.962 to 0.989. Largest moves:

| champion | role | games | fetched seats | players' mean points | raw | at 50k | move |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Locke | middle | 89,649 | 31,716 | 15k | -0.05 | +1.55 | +1.60 |
| Locke | jungle | 10,191 | 3,752 | 14k | -3.01 | -1.46 | +1.55 |
| Corki | top | 8,782 | 2,327 | 17k | -4.95 | -3.52 | +1.43 |
| Locke | top | 3,213 | 1,100 | 18k | -2.40 | -1.03 | +1.37 |
| Zaahen | top | 33,812 | 12,121 | 24k | +0.28 | +1.52 | +1.24 |
| Yunara | bottom | 127,354 | 40,863 | 28k | -0.81 | +0.31 | +1.11 |
| Kog'Maw | middle | 9,657 | 3,989 | 29k | -0.58 | +0.50 | +1.08 |
| Cho'Gath | jungle | 91,315 | 32,929 | 28k | +1.70 | +2.70 | +0.99 |
| Renata Glasc | support | 19,836 | 6,683 | 27k | +1.38 | +2.36 | +0.98 |
| Vel'Koz | top | 1,502 | 498 | 420k | +0.12 | -0.91 | -1.03 |
| Zoe | top | 1,546 | 537 | 421k | +2.23 | +1.22 | -1.01 |
| Katarina | middle | 79,364 | 26,729 | 305k | +0.73 | -0.21 | -0.95 |
| Shaco | jungle | 60,156 | 20,471 | 264k | +0.07 | -0.85 | -0.92 |
| Riven | middle | 5,214 | 1,902 | 310k | +1.10 | +0.20 | -0.90 |
| Neeko | middle | 4,456 | 1,419 | 320k | +1.28 | +0.38 | -0.89 |
| Fiddlesticks | support | 6,759 | 2,430 | 264k | -0.02 | -0.91 | -0.89 |

(pp vs the role at an even game; "players' mean points" is 10^(mean m + 3) - 1000.)

Lane card double count: lanecard.rankLogit adds beta * m to the draft's logit, whose
champion strength is raw, i.e. already at that champion's usual mastery. Scored on
dev-val (161,124 games, fit on the 1,208,276 before the dev cut, beta 0.0815), every
fetched seat of both teams, paired per game:

| scoring | log loss | vs raw strength (milli-nats) |
| --- | --- | --- |
| raw strength | 0.68794 | |
| raw + beta (m - everyone's mean m): the lane card now | 0.68519 | -2.75 ± 0.43 |
| raw + beta (m - the champion-role's mean m) | 0.68489 | -3.05 ± 0.41 |
| refit: theta + beta m | 0.68488 | -3.07 ± 0.41 |

Centring on the champion-role's mean beats the lane card's form by -0.30 ± 0.13
milli-nats a game, and matches the refit. So yes, the bonus double counts: within one
player's pool it favours champions whose players are practised in general (Katarina,
Shaco, Riven, Neeko by ~0.9 pp) and under-rates new or rarely mained ones (Locke,
Corki top, Zaahen top by up to 1.6 pp).

Reading (dev, final for the method, early for the site):
- A tier list or "safe blind" at fixed mastery moves few ranks (rank r >= 0.96); the
  champions that move are new releases (Locke every role) and one-trick favourites
- Fix for the lane card: rank by draft logit + beta (m - mean m of the champion-role),
  with a per-champion-role mean log mastery shipped beside the strengths (from fetched
  seats, shrunk to the role's). Not yet measured: the replay's hit rate with it
  (`meiolol eval --replay`), the honest test of the ranking itself
- beta is not causal practice alone: better players are also more practised on their
  mains. It is the right term for ranking within one player's pool (the replay's
  point), and for a tier list it standardises who plays the champion

### A4 on the new pin, shipped form, 2026-10-24 (meiolol-a4b, prepin run)

The frozen A4 candidate (`pair+kit:tag` at 40197e9, "Pair cells that borrow strength
(A4)") rerun against additive v2 in the form the stats file carries, on games no A4 run
had scored, to get it ready for Jacob's ship decision. Dev only, no test look.
Pre-declared in data/team/2026-10-23-prepin/a4b.md before any run.

Setup (`meiolol-lab pairprior --shipped --seen FILE`, 754c01d): both arms as fitted.zig
ships them: no damage mix, no side term, a pair cell's own part 0 under 20 fit games (its
parents kept), every term f16; a cell a slot never had gets its parents. snap-20261023T2004Z,
blocks 1-5 and dev-val, each fitted on its dev-visible games before the block (595k to
1.19M); the 410,801 match ids any 1007Z A4 run scored are left out of scoring, so each
block keeps its fresh games (1: 19,580; 2: 21,370; 3: 83,452; 4, 5: 119k each; dev-val
158,728; 521,223 pooled; folds 1-3's are older games the 1007Z pack didn't hold). Pass:
a4.md's rule on the pooled fresh games.

Runs 20261023T223630Z-a4b-ship, 223648Z-r1, 223712Z-r2, 231328Z-shuf, 231425Z-full
(Mac); milli-nats a game against v2 shipped, pooled per game (a4b-pool.py):

| statistic | pooled fresh games | blocks 1 / 2 / 3 / 4 / 5 / dev | verdict |
| --- | --- | --- | --- |
| candidate - v2 | -0.99 ± 0.12 | -1.05 / -0.52 / -0.99 / -1.10 / -1.07 / -0.90 | pass (bound -0.79) |
| resample 1 / 2 | -0.99 ± 0.12 / -0.94 ± 0.12 | | both < 0 |
| control (both shuffled) - v2 | +0.001 ± 0.001 | | not below v2 |
| candidate - control | -0.99 ± 0.12 | | < 0 |
| shuffled labels: candidate - v2 | -0.000 ± 0.008 | | no gain |
| pair alone / kit:tag alone (reported) | -0.66 ± 0.10 / -0.34 ± 0.07 | | |

Log loss: v2 shipped 0.6850-0.6862 by block, candidate 0.6841-0.6852. Worth shipping
(-0.10 or better).

What shipping costs and gives back (231425Z, the unshipped form on the same games: mix,
side term, no floor, f64): candidate - v2 there -0.73 ± 0.10. The shipped simplifications
cost v2 +0.84 ± 0.12 and the candidate only +0.58 ± 0.11, so shipped A4 against unshipped
v2 is -0.15 ± 0.15: it wins back everything v2 lost to shipping. The extra gain shipped is
the floor: today's file zeroes cells under 20 games, and the parents refill them.

The ship code (aefe235, behind a flag, off): additive.Parents in src/additive.zig, kit
classes from the champions table's tags, parents folded into statsfile v2's dense cells
by fitted.attach. Its parent step carries a guard the lab's lacks: the step is diagonal
over parents that share game sides (a team's 10 ally pairs), so where the data outweighs
the prior it overshoots (a dense 12-champion toy ran the lab fit to 4 million logits);
additive.zig halves a step until the penalised loss doesn't rise (Config.parent_guard
false is the lab's step, equal to pairprior's to 1e-9 in a test). Real fits halve 9-48
of ~170 steps. pairprior's `ship` variant runs that code (run 20261023T234104Z-a4b-shipcode,
fresh games, shipped form): ship - v2 pooled -0.98 ± 0.12 (blocks -1.04 / -0.56 / -0.99 /
-1.08 / -1.07 / -0.90, 14-34 halvings a fit) against the frozen fit's -0.99 ± 0.12.

End to end (`meiolol eval --dev --pair-prior`, aefe235, run 20261024T000646Z-a4b-eval: the
stats file and core.score as the site uses them, 2004Z's database, every platform, train
1,208,276 games to 18 Oct, dev-val 161,124 from 18 to 20 Oct): log loss 0.6843 against the
current model's 0.6851, -0.0009 ± 0.0002; AUC 0.576 against 0.572; accuracy 55.3% against
55.1%.

Cost per stats view and the ship plan: docs/plan/data-and-model.md DM1 (dense v2 cells:
no scorer or format change, download 1.6-3x larger gzipped; the 1.56M-game view's fit
163 s -> 363 s and 1.26 -> 1.62 GB on a shared Mac).

### Draft ceiling (B1) rerun on 2004Z, 2026-10-24 (w1c, prepin run)

The 22 Oct B1 ("Lab frontier wave 1") was provisional: null sd 0.35-0.64, planted flips
short, and additive v2 showing more left than win-draft though it predicts better. Rerun
on snap-20261023T2004Z, dev only, no test look, with the estimator fixed. Script
py/xcheck/ceiling.py (Mac, `uv run --no-project --with numpy --with pandas`), output
data/runs/b1-2004Z/ (ceiling.md final, effects.md the same on the effects models,
effects-v1-estimator.md the 22 Oct estimator on these preds, attain.md).

Preds (753,959 games: folds 1-5 and dev-val, every platform, each block fitted on the
games before it): one Mac run 20261023T225629Z-effects-wr-v2-2004Z (`effects --param v2`
built with -Dcand win-ratings, HEAD ed17798) for win-ratings (the reference: champion-role
ratings, no pair terms), additive mains, v2 full (damage mix) and v2 without the mix
(the shipped form's terms, f64, side term kept); w1g's gpu-box runs
20261023T232808Z-setid-wd-2004Z (win-draft and its set net, seeds 1-3) and
20261023T234438Z-setid-wa-2004Z + 20261023T235036Z-setid-wa-s456-2004Z (set net +
champion-role embedding on v2, seeds 1-6 as one logit mean). Their candidates' preds
match the effects run's to the printed digit.

What was wrong with the 22 Oct estimator, each found by a check on the real schedule of
games:
- Overlaps: it assumed two games sharing a pair cell share only that cell's two mains.
  They often share a third champion or an enemy too, so each pair effect was counted
  again through the other cells. Planted cells (y drawn from win-ratings' logit plus cells
  at the sizes measured): the old estimator recovered 22.4 milli-nats where 12.3 were
  planted, ~1.8x. Now M, the expectation of each block's statistic given each unit's
  variance, comes from simulation: each unit's cells at +-1 (Rademacher) and nothing
  else, through the same statistic, so every overlap counts
- Nested folds: block k's model has seen block k-1's games, so a pair of games across
  blocks carries the model's step on the earlier game (-lambda w w) instead of a
  residual covariance. That pulls a model's estimate down where it estimates cells
  (win-ratings' mains came out negative, v2's own V/8 2.1 below its distance to the
  ceiling on a dev + fold 5 check). Now a cell is per scored block: only games one model
  scored, none of which it saw, share it
- Pair weighting: each cell weighed by its pairs of games (n^2), so the biggest cells
  decided the answer, while rare cells spread more (B4). Now cells sit in bands by games
  in the block (2-9, 10-49, 50-199, 200+; mains 2-499, 500-1999, 2000+), one variance
  per band, and V counts each band by the cells a game holds (one-game cells, 0.47 a game
  of 55, at their block's smallest band). That is the per-game excess log loss, the
  thing a model's log loss measures

Result: milli-nats a game a perfect estimate of each block would gain over the model
(V/8), null sd of the total from 20 Bernoulli draws on each model's own chances:

| model | main | ally | lane | cross | total (null sd) | log loss | log loss - V/8 | s of the model |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| win-ratings (reference) | 0.08 | 2.41 | 2.98 | 3.65 | 9.11 (0.96) | 0.68848 | 0.67937 | 0.193 |
| additive mains | -0.14 | 2.13 | 2.95 | 3.24 | 8.17 (1.02) | 0.68799 | 0.67982 | 0.203 |
| win-draft | 0.12 | 1.63 | 2.08 | 2.49 | 6.32 (0.94) | 0.68595 | 0.67963 | 0.240 |
| v2 without the mix | 0.07 | 1.60 | 1.58 | 2.43 | 5.68 (1.12) | 0.68526 | 0.67958 | 0.251 |
| v2 full | 0.08 | 1.28 | 1.57 | 2.48 | 5.40 (0.85) | 0.68468 | 0.67928 | 0.260 |
| set net on win-draft | 0.14 | 1.20 | 1.94 | 2.12 | 5.41 (0.98) | 0.68452 | 0.67911 | 0.263 |
| set net on v2 (6 seeds) | 0.12 | 1.14 | 1.45 | 2.04 | 4.76 (0.88) | 0.68390 | 0.67914 | 0.272 |

Checks:
- Consistency: V/8 is an excess loss, so every model's log loss minus its V/8 should
  be the same perfect log loss. It is: 0.67911 to 0.67982, all within one null sd of
  the reference's 0.67937. The 22 Oct paradox is gone: what is left now falls in the
  models' log loss order (win-draft 6.3, v2 5.4, set net 4.8)
- Flips (10% of labels, 20 draws): win-ratings 5.76 ± 0.62 against 5.80 expected, set
  net 2.96 ± 0.82 against 3.00 (expected from the estimate and M of the flipped chances)
- Planted (6 draws over two runs): recovered 8.93 ± 0.43 and 8.21 ± 1.23 against 9.36
  and 9.35 planted. Models of the planted truth that estimate each pair cell from its
  games: V/8 8.02 and 7.24 against a true excess of 8.45-8.47 and a log loss gap of
  8.03-8.11 (posterior-mean shrink); 10.58 and 9.80 against 10.72 and 10.24-10.44
  (shrunk a quarter as much). So model cell noise counts in V/8 as excess, as it
  should, and nothing else inflates it; the estimator may sit ~5-10% low
- Null sd of the total ~0.9-1.1 milli-nats: within-block pairs and bands cost the
  doubled games' gain. By scored block alone, the total varies more than the null
  (win-ratings 4.3, 13.6, 9.7, 9.7, 12.1, dev-val 5.7; set net 0.6, 8.7, 6.0, 5.8, 7.7,
  1.2; null sd ~2.4 each; chi-square p ~0.05): fold 1 and dev-val show least

Where it is (pair blocks, by the cell's games in its scored block, ± null sd):

| model | one-game cells | 2-9 | 10-49 | 50-199 | 200+ |
| --- | --- | --- | --- | --- | --- |
| win-ratings | 0.24 | 1.34 ± 0.60 | 1.57 ± 0.37 | 3.20 ± 0.23 | 2.68 ± 0.19 |
| v2 full | 0.19 | 1.08 ± 0.66 | 1.12 ± 0.43 | 1.66 ± 0.28 | 1.26 ± 0.13 |
| set net on v2 | 0.17 | 0.94 ± 0.69 | 0.93 ± 0.57 | 1.40 ± 0.25 | 1.19 ± 0.17 |

The reference's cell sd (pp at an even game): ally 0.7-1.1, lane 1.4-1.8 (2.9 in 2-9
game cells), cross 0.8-0.9 (2.0 in 2-9); mains left over the ratings: 1.4 pp in
off-role cells under 500 games a block, ~0 above.

How much of the reference's 9.5 an ideal estimate of each cell on its own could reach
(posterior mean per cell, lambda = s2 / (s2 + 4 / n), n its games over all 1.37M dev
games, s2 the reference's band; data/runs/b1-2004Z/attain.py, a one-off): 3.3 (35%);
with 2x the games 4.5, 4x 5.7, 10x 7.1. The models already pass the 1x figure: v2
captures 3.7 of the reference's 9.1, the set net 4.4, by borrowing across cells (low
rank, damage mix, embeddings).

Gate (lab-frontier "Order and gates": a ceiling near s 0.27 -> stop draft architecture
work): not met. The four blocks known perfectly give log loss ~0.6793, s
0.33 (about 56.5% of games called right), against the best model's 0.6839, s 0.27
(~55.4%): 4.8 ± 0.9 milli-nats a game left, six times the set net's gain over v2. It
is in pair cells (cross-role enemy pairs most, then lane matchups, then ally pairs),
2.6 of it in cells with 50+ games a block (500+ in a fit). Estimating cells one by one
is spent at this data size, so what is left needs strength borrowed across cells (A4's
pair and kit parents, low rank, nets) or more games: an ideal per-cell estimate gains
~1.2 milli-nats a doubling of games here, more than the set net's gain over v2 (0.8),
so the production key's games pay as well. B1 is now fit to be the gate: the four checks
hold and its null sd is ~1 milli-nat; rerun it at each pin.

Not covered: three-way and comp effects beyond the four blocks (the damage mix and nets
capture some; their gain shows as the models' log loss, not here), drift within a cell
(the estimate is each block's own cell effect), player terms (D1, the replay).

## Shipped model, 2026-10-23: additive v2 in the stats file

Drafts (app suggest, the site's draft helper, Daily Draft, Learn, lane cards, pool) now
score with additive v2 without its damage mix (src/fitted.zig on src/additive.zig, moved
out of the lab), fitted on each stats file's own played games (15:00+) and written into
it as statsfile v2: f16 logits, pair cells under 20 games 0 (the lab export's floor),
no side term. Each site view fits its own (4 fits a site round; 878k games: +18 s and a
744 MB peak on the Mac); `meiolol stats` too. Page rates (roleWin, duoPp, matchupPp)
keep the counts; score.Options.fitted false gives the 17 Oct counts model. The desktop
copy is stripped back to v1 (deploy/web-loop.sh strip_fitted) until a desktop release
reads v2.

Eval on snap-20261018T1007Z's database (877,814 games, every platform, test 131,746
newest, 15 to 18 Oct), shipped form against the counts model: log loss 0.6860 against
0.6864, -0.00036 ± 0.00021, AUC 0.567 against 0.566, accuracy 54.8% against 54.6%. The
same fit unfloored with its platform side terms: -0.0007 ± 0.0002. The floor costs
nothing (floors 0 and 5: -0.00037 ± 0.00021 each), so the ~0.0003 is the per-platform
side terms, which side-free suggestions can't use. Pick metric: winners' picks rank 0.670 vs losers' 0.648
(counts 0.682 vs 0.664), AUC 0.522 both. From 23 Oct the daily eval's "current model"
and eval-history's ll_current are this model; ll_counts, d_current_counts and
ci_current_counts keep the counts model beside it. The damage mix (~0.7 milli-nats more
in the lab) needs per-champion-role profiles on the box (seat stats decision).

## Shipped model, 2026-10-17

`score.Options` defaults (app suggest, site draft tester, Daily Draft, pool, matchup and
duo numbers on pages) moved from priors 1000/1000 with plain sums to the daily eval's
"tuned + term weights" of 17 Oct: base prior 50, pair prior 3200, term weights base
0.943, duo 0.765, lane 2.025, matchup 1.009 (no blue side intercept: suggestions are
side-free). Eval that day (785,843 games, 15 platforms, test 117,908 newest, 15 to 17
Oct): log loss 0.6860 against 0.6878, -0.0017 ± 0.0004, AUC 0.567 against 0.562,
accuracy 54.8% against 54.4%.

- What changes on screen: ally duos shrink most (0.765 under a 3200 prior: a 1000-game
  duo keeps ~18% of its raw delta, was 50%); lane matchups move little at typical sizes
  (1000 games: 48% kept, was 50%; 3000: 98%, was 75%) and exceed the raw delta above
  ~3,100 games; other matchups shrink more. Base ratings shrink less (50 pseudo-games)
- Lane above 1 is one shared pair prior being too strong for lane opponents (EB says
  ~1000 for lanes, ~33k for other matchups). Next: tune duo, lane and matchup priors
  separately in eval; weights near 1 would keep shown numbers close to the data
- From 18 Oct eval-history's ll_current and the report's "current model" are this
  model; "previous model (1000/1000)" keeps the old one in the report, and "champion
  base only" stays at the old base prior 1000 so its column continues. Every other row
  (tuned priors, empirical Bayes, the tuning grid) sums its terms plainly as before
- Values are fixed, not retuned daily: prior strengths reflect the real spread between
  champions, not the sample size. Revisit when the daily tuning drifts from them

## Model files and tests

### Draft model file (meiolol draft-model, meiolol-lab draft --export)

`meiolol draft-model [--out DIR]` (src/draftmodel.zig, default DATA/tester) writes the
shipped model (core.score, Options defaults, as the site and app score drafts) fitted on
every played game in the database, every platform and patch: kind "draft", the same file
as the win-draft export below (17 Oct, snap-20261017T1320Z: every term and pair cell
equal, 800,302 games, 6 s on the Mac; meta.snapshot "box database"). It stops unless
the file's scorer matches core.score.draftWin on 500 test games within 1e-4 (5e-9
measured); meta.dev refits on the played games older than dev-val and scores dev-val per
game, baseline champion strength alone. Daily on the box (deploy/web-loop.sh), served at
/admin/models/ with the admin upload. The tester's Model switch picks the draft model:
"Shipped model" (this file) or "Lab experiment" (/admin/training/, `lab-push.sh use`, with
the set net when draft-setnet.json is there); the lane model is the box's, else the lab's;
comp terms the lab's. It also writes champ/<id>.json (and .gz) per champion: by role, its team's
chance against an average draft (95% range) and with each opponent ("vs") and ally
("with") it has a cell with, [role, champion, chance, games], every other slot its
role's average pick; the private site's pv.js shows them on champion and matchup pages
(docs/plan/app.md "Private site"). The writer is src/draftfile.zig and the scorer
src/core/draftscore.zig, shared with the lab and ui.wasm. `meiolol tester-bin DIR`
encodes DIR's export as draft-model.bin for the new tester page (ui/testerdata.zig),
only when the Zig scorer reading it matches draft-ref.json; the web loop runs it after
`draft-model`, deploy/lab-push.sh on a lab export.

`meiolol-lab draft SNAP --export DIR` (src/lab/draft.zig, built with a candidate that has
`exportModel`, today win-ratings) fits on every game in the snapshot and writes
DIR/draft-model.json and DIR/draft-ref.json for the admin draft board (meiolol-3b).
With `--model additive [--pair-floor N]` it fits the additive model instead (effects'
v2 "full": champion strength, ally pairs, the 15 identified matchup blocks, damage mix;
src/lab/addinputs.zig builds its inputs for both, so the shipped model is the evaluated
one) on every played game, -Dcand unused; needs seat stats.
Admin only: the public site never shows "this draft wins X%" (docs/learned.md). Run it
into a run dir on the Mac (~/ml/runs/<stamp>-draft-export); lab-push.sh sends the newest.
Built with -Dcand=src/lab/cand/win-draft it exports the shipped model (kind "draft",
17 Oct): b the weighted base, pairs every ally pair and matchup cell with the term weight
folded into theta (min_games 1, nothing left out), intercept 0, temperature 1 (pass
`--temperature 1`: the cand default is 0.80); the scorer check came out at 3e-8 on 500
test games, so the tester scores drafts as the app and site do. Its companion,
`meiolol-lab champcomp SNAP --export DIR` (same cand), writes DIR/draft-comp.json:

- format meiolol-champcomp, version 2 (1: 16 features, no groups; the tester reads both);
  meta {snapshot, offset "win-draft", fit_games
  (dev-val's: dev games, no test look), what, folds and devval {mean, half, n} (nats a
  game against the offset), better (of 5), clear, tests, bh}
- traits [9 labels, the last auto-attack build: `--aa`, 0 without]; features [18 {name,
  label, mean, sd}]: the enemy's five, then the seat's four allies; mean and sd
  standardise the raw set traits
- seats [[champion, role, magic, dmg, v1..v8]] and role_seats [5][magic, dmg, v1..v8]
  (an empty slot or a champion-role with no profile): a set's AP share is its summed
  magic over summed dmg (0.5 with none), every other trait the sum of v
- cells [{champion, role, games, centre[18], dev[18], sd[18], clear [feature indices],
  group[18], member [group indices]}]: group[f] is the part of dev[f] its kit groups
  predict (centred memberships, so a non-member's is small and the other way), dev[f] -
  group[f] the champion's own; groups [{label, words, feature, gamma, sd, members}]
  (`--groups`, else empty; gamma in logit per sd of the enemy feature);
  champion-roles with any nonzero deviation only: a seat's term on its team's logit is
  sum_f dev[f] * ((x[f] - mean[f]) / sd[f] - centre[f]); team terms left out
  (-0.00001 ± 0.00005)
- refs [{label, teams, blue}]: blue's part (blue's seat terms minus red's) on 6 dev-val
  games; the tester checks itself against them (1e-6) and adds the part to the shipped
  model's logit; draft-ref.json is still checked on the model alone


draft-model.json (format meiolol-draft-model, version 4; 3 had no pairs, 2 no
temperature, 1 no p and no comp):
- meta: name ("win-ratings (ratings)"), run, snapshot, newest_game, training_games
  (games that lasted 15:00, as the harness fits), patch (the share patch: the newest
  with 20,000+ games every platform, else the newest; draftfile.min_share_games),
  patch_games (its games), oldest_patch and newest_patch (training games'; 21 Oct, older
  files lack them), platform (EUW1: the intercept used), dev {what, games, log_loss,
  baseline_log_loss, coin_log_loss, accuracy, auc}: a refit on dev's games, scored on
  dev-val, as described in `what`
- roles: top, jungle, middle, bottom, utility; role fields are indices into it
- has_pairs: false for rates and ratings. Then the other picks shift the numbers, not
  the order of candidates for a slot. true for embeddings and additive
- min_games: default floor of training games in the role to list a candidate (100)
- champions [{id, name, alias}]: alias is the name lowercased, letters and digits only
- cells [{champion, role, games, patch_games, patch_share}]: training games in the role
  (every patch); games and share of the role's games on the share patch (random games,
  picker order, role averages)
- average[role] {b, u, v, s, p, raw}: the empty-slot term, patch_share-weighted mean of the
  role's terms on the share patch
- model {kind, dim, intercept, w[25], z[25], terms [{champion, role, games, b, sd, u, v,
  s, p, raw}], comp, temperature}: temperature multiplies the whole logit and the
  interval's ends (calibration; draft.zig default_temperature 0.80: win-ratings' preds on
  win-comp's 5 forward folds of 2055Z, 44,353 games, fitted 0.80 ± 0.11, its top tenth
  said 58.6% and won 55.8%; `--temperature T` overrides, 1 is the raw model; refitted per
  pin on that pin's fold preds: snap-20261013T2253Z before its global re-cut, 78,036 fold
  games, 0.89 ± 0.04, folds 0.71-1.30, dev-val 1.02 ± 0.10, so with ~2x the fit games
  ratings is less over-confident; the shipped fit has more games than any fold, so the
  folds' T may shrink slightly too much; after the all-platform re-cut, 134,375 fold
  games: 0.965 ± 0.029, folds 0.86-1.11, dev-val 1.07 ± 0.06, top tenth said 59.8% and
  won 59.3%. Export 20261014T004029Z-draft-export-2253Z (0c3e486, --temperature 0.965)
  fits on all 363,472 played games, test and every platform included, as shipped models
  now do). Every shown chance, slot list and comp reason
  uses it; ratings, comp parts and the debug trace's
  terms stay in the model's own logit; u, v, s are length dim (empty for rates and ratings); w and z
  row-major 5 x 5; p the champion-role's profile (k numbers, z-scored within the role;
  empty without comp); raw the profile in raw units, all 12 of win-comp's Feature order
  (magic share of damage first, damage per minute third; empty without team terms). b
  already holds any profile prior
- pairs (null except additive): {min_games, groups [{name, kind ("ally" or "matchup"), r,
  q, sd (the block's sd in logit: spread of true effects), fitted, shipped (cells in the
  fit and in the file)}], cells [[group, a, b, theta, games]]}: group indexes groups;
  theta in logit, rounded to 1e-5; cells on fewer than min_games fit games (default 20)
  are left out and count 0, the prior mean (the export prints how far that moves blue's
  logit). Additive's terms: b champion strength, sd 1 / sqrt(posterior curvature), raw
  the champion-role's damage mix profile (magic share at 0, damage per minute at 2,
  the rest 0); comp has no stats and one team term, mix at centre 0.5
- comp (null without comp terms, win-comp): stats [{name, label}] (k; label plain English
  for the tester's reasons), S and A (k x k row-major; S symmetric, an off-diagonal pair's
  weight split half and half; A antisymmetric), S_sd and A_sd (Laplace sd per entry), team
  [{kind, stat (unused), centre, weight, sd (optional)}] (within-team terms on f, the
  team's damage-weighted magic share: kinds mix, ad_heavy, ap_heavy; any other kind stops
  the export and the page), beta (5 x k profile prior per role, shown only)

Scoring (Scorer in draft.zig, the reference). Each slot is a champion-role term; an
empty slot, or a champion with no term in that role, is average[role] with sd 0. B_r and
R_r are blue's and red's slot in role r:

```
logit = intercept + sum_r (B_r.b - R_r.b)
      + sum_{ri,rj} w[ri*5+rj] * (<B_ri.u, R_rj.v> - <R_ri.u, B_rj.v>)
      + sum_{a<b} z[a*5+b] * (<B_a.s, B_b.s> - <R_a.s, R_b.s>)
      + P_b' S P_b - P_r' S P_r + P_b' A P_r     P_b = sum_r B_r.p, P_r = sum_r R_r.p
      + sum_team weight * (form(f_b - centre) - form(f_r - centre))
      + pairs (below)
f = sum_r raw.dmg * raw.magic / sum_r raw.dmg (0.5 if no damage); form: mix d^2,
ad_heavy min(d, 0)^2, ap_heavy max(d, 0)^2
blue = 1 / (1 + exp(-T logit)); red = 1 - blue          T = model.temperature (1 if absent)
var = sum over the 10 slots of sd^2;  interval = sigmoid(T (logit -/+ 1.96 sqrt(var)))
```

pairs, per group (an empty slot touches no cell): ally cell(B_r, B_q) - cell(R_r, R_q);
matchup r < q cell(B_r, R_q) - cell(R_r, B_q); matchup r = q with a = B_r, b = R_r: 0
if a = b, else cell(min, max) signed + if a < b, - if not. Additive's temperature:
default_temperature_additive 1.01, fitted on effects' v2 "full" preds on 2253Z's 5
forward folds (run 20261014T041809Z-e53v2-V0, 134,375 games): 1.01 ± 0.03, folds
0.96-1.10, dev-val 1.14 ± 0.05; the top tenth said 61.1% and won 61.2%. Unlike ratings
(0.80 on 2055Z, 0.965 on 2253Z) the shrunk additive model needs no calibration.

sd is a Laplace approximation of each rating's own uncertainty, 1 / sqrt(games / 4 +
prior precision), treated as independent: parameter uncertainty, not the game's.
Slot query (the tester's list): candidates are champions with games >= min_games in the
role, not picked by either team and not banned; win is the user's team's chance with it
in the slot, change = win minus the chance with the slot empty, and "an average pick" is
the mean of the candidates' win weighted by their games in the role.
Comp reasons (the tester, with comp terms): each S and A entry's and team term's part of
the picking side's logit change when the candidate fills the empty slot (A from that
side: mine'A theirs), in pp through the sigmoid's secant over the whole change, +-1.96 sd
of the entry ("no range exported" without one); pair reasons the same way, each cell the
candidate touches as "with your X" or "against their X", with the cell's games for want
of an sd; the two largest of either kind are shown. The win interval stays ratings-only.

draft-ref.json: `tolerance` 1e-9; `drafts` [{label, teams[side][role] (0 empty), blue
{p, lo, hi}, comp (the comp part of blue's logit), pairs (the pair part)}] (three EUW1 test games whole and with
three slots empty, the empty board, every slot a champion with no term in its role, and
Rammus jungle alone into a full AP and a full AD red team); `slots` [{label, role, side,
teams (by side), bans, min_games, empty, average, options [{champion, games, win, lo, hi,
change}] sorted by win, then champion id}] (blue middle to fill, red middle to fill, blue
jungle to fill into 5 AP and into 5 AD). Export
checks the scorer against the candidate's own predict (through the same temperature) on
500 test games and stops if they differ by more than 1e-4 (f32: ~5e-8 measured); for
additive, against additive.predict with the exported cells (floor and rounding applied),
the shipped mix profiles and EUW1's side term. meta.dev for additive: log loss per game,
baseline champion strength alone.

### Lane model file (meiolol-lab lane --export)

`meiolol-lab lane SNAP --export DIR` (src/lab/lane.zig, built with
-Dcand=src/lab/cand/team2, the candidate with `exportLane`) fits 3c-team2 on every game
that reached 15:00 and writes DIR/lane-model.json and DIR/lane-ref.json for the admin
Draft tester's champion suggester (meiolol-3b): early outcomes for a champion into a lane
opponent. Champion-only inputs; admin only. Run it through deploy/lab-run.sh with
`-- lane "~/ml/snaps/SNAP" --export .` (first run 20261012T2326Z-lane-export: 182,748
games, 849 champion terms, 48,194 pairs, 2.8 MB).

`meiolol lane-model [--out DIR]` (src/lanemodel.zig, default DATA/tester) fits the same
candidate (team2's fitLane: its fit on compact rows, lane outcomes only) on every played
game in the database and writes the same files, daily on the box beside `meiolol
draft-model` (served at /admin/models/). Its rows are the lab's (gold14 from
participants, else the timeline's; the rest from timelines that reached 15:00; one
participants pass and one timelines pass), 0.9 GB peak for 800k games where the lab's
full rows take 4.8 GB. On snap-20261017T1320Z (17 Oct) every term, pair cell, intercept
and dev figure equals the lab export's; 137 s on the Mac. The scorer and writer are
src/lanefile.zig, shared with lab/lane.zig.

lane-model.json (format meiolol-lane-model, version 1); every number rounded to 0.01:
- meta: name, run, snapshot, newest_game, training_games, patch (newest: its offset is
  in the intercept), oldest_patch and newest_patch (training games'), platform
  (EUW1), dev [{outcome, unit, rows, err_base, err_cand, removed_pct, removed_half}]: a
  refit on dev's games scored on dev-val (typical miss in the unit, % of the champion-role
  baseline's error removed, 95% half-width)
- roles; outcomes [gold14, lanediff14, cs10, deaths15]; units [gold, gold, CS, deaths]:
  every per-outcome array below is in this order
- champions [{id, name, alias}]
- intercept[o][role]: role mean + EUW1's platform offset + the newest patch's offset
- others[o][role]: the other eight slots at their average (rows-weighted mean of the
  duo, jungle and rest terms)
- spread[o][role]: residual sd, the typical game-to-game spread around an expectation
- champ, enemy [{champion, enemy (0), role, n, b[o], sd[o]}]: own champion's term, and
  the lane opponent's own term for the player in that role; n training rows (gold14's)
- pair_columns, pairs: lane cells (own champion vs opponent, every pair with a training
  game) as arrays [champion, enemy, role, n, b x4, sd x4]

Scoring (Scorer in lane.zig, the reference). For champion X in role r into opponent Y,
per outcome o, a missing term counting 0:

```
value = intercept[o][r] + others[o][r] + champ(X, r).b[o] + enemy(Y, r).b[o] + pair(X, Y, r).b[o]
range = value -/+ 1.96 sqrt(sum of the present terms' sd[o]^2)
```

sd is each shrunk effect's posterior, sigma / sqrt(n + k), in the outcome's units:
uncertainty of the average, not of one game (spread is that). lane.zig checks the
export against the model's predictions before writing (max |diff| 0.02, rounding).
lane-ref.json: per role the 4 most played pairs, a champion into an opponent with no
pair cell and an unknown champion (id 0), each with value, lo, hi, champ_games and
pair_games from Scorer.value; the page's JS must match them to 0.01.

### In-game model file (py/state/stateship.py)

Your games' win chance by minute (src/statemodel.zig) is richc ("Rich state and
champions (richc)"). `deploy/lab-run.sh start gpu-box state-ship --python
py/state/stateship.py --with py/xcheck/nnsets.py -- '$HOME/ml/snaps/SNAP' --out out`
fits it on every played game with a timeline (test included, as shipped exports do),
the same procedure as one statemodels.py block: win-ratings L2 and richc's ridge
picked on the newest 10% of games, the fit rows' draft logit cross-fitted in 5 parts,
rows every other minute 1-40. It writes out/state-model.bin, copied to
src/state_model.bin (embedded in the binary), and out/state-check.tsv (match_id,
minute, p: blue's chance for 500 random fitted games from the file's numbers, which
stateship checks against the fit's own predict, max |diff| under 1e-5). Then
`meiolol-lab state-export SNAP --check state-model.bin state-check.tsv` recomputes
those chances in Zig from the timelines (livestate.zig, the code state-export uses)
and exits 1 when any differs by more than 1e-4.

state-model.bin, little-endian, version 1:
- header (180 bytes): magic "meiolol-state" padded with zeros to 16 bytes; u32
  version, F (features, 91), K (knots), P (platforms), C (champion-role terms),
  training games, 0; i64 newest game start (ms); snapshot and run names, 64 bytes each,
  zero-padded
- K f32 knots (minutes 1, 5, ..., 40)
- F names, 24 bytes each, zero-padded: statecommon.features' order, which
  statemodel.zig's `names` must equal (parse refuses the file otherwise)
- F f32 mu, F f32 sd (standardisation from the fit rows), F x K f32 W (feature-major),
  K f32 b (intercept by knot)
- f32 default platform intercept (fit games' mean), then P x (8-byte platform id, f32
  intercept): win-ratings' platform term
- C x (u32 Riot champion id, u32 role 0-4 as core.Role, f32 rating, K f32 effect): the
  champion-role's win-ratings term and its richc effect by knot; a champion-role not in
  the file counts 0

Scoring (statemodel.zig; seats s = side x 5 + role, blue 0-4):

```
draft  = intercept[platform] + sum_{s<5} rating(s) - sum_{s>=5} rating(s)
x      = features(state at minute m, draft)       (91, blue minus red, units as statecommon)
h      = hat(m): weights linear between knots, m clipped to [first, last] knot
logit  = sum_k h_k (b_k + sum_f (x_f - mu_f) / sd_f W[f,k]
                    + sum_{s<5} effect(s)_k - sum_{s>=5} effect(s)_k)
blue   = 1 / (1 + exp(-logit)); 0.5 at minute 0; none once the game has ended
```

Shipped file: run 20261014T211923Z-state-ship-2253Zr (snap-20261013T2253Z re-cut, 6dd6bfe):
286,721 played games with a timeline (358,334 played; test included), 4,160,946 fit
rows, ratings L2 1e-3, ridge 1e-5 (newest 10%: 0.50797 at 1e-5, 0.51191 at 3e-4: the
grid's edge again), champion effect sd by knot 0.09, 0.14, 0.16, 0.16, 0.16, 0.15,
0.12, 0.09, 0.05; 863 champion-role terms, 48,048 bytes, default intercept 0.023; the
file against the fit's predict on 500 games (14,087 game-minutes): max |diff| 2.2e-7;
statemodel.zig from the timelines against the file's chances on the same game-minutes
(run 20261014T215013Z-state-ship-check, e8cb4b0): max |diff| 2.1e-8.
Rare champion-roles are shrunk hard (under 30 games: largest effect at any knot 0.10;
1,000+ games: median 0.19, largest 0.77, Kayle middle late), so effects are those of
picks seen often.

Your games: every side's five teamPositions once, else winchance.zig; the platform
from the match id; completed items from the newest curves patch's legendaries
(ddragon), as the lab uses its patch's legendaries.tsv. Ranked solo fit, shown for
flex, draft and Swiftplay too (as winchance was).

### Model tests, 2026-10-13 (meiolol-tests: meiolol-0a [8b5601], then meiolol-d8)

Question: do the models work and train properly, and could they have detected the effects
we call "not detected"? Three kinds of check, all on the gpu-box:
- Golden numbers: `deploy/golden.sh [--commit SHA] [--test] [CASE...]` reruns the reference
  models of docs/golden.tsv on their snapshot and needs each published log loss to the
  last digit; a miss is a finding, never a reason to edit the expected value. Test cases
  (`*-test`) only with `--test` or by name: the test looks ledger (looks.zig) counts each
  rerun as a look. Run it after any tooling or numeric change (~2 min)
- Training health: `meiolol-lab health` (src/lab/health.zig, ~25 s) trains each net family
  on synthetic games with a known logit through its healthFit entry point
- Planted effects: any command's SNAP may be `plant:SPEC:PATH` (src/lab/synth.zig): the
  real games, drafts, folds and seat stats, with only who won redrawn from a logit with
  known planted terms (champion-role strengths, an ally pair, a lane matchup, every ally
  pair or matchup with its own effect, the damage mix, per-player champion experience).
  `meiolol-lab plant-score PLANT PREDS.tsv [REF]` then scores any model's per-game preds
  against the truth: loss vs the reference, the oracle's loss, and the share of each
  planted part the model's logit carries ("captured": slope on that part, 1 all of it)

Golden, snap-20261012T2055Z: all 6 reproduce to the last digit at d87d8d7 (74cf241); the
4 non-test cases again at a7961de (f98213f).
Golden moved at 85fd62a (one time cut over every platform, 14 Oct), by design: dev-val
went from 8,500 EUW1 games to 22,174 games on every platform (85,000 to 221,740 rows), the
folds' cut moved with the test cut. Parent c4e8077 gives all 4 non-test cases exactly; from
85fd62a on, ratings-dev 0.68867, comp-dev 0.68835, ratings-folds 0.68947, comp-folds
0.68905 (same at 616e0a6 and e0ef0f5). Test cases not rerun (each is a look). golden.tsv
still holds the old-protocol values: new ones are Jacob's call.

| case | published | got |
| --- | --- | --- |
| win-ratings dev-val | 0.68969 | 0.68969 |
| win-comp dev-val | 0.68999 | 0.68999 |
| win-ratings folds | 0.69090 | 0.69090 |
| win-comp folds | 0.69033 | 0.69033 |
| win-ratings test (rerun of look 20261013T195618Z) | 0.69064 | 0.69064 |
| win-comp test (rerun of look 20261013T195708Z) | 0.69065 | 0.69065 |

Health: 0 of 45 checks failed (run 20261013T225211Z-tst-health3, c3347bb), 9 per family:
big (draftnet), small and resid (winnet), set (setnet), player (playernet). Per family:
loss at init within 0.01 of the base rate's (the offset's for residual nets: their output
weights start at 0); logit sum with sides swapped constant at init and after training
(antisymmetry); held-out loss below the base rate's by > 0.03 after training (largest
seen 0.165, smallest 0.145, resid); trains a tiny random-label set to ~0 loss (set net
0.0012, limit 0.45: dropout and mean pooling); same seed gives identical parameters, seed
2 differs; no non-finite parameters. Not covered yet: win-ratings, win-comp, stacking and
GBDT themselves (the golden numbers cover the first two).

Planted sweep 1: netcheck --net small --max-epochs 1 --seeds 1 on planted copies of
snap-20261012T2055Z (pinned commit d87d8d7), win-ratings or win-comp as the candidate,
champion sd 2.5 pp (too wide: ratings reach 0.684 on folds vs 0.691 real; later sweeps use
1.7). Folds, 44,353 games; mix in pp per sd of win-comp's mix form; oracle = what the
planted term is worth in nats/game to the truth on these games.

| planted mix | win-comp captured, seeds 1/2/3 (± ~0.03) | oracle value |
| --- | --- | --- |
| -1 | 0.74 / 0.61 / 1.01 | -0.00018, +0.00003, -0.00022 (± 0.0002) |
| -2 | 0.91 / 0.60 / 0.99 | -0.00077, -0.00036, -0.00077 (± 0.0004) |
| -4 | 0.92 / 0.83 / 0.94 | -0.00293, -0.00221, -0.00302 (± 0.0007) |

Runs 20261013T221917Z-tst-wr-none-s1 to 20261013T222133Z-tst-wc-mix4-s3 (17, list in
the tests progress file), scored by tst-score-*.
- win-comp finds the planted mix in 9 of 9 runs, down to 1 pp per sd (at ~90k fit games
  its se is ~0.17 pp, so 1 pp is ~6 se); the captured share's seed spread (0.6-1.0) is
  estimation noise
- But a 1 pp/sd effect is worth ~0.0001-0.0002 nats/game, under the folds' paired noise
  (± ~0.0003, and the floor ± ~0.0005): a real effect of that size shows as an effect
  estimate yet "not detected" as a gain. So report the effect with its interval beside
  the gain. The real fit, mix -1.50 ± 0.33 pp/sd with a folds gain of -0.00057 ± 0.00028,
  is in line with a true effect of ~1.5-2 pp/sd
- win-ratings alone carries 39% of a planted -4 mix through champion strengths (paired at
  mix -4, seed 1: win-comp -0.0009 vs ratings, against an oracle -0.0029): a comp term's
  gain over ratings understates the comp effect
- Controls (win-ratings, synergy 4, counter 4, skill 1): ratings carry 43% ± 4 of the top
  ally pair (4,749 team-games) and 29% ± 5 of the top lane matchup (3,789 games) through
  the two champions' strengths, and 3% ± 2 of skill (no experience input)
- Nothing planted: win-comp equals win-ratings within 0.00002 (no false mix)
- Small net, 1 epoch, one seed, is worse than its candidate on planted data (+0.0017 on
  folds): as on real data, not a health failure

Planted tests of the additive effects model ("Effects and the CPU model"): `effects
plant:seed=1,champ=1.7[,X]:snap-20261012T2055Z --blocks 1,2,3,4,5 --boot 50 --drop 0`
(a7961de, --null 10), fitted on dev's 88,706 fit games; block sd = sd_corr_pp, win pp at
50%; covers = its 95% interval holds the planted value; captured from plant-score of the
fold games files (44,353 games).

| planted | blocks | mean sd | covers | detected | full: captured, vs ratings |
| --- | --- | --- | --- | --- | --- |
| nothing | 10 ally, 25 enemy | 0.00 | 10/10 ally | 0/35 | -, -0.00003 ± 0.00020 |
| nothing | 5 champion (1.7) | 1.65 | 4/5 | 5/5 | |
| ally pairs sd 2 | 10 ally | 1.21 | 1/10 | 6/10 | 10%, -0.00114 ± 0.00034 |
| ally pairs sd 4 | 10 ally | 2.99 | 0/10 | 10/10 | 22%, -0.01272 ± 0.00115 |
| matchups sd 2 | 5 same-role lanes (cell 1.0) | 0.90 | 2/5 | 3/5 | 13%, -0.00055 ± 0.00027 |
| matchups sd 4 | 5 same-role lanes (cell 2.0) | 2.02 | 4/5 | 5/5 | 28%, -0.00578 ± 0.00078 |
| mix -2 pp/sd | damage mix | -1.69 ± 0.33 | yes | yes | 94%, -0.00022 ± 0.00032 |

Runs 20261013T230632Z-tst-eff-none, 230656Z-pair2, 230723Z-pair4, 230751Z-ctr2,
230817Z-ctr4, 230841Z-mix2; scores 233602Z..233749Z-tst-score-eff-*.
- No false effects: with nothing planted every pair block is ~0 and the gain is nil
- Lane blocks are half the matchup's spread: a same-role matchup enters the logit as
  theta(a, b) - theta(b, a) (additive.cells), so an antisymmetric matchup effect c is fitted
  as c / 2 per cell. Read "X vs their X" x2 for a matchup's spread (top vs top 1.23 pp:
  ~2.5 pp per matchup). Bottom vs support across lanes is one matchup split over two
  blocks (planted 4: 3.43 and 0.00; 2: 0.87 and 0.53): one block, root sum of squares
- Ally block sds run low, 40% at 2 pp and 25% at 4, always low, and their intervals rarely
  hold the truth: a reported ally sd is a lower bound, and "not detected" ally blocks
  could hide ~2 pp (6 of 10 detected at 2 pp)
- At ally pair sd 4 the jungle and bottom champion blocks collapse to ~0 (strength moved
  into pair cells); at the real ally sizes (< 1.5) champion blocks hold
- A big planted pair term is mostly not learnable at 89k games: ally pairs sd 2 are worth
  -0.016 nats/game to an oracle, the model gets 10% of that. Blocks, not single pairs
- The mix comes back within its interval and nearly whole (94%), yet its gain over ratings
  (-0.00022 ± 0.00032) is not detected: as with win-comp, report the effect estimate

Rules of thumb for minimum detectable effects (MDE, 80% power at 5%): a binary term held
by m games has se ~50/sqrt(m) pp, MDE ~140/sqrt(m) pp (a pair in 5,000 games: ~2 pp; in
500: ~6 pp); a per-sd term on n games has se ~50/sqrt(n) pp (matches win-comp's -1.50 ±
0.33 at 89k). As a log-loss gain the bar is far higher (above).

## Where results show (admin Models tab)

Models tab: one category per docs/learned.md heading, each with what we learnt, the best
model against its baseline, run cards (plain sentence from meiolol-lab's RESULT line or
the run's findings.tsv) and run health. Runs of the Mac and the gpu-box (deploy/lab-run.sh)
show live there via deploy/lab-push.sh (docs/hosting.md), which also sends learned.md,
model.md (the team effects table), lab campaigns and meiolol-lab's per-run result.tsv
(category, % of error removed, typical miss), findings.tsv (one sentence per line) and
effects-*.tsv (`# title | unit | what higher means`, then label, effect, ci, n).
A run reports progress by appending to metrics.tsv in its run directory
(the working directory): a header, then a row per evaluation, first column the x axis
(step, epoch, games), the rest numbers.
Columns sharing the part after the last `_` share a chart (`train_loss`, `test_loss`),
and each prefix keeps its colour across charts. Flush each row as it is written.

## Next steps

- Untried model ideas (20 Oct; in-game chance as score or soft label ruled out:
  "Scoring draft models against the in-game win chance"), cheapest first: a pairwise
  interaction net (MLP summed over the 25 enemy and 20 ally pairs, antisymmetric, on
  additive v2's offset: the set net pools a team before comparing); TabM / BatchEnsemble
  heads for the big and set nets (one run instead of 10 seeds); additive v2 cells shrunk
  toward the same champion in other roles and matchup cells toward kit group x kit group
  or a low-rank u.v, not 0; GBDT (gbdt.zig) on dense pre-game features with additive
  v2's logit as base margin; masked-pick pretraining (hide one pick, predict it from the
  other nine) as a third embedding source; leaver games (flat gold and XP after 15:00)
  out of training only; champion strength as a daily random walk whose patch-day jump
  depends on the patch notes (needs 16.21 in dev); a small team-vs-team cross-attention
  net last (research expects a tie)

- Patch and rank context (meiolol-48, 2026-10-13; cand/win-context, model.md "Patch
  and rank context"): rerun per-patch offsets (cfg.folds with the shuffled control) once
  a snapshot has 16.21 games in dev; rank brackets (cfg.bracket) on the 19 Oct weekly
  snapshot, the first with rank_start in dev: report coverage by bracket first. With the
  16.21 rerun, report per fold the share of scored games on a patch the fit has seen
  (unseen patches get no offset, so a null there is not a test; verifier, meiolol-4b)

- Net exporter for the tester (meiolol-ba/d8, 2026-10-13): done 23 Oct on additive v2
  ("Set net on additive v2 in the tester and eval, 2026-10-23"). Next: Jacob's go on
  the test-look rule (docs/plan/lab-frontier.md "P3 proposal"), then the look with
  seeds 7-9. Formats agreed: f1's concat-pool net (R[role] added,
  antisymmetric, residual, seed list, ReLU, empty slot = game-weighted mean input);
  35's set net (x = p(12) ++ role one-hot(5) ++ optional E, phi dense + ReLU, mean pool,
  rho on [t_own; t_other], f = w.h, antisymmetric, + a x candidate logit)

- Pretrained embeddings (meiolol-5b, 2026-10-13; `meiolol-lab pretrain`, model.md
  "Pretrained champion-role embeddings"): borderline, no test look (consistent sign on
  5 of 5 folds, interval touching 0, gain in rare picks only). Rerun d8 (`--dim 8`) as
  a ratings prior on the 19 Oct pinned snapshot (more games, tighter interval), same
  controls; d8 vectors offered to meiolol-08 as a prior for rare pairs in its additive
  model

- Your usual style (parked, 2026-10-13, meiolol-3f): style from a player's earlier games
  is use-time valid for the user's own; measure it on early outcomes over 3c-team2 and
  on win over b0's model on the full 14:00 state (`meiolol-lab style`, model.md
  "Playstyle clusters and sequence net"). If the net is retried: fewer inputs (zone
  shares per minute), stronger regularisation, and the positive control first

- Field ranking follow-ups (parked, 2026-10-13): lens B over a team end-state base
  (team kills, towers, objectives) so player-level fields beyond the team's result show;
  per-champion check of ward takedowns (traps counted as wards?). `meiolol-lab fields`,
  see "Field ranking"

- Player experience and everything pre-game (win-ratings, internal scope): rerun when
  meiolol-78 pins a snapshot with about a week of rank_history and pre-game mastery
  (fetch time before game_start), on its fresh test set. Add rank at game start and the
  lobby rank spread as a group, mastery as a group, then the rank-sensitivity slope per
  champion-role beside the experience one (shrunk to the role's). Same ablation table,
  dev first, final on the coordinator's go. Scratch scripts (variants from a clean
  tree, paired dev.tsv comparisons) are simple to redo: see "Player experience and
  everything pre-game"
  Mastery source (meiolol-11, 2026-10-13): the box keeps one mastery row per player,
  overwritten on each refresh (INSERT OR REPLACE, fetched_at in s), and the pass
  fetches right after a stored game, so a box snapshot's row is post-game for that
  game. Rule: use a row for a game only if fetched_at < game_start (ms), else missing.
  For most games pre-game mastery exists only in the raw archive's fetch history
  (hourly mastery-NAME.tsv.zst, salted hashes, fetched_at): a loader takes each
  player's latest fetch before game start. Same salt as the snapshots (11): from 19
  Oct the snapshot carries SNAP/mastery_pre.tsv (`meiolol-lab mastery-pre`, b424a24):
  match_id, slot, fetched_at, level, points, last_play (game's champion), champions,
  total_points; join on (match_id, slot); no line = no pre-game fetch. Coverage ~0
  before 13 Oct, growing with weekly refreshes: report it per split first

- Next lab campaign, rank at game start on 3c-team2 (agreed with meiolol-78; runs on the
  snapshot 78 pins after ~a week of rank_history, with a fresh test set: rank_start
  needs games from 13 Oct on):
  - Why: gold14-a's own-rank term (on 3c-team) held on test (gold14 +0.32 ±0.09% of
    base MSE, cs10 +1.40 ±0.15) but used participants.tier, the rank looked up after
    the game, which lifts win from 53.7% to 63.8% called on dev (db). Its share of the
    gold14 and cs10 gains is unknown
  - Harness (done, 9eb6982): rows.Row.rank_start is the ladder rank as last seen on a
    UTC day before the game's (ranks when its seen_day is that early, else rank_history's
    latest earlier change; null otherwise: unranked, below Platinum IV or before 12
    Oct). Every scope's rank (own and others', internal included) and the lane and draft
    exports use it: pre-game data only. participants.tier is rows.Row.rank_after, a
    labelled dev-only diagnostic (H2 below): it reaches only a candidate declaring
    `after_game_rank`, in dev runs (score refuses select and final; exp refuses
    --select, final and preds; the brief forbids agents to declare it), never a feature
    of a model of record or any final. Test: harness "the after-game rank reaches only
    candidates that ask"; pipeline pack test with rank history
  - At the pin, first: switch summary.md's tier slices (exp.zig) and diagnose's tier
    covariate (search.zig) from rank_after to rank_start (rank_after until then: on
    snap-20261012T2055Z rank_start is almost all null); repack the new snapshot
    (`meiolol-lab pack`, Mac and gpu-box)
  - Leak check before any campaign run (dev, same candidate both sides): win with
    rank_start vs with the post-game rank, on rows that have both. Near 63.8% with
    rank_start: suspect rank_start first (sample rank_history timestamps against game
    start, look for lookups after the game), then decide. Well below it: the gap is the
    leak's size for win; record it in docs/learned.md
  - Rows: the rank term fits only on rows with rank_start (null: no term); report row
    counts in train, dev and test before starting; dev floor 20k rows. At 85k dev rows
    gold14-a's rank term was ±0.11, so expect about ±0.22 at 20k: enough for a 0.6
    effect, not for the test's 0.3
  - Campaign: from team2, scope champ_select, targets gold14 then cs10 (lanediff14,
    deaths15 and first_item read from the same runs' dev.tsv, no separate looks). H1
    gold14-a's term (own tier per role) on team2 with rank_start; H2 (diagnostic, dev
    only) the same with the post-game rank on the same rows, so H2 - H1 is the leak's
    share; then tier x role refinements only if H1 beats ref beyond its interval. One
    selection look per target; final by a human, paired vs team2's own test preds from
    the same build
  - Site, if it holds: the "at your rank, expect X" lesson line uses rank_start's table
- Experience term: rerun once the daily eval shows 300+ train and 100+ test games per
  variant. If "user only" beats the no-experience model beyond its interval, wire it into
  recommend() as the "your pool" reason (wasm `pool` field) with the measured per-bin pp
- Lane gold (lanegold.zig): reports from 500 train / 100 test games with timelines
  (865 timelines at last check); if it wins, store champion and pair gold in the model
  file (statsfile v2) and tell meiolol-b5 and meiolol-de
- Daily history chart: data/eval-history.tsv on the box; with a few days of lines, a
  "Model accuracy vs data" chart on the site's method page (meiolol-b5)
- Switch defaults to empiricalPriors once eval shows a gain at volume; retry pair
  evidence for role inference with shrinkage; comp features (damage mix, frontline)
  and rank brackets (participants.tier) when data allows

Why: a champion-role has ~60 games here, so its winrate is known to about ±6 pp, while
real differences between champions are 1-3 pp. Pair cells have a handful of games.
The data is the bottleneck, not the model form; the all-regions crawl (~135k games/day)
is what can move these numbers. Detectable now: the paired interval is ±0.0012 on 1334
test games, so a model at the published ~55% (log loss ~0.687) would show clearly.
