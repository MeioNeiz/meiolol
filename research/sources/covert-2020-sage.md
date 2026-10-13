---
title: 'Covert, Lundberg, Lee 2020: Understanding global feature contributions with additive importance measures (SAGE)'
url: https://arxiv.org/pdf/2004.00668
kind: paper
commit: 
for: [correlated-importance]
looked: 2026-10-13
depth: docs (1-5; supplements D, E, G skimmed)
relevance: high
grade: A/fair
description: NeurIPS 2020 (arXiv 2004.00668 v2); SAGE, the Shapley value of a model's loss reduction over feature subsets, as a global importance; unifies permutation, ablation and univariate methods as additive importance measures; sampling estimator with standard errors; package iancovert/sage
---
# Covert, Lundberg, Lee 2020: Understanding global feature contributions with additive importance measures (SAGE)

Why: a Shapley-style split of total predictive power (log-loss skill) across features or
groups that sums to the whole: "gold lead explains X of the model's skill at minute 15".

## Assessment

- Evidence: A. NeurIPS 2020, Lundberg (SHAP) co-author, widely used package; two
  convergence theorems; experiments on 5 datasets (XGBoost, CatBoost, logistic, MLP)
  against permutation, mean importance, ablation and univariate baselines.
- Reasoning: fair. Clear definitions and properties, and Supplement D admits that the
  practical estimator samples from the marginal, which drops the properties sold in the
  main text; the main-text evaluations do not test correlated features directly.
- Interests: authors' own method; baselines chosen by them.
- Weigh: trust the definition and the cost result (far cheaper than averaging local
  SHAP). Do not trust its correlated-feature behaviour as run by default: marginal
  sampling extrapolates like permutation (see [[hooker-2021-permutation-extrapolation]]).
  Gains over permutation in Table 2 are small on tabular data.

## Findings

- [method] Importance as predictive power: the restricted model f_S marginalises
  missing features over their conditional distribution, and v_f(S) is the drop in loss
  versus the mean prediction. Section 2.1 ^f1
  > so that missing features XS̄ are marginalized out using the conditional distribution p(XS̄ |XS = xs ).
- [method] Three families: drop one feature (permutation, conditional permutation, mean
  imputation, ablation), use one feature alone (univariate), or all subsets (SAGE).
  Ablation fails for correlated features; univariate misses complementary ones.
  Section 2.3 ^f2
  > two perfectly correlated features with significant predictive power would both be deemed unimportant by a feature ablation study, and two complementary features would have their importance underestimated by univariate models
- [method] SAGE = Shapley values of v_f: they sum to the model's total predictive power
  (efficiency), and perfectly correlated features get equal shares (symmetry), under
  the conditional formulation. Section 3.1 ^f3
  > Due to the efficiency property, SAGE values sum to X’s total predictive power.
  > pairs of features (Xi , Xj ) with a deterministic relationship (e.g., perfect correlation) always have equal importance
- [method] SAGE equals the average over the data of per-row SHAP values of the loss,
  but computing it that way needs 2-4 orders of magnitude more model evaluations than
  their sampler. Section 3.1, Supplement G ^f4
  > SAGE values are the expectation of per-instance SHAP values applied to the model loss
  > both approaches eventually converge to the correct values, but SHAP requires 2-4 orders of magnitude more model evaluations
- [method] The practical estimator samples missing features from the marginal, not the
  conditional, which moves it towards the model's mechanism and away from information
  value. Section 3.3 ^f5
  > We address the first challenge by sampling random subsets of features S ⊆ D, and the second by sampling XS̄ from its marginal distribution.
  > doing so alters some of SAGE’s properties to align less with the information value of each feature and more with the model’s mechanism
- [method] With marginal sampling, perfectly correlated features may not get equal
  shares, and a feature the model ignores gets zero even if a correlated one carries
  its information. Supplement D.2 ^f6
  > Unlike in the original formulation, perfectly correlated features may not receive equal importance.
  > the value φi (ṽf ) for a sensitive attribute Xi (e.g., race) may be zero even if the model depends on correlated features (e.g., zip code)
- [stats] The sampler's variance falls as 1/n, giving standard errors and a stopping
  rule; these are Monte Carlo intervals for fixed model and data, not sampling
  uncertainty over games. Section 3.3 ^f7
  > This quantity can be estimated while running the sampling algorithm and can then be used to provide confidence intervals on the estimated values.
- [method] [stats] Sum of importances vs loss of models retrained on feature subsets
  (correlation): SAGE best or near best, but permutation is close on tabular data (Bank
  0.9937 vs 0.9918, Bike 0.9815 vs 0.9798, Credit 0.9565 vs 0.9571); ablation collapses
  with many features (MNIST -0.4536). Table 2 ^f8
  > Feature Ablation fails for datasets with moderate numbers of features (BRCA and MNIST), but permutation tests and univariate predictors are both sometimes competitive.
- [method] (inferred) For us: SAGE over 5-7 feature groups at minute t gives a split of
  the model's log-loss skill that sums to the whole, which LOCO cannot (LOCO gives
  unique shares that sum to less). With groups, the correlated-within-group problem
  disappears; between-group correlation (gold vs towers) is still shared by Shapley
  averaging, and marginal sampling of one group while keeping the others still makes
  off-manifold rows. ^f9
- [method] (inferred) A universal-predictive-power version (refit a model per subset of
  groups) is affordable with 6 groups: 2^6 = 64 LightGBM fits per minute bucket, exact
  Shapley over groups with no sampling and no extrapolation; this is SAGE's v(S) rather
  than v_f(S). ^f10

## Read

- Sections 1-5, Supplement D (marginal sampling), E (theorem statements), G (cost).

## Not read

- Supplement A-C (mutual information and conditional variance links), H (datasets);
  the sage package docs (grouped imputers) not checked.
