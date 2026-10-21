---
title: 'Ishida et al. 2023: A direct approach to estimating the Bayes error in binary classification'
url: https://arxiv.org/abs/2202.00395
kind: paper
commit:
for: [frontier-ceiling]
looked: 2026-10-21
depth: docs (sections 1-3, 5.4, 6)
relevance: medium
grade: A/strong
description: ICLR 2023 top-5% paper; estimates the Bayes error as the mean of min(p, 1-p) over soft labels, model-free and instance-free, with ICLR accept/reject as a worked case
---
# Ishida et al. 2023: A direct approach to estimating the Bayes error in binary classification

Why: the cleanest modern statement of the Bayes error for a binary outcome, and whether
it can be estimated from one hard label per game (our case).

## Assessment

- Evidence: A. ICLR 2023 oral (top 5%), Sugiyama's group, proofs of unbiasedness and
  rates; follow-ups at ICLR 2026 ([[jeong-soft-label-ber-2025]]).
- Reasoning: strong. States its limits: hard labels alone need sign labels, noisy soft
  labels bias the naive estimator.
- Interests: none known.
- Weigh: the identity is textbook. The estimator needs per-instance class
  probabilities; with one outcome per draft we only have model outputs, which brings in
  the calibration problem of the follow-up paper.

## Findings

- [method/ceiling] The Bayes error of a binary task is the mean over inputs of the
  smaller class probability; so the best accuracy is the mean of max(p, 1-p) of the
  true win probability. Sec. 3 ^f1
  > it is known to be equivalent to the expectation of the minimum of class-posteriors with respect to classes for binary classification
- [method/ceiling] With true soft labels the plug-in mean of min(c, 1-c) is unbiased
  with O(1/sqrt(n)) error and no dependence on input dimension. Props 3.1, 3.2 ^f2
  > We are also free from the curse of dimensionality since the instance dimension d does not appear in the bound.
- [method/ceiling] Noise inside the min biases the plug-in: zero-mean noise on the soft
  labels makes it a biased estimator; averaging m hard labels per instance removes the
  bias only as m grows. Thm 3.3, Prop 3.6 ^f3
  > This is basically due to the noise inside the nonlinear min operation.
- [method/ceiling] (inferred) A single hard outcome per game is the m = 1 case: the
  naive estimator gives 0, so the method needs soft labels from elsewhere (a model's
  calibrated output, or many repeats of the same draft, which we lack). ^f4
- [method/ceiling] Real case: ICLR accept/reject Bayes error 6.8-9.6% per year, using
  reviewer scores Platt-scaled to the decisions as soft labels. Sec. 5.4 ^f5
  > We used Platt scaling (Platt et al., 1999) with the hard labels so that we have a calibrated score between 0 and 1.
- [method/ceiling] Purpose: a known Bayes error flags test-set overfitting when a model
  beats it. Sec. 1 ^f6
  > We may even find out that the model’s error has exceeded the Bayes error. This may imply test set overfitting

## Read

- Sections 1-3, 5.4, 6: fully.

## Not read

- Section 4 (positive-confidence data), 5.1-5.3 (CIFAR-10H, Fashion-MNIST-H) and
  appendix proofs: not our setting.
