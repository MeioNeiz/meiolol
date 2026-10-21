---
title: 'Pargent, Pfisterer, Thomas, Bischl 2022: Regularized target encoding outperforms traditional methods in supervised machine learning with high cardinality features'
url: https://arxiv.org/pdf/2104.00629
kind: paper
commit: 
for: [frontier-tabular-ensembles]
looked: 2026-10-21
depth: skimmed (abstract, 2.7, 4)
relevance: medium
grade: A/fair
description: Computational Statistics 2022 (LMU): benchmark of categorical encoders x 5 learners (lasso, RF, xgboost, KNN, SVM) on 24 datasets with high-cardinality features; GLMM (shrunk) target encoding with 5-fold cross-fitting best everywhere
---
# Pargent et al. 2022: regularised target encoding

Why: to feed champion ids to a GBDT or a stacker, how should high-cardinality
categoricals be encoded?

## Assessment

- Evidence: A. Peer-reviewed, large benchmark (24 datasets, 5 learners, many encoders),
  code public; mlr group.
- Reasoning: fair. Clear protocol; IID 5-fold CV only.
- Interests: none.
- Weigh: our shipped model is already a shrunk (GLMM-like) per-champion estimate; the
  finding says use it, cross-fitted, as the encoding.

## Findings

- [method/tabular] Regularised target encoding (predictions from the level's training
  targets as a numeric feature) was best; integer encoding and level-collapsing before
  one-hot were worse. Abstract ^f1
  > In our study, regularized versions of target encoding (i.e. using target predictions based on the feature levels in the training set as a new numerical feature) consistently provided the best results.
- [method/tabular] GLMM encoders with cross-validation beat every other approach for all
  learners, including gradient boosting. 4 ^f2
  > approaches based on GLMM’s in combination with cross-validation outperform all other approaches across all algorithms.
- [method/tabular] Cross-fitting: fit the encoder on each CV training part and encode each
  row with the model that did not see it. 2.7 ^f3
  > For each observation, there is exactly one glmm that did not use that observation for model fitting and can be safely used for encoding.
- [method/tabular] Some encoder and learner combinations did worse than dropping the
  high-cardinality features. 4 ^f4
  > some encoder × ML algorithm conditions performed worse than simply removing high cardinality features.
- [method/tabular] (inferred) For us: a GBDT or TFM over a draft should take the shipped
  model's shrunk per-champion and pair terms, cross-fitted forward in time, as dense
  inputs (or as base margin), not raw champion ids. ^f5

## Read

- Abstract, 2.7 GLMM encoding, 4 results (raw/pargent-target-encoding-2022.txt)

## Not read

- Per-dataset figures, HCT threshold analysis
