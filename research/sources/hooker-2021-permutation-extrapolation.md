---
title: 'Hooker, Mentch, Zhou 2021: Unrestricted permutation forces extrapolation'
url: https://arxiv.org/pdf/1905.03151
kind: paper
commit: 
for: [correlated-importance]
looked: 2026-10-13
depth: docs (1-5, 7; section 6 skimmed)
relevance: high
grade: A/strong
description: Statistics and Computing 2021 (arXiv 1905.03151 v2); argues against permute-and-predict importance and PDPs under dependent features, shows why (extrapolation), compares conditional, drop-and-refit, permute-and-relearn and condition-and-relearn
---
# Hooker, Mentch, Zhou 2021: Unrestricted permutation forces extrapolation

Why: does plain permutation importance mislead when features are correlated (gold lead,
XP lead, towers, kills), and what should replace it?

## Assessment

- Evidence: A. Peer-reviewed (Statistics and Computing), widely cited; theorems for
  linear models plus simulations (random forests, neural nets, linear; 10 features, x1
  and x2 Gaussian copula, rho 0 to 0.9, N 100 to 5000, 20 to 100 repeats), a testing
  simulation and one real dataset (bike sharing).
- Reasoning: strong. Explains the mechanism (tree potential nearest neighbours off the
  data), states the cost of every alternative, cautions that relearning is not a
  complete fix either.
- Interests: authors proposed some of the alternatives (permute-and-relearn tests).
- Weigh: trust the direction (marginal permutation inflates correlated features for
  flexible models; refit or conditional measures shrink them). Simulations are small (N
  at most 5000, 10 features); with our 230k games the inflation shrinks for weak
  correlation but not for strong (their Figure 2). Theorems are exact only for linear
  models and squared error, not log loss.

## Findings

- [method] Permute-and-predict (Breiman permutation importance, PDP, ICE) can be highly
  misleading when features are dependent, and over-emphasises correlated features.
  Abstract ^f1
  > When features in the training set exhibit statistical dependence, permute-and-predict methods can be highly misleading when applied to the original model.
  > find support for previous claims in the literature that PaP metrics can vastly over-emphasize correlated features
- [method] Mechanism: permuting one of two correlated features creates rows with no
  training data nearby, so the score depends on how the model extrapolates there.
  Section 1 ^f2
  > the predictions made in the upper-left corner of (x1 , x2 ) space will mostly depend on the extrapolation behavior of the particular learning method employed
  > an evaluation of the importance of pregnancy status in a model that also includes gender would result in the evaluation of the response of pregnant men as often as pregnant women
- [method] [stats] Simulation: at rho 0.9, random forests and neural nets rank x1, x2
  above features with larger true coefficients; linear models keep the true order.
  Strong correlation keeps the bias as N grows. Section 3 ^f3
  > when ρ = 0.9, permutation-based methods applied to random forests and neural networks rank x1 and x2 as more important than (x3 , x4 , x5 ) and frequently more important than even x9 , which has a larger coefficient
  > for small ρ this effect is removed at larger N
- [method] Alternatives: conditional importance (resample x_j given the rest), dropped
  importance (LOCO, refit without x_j), permute-and-relearn, condition-and-relearn;
  each needs another model, either a refit or a model of x_j given the rest.
  Section 5 ^f4
  > These measures all necessarily entail additional computational costs: requiring training a new model, and/or estimating, and simulating from, the distribution of (xij |xi,−j ).
- [method] [stats] Under squared error all four target the same quantity, E(f(x) -
  f_-j(x_-j))^2 (Theorem 2); in simulation they agree on the ordering and shrink the
  importance of correlated features. Section 5 ^f5
  > these measures also all agree (to within Monte Carlo variability) on the ordering of covariate importance across all models
  > Unlike the permute-and-repredict measures, they reduce the importance of x1 and x2 when these become more correlated.
- [method] Compensation effect: refit and conditional measures give a feature only its
  unique share; two strongly correlated features each look weak. The reliable
  diagnostic is to remove or permute the pair jointly and refit: a joint importance not
  recoverable from single-feature scores. Section 5 ^f6
  > All of these methods exhibit the compensation effect; reducing the importance of correlated features relative to their coefficients.
  > the most reliable diagnostic that we know of for this is to examine the effect of jointly removing or permuting
- [method] [stats] Permute-and-relearn tests reject far above 5% for noise features
  correlated with real ones; substitutes from the true conditional or model-X knockoffs
  hold about 5%. Any test comparing models with features dropped or permuted shares
  the issue. Section 5.1 ^f7
  > the rejection rates of the “Permute-and-Relearn” approach lie well above that nominal level
  > any test of conditional independence evaluated by comparing model performance when a subset of features are dropped or permuted will suffer the same issue
- [method] Authors' gold standard: condition-and-relearn (conditional substitutes plus
  a refit). Section 1 ^f8
  > we therefore see a condition-and-relearn approach – in which we both replace the feature values under investigation with samples generated conditional on the remaining features and construct a new model – as essentially the gold standard for evaluating feature importance
- [method] Shapley values avoid nothing by default: computed carelessly they share the
  same extrapolation bias. Section 7 ^f9
  > Shapley values (Owen, 2014; Lundberg and Lee, 2017), although the calculation of these, if not undertaken carefully, can be subject to the same extrapolation bias that we identify here
- [method] (inferred) For us: plain permutation of gold lead in a GBDT that also sees XP
  lead, kills and towers scores rows like "+5k gold, -3 kills, behind on towers" that
  never happen at minute 15; per-feature scores from it are not usable. Group the
  correlated state features (the joint importance of ^f6) and refit or condition. ^f10
- [stats] (inferred) With ~230k games, the gap between drop-and-refit and conditional
  measures is about the unique share versus the shared share, not sampling noise: report
  the group (economy: gold, XP, kills, CS) and, within it, unique shares, and say which
  is which. ^f11

## Read

- Sections 1-5, 7: fully. Section 6 (PDP alternatives): skimmed.

## Not read

- Appendix proofs of Theorems 1-3; Mentch and Zhou 2020 (permuted feature improving
  low-signal fits).
