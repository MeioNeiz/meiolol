---
title: 'Radenovic, Dubey, Mahajan 2022: Neural basis models for interpretability'
url: https://arxiv.org/pdf/2205.14120
kind: paper
commit: 
for: [frontier-interactions]
looked: 2026-10-21
depth: docs (abstract, 1-3, 4 setup)
relevance: low
grade: B/fair
description: NeurIPS 2022 (Meta AI); GAM whose shape functions are combinations of a few bases learnt by one shared net; NB2M models all pairs with shared bivariate bases, parameters growing linearly not quadratically; one-hot or target-encoded categoricals; state of the art among GAMs on 12 tabular sets
---
# Radenovic, Dubey, Mahajan 2022: Neural basis models

Why: a GA2M that fits every pair at once through a shared low-rank basis, the nearest
neural analogue of low-rank champion pair terms.

## Assessment

- Evidence: B. NeurIPS 2022, Meta AI, code public; 12 tabular and 2 image sets.
- Reasoning: fair. Clear scaling argument; accuracy claims against other GAMs.
- Interests: authors' method.
- Weigh: built for continuous features; with one-hot champion seats each shape
  function is one number, so the basis idea matters only for profile features.

## Findings

- [method/interpret] Shape functions are weighted sums of a small number of bases shared
  by all features, learnt by one net; scales to high-dimensional sparse features.
  Abstract ^f1
  > A small number of basis functions are shared among all features, and are learned jointly for a given task
- [method/interpret] Pairs: a second set of shared bivariate bases, coefficients per pair,
  so parameters grow linearly, without the interaction pre-selection EBM and NA2M need.
  Section 1 ^f2
  > This approach effectively only linearly increases the parameters, while other models such as EB2 Ms [36, 37] and NA2 Ms [2] suffer from quadratic growth of parameters
- [method/interpret] Reported: NBMs and NB2Ms beat other GAMs and GA2Ms while fitting far
  fewer parameters, 5-50x fewer than NAM past ten features. Section 1 ^f3
  > For datasets with more than ten features, using NBMs result in around 5×–50× reduction in parameters over NAMs
- [method/interpret] Categoricals one-hot encoded on some sets, target-encoded on others.
  Section 4 ^f4
  > We perform one-hot encoding for categorical features
- [method/interpret] Checked, not there: interaction detection, error control,
  identity-level categorical pairs. ^f5
- [method/interpret] (inferred) For champion seats one-hot, a shape function is a scalar
  per champion (our main effect) and a pair function a scalar per champion pair, so
  NB2M collapses to a factorised pair table, i.e. a factorisation machine; nothing new
  over the low-rank pair terms already in [[chen-avatar-embedding-2018]]. ^f6

## Read

- Abstract, 1, 3 (NBM, NB2M, sparse), 4 data setup.

## Not read

- Results tables, image experiments, RKHS basis count heuristic.
