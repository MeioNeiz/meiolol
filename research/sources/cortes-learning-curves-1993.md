---
title: 'Cortes et al. 1993: Learning curves, asymptotic values and rate of convergence'
url: https://proceedings.neurips.cc/paper/1993/hash/1aa48fc4880bb0c9b8a3bf979d3b917e-Abstract.html
kind: paper
commit:
for: [frontier-ceiling]
looked: 2026-10-21
depth: docs (all, 8 pages)
relevance: high
grade: A/fair
description: NIPS 1993 Bell Labs paper (Cortes, Jackel, Solla, Vapnik, Denker); a model's training and test errors bracket a common asymptote, so their sum and difference against training size give the asymptotic error
---
# Cortes et al. 1993: Learning curves, asymptotic values and rate of convergence

Why: our a*N^-b + c fits of test loss alone leave c unidentified (docs/model.md). Is
there a better-posed way to estimate a model family's asymptote?

## Assessment

- Evidence: A. Classic, Vapnik and Cortes, widely cited; tested on many boolean
  classifiers and a digit task.
- Reasoning: fair. Simple model, stated assumptions, few experiments.
- Interests: none known.
- Weigh: gives the asymptote of one model family (its approximation error), not the
  Bayes error; it bounds the ceiling only for that family.

## Findings

- [method/ceiling] Test error sits above training error at every size and both
  converge to one asymptote a. Sec. 2 ^f1
  > The test error is always larger than the training error, but asymptotically they reach a common value, a.
- [method/ceiling] Model: test = a + b/l^alpha, train = a - c/l^beta; the sum is flat at
  2a and the difference is a straight line in log-log, so a comes from where they meet
  instead of from extrapolating test error alone. Sec. 2 ^f2
  > a constant "-' log(2a) for the sum, and a straight line with slope -a and intersection log(b + c)
- [method/ceiling] Unequal amplitudes still give a straight difference line; a weighted
  sum of test and train errors is then constant. Sec. 2 ^f3
  > the difference ['test - ['train still forms a straight line in a log-log-plot.
- [method/ceiling] Fitted from intermediate sizes and extrapolated to the full database
  in their tests. Sec. 2 ^f4
  > it appears to be valid already at intermediate sizes
- [method/ceiling] (inferred) For us: per model, the in-sample (train) and held-out log
  loss at 6 nested sizes bracket that model's asymptotic log loss; the midpoint at the
  largest size is a cheap estimate with a sandwich, where test-only fits gave c
  meaningless. For a well-specified likelihood model the AIC result says the gap is
  about k/n each side, so the midpoint is already near the asymptote. ^f5

## Read

- All 8 pages.
