---
title: 'Lakshminarayanan, Pritzel, Blundell 2017: Simple and Scalable Predictive Uncertainty Estimation using Deep Ensembles'
url: https://arxiv.org/abs/1612.01474
kind: paper
commit: 
for: [draft-predictor-methods]
looked: 2026-10-12
depth: skimmed (abstract, 2 recipe incl. ensembles vs bagging, 5 conclusion)
relevance: medium
grade: A/fair
description: NeurIPS 2017 DeepMind paper: average M = 5 independently initialised networks trained with a proper scoring rule; better calibrated than Bayesian NNs; bagging hurt
---
# Lakshminarayanan et al. 2017: Deep Ensembles

Why: whether ensembling several models is worth its cost for a noisy win
probability, and how to build the members.

## Assessment

- Evidence: A. NeurIPS 2017, the standard ensembling-for-uncertainty reference,
  thousands of citations.
- Reasoning: fair. Simple recipe with ablations; uncertainty-focused benchmarks, not
  low-signal tabular data.
- Interests: none known.
- Weigh: trust the recipe (random init, full data, M = 5, proper score); the size
  of the log-loss gain for a near-linear model on noisy labels is small and must be
  measured.

## Findings

- [method] Recipe: train with a proper scoring rule (log loss or Brier), M = 5
  networks from random initialisations, average predictions. Algorithm 1 ^f1
  > Use a proper scoring rule as the training criterion `(θ, x, y). Recommended default values are M = 5
- [method] Bagging is a good diversity source for convex learners without intrinsic
  randomness; for NNs random init plus shuffling on full data was enough and bagging
  hurt. Section 2.4 ^f2
  > If the base learner lacks intrinsic randomization (e.g. it can be trained efficiently by solving a convex optimization problem), bagging is a good mechanism for inducing diversity.
  > We observed that bagging deteriorated performance in our experiments.
- [method] Even 5 members significantly improve uncertainty quality; adversarial
  training is optional. Section 5 ^f3
  > Ensembles, even for M = 5, significantly improve uncertainty quality in all the cases.
- [method] Cost: M times the parameters and training (trivially parallel); can be
  distilled into one model. Section 5 ^f4
  > The ensemble has M times more parameters than a single network; for memory-constrained applications, the ensemble can be distilled into a simpler model
- [method] (inferred) A convex logistic model has a single optimum, so random-init
  ensembling does nothing for it; ensembling pays only once we use non-convex models
  (FM, set nets) and mainly improves calibration, i.e. log loss, not AUC. ^f5

## Read

- Abstract, 1, 2 (recipe, ensembles, bagging), 5 discussion

## Not read

- 3 experiments in detail (regression, MNIST, SVHN, ImageNet)
