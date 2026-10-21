---
status: answered
priority: now
area: stats
parent: frontier-dynamics
tags: [method/dynamics, stats]
description: How do we train on older patches to predict the newest one, and how should scarce newest-patch games be split between training and evaluation?
---
# How do we train on older patches to predict the newest one, and how should scarce newest-patch games be split between training and evaluation?

Feeds: docs/plan/patch-transfer.md (experiment plan), docs/plan/lab-frontier.md E2-E5.
Builds on [[frontier-dynamics]] (stationary strength plus shrunk per-patch offsets; at most
~1 milli-nat on a new patch's first days) and docs/model.md "Patch and rank context"
(offsets not detected on the one 16.19 to 16.20 boundary).

## Answer

A patch does move our champions, and mostly the ones it touched: 16.21's first day
shifted champion-role win rates 0.75 pp RMS within platform against 0 for a within-patch
control, 1.9 pp for the 12 champions with Data Dragon changes vs 0.5 pp for the rest
(C5). Ignoring it costs ~1.1 milli-nats per game on day one (C5, inferred).

How to train: supervised domain adaptation says pooling everything is a hard bar (C2),
and the two methods that beat it are a shared weight plus a per-domain copy (our rating
plus per-patch offset) and fitting the new domain with an L2 prior centred on the old
model (warm start) (C1). Both lose when the new data is too thin to separate the
domains (C3), which is a patch's first day for unchanged champions; a looser prior for
the patched champions is where day-one gains can come from (C8). Fine-tuning toward the
latest data helps only for gradual shift (C4); a patch is sudden and local.

How to evaluate: score only newest-patch games, by day since the patch, with a rolling
origin (fit up to day d, score day d, then train on it). That is how the site refits,
and it uses every new game for both, so the train-vs-eval trade-off disappears for the
shipped procedure (C6). It remains only for knobs tuned on new-patch games, and for one
or two knobs the split barely matters (C7). Eval precision is not the bottleneck: a
day of new games (~50k) gives ± 0.19 milli-nats on paired differences (C5's source).

Learning the delta itself (predicting a champion's jump from the patch's changes) has
no support beyond "changed vs not" yet: counting buffs and nerfs predicts poorly
(frontier-dynamics C6) and mean reversion is only a hint here (C5). It needs more
boundaries than the two we have.

## Claims

- C1: With little target data, a shared-plus-per-domain parameterisation (feature augmentation) and an L2 prior centred on the source model's weights beat the simple baselines. for: [[daume-2007-easy-da#^f3]], [[daume-2007-easy-da#^f4]], [[daume-2007-easy-da#^f6]], [[chelba-acero-2004#^f1]], [[chelba-acero-2004#^f3]]
- C2: Training on all past data pooled is a hard baseline under temporal and domain shift; most adaptation and invariance methods do not beat it. for: [[daume-2007-easy-da#^f1]], [[wild-time-2022#^f3]], [[wild-time-2022#^f4]]
- C3: Adaptation loses where the target sample is too small to tell the domains apart, and the prior's strength, tuned on target dev data, decides between no adaptation and overfitting the target. for: [[daume-2007-easy-da#^f6]], [[chelba-acero-2004#^f2]]
- C4: Fine-tuning and incremental training help only for gradual shift, since they bias toward the latest data. for: [[wild-time-2022#^f5]]
- C5: On our games a patch moves champion win rates beyond noise (0.75 pp RMS on 16.21's first day vs 0 within patch), about four times as much for champions the patch changed. for: [[patch-jump-16-21-measured#^f1]], [[patch-jump-16-21-measured#^f2]]
- C6: A rolling-origin (stream) evaluation, fit up to t and score the next period, matches how a frequently refitted model is used. for: [[wild-time-2022#^f1]], [[wild-time-2022#^f6]]
- C7: When the holdout picks a simple knob, the share held out barely matters (10-50% near optimal); a fixed ~10% worked across complexities. for: [[kearns-1996-cv-split#^f1]], [[kearns-1996-cv-split#^f3]]
- C8 (inferred): Our patch-aware arms should be pooled + per-patch offsets with a looser prior for changed champions, and a warm start toward last patch's ratings, scored only on newest-patch games by day since patch against pooled; the delta regression waits for more boundaries. from: C1, C2, C3, C5, C6

## Disagreements

- Fine-tune vs pool: Wild-Time finds incremental methods worse than invariant ones on
  most sets (B), Chelba-Acero finds MAP adaptation a 20-25% gain (B). Different shifts:
  total and gradual vs a related domain with a strong prior. Our arms A2 vs A4 settle it.

## Open

- Days 2+ of 16.21: does the unchanged champions' 0.5 pp shrink (patch-day players and
  adoption) or stay (real knock-on effects)?
- Patch notes beyond Data Dragon: ability-number changes are missing from the changed
  list; CommunityDragon or the notes page would complete it.
- More boundaries for a delta regression: backfill 16.17-16.18 games (Riot budget).
- Not read: Gama et al. 2013 on prequential evaluation (lead, no open copy); Guyon et
  al. 1998 test-set size (no open copy found; our own paired sd answers it for us).
