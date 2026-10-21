---
title: 'Viering and Loog 2022: The shape of learning curves, a review'
url: https://arxiv.org/abs/2103.10948
kind: paper
commit:
for: [frontier-ceiling]
looked: 2026-10-21
depth: docs (abstract, sections 2.4, 4.2-4.3, 7.1)
relevance: medium
grade: A/fair
description: IEEE TPAMI 2023 review of learning curve shapes; power law with offset fits and extrapolates best in most studies, but no universal form and ill-behaved curves exist
---
# Viering and Loog 2022: The shape of learning curves, a review

Why: how far can a learning-curve asymptote be trusted as a ceiling?

## Assessment

- Evidence: A. TPAMI review, the reference survey of the topic.
- Reasoning: fair. Survey; points out where evidence is preliminary.
- Interests: none known.
- Weigh: the asymptote of a fit is a model family's limit, not the Bayes error, and
  its reliability is weakly studied.

## Findings

- [method/ceiling] Power law with offset (POW3, a*n^-b + c) usually fits and
  extrapolates best; the offset is needed for any real task with nonzero asymptotic
  error. Sec. 4.2 ^f1
  > Studies investigating these parametric forms often find the power law with offset (POW3 in the table) to offer a good fit.
  > For extrapolation, the power law with bias performed the best overall.
- [method/ceiling] Asymptote and exponent may be related, so they trade off in a fit,
  which is why c is poorly pinned (ours: docs/model.md). Sec. 4.3 ^f2
  > provide evidence that the asymptotic value of the power law and its exponent could be related.
- [method/ceiling] Curves of logistic regression and trees cross depending on the
  Bayes error; with a high Bayes error the simple model stays ahead. Sec. 4.3 ^f3
  > Perlich et al. [36] find that the Bayes error is indicative of whether the curves of decision trees and logistic regression will cross or not.
- [method/ceiling] No universal parametric form; some curves get worse with more data.
  Abstract ^f4
  > our review underscores that learning curves are surprisingly diverse and no universal model can be identified.
- [method/ceiling] Robust fitting from few curve points is an open problem. Sec. 7 ^f5
  > further investigations into how to robustly fit learning curve models from small amounts of curve data seems promising to investigate.

## Read

- Abstract, 2.4 (summaries), 4.2-4.3 (parametric fits), 7.1.

## Not read

- Theory sections (GP learning curves, PAC bounds), ill-behaved curve examples.
