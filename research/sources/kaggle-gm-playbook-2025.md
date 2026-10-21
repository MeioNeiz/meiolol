---
title: 'Onodera, Viel, Titericz, Deotte 2025: The Kaggle Grandmasters Playbook: 7 Battle-Tested Modeling Techniques for Tabular Data (NVIDIA blog)'
url: https://developer.nvidia.com/blog/the-kaggle-grandmasters-playbook-7-battle-tested-modeling-techniques-for-tabular-data/
kind: article
commit: 
for: [frontier-tabular-ensembles]
looked: 2026-10-21
depth: docs (whole post)
relevance: medium
grade: B/weak
description: NVIDIA blog by four Kaggle grandmasters (Sep 2025): CV matched to the test structure, diverse baselines, categorical pair features, hill-climbing blends, multi-level stacking, pseudo-labels, seed averaging and full-data refit, each tied to a competition win
---
# Kaggle Grandmasters Playbook (NVIDIA, 2025)

Why: how current Kaggle tabular wins are built: hill climbing, stacking, seeds.

## Assessment

- Evidence: B. Four Kaggle grandmasters' first-hand practice, each technique tied to a
  named first or second place; no controlled comparisons.
- Reasoning: weak. Recipes with anecdotes; no sizes of gains or failures.
- Interests: NVIDIA sells GPUs; every section ends in a GPU pitch.
- Weigh: the techniques are standard; the evidence is that they win IID playground
  leaderboards (often synthetic data, large test sets), not that they transfer to a
  time-shifted, near-coin-flip target.

## Findings

- [method/ensemble] Hill climbing: start from the strongest model, add others with weights
  only while validation improves (Caruana-style); won Predict Calorie Expenditure with
  XGBoost, CatBoost, nets and linear models. 4 ^f1
  > Start with your strongest single model, then systematically add others with different weights, keeping only the combinations that improve validation.
- [method/ensemble] Stacking: a second-level model on out-of-fold predictions or on the
  first stage's residuals; a three-level stack of linear, GBDT, nets and AutoML won the
  Podcast Listening Time competition. 5 ^f2
  > Residuals: Train a Stage 2 model on what Stage 1 got wrong (the residuals).
  > a three-level stack of diverse models (linear, GBDT, neural nets, and AutoML) was used.
- [method/ensemble] Seed averaging: 100 XGBoost seeds clearly beat single seeds; refit on
  all data after tuning. 7 ^f3
  > ensembling XGBoost models across 100 different seeds clearly outperformed single-seed training.
- [method/ensemble] Validation must match the test structure: time-series splits for
  time-dependent data. Core principles ^f4
  > Match your CV strategy to how the test data is structured.
- [method/tabular] Pairs of categorical columns combined into new categorical features (8
  columns to 28 pairs) to expose interactions to GBDTs. 3 ^f5
  > By combining pairs of them, we created 28 new categorical features that captured interactions the original data didn’t show.
- [method/ensemble] (inferred) For us: Kaggle practice is GES or hill climbing over very
  different families plus seeds; our library lacks a GBDT member on dense features and a
  field-aware FM, which are the families most unlike the shipped logistic model. ^f6

## Read

- Whole post (raw/kaggle-gm-playbook-2025.md)

## Not read

- Linked write-ups (calorie hill climbing notebook, podcast stacking blog)
