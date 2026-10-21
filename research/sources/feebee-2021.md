---
title: 'Renggli et al. 2021: Evaluating Bayes error estimators on real-world datasets with FeeBee'
url: https://arxiv.org/abs/2108.13034
kind: paper
commit:
for: [frontier-ceiling]
looked: 2026-10-21
depth: docs (sections 1, 3, 4 results, conclusion)
relevance: medium
grade: A/fair
description: NeurIPS 2021 Datasets and Benchmarks paper; scores 7 Bayes error estimators (kNN, Cover-Hart 1NN bound, GHP divergence, KDE) on real data by injecting label noise
---
# Renggli et al. 2021: Evaluating Bayes error estimators on real-world datasets with FeeBee

Why: the brief names FeeBee; are kNN and divergence Bayes error estimators usable on
draft data?

## Assessment

- Evidence: A. NeurIPS Datasets and Benchmarks, ETH Zurich, open framework, 7
  estimators on 6 datasets.
- Reasoning: fair. Clear method; results are on vision and NLP with pretrained
  embeddings, far from near-coin-flip tabular data.
- Interests: none known.
- Weigh: trust the evaluation idea and the asymptotic caveat; the estimator ranking is
  for well-separated, embedded data.

## Findings

- [method/ceiling] Label-noise check: flipping a fraction rho of labels moves the
  Bayes error by a known linear amount, so an estimator can be scored on real data
  without knowing the truth. Lemma 3.1, Sec. 3 ^f1
  > injecting a controlled amount of label noise and performing multiple evaluations on a series of different noise levels
- [method/ceiling] The Cover-Hart 1NN rule gives a lower bound on the Bayes error from
  the 1NN error, but only as n goes to infinity. Sec. 4 ^f2
  > in the asymptotic regime, i.e. for n = ∞, Cover and Hart [5] proved that the RHS of Equation 2 serves as a lower bound of the BER.
- [method/ceiling] kNN bounds hold only asymptotically; extrapolating kNN convergence
  needs samples exponential in the input dimension. Sec. 4 ^f3
  > this requires the number of samples to be exponential in the input dimension
- [method/ceiling] Result: GHP (Henze-Penrose divergence) and 1NN are the best lower
  bound estimators; no estimator wins on both bounds. Conclusion ^f4
  > we observe that GHP and 1NN are consistently outperforming the other lower bound estimators
  > currently there does not exist an estimator that is able to simultaneously outperform other estimators on both lower and upper bound
- [method/ceiling] Estimators depend on the feature transformation (pretrained
  embeddings help 1NN and kNN). Sec. 5 ^f5
  > 1NN and kNN perform better on pre-trained embeddings
- [method/ceiling] (inferred) On drafts kNN bounds are unusable: every draft is nearly
  unique, a 1NN on 10 champion-role slots is far from asymptotic, and near 50% the
  binary 1NN error 2R(1-R) is about 0.495 even for a 54.8% Bayes classifier, so a
  finite-sample 1NN near 0.50 would "prove" a ceiling below what our model already
  reaches. ^f6

## Read

- Sections 1, 3 (method), 4 (estimators), result summary and conclusion.

## Not read

- Appendix tables per dataset and transformation.
