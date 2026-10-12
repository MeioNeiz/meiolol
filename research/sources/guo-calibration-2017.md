---
title: 'Guo et al. 2017: On Calibration of Modern Neural Networks'
url: https://arxiv.org/abs/1706.04599
kind: paper
commit: 
for: [draft-predictor-methods]
looked: 2026-10-12
depth: skimmed (abstract, 1, 3, 4.1, 5 summary, 6)
relevance: medium
grade: A/strong
description: ICML 2017 Cornell paper showing deep nets are miscalibrated (capacity, low weight decay, overfitting NLL) and that one-parameter temperature scaling fixes it best
---
# Guo et al. 2017: On Calibration of Modern Neural Networks

Why: if we move from logistic regression to a neural model, will its win
probabilities stay honest, and what fixes them cheaply.

## Assessment

- Evidence: A. ICML 2017, the standard calibration reference, thousands of citations.
- Reasoning: strong. Ablations on depth, width, BatchNorm and weight decay; compares
  histogram binning, isotonic, BBQ, Platt, matrix and temperature scaling across many
  datasets.
- Interests: none known.
- Weigh: trust the mechanism and the recipe; datasets are images and text, not
  noisy binary outcomes.

## Findings

- [method] Older (shallow) neural networks gave well-calibrated binary probabilities;
  modern high-capacity ones are miscalibrated. Section 1 ^f1
  > Niculescu-Mizil & Caruana (2005) showed that neural networks typically produce well-calibrated probabilities on binary classification tasks.
- [method] Miscalibration comes from overfitting log loss while 0/1 error still
  improves; overfitting shows in probabilities, not accuracy. Section 3 ^f2
  > This disconnect occurs because neural networks can overfit to NLL without overfitting to the 0/1 loss.
  > overfitting manifests in probabilistic error rather than classification error.
- [method] Less weight decay hurts calibration. Section 3 ^f3
  > We find that training with less weight decay has a negative impact on calibration.
- [method] All calibration methods are post-processing fitted on a held-out validation
  set; Platt scaling fits sigma(a z + b) on validation NLL with the network frozen.
  Section 4.1 ^f4
  > Each method requires a hold-out validation set
  > Platt scaling learns scalar parameters a, b ∈ R and outputs q̂i = σ(azi + b) as the calibrated probability.
- [method] Temperature scaling (one parameter) is simplest, fastest and often most
  effective, and it does not change accuracy. Sections 4.2, 6 ^f5
  > Temperature scaling is the simplest, fastest, and most straightforward of the methods, and surprisingly is often the most effective.
  > temperature scaling does not affect the model’s accuracy.
- [method] (inferred) For us: judge model changes by held-out log loss, not accuracy
  (accuracy can improve while probabilities degrade), and refit a Platt or temperature
  step on a recent validation slice after any non-linear model. ^f6

## Read

- Abstract, 1, 3 (observing miscalibration), 4.1 binary methods, 4.2 temperature, 6

## Not read

- 2 definitions and ECE detail, 5 result tables per dataset
