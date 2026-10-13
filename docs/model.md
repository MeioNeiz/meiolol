# Draft model: how good is it?

Measured with `meiolol eval` (src/eval.zig) on a read-only copy of the box DB. Rerun as
data grows; add a dated section, keep the old ones (the curve over training size is
evidence for the production key).

```
meiolol eval --data DIR [--patch P] [--platform P] [--test-platform P]
             [--test-share 0.2] [--folds 5]
```

Copy of the box DB without touching the live one (python3 on the box, read-only source):
`sqlite3.connect("file:.../meiolol.db?mode=ro", uri=True).backup(sqlite3.connect(dst))`.

The box runs it daily (deploy/web-loop.sh, ~9 min) into data/eval-history.tsv. Watch it
from here: `deploy/box.sh model [ROWS] [-f]` (run state, AUC sparklines per model, last
runs with the best log loss vs coin flip; -f redraws every minute). Charts and the latest
report: the admin page's Models tab (https://meiolol.jomify.lol/admin/#models/win).

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
  of dev games right
- Split: eval's. Test = newest 20% of EUW1 games by gameCreation; train = older games,
  every platform. Tuning by folds inside train only; test touched once per model
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

### Team effects on early outcomes, 2026-10-12 (meiolol-3c)

`meiolol outcomes --data SNAP --platform all --preds DIR` (src/outcomes.zig) on
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

`meiolol items --data SNAP --platform all --preds DIR` (src/items.zig), same split,
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

`meiolol scaling --data SNAP --platform all --preds DIR --table FILE` (src/scaling.zig),
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
prior, within-team and cross-team terms. Sessions: docs/model-agents.md.

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
- Test look: not yet (meiolol-2c's go). Run dirs ~/ml/runs/*-wc-{a,b,c}-* on the gpu-box

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

Leakage review (ea's 25737aa, 0d's win-comp working copy, 2026-10-13): the harness copies
Row.stats into Train for visible rows only (test "seat stats reach fit on visible games
only" covers dev, select, final); rows.load holds only eval's train (older than the first
test game) and test, so final's profiles are older than every test game; a Query has no
stats. win-comp built profiles for its inner validation from every visible game, the val
games included (their own stats in their profiles); fixed by 0d: tuning on fit-set
profiles, refit rebuilds them on all visible rows; forward-chaining folds rebuild
everything per fold (foldAblation calls fitWith on older games only).

### Draft model file (meiolol-lab draft --export)

`meiolol-lab draft SNAP --export DIR` (src/lab/draft.zig, built with a candidate that has
`exportModel`, today win-ratings) fits on every game in the snapshot and writes
DIR/draft-model.json and DIR/draft-ref.json for the admin draft board (meiolol-3b).
Admin only: the public site never shows "this draft wins X%" (docs/learned.md). Run it
into a run dir on the Mac (~/ml/runs/<stamp>-draft-export); lab-push.sh sends the newest.

draft-model.json (format meiolol-draft-model, version 2; 1 had no p and no comp):
- meta: name ("win-ratings (ratings)"), run, snapshot, newest_game, training_games
  (games that lasted 15:00, as the harness fits), patch (newest), platform (EUW1: the intercept used), dev {what, games, log_loss,
  baseline_log_loss, coin_log_loss, accuracy, auc}: a refit on dev's games, scored on
  dev-val, as described in `what`
- roles: top, jungle, middle, bottom, utility; role fields are indices into it
- has_pairs: false for rates and ratings. Then the other picks shift the numbers, not
  the order of candidates for a slot
- min_games: default floor of training games in the role to list a candidate (100)
- champions [{id, name, alias}]: alias is the name lowercased, letters and digits only
- cells [{champion, role, games, patch_games, patch_share}]: training games in the role
  (every patch); games and share of the role's games on the newest patch (random games,
  picker order, role averages)
- average[role] {b, u, v, s, p, raw}: the empty-slot term, patch_share-weighted mean of the
  role's terms on the newest patch
- model {kind, dim, intercept, w[25], z[25], terms [{champion, role, games, b, sd, u, v,
  s, p, raw}], comp}: u, v, s are length dim (empty for rates and ratings); w and z
  row-major 5 x 5; p the champion-role's profile (k numbers, z-scored within the role;
  empty without comp); raw the profile in raw units, all 12 of win-comp's Feature order
  (magic share of damage first, damage per minute third; empty without team terms). b
  already holds any profile prior
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
f = sum_r raw.dmg * raw.magic / sum_r raw.dmg (0.5 if no damage); form: mix d^2,
ad_heavy min(d, 0)^2, ap_heavy max(d, 0)^2
blue = 1 / (1 + exp(-logit)); red = 1 - blue
var = sum over the 10 slots of sd^2;  interval = sigmoid(logit -/+ 1.96 sqrt(var))
```

sd is a Laplace approximation of each rating's own uncertainty, 1 / sqrt(games / 4 +
prior precision), treated as independent: parameter uncertainty, not the game's.
Slot query (the tester's list): candidates are champions with games >= min_games in the
role, not picked by either team and not banned; win is the user's team's chance with it
in the slot, change = win minus the chance with the slot empty, and "an average pick" is
the mean of the candidates' win weighted by their games in the role.
Comp reasons (the tester, with comp terms): each S and A entry's and team term's part of
the picking side's logit change when the candidate fills the empty slot (A from that
side: mine'A theirs), in pp through the sigmoid's secant over the whole change, +-1.96 sd
of the entry ("no range exported" without one); the two largest by size are shown. The win interval stays ratings-only.

draft-ref.json: `tolerance` 1e-9; `drafts` [{label, teams[side][role] (0 empty), blue
{p, lo, hi}, comp (the comp part of blue's logit)}] (three EUW1 test games whole and with
three slots empty, the empty board, every slot a champion with no term in its role, and
Rammus jungle alone into a full AP and a full AD red team); `slots` [{label, role, side,
teams (by side), bans, min_games, empty, average, options [{champion, games, win, lo, hi,
change}] sorted by win, then champion id}] (blue middle to fill, red middle to fill, blue
jungle to fill into 5 AP and into 5 AD). Export
checks the scorer against the candidate's own predict on 500 test games and stops if
they differ by more than 1e-4 (f32: ~5e-8 measured).

### Lane model file (meiolol-lab lane --export)

`meiolol-lab lane SNAP --export DIR` (src/lab/lane.zig, built with
-Dcand=src/lab/cand/team2, the candidate with `exportLane`) fits 3c-team2 on every game
that reached 15:00 and writes DIR/lane-model.json and DIR/lane-ref.json for the admin
Draft tester's champion suggester (meiolol-3b): early outcomes for a champion into a lane
opponent. Champion-only inputs; admin only. Run it through deploy/lab-run.sh with
`-- lane "~/ml/snaps/SNAP" --export .` (first run 20261012T2326Z-lane-export: 182,748
games, 849 champion terms, 48,194 pairs, 2.8 MB).

lane-model.json (format meiolol-lane-model, version 1); every number rounded to 0.01:
- meta: name, run, snapshot, newest_game, training_games, patch (newest), platform
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

## Next steps

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
