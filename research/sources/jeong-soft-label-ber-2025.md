---
title: 'Ushio, Ishida, Sugiyama 2026: Practical estimation of the optimal classification error with soft labels and calibration'
url: https://arxiv.org/abs/2505.20761
kind: paper
commit:
for: [frontier-ceiling]
looked: 2026-10-21
depth: docs (abstract, sections 1, 3.2-3.3)
relevance: high
grade: A/strong
description: ICLR 2026 follow-up to Ishida 2023; shows calibrated soft labels can still misestimate the Bayes error and proves isotonic calibration gives a consistent estimate when the scores' order is right
---
# Ushio, Ishida, Sugiyama 2026: Practical estimation of the optimal classification error with soft labels and calibration

Why: our only soft labels are model outputs. Does plugging a calibrated model's win
probabilities into the Bayes error formula give the ceiling?

## Assessment

- Evidence: A. ICLR 2026, same group as [[ishida-bayes-error-2023]], proofs and code
  (github.com/RyotaUshio/bayes-error-estimation).
- Reasoning: strong. Gives a counterexample, then the condition under which it works.
- Interests: none known.
- Weigh: the key condition (scores are a monotone function of the true probability)
  is exactly what a model that misses signal violates, so on our data the plug-in is
  an upper bound on the Bayes error, not an estimate.

## Findings

- [method/ceiling] Calibration alone is not enough: even perfectly calibrated soft
  labels can give a badly wrong Bayes error estimate. Abstract ^f1
  > even perfectly calibrated soft labels can result in a substantially inaccurate estimate.
- [method/ceiling] Counterexample: a constant prediction equal to the base rate is
  perfectly calibrated and gives the coin-flip error whatever the true error. Example 2 ^f2
  > If A is a calibration algorithm that produces constant soft labels ηbiA = θ = 0.5 for all i ∈ [n], it indeed achieves perfect calibration.
- [method/ceiling] Isotonic calibration of corrupted soft labels against hard labels,
  then the min(p, 1-p) plug-in, is consistent if the scores are an increasing function
  of the true probability. Thm 2 ^f3
  > we can construct a consistent estimator of the Bayes error using isotonic calibration as long as the soft labels’ order is preserved.
- [method/ceiling] (inferred) For us: a calibrated draft model's p is E[true p | what
  the model sees], so mean min(p, 1-p) is its own expected error, an upper bound on the
  draft Bayes error (a lower bound on the ceiling); it equals the Bayes error only if the
  model ranks drafts in the true order. ^f4
- [method/ceiling] Purpose: knowing the optimum tells whether to keep training bigger
  models. Sec. 1 ^f5
  > if the current SOTA performance is close enough to the limit, there is no point in seeking further improvement.

## Read

- Abstract, section 1, sections 3.2-3.3: fully.

## Not read

- Section 3.1 (bias decay with hard labels per instance): needs many labels per
  instance, which we lack. Experiments section.
