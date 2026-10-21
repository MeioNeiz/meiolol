---
title: 'Rubachev, Kartashev, Gorishniy, Babenko 2025: TabReD: Analyzing Pitfalls and Filling the Gaps in Tabular Deep Learning Benchmarks'
url: https://arxiv.org/pdf/2406.19380v4
kind: paper
commit: 
for: [frontier-tabular-ensembles]
looked: 2026-10-21
depth: skimmed (abstract, 1, 4, 5.1-5.4)
relevance: high
grade: A/strong
description: ICLR 2025 (Yandex): 8 industrial tabular datasets with time-based train/validation/test splits; GBDT and MLP with numerical embeddings best, ensembles help, retrieval models (TabR, ModernNCA), DCNv2 and long training recipes do not transfer; time vs random splits reorder methods
---
# TabReD (Yandex, ICLR 2025)

Why: the only major tabular benchmark built on time-based splits, our evaluation
regime; which modern learners survive temporal shift?

## Assessment

- Evidence: A. ICLR 2025, same group as TabM and FT-Transformer, open code and data,
  8 datasets (20k to millions of rows, some subsampled), 15 seeds per config.
- Reasoning: strong. Compares the same methods on random and time splits.
- Interests: the group proposed TabR and MLP-PLR; TabR does badly here, which they report.
- Weigh: feature-rich industrial data (hundreds of features), mostly not categorical
  ids; tabular foundation models not tested.

## Findings

- [method/tabular] Time-based splits rank methods differently from random splits; simple
  MLP-like nets and GBDT do best, other methods less so. Abstract ^f1
  > We demonstrate that evaluation on time-based data splits leads to different methods ranking, compared to evaluation on random splits
  > simple MLP-like architectures and GBDT show the best results on the TabReD datasets
- [method/tabular] DCNv2, SNN, ResNet and Trompt are no better than a plain MLP on these
  time splits. 5.2 ^f2
  > SNN, DCNv2, ResNet and Trompt are no better than the MLP baseline.
- [method/tabular] Retrieval models and long training recipes that win on earlier
  benchmarks underperform; train rows retrieved may not help under gradual temporal
  shift. 5.3 ^f3
  > This can be violated by the presence of gradual temporal shift.
- [method/ensemble] Ensembling and numerical embeddings transfer to time-split data;
  ensembles consistently improve MLP and MLP-PLR. 5.2, 5.3 ^f4
  > Ensembles also bring consistent performance improvements to MLP and MLP-PLR in line with the existing knowledge on prior benchmarks and practice.
- [method/tabular] XGBoost's lead over MLPs shrinks on time-shifted test sets, perhaps
  because GBDTs exploit time leakage on random splits. 5.4 ^f5
  > One notable example is XGBoost decreasing its performance margin to MLPs when evaluated on temporally shifted test sets
  > This might indicate that GBDTs are less robust to shifts, conversely performing better on random splits, by possibly exploiting time-based leakage.
- [method/tabular] Seed spread is larger on time-split test sets than on random ones.
  5.4 ^f6
  > the spread of scores depending on random initialization for each model and data split is generally larger on the time-split based test set
- [method/tabular] (inferred) For us: this matches our own record (nets early-stop at 1-4
  epochs, random-split gains vanish on time splits). Of the frontier learners, only GBDT,
  embedding MLPs and ensembles have time-split evidence; retrieval-like in-context models
  (TabPFN, TabICL) have none on this benchmark. ^f7

## Read

- Abstract, 1, 4 (datasets), 5.1-5.4 (raw/tabred-2025.txt)

## Not read

- Appendix A.1-A.3 (shift analysis, robustness methods), per-dataset Table 3 values
