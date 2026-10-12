---
title: 'Lu, Liu, Dong, Gu, Gama, Zhang 2018: Learning under Concept Drift, A Review'
url: https://arxiv.org/abs/2004.05785
kind: paper
commit: 
for: [draft-predictor-methods]
looked: 2026-10-12
depth: skimmed (abstract, 1, 2.2 drift types, 4 severity, 5 adaptation)
relevance: medium
grade: A/fair
description: IEEE TKDE 2018 review (Gama among authors) of drift detection, understanding and adaptation: retrain on a window, ensembles for recurring drift, partial model updates for regional drift
---
# Lu et al. 2018: Learning under Concept Drift, A Review

Why: patches change champion strength; which adaptation strategy (window, decay
weighting, partial update) fits a known, partly local, recurring change.

## Assessment

- Evidence: A. IEEE TKDE review, highly cited; co-author Gama wrote the 2014 ACM CSUR
  drift survey.
- Reasoning: fair. A taxonomy, little head-to-head evidence on which strategy wins.
- Interests: authors' own detection methods feature.
- Weigh: aimed at streams with unknown change points; our change points (patch dates)
  are known, which removes the detection problem.

## Findings

- [method] [data] Drift comes in types: sudden, incremental, gradual, and recurring
  concepts. Section 2.2 ^f1
  > Gradual Drift: A new concept gradually replaces an old one over a period of time.
- [method] [data] Three adaptation families: simple retraining, ensemble retraining,
  and model adjusting. Section 5 ^f2
  > There are three main groups of drift adaptation methods, namely simple retraining, ensemble retraining and model adjusting
- [method] [stats] Window size is a trade-off: small reflects the latest
  distribution, large gives more training data. Section 5.1 ^f3
  > A small window can better reflect the latest data distribution, but a large window provides more data for training a new model.
- [method] Severity guides the strategy: low severity, update the current learner
  incrementally; high severity, retrain. Section 4 ^f4
  > if the severity of drift in a classification task is low, the decision boundary may not move much in the new concept. Thus, adjusting the current learner by incremental learning will be adequate.
- [method] When drift is local, partially updating the model is arguably more
  efficient than retraining all of it. Section 5.3 ^f5
  > This approach is arguably more efficient than retraining when the drift only occurs in local regions.
- [method] (inferred) A patch is a known-date, mostly local drift (a few champions and
  items change). That points to keeping all patches but letting changed champions'
  parameters move (patch-specific offsets shrunk to the pooled value, or recency
  weights), rather than a hard last-patch window that throws away 90%+ of games. ^f6

## Read

- Abstract, 1, 2.2, 4 severity, 5.1-5.3

## Not read

- 3 detection algorithms, 6 datasets and evaluation, 7 directions
