---
title: 'Qu, Holzmüller, Varoquaux, Le Morvan 2026: TabICLv2: A better, faster, scalable, and open tabular foundation model'
url: https://arxiv.org/pdf/2602.11139v1
kind: paper
commit: 
for: [frontier-tabular-ensembles]
looked: 2026-10-21
depth: skimmed (abstract, 4.2, 6, 8)
relevance: medium
grade: B/fair
description: Inria 2026: open (BSD-3) tabular foundation model, in-context learning to 1M rows with CPU and disk offloading; beats tuned GBDTs and RealTabPFN-2.5 on TabArena and TALENT without tuning
---
# TabICLv2 (Inria, 2026)

Why: the open tabular foundation model that claims million-row tables; could one run on
our 1.4M games, or serve as a stacker?

## Assessment

- Evidence: B. Preprint from the Inria soda team (Varoquaux), code and weights released
  (github soda-inria/tabicl: BSD-3, 1.4k stars, 22 contributors, v2.2.0 Sep 2026);
  results on TabArena and TALENT, i.e. IID benchmarks mostly under 100k rows.
- Reasoning: fair. Ablations of each component; limitations stated.
- Interests: authors propose the model; one author co-authors TabArena.
- Weigh: the million-row claim is about memory and runtime; quality evidence above 100k
  rows is two huge TALENT datasets by accuracy. Nothing on time splits or near-coin-flip
  targets.

## Findings

- [method/tabular] With disk offloading TabICLv2 fits a 1M-row, 500-feature table in under
  24 GB CPU and 50 GB GPU memory within 450 seconds, with no retrieval or distillation.
  4.2 ^f1
  > reducing requirements to under 24 GB CPU and 50 GB GPU to process a table with 1M samples and 500 features within 450 seconds
- [method/tabular] Untuned it beats tuned and ensembled RealTabPFN-2.5 and heavily tuned
  CatBoost and XGBoost on TabArena and TALENT. 6 ^f2
  > Without any tuning, TabICLv2 surpasses RealTabPFN-2.5 (tuned + ensembled)
  > TabICLv2 also substantially outperforms heavily tuned traditional methods, such as CatBoost and XGBoost
- [method/tabular] Evidence beyond 100k rows is two 600k-row TALENT datasets, scored by
  accuracy, where TabPFN-2.5 ran out of memory. 6, Figure 9 ^f3
  > On even larger datasets (600K) from the TALENT extension, TabICLv2 still performs strongly
- [method/tabular] Authors' own limits: millions of rows remain hard; distribution shift
  is left to future work. 8 ^f4
  > despite improved scalability, datasets with millions of samples remain challenging.
  > Many extensions, such as multi-output regression or handling distribution shifts (Helli et al., 2024) are also left to future work.
- [method/tabular] (inferred) For us: our 3080 has 10 GB, a fifth of the 50 GB quoted for
  1M rows; a run would use a subsample of context rows or a dense feature table of a few
  dozen columns. The model cannot ship in the Zig app (a pretrained transformer), so it is
  only a lab probe of how much signal a strong generic learner finds in our features. ^f5

## Read

- Abstract, 4.2 inference, 6 results, 8 limitations (raw/tabiclv2-2026.txt)

## Not read

- Appendix K.8 (results above 10k rows by dataset) and H.2 offloading details
