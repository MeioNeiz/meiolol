---
status: answered
priority: now
area: stats
tags: [method, stats]
description: How do we build the most accurate pre-game draft win predictor for ranked League, and what methods, data handling and features got the best published results in LoL, Dota 2 and similar games?
---
# How do we build the most accurate pre-game draft win predictor for ranked League, and what methods, data handling and features got the best published results in LoL, Dota 2 and similar games?

Feeds: docs/plan.md Draft model (Jacob's goal: the best League draft predictor; owner
meiolol-88); docs/model.md win results. Ours today: 53.3-53.5% accuracy, AUC 0.550,
log loss 0.6897 at 90k Plat+ games (time split, dev), -0.0008 log loss per doubling, no
plateau; LoLDraftAI reports 55-56% ([[loldraftai#^f6]]).

## Answer

The honest ceiling for draft-only ranked LoL is about 53-54% accuracy, AUC 0.55, log
loss 0.683-0.689 on a time split, and every model family lands there at 100-300k games
(C1, C2). We are already at it. LoLDraftAI's 55-56% (loss 0.681) is not comparable: a
random file split, the checkpoint chosen on the test set, and filters that use
15-minute stats to drop short, stomp and AFK games (C6); random splits alone inflate
MOBA results by points (C5). To compare fairly, report both our time split and a
LoLDraftAI-style random split on the same games with the same filters (C17). Results
above about 57% on ranked usually leak the outcome (C7). Adding pre-game player
features honestly reaches about 55-57% (C11); a time-split ranked number above that is
suspect.

Levers, in order (C18). (1) Data volume: LoL curves are still rising at 73-90k games,
and GLMs stay hard to beat until millions of rows (C9, C10). (2) Player-champion
experience computed strictly before game start, the largest non-draft group; MMR and
momentum add little (C11, C12); internal model only, since the app may show only the
user's own data. (3) Factorised pair terms (FM) from about 1M games, warm-started from
the logistic fit with validation early stopping; they add 0.01-0.035 AUC at 1-3M games
on random CV but nothing yet at 110k on a time split (C4, C15). (4) A per-patch
champion offset on a stationary strength, not recency weighting (C14). (5) A deep
embedding MLP only at 10M+ games (C10). (6) Temperature scaling, which fixes log loss
without touching accuracy (C16). Skip GBDT on one-hot picks (C3) and side-swap
augmentation: build symmetry into the model (C13). Evaluation rules: chronological
split, every feature as of game start, pair and win-rate statistics computed only on
training games, checkpoints and tuning on a validation slice never the test, a fixed
search budget (C7, C8).

## Claims

- C1: Honest draft-only LoL solo queue is about 53-54% accuracy, AUC ~0.55, log loss 0.68-0.689. for: [[jcj-lol-draft#^f1]], [[draftrec-2022#^f4]], [[leaguephd-about#^f3]], [[loldraftai#^f24]]
- C2: At up to ~300k LoL games, pairs, FM, NN, attention and transformers do not beat per-role champion LR beyond noise; neural counter models overfit. for: [[jcj-lol-draft#^f2]], [[draftrec-2022#^f4]], [[lin-2024-comp-counters#^f4]], [[draftrec-2022#^f5]]
- C3: Trees lose to LR or factorised pairs on one-hot draft data with low separability. for: [[jcj-lol-draft#^f3]], [[chen-avatar-embedding-2018#^f6]], [[perlich-tree-vs-logistic-2003#^f2]], [[perlich-tree-vs-logistic-2003#^f3]]
- C4: Factorised pair terms add 0.01-0.035 AUC over additive LR at 0.6-3M games on random splits, and generalise to rare pairs. for: [[chen-avatar-embedding-2018#^f4]], [[neuralac-2021#^f4]], [[rendle-fm-2010#^f2]], [[ffm-juan-2016#^f1]], [[ffm-juan-2016#^f3]] against: [[jcj-lol-draft#^f2]]
- C5: Random splits inflate MOBA results: a player model scored 64.3% random and 55.65% chronological; NeuralAC's random-split gain tied LR on a time split. for: [[moba-cupid-rematchmaking#^f5]], [[moba-champ-matchmaking#^f1]], [[moba-champ-matchmaking#^f2]], [[neuralac-2021#^f3]], [[draftrec-2022#^f4]]
- C6: LoLDraftAI: champion, patch, champion x patch, rank and queue embeddings into an MLP; random file split, checkpoint picked on test, in-game filters drop sub-15-minute and stomp games; a duplicate bug once hid 52%. for: [[loldraftai#^f9]], [[loldraftai#^f21]], [[loldraftai#^f23]], [[loldraftai#^f19]], [[loldraftai#^f25]], [[loldraftai#^f15]]
- C7: Inflated 62-93% claims come from outcome leakage: post-game win rates, or pair and champion stats computed over test games. for: [[jcj-lol-draft#^f8]], [[lol-huang-predictor#^f3]], [[lol-player-champion-experience#^f4]], [[lol-player-champion-experience#^f6]], [[bcappu-high-elo-draft#^f4]], [[dota2-predictor#^f6]]
- C8: Draft explains less of the outcome at higher skill. for: [[semenov-mlsa16-slides#^f3]], [[beyond-the-meta-2023#^f1]]
- C9: Additive LoL draft curves still improve at 73k games; Dota additive curves plateaued at 18-200k. for: [[jcj-lol-draft#^f6]] against: [[conley-perry-2013#^f4]], [[dota2-predictor#^f5]]
- C10: Near 10^5 rows GLMs are hard to beat; non-linear models gain only in the millions, by little; priors that help small data stop helping at tens of millions. for: [[actuarial-scaling-2026#^f1]], [[actuarial-scaling-2026#^f3]], [[hestness-scaling-2017#^f3]], [[loldraftai#^f14]], [[juewu-draft-2020#^f4]]
- C11: Pre-game player-champion experience is the largest non-draft group; honest time-split results with player features reach 55.7-56.9%, random CV 60%. for: [[lol-momentum-forecasting#^f5]], [[lol-skill-decomposition#^f2]], [[lol-skill-decomposition#^f4]], [[draftrec-2022#^f4]], [[moba-champ-matchmaking#^f2]]
- C12: MMR alone gives about 52.8%, Elo about 0.3 points and momentum 0.1-0.3 points. for: [[moba-cupid-rematchmaking#^f4]], [[lol-momentum-forecasting#^f5]], [[lol-momentum-forecasting#^f7]]
- C13: Side symmetry is better built into the model than added by augmentation under approximate invariance. for: [[jcj-lol-draft#^f5]], [[chen-augmentation-2020#^f3]], [[chen-augmentation-2020#^f4]], [[conley-perry-2013#^f3]]
- C14: Strong recency down-weighting hurts; a stationary bias plus a regularised per-time-bin offset works; recency is not relevance under noise. for: [[jcj-lol-draft#^f7]], [[koren-temporal-2009#^f2]], [[koren-temporal-2009#^f4]], [[gama-drift-survey-2014#^f2]], [[gama-drift-survey-2014#^f3]], [[lu-concept-drift-review#^f5]]
- C15: FM-type models overfit and need validation early stopping and a warm start from the fitted LR. for: [[ffm-juan-2016#^f4]], [[jcj-lol-draft#^f4]]
- C16: Overfitting shows in log loss before accuracy; one-parameter temperature scaling recalibrates without changing accuracy. for: [[guo-calibration-2017#^f2]], [[guo-calibration-2017#^f5]]
- C17 (inferred): Compare with LoLDraftAI by running both our time split and its random split with its filters on our data. from: C5, C6
- C18 (inferred): Lever order: data volume, pre-game player-champion features, FM from ~1M games, per-patch offset, deep MLP at 10M+, calibration. from: C9, C10, C11, C4, C15, C14, C16
- C19: Tuning one model family with 30-64 random trials beats picking among families. for: [[mcelfresh-nn-vs-gbdt-2023#^f2]], [[bergstra-random-search-2012#^f3]]

## Disagreements

- Pair terms: +0.01-0.035 AUC at 1-3M games on random CV (Chen B, NeuralAC B) vs no
  gain at 110-280k on time splits (jcj C, DraftRec B, Lin B). Data size or split; our
  FM learning curve on a time split from 300k to 1M+ games settles it.
- Plateau: Dota additive curves flat at 18k (Conley C, random hero modes inflate it,
  [[conley-perry-2013#^f7]]) and 200k (dota2-predictor C) vs LoL rising at 73k (jcj
  C) and ours at 90k. Different games; our curve fit decides.
- NNs at scale: an embedding NN beat LR by 0.05 AUC at 30M games (JueWu C/weak) vs
  0-0.03 elsewhere; GBDTs gain with size ([[mcelfresh-nn-vs-gbdt-2023#^f3]], A) vs the
  NN gap shrinks ([[grinsztajn-tabular-2022#^f3]], A, outside our regime per
  [[grinsztajn-tabular-2022#^f2]]). Only a 10M+ run of our own would settle it.

## Options

Experiment sequence for meiolol-88; each step kept only if it beats the last on the
time split.

| Option | Claims for | Claims against | Would change if |
| --- | --- | --- | --- |
| 0. Eval: time split plus LoLDraftAI-style random split with its filters, paired bootstrap, temperature-scaled log loss | C5, C6, C16, C17 | none | LoLDraftAI publishes a time-split number |
| 1. More data: pool regions and ranks, fit a N^-b + c on nested subsets | C9, C10 | C9 (Dota plateaus) | our fit shows a floor near 90k |
| 2. Player-champion experience as of game start (games, shrunk win rate) | C11, C12 | none (app cannot show others' stats) | time-split gain under 0.5 points |
| 3. Per-patch champion offset on stationary strength | C14 | none | offsets shrink to zero at our patch count |
| 4. FM pairs from ~1M games, warm start from LR, early stopping | C4, C15 | C2 | still tied with LR at 1M on time split |
| 5. Embedding MLP (LoLDraftAI-like) at 10M+ games | C10 | C2, C3 | we never reach 10M games |
| Not: GBDT on one-hot, strong recency weights, side-swap augmentation | C3, C13, C14 | none | a time-split result says otherwise |

## Open

- LoLDraftAI's number on our games with its filters: unknown until step 0 runs.
- Player features in LoL Plat+ on a time split: the clean numbers (C11) are an
  unnamed mobile MOBA and top 0.1% LoL; no Plat+ LoL measurement yet.
- Rank at game start and premade or autofill flags must be inferred from snapshots
  and co-play ([[riot-dev-ranked-matchmaking-2020#^f1]],
  [[riot-dev-ranked-matchmaking-2020#^f5]]).
- Ensembling: bagging helps convex learners, seeds suffice for NNs
  ([[deep-ensembles-2017#^f2]]); untested on draft data.
- What counts as a remake or leaver in our filters, and whether LoLDraftAI's 15-minute
  filters remove more than duration_s < 900 does.
