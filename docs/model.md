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

Why: a champion-role has ~60 games here, so its winrate is known to about ±6 pp, while
real differences between champions are 1-3 pp. Pair cells have a handful of games.
The data is the bottleneck, not the model form; the all-regions crawl (~135k games/day)
is what can move these numbers. Detectable now: the paired interval is ±0.0012 on 1334
test games, so a model at the published ~55% (log loss ~0.687) would show clearly.
