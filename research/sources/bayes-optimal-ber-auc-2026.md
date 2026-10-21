---
title: 'Ushio, Ishida, Sugiyama 2026: Bayes-optimal BER and AUC, estimation and evaluation of estimators'
url: https://arxiv.org/abs/2609.02304
kind: paper
commit:
for: [frontier-ceiling]
looked: 2026-10-21
depth: docs (abstract, sections 1-2)
relevance: medium
grade: B/strong
description: September 2026 preprint extending soft-label Bayes error estimation to the optimal balanced error and optimal AUC, and the FeeBee label-noise evaluation to both
---
# Ushio, Ishida, Sugiyama 2026: Bayes-optimal BER and AUC, estimation and evaluation of estimators

Why: we report AUC (0.569); is there an optimal-AUC formula we can plug into?

## Assessment

- Evidence: B. Recent preprint (not yet peer reviewed) from the group behind
  [[ishida-bayes-error-2023]] and [[jeong-soft-label-ber-2025]].
- Reasoning: strong: proofs, finite-sample bounds.
- Interests: none known.
- Weigh: same soft-label caveat as the earlier papers; the optimal AUC formula itself
  is classical (Clemencon 2008), the paper proves it.

## Findings

- [method/ceiling] The optimal AUC is an expectation over pairs of inputs of a function
  of their two true class probabilities, so it too can be computed from soft labels
  (O(n log n) algorithm given). Lemma 2.2 ^f1
  > Clémençon et al. (2008, Example 1) mentioned the former expression of AUC
- [method/ceiling] Practical estimator: isotonic regression of the soft labels on hard
  labels, then plug in; the class prior from a clipped mean of the hard labels.
  Abstract ^f2
  > we approximately recover the clean soft labels via isotonic regression with auxiliary hard labels
- [method/ceiling] FeeBee's label-noise evaluation extended to optimal BER and AUC, so
  any estimator can be scored without knowing the optimum. Abstract ^f3
  > We extend the FeeBee framework, originally proposed for evaluating Bayes-error estimators, to the optimal BER and AUC.

## Read

- Abstract, sections 1-2.

## Not read

- Sections 3-5 (corrupted labels, evaluation, experiments): same method as
  [[jeong-soft-label-ber-2025]] applied to AUC.
