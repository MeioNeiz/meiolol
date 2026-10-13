---
title: 'Molnar, Koenig, Bischl, Casalicchio 2023: Model-agnostic feature importance and effects with dependent features, a conditional subgroup approach'
url: https://arxiv.org/pdf/2006.04628
kind: paper
commit: 
for: [correlated-importance]
looked: 2026-10-13
depth: docs (1, 3-4.2, 6-6.1, 8.1, 11)
relevance: high
grade: A/strong
description: Data Mining and Knowledge Discovery 2023 (arXiv 2006.04628 v2, LMU Munich); conditional permutation importance by permuting within subgroups from a tree that predicts the feature from the rest (cs-PFI), benchmarked against Strobl's CVIRF, model-X knockoffs and random-forest imputation on known ground truth
---
# Molnar, Koenig, Bischl, Casalicchio 2023: Model-agnostic feature importance and effects with dependent features, a conditional subgroup approach

Why: how to do conditional permutation importance in practice, what it means, and which
conditional sampler works when a feature depends on many others (gold lead on XP, kills,
CS, towers).

## Assessment

- Evidence: A. Peer-reviewed journal, Molnar (Interpretable Machine Learning book, iml
  package); ground-truth simulations repeated 1000 times over 4 dependence scenarios,
  n 300 and 3000, p 10 and 90; data fidelity benchmark on OpenML-CC18; code public.
- Reasoning: strong. States where their own method loses (many linear dependencies)
  and recommends a competitor there.
- Interests: authors' method; but they report its losses.
- Weigh: trust the interpretation section and the "it depends on the dependence
  structure" result. Sample sizes are far below ours; with 230k games the imputation
  approach (model x_j from x_-j) gets easier, not harder.

## Findings

- [method] Marginal permutation importance extrapolates to low-density regions when
  features are dependent; conditional sampling avoids it but changes what is measured.
  Section 1 ^f1
  > If features are dependent, such changes can lead to extrapolation to areas of the feature space with low density.
  > Extrapolation can be avoided by sampling a feature conditional on all other features and thereby preserving the joint distribution
- [method] Conditional PFI is the unique contribution of a feature given the others
  ("partial importance"); two strongly dependent features can both look unimportant,
  which means "less relevant given the other", not "irrelevant". Section 1 ^f2
  > The conditional PFI must be interpreted as the additional, unique contribution of a feature given all features we conditioned on
  > The correct conclusion would be that a feature is less relevant given knowledge of the dependent feature.
- [method] cs-PFI: fit a tree predicting x_j from x_-j on training data, then permute
  x_j only within each leaf on test data; the leaves are readable subgroups and give
  local importances. Section 4.2, Algorithm 1 ^f3
  > Train a decision tree to predict the feature of interest and compute the (marginal) PFI / PDP in each terminal node defined by the decision tree.
- [method] [stats] Ground truth MSE (true model, Table 2): marginal PFI is far off in
  the linear scenario (n=3000, p=10: 37.40 vs cs-PFI 0.26-0.40); in the non-linear
  scenario cs-PFI wins (1.00-1.18 vs knockoffs 626.80, imputation 144.77); with many
  linear dependencies imputation by random forest wins (140.98 vs cs-PFI 900.68-1031.83).
  Section 6.1, Table 2 ^f4
  > The multiple linear dependencies scenario was the only scenario in which the cs-PFI approach was consistently outperformed by the other methods.
  > Imputation with random forest worked well when multiple linear dependencies are present.
- [method] [stats] Strobl's conditional importance for random forests (CVIRF)
  underestimated conditional PFI at the larger sample size, even with independent
  features. Section 6.1 ^f5
  > The CVIRF approach consistently underestimated the conditional PFI in all scenarios with high n, even in the independent scenario.
- [method] Knockoffs assume multivariate Gaussian features, too restrictive on real
  data; cs-permutation had the best data fidelity. Section 8.1 ^f6
  > Knockoffs were proposed to preserve the joint distribution, but are based on multivariate Gaussian distribution. This seems to be too restrictive for the data sets in our experiments.
- [method] Recommendation: look at the dependence structure first; impute (model x_j
  from the rest) when x_j depends on many features, cs-PFI otherwise. Section 11 ^f7
  > We recommend analyzing the dependence structure beforehand, using the imputation approach with random forests in the case of multiple dependencies, and cs-PFIs in all other cases.
- [method] (inferred) For us: gold lead at minute t depends on many features at once (XP
  lead, kills, CS, towers, dragons), the multiple-dependency case, so subgroup
  permutation is the wrong sampler for it; residual resampling from a model of gold
  given the rest would be the conditional route. But conditional single-feature scores
  will be small for every economy feature by construction (^f2); for "how much the
  economy matters" use groups instead. ^f8
- [method] (inferred) cs-PFI's leaves are useful for discrete objective counts
  (dragons, barons, inhibitors) given a few context features: "barons matter given the
  gold lead bucket" is the kind of readable conditional statement it gives. ^f9

## Read

- Introduction, related work on conditional PFI, method (4-4.2), ground truth
  simulation and results (6, 6.1), data fidelity results (8.1), discussion.

## Not read

- cs-PDP (4.3), tree depth trade-off (7), model fidelity (9), bike application (10),
  appendices.
