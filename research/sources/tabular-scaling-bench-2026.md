---
title: 'Ding 2026: Scaling Laws for Classical Machine Learning on Tabular Data, An Empirical Benchmark Study'
url: https://arxiv.org/abs/2607.21866
kind: paper
commit: 
for: [draft-predictor-methods]
looked: 2026-10-12
depth: skimmed (abstract, 1-3 protocol and fitting, 4.2 exponents and floors)
relevance: medium
grade: B/fair
description: July 2026 preprint (UPenn): 127 students fit error = a N^-b + c on 18 tabular datasets x 6 classical families; power laws fit 78% of cells; logistic has the steepest exponent, trees the lowest floors
---
# Ding 2026: Scaling Laws for Classical ML on Tabular Data

Why: what learning-curve shape and exponent to expect for logistic regression and
GBDT on tabular data, and how to fit it.

## Assessment

- Evidence: B. Recent preprint, not peer reviewed; 11,536 runs and 1,648 fits by a
  graduate cohort; datasets are small UCI-style sets; error metric 1 - AUROC.
- Reasoning: fair. Honest about replicator variance (exponent CV 14%) and that it is
  partial replication; fixed hyperparameters across N (no per-N retuning).
- Interests: none known.
- Weigh: trust the functional form and the "look at b and c jointly" lesson; numbers
  come from easy datasets (floors near AUROC 0.8-0.9), far from our 0.55.

## Findings

- [method] [stats] Fit error(N) = a N^-b + c (c the irreducible floor) to nested
  subsets at seven fractions (1% to 100%) on one fixed test set. Section 3.3 ^f1
  > For each (replicator, dataset, model) triple we fit a three-parameter power law,
- [method] [stats] Power laws fit well (R^2 > 0.8) on 77.7% of cells; tree ensembles
  win at full data, linear models underperform on classification. Abstract ^f2
  > Power laws fit: R2 > 0.8 on 77.7% of cells, with tree ensembles dominating at full data (Boosting 50% of datasets, RandomForest 33%; linear models underperform on classification).
- [method] [stats] Logistic regression has the steepest stable exponent (median b =
  0.83), boosting 0.48, random forest 0.33. Section 4.2 ^f3
  > Linear/Logistic regression has the largest stable exponent (b̃ = 0.830) on classification,
- [method] [stats] Exponent alone misleads: what matters is exponent and floor
  together. Section 4.2 ^f4
  > The takeaway is that for practical decisions, b alone is misleading; what matters is the joint (b, c).
- [method] Even with the seed fixed, re-implementations of one protocol moved the
  fitted exponent by about 14%. Abstract ^f5
  > with the random seed fixed, independent re-implementations of the same protocol still differ by a mean coefficient of variation CV(b) = 0.144 on the fitted exponent b
- [stats] (inferred) Our curve (-0.0008 log loss per doubling) should be fitted with a
  floor c, at several nested fractions, and compared between model families on the
  same test set; a single exponent from one run is ±15% at best. ^f6

## Read

- Abstract, 1, 2, 3 (protocol, fitting), 4.2

## Not read

- 4.3 shared exponents, 4.4 replicator variance detail, N* table
