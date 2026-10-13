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
in 3 roles). Deaths before 15: lane 0.1-0.35, a jungler 0.1-0.17, anyone else
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
off in every role (no detectable spread). Largest item effects (shrunk, 500+ rows):
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

Style weights given the state, win pp per +1 sd (± 95% about ±0.25-0.4, from the
Hessian with rows treated as independent: ten per game, mirrored state features, so
too narrow until refitted with errors clustered by game):

| feature | top | jungle | middle | bottom | utility |
| --- | --- | --- | --- | --- | --- |
| away | 0.23 | -0.85 | 0.31 | 0.69 | 0.64 |
| enemy_half | -0.23 | 0.46 | 0.16 | -0.31 | 0.98 |
| fights | 0.39 | -0.60 | -0.20 | -1.10 | 0.91 |
| damage | 0.44 | 1.04 | 1.65 | 2.36 | 0.65 |
| wards | 0.57 | 0.20 | 0.70 | 0.26 | 0.65 |
| control_wards | -0.41 | 0.01 | -0.66 | -0.58 | -0.29 |
| ward_kills | 0.56 | 0.32 | 0.43 | 0.53 | 0.31 |
| off_role_cs | 0.29 | -0.15 | 0.67 | 0.77 | 0.56 |

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
  wards bought for the same gold lead go with losing (-0.3 to -0.7): likely behind
  teams buy them, not that they hurt
- Lesson material at most, with intervals; one sd of any style is worth under 2.5 pp
  once the state is known

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
  Not detected rather than bounded: the spread estimate is truncated at 0 and reaches
  ~2 pp per 1000 gold (jungle 10-20); a bootstrap over games would give a real bound
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

### Draft model file (meiolol-lab draft --export)

`meiolol-lab draft SNAP --export DIR` (src/lab/draft.zig, built with a candidate that has
`exportModel`, today win-ratings) fits on every game in the snapshot and writes
DIR/draft-model.json and DIR/draft-ref.json for the admin draft board (meiolol-3b).
Admin only: the public site never shows "this draft wins X%" (docs/learned.md). Run it
into a run dir on the Mac (~/ml/runs/<stamp>-draft-export); lab-push.sh sends the newest.

draft-model.json:
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
- average[role] {b, u, v, s}: the empty-slot term, patch_share-weighted mean of the
  role's terms on the newest patch
- model {kind, dim, intercept, w[25], z[25], terms [{champion, role, games, b, sd, u, v,
  s}]}: u, v, s are length dim (empty for rates and ratings); w and z row-major 5 x 5

Scoring (Scorer in draft.zig, the reference). Each slot is a champion-role term; an
empty slot, or a champion with no term in that role, is average[role] with sd 0. B_r and
R_r are blue's and red's slot in role r:

```
logit = intercept + sum_r (B_r.b - R_r.b)
      + sum_{ri,rj} w[ri*5+rj] * (<B_ri.u, R_rj.v> - <R_ri.u, B_rj.v>)
      + sum_{a<b} z[a*5+b] * (<B_a.s, B_b.s> - <R_a.s, R_b.s>)
blue = 1 / (1 + exp(-logit)); red = 1 - blue
var = sum over the 10 slots of sd^2;  interval = sigmoid(logit -/+ 1.96 sqrt(var))
```

sd is a Laplace approximation of each rating's own uncertainty, 1 / sqrt(games / 4 +
prior precision), treated as independent: parameter uncertainty, not the game's.
Slot query (the tester's list): candidates are champions with games >= min_games in the
role, not picked by either team and not banned; win is the user's team's chance with it
in the slot, change = win minus the chance with the slot empty, and "an average pick" is
the mean of the candidates' win weighted by their games in the role.

draft-ref.json: `tolerance` 1e-9; `drafts` [{label, teams[side][role] (0 empty), blue
{p, lo, hi}}] (three EUW1 test games whole and with three slots empty, and the empty
board); `slots` [{label, role, side, teams (by side), bans, min_games, empty, average,
options [{champion, games, win, lo, hi, change}] sorted by win, then champion id}]. Export
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
