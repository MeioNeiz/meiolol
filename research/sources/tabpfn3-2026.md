---
title: 'Prior Labs 2026: TabPFN-3: Technical Report'
url: https://arxiv.org/pdf/2605.13986
kind: paper
commit: 
for: [frontier-tabular-ensembles]
looked: 2026-10-21
depth: skimmed (summary, 2.4-2.6 prior, 3 large data, 5 licence)
relevance: medium
grade: C/fair
description: Prior Labs vendor report (May 2026): TabPFN-3 scales in-context learning to 1M training rows on one H100, beats 8-hour-tuned GBDTs on 13 large datasets; a temporal prior; weights non-commercial, production only under an enterprise licence
---
# TabPFN-3 technical report (Prior Labs, 2026)

Why: the vendor claim that a tabular foundation model now handles 1M rows, our size.

## Assessment

- Evidence: C. Vendor technical report, own benchmark of 13 large datasets plus 14 TALENT
  datasets; the TabPFN line is widely used (Nature 2025 paper, 8k-star repo).
- Reasoning: fair. Explains the row-compression trade-off; little on failure cases.
- Interests: vendor selling API and enterprise licences.
- Weigh: the large-data claim rests on 13 datasets, scored by ROC AUC and RMSE; verify on
  our own data before believing it on near-coin-flip log loss. The licence rules it out
  for anything the app or site uses.

## Findings

- [method/tabular] Claims to beat 8-hour-tuned GBDTs on datasets up to 1M training rows
  and 200 features, in one forward pass. Summary ^f1
  > beats 8-hour-tuned gradient-boosted-tree baselines on datasets up to 1M training rows and 200 features.
- [method/tabular] Rows are first compressed into fixed-size representations, then
  in-context learning runs over rows; with many rows and many features the compression can
  bottleneck. 3 ^f2
  > when both the number of rows and the number of features are very large, the early compression of feature information can become a bottleneck.
- [method/tabular] The large-data regression datasets use temporal splits (train on past,
  test on future). 3 ^f3
  > For regression, the datasets in our benchmark exhibit temporal structure, where models are trained on past data and must generalize to future data.
- [method/tabular] The prior adds temporal structure and out-of-distribution tasks for
  time-ordered splits and shift. 2.5 ^f4
  > train and test splits are often ordered by time rather than drawn i.i.d., and temporal dependencies between variables are common.
- [method/tabular] Memory: a KV cache of 7 GiB per estimator at 1M rows; 8 estimators by
  default, on an H100. 2.4 ^f5
  > This achieves a KV-cache size of 7GiB per estimator for 1M rows datasets
- [method/tabular] Licence: the model, derivatives and outputs cannot be used for
  commercial or production purposes, including as inputs to decisions. 5 ^f6
  > The key restriction is that the model, its derivatives, and its outputs cannot be used for commercial or production purposes.
- [method/tabular] (inferred) For us: usable only as an internal lab yardstick (licence,
  and a transformer cannot be rebuilt in Zig); on a 10 GB 3080, one estimator with a
  subsampled context. ^f7

## Read

- Summary page, 2.4-2.6, 3 large-data section, 5 licence (raw/tabpfn3-2026.txt)

## Not read

- Per-dataset large-data scores (F.2), relational and text results
