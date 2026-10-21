---
title: 'Cai, Ye 2025: Understanding the Limits of Deep Tabular Methods with Temporal Shift'
url: https://arxiv.org/pdf/2502.20260v2
kind: paper
commit: 
for: [frontier-tabular-ensembles]
looked: 2026-10-21
depth: skimmed (abstract, 1, 4.1-4.4, Table 1)
relevance: high
grade: B/fair
description: ICML 2025 (Nanjing, TALENT group): on TabReD, validating on the newest pre-test slice costs deep tabular models; training on the newest data and validating on a slice with the same shift (even the oldest) gains ~2%; TabM best under the original temporal split
---
# Cai and Ye 2025: deep tabular methods under temporal shift

Why: how to validate and early-stop learners under a time split, our protocol; and which
modern learner holds up.

## Assessment

- Evidence: B. ICML 2025 paper by the TALENT benchmark group, all 8 TabReD datasets,
  11 methods, multiple seeds.
- Reasoning: fair. Isolates training lag and validation bias with controlled splits;
  the proposed split is tuned on the same benchmark it is scored on.
- Interests: proposes its split and a temporal embedding.
- Weigh: percentage gains are averaged over regression and classification metrics;
  trust the direction (newest data belongs in training), not the size.

## Findings

- [method/tabular] On TabReD's original temporal split, retrieval methods fall behind
  trees and MLP-PLR, and TabM performs best. Figure 2 ^f1
  > In this setting, the performance of retrieval-based methods significantly declines, falling behind tree-based methods and MLP-PLR, while TabM achieves the best performance.
- [method/ensemble] Merely splitting train and validation at random (ignoring time)
  instead of holding out the newest pre-test slice improved models, though less stably.
  1 ^f2
  > even when randomly splitting the training and validation sets and ignoring temporal order, the model outperformed the temporal split, resulting in significantly enhanced performance
- [method/ensemble] Two causes: the newest data is spent on validation rather than
  training (lag), and the test is further from training than validation is (bias).
  Closing the lag alone gained 1.62% on average across MLP-PLR, ModernNCA and TabM. 4.1 ^f3
  > the data closest to the test time are not used for training, and the shift degree of test set relative to validation set is more significant in temporal splits.
  > hypothesis holds for all three methods, with a total average improvement of 1.62%.
- [method/ensemble] Protocol: put instances near the test time in training, not
  validation; pick a validation slice whose time gap to training matches the test's,
  which can lie in the opposite direction (older data). 4.4 ^f4
  > The lag between training and test set should be minimized since instances near the test time are more valuable for training, rather than for model selection.
  > An effective validation is available in the opposite temporal direction by aligning the degree of shift in the validation set with the actual shift between training and testing data.
- [method/ensemble] (inferred) For us: nets that early-stop on the newest fit fold and
  stackers fitted only on older folds both give up the newest games; check whether
  refitting the chosen epoch count on all fit games, or validating on an older slice,
  gains on dev-val. Our A/A floor (~0.5 milli-nats) may hide a 1-2% relative change in
  the reducible part. ^f5

## Read

- Abstract, 1, 4.1-4.4, Table 1 (raw/temporal-shift-tabular-2025.txt)

## Not read

- Section 5 temporal (Fourier) embedding, appendix C per-dataset results
