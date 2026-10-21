---
status: answered
priority: soon
area: stats
parent: frontier-experiments
tags: [method, method/tabular, method/ensemble]
description: Do modern tabular learners (tabular foundation models, TabM, RealMLP, factorisation machines past 1M rows) and large stacked ensembles beat a strong shrunk logistic model on high-cardinality categorical, near-coin-flip outcomes, and how are such ensembles built without overfitting the validation set?
---
# Do modern tabular learners (tabular foundation models, TabM, RealMLP, factorisation machines past 1M rows) and large stacked ensembles beat a strong shrunk logistic model on high-cardinality categorical, near-coin-flip outcomes, and how are such ensembles built without overfitting the validation set?

Feeds: docs/plan/lab-frontier.md (gpu-box experiment programme), parent [[frontier-experiments]].
Builds on [[draft-predictor-methods]] (FM from ~1M games, C4, C15), [[nn-draft-models]]
(TabM, RealMLP defaults, seed ensembles) and [[gnn-match-outcome]] (GBDT on dense
features, C5); not repeated here.

## Answer

No source tests any of these on our regime (1.4M rows, ten high-cardinality picks, a
time split, a target ~6 milli-nats from a coin). The evidence reads across as follows.

Tabular foundation models now claim ~1M rows (TabICLv2 open, TabPFN-3 vendor), but at
50 GB GPU or an H100, with quality evidence above 100k rows from a handful of datasets
(C1). TabPFN-3's licence bars its outputs from production use (C2), and neither can be
rebuilt in Zig. On time-split data, retrieval-style learners fall behind and the main
TFM benchmark excludes non-IID data (C3). So a TFM is at most a lab yardstick on a
subsample of dense features; low priority.

Learners with time-split evidence: GBDT, MLPs with embeddings and TabM, which was best
on TabReD's temporal split and the only net that resisted overtuning (C4). Explicit
cross nets (DCNv2) were no better than an MLP on time splits; on Criteo a tuned DNN tied
every crossing model and DCN-V2 beat it by ~1.5 milli-nats (C5). In CTR at 40-46M rows the
big step is LR to FM (~6-14 milli-nats); field-aware FM adds ~2-3, higher-order FM ~0
(C5); 1 milli-nat counts as significant there (C6), the size of our set net's gain.
Our shipped model already holds shrunk role-pair terms, so a field-aware FM is likely
worth a fraction of a milli-nat alone, but it is a cheap, Zig-friendly, diverse member.
GBDT inputs should be cross-fitted shrunk encodings, not raw ids (C12); no source
measures GBDT on a GLM's logit as base margin against the GLM itself (C13).

Ensembles are the most reliable gain on tabular data: post-hoc ensembles of tuned
configs and of different families beat any single model, and seeds help (C10). The
standard builder is Caruana's greedy selection with replacement, sorted initialisation
and bagged selection, which beat stacking with LR (C7). Every way of fitting weights
overfits the validation set: greedy selection over-picks validation-overfit nets,
smarter searches gain only on validation, and ensembles fall below the single best on
some datasets (C8). Stackers need out-of-fold inputs, and early stopping on the fold the
stacker sees leaks (C9). Under a time split, spending the newest games on validation
costs (C11). Experiments in C14. Searches: 16, still growing; the TFM-at-scale and
ensemble-overfitting angles found little new in the last searches.

## Claims

- C1: Tabular foundation models claim ~1M training rows (TabICLv2 under 50 GB GPU and 24 GB CPU with offloading; TabPFN-3 7 GiB KV cache per estimator on an H100), with quality evidence above 100k rows from a few datasets. for: [[tabiclv2-2026#^f1]], [[tabiclv2-2026#^f3]], [[tabpfn3-2026#^f1]], [[tabpfn3-2026#^f5]] against: [[tabiclv2-2026#^f4]]
- C2: TabPFN-3's weights and outputs may not be used for production or commercial decisions; TabICLv2 is BSD-licensed. for: [[tabpfn3-2026#^f6]]
- C3: Retrieval-style learners degrade under temporal shift, and the main TFM benchmark excludes non-IID and >250k-row data; no TFM has a time-split result on TabReD. for: [[tabred-2025#^f3]], [[temporal-shift-tabular-2025#^f1]], [[tabarena-2025#^f1]], [[tabarena-2025#^f8]] against: [[tabpfn3-2026#^f3]]
- C4: On time-split benchmarks GBDT, MLPs with embeddings and TabM do best (TabM best on TabReD's split), and time vs random splits reorder methods. for: [[tabred-2025#^f1]], [[tabred-2025#^f5]], [[temporal-shift-tabular-2025#^f1]], [[actuarial-scaling-2026#^f4]]
- C5: At 40-46M CTR rows: LR to FM is the big step, field-aware FM adds ~2-3 milli-nats, higher-order FM ~0, deep models ~3-5 more; tuned deep and crossing models tie each other, DCN-V2 beats a tuned DNN by ~1.5; on time splits DCNv2 is no better than an MLP. for: [[bars-ctr-2021#^f3]], [[bars-ctr-2021#^f4]], [[bars-ctr-2021#^f5]], [[dcnv2-2021#^f1]], [[dcnv2-2021#^f3]], [[tabred-2025#^f2]]
- C6: 0.001 nats of log loss is treated as practically significant in industrial CTR. for: [[bars-ctr-2021#^f1]], [[dcnv2-2021#^f4]]
- C7: Greedy ensemble selection with replacement, sorted initialisation and bagged selection beats the best of 2000 models (64 of 70) and stacking with LR; it is the default post-hoc ensembler. for: [[caruana-ensemble-selection-2004#^f2]], [[caruana-ensemble-selection-2004#^f4]], [[caruana-ensemble-selection-2004#^f5]], [[caruana-ensemble-selection-2004#^f6]], [[tabarena-2025#^f3]], [[autogluon-tabular-2020#^f1]]
- C8: Fitting ensemble weights or selecting configs overfits validation: greedy selection over-picks validation-overfit nets, nets overtune more than trees (TabM excepted), smarter searches gain only on validation, ensembles fall below the single best on some datasets. for: [[tabarena-2025#^f6]], [[tabarena-2025#^f7]], [[tabarena-2025#^f9]], [[qdo-es-2023#^f1]], [[qdo-es-2023#^f3]], [[caruana-ensemble-selection-2004#^f1]], [[cawley-talbot-2010#^f2]]
- C9: Stackers must be trained on out-of-fold predictions; early stopping on the out-of-fold data leaks and compounds per layer; repeated bagging dampens it. for: [[autogluon-tabular-2020#^f2]], [[autogluon-tabular-2020#^f3]], [[autogluon-tabular-2020#^f4]]
- C10: Post-hoc ensembles of tuned configs and across families beat any single model on IID tabular data, and seed averaging is a reliable cheap gain, also at 4M rows. for: [[tabarena-2025#^f2]], [[tabred-2025#^f4]], [[kaggle-gm-playbook-2025#^f1]], [[kaggle-gm-playbook-2025#^f3]], [[actuarial-scaling-2026#^f5]], [[tabm-2024#^f5]], [[qdo-es-2023#^f2]]
- C11: Under temporal shift, holding out the newest pre-test data for validation costs accuracy; train on the newest and validate on a slice with matching shift, even an older one; seed spread is larger on time splits. for: [[temporal-shift-tabular-2025#^f2]], [[temporal-shift-tabular-2025#^f3]], [[temporal-shift-tabular-2025#^f4]], [[tabred-2025#^f6]], [[tabarena-2025#^f5]]
- C12: High-cardinality categoricals enter GBDT-style learners best as cross-fitted shrunk (GLMM) target encodings; trees on one-hot draft ids lose to LR. for: [[pargent-target-encoding-2022#^f1]], [[pargent-target-encoding-2022#^f2]], [[pargent-target-encoding-2022#^f3]], [[jcj-lol-draft#^f3]], [[kaggle-gm-playbook-2025#^f5]]
- C13: GBDT built around a strong rating wins forward tests, with the rating carrying most of the signal; no source compares GBDT on a GLM's logit as base margin against the GLM. for: [[hubacek-soccer-gbdt-2019#^f4]], [[hubacek-soccer-gbdt-2019#^f5]]
- C14 (inferred): Ranked for us: (1) greedy selection with replacement and bagging over existing forward-fold predictions, judged on sealed blocks; (2) TabM residual on win-draft; (3) field-aware FM residual as a cheap Zig-friendly member; (4) GBDT with win-draft as base margin on cross-fitted dense features; (5) a validation-protocol check (newest games in training); (6) TabICLv2 as a lab yardstick only. from: C3, C4, C5, C7, C8, C9, C10, C11, C12, C13

## Disagreements

- TFMs at scale and under shift: TabPFN-3 (C, vendor) claims wins on temporal-split
  regression up to 1M rows; TabReD and Cai and Ye (A, B) find retrieval-style learners
  fall back on time splits, and TabICLv2's own authors call millions of rows and shift
  open. Settled for us only by TabICLv2 on our dense features, forward split.
- GBDT and size: GBDT gains with dataset size (McElfresh, A) vs XGBoost's lead shrinks on
  time splits (TabReD, A). Both may hold; our 1.4M-row time split decides.

## Open

- TFM as a stacker over a few forward-fold logits: no source found (1 search).
- GBDT with a logistic base margin vs the logistic model alone: no measured comparison
  found (1 search); our run would be the evidence.
- How many members pay at near-coin-flip targets: Caruana's gains are on strong
  signals; lead Lobacheva 2020 (power laws in ensembles) for loss vs ensemble size.
- Field-weighted FM and FFM on time splits at 1M+ rows in any domain: none found.
- Numerai-style low-signal temporal tabular practice (lead Wong and Barahona 2023).
- TabArena's later leaderboard (TabPFN-3, TabICLv2 rows), 2026 TFM review (lead).
