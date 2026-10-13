---
title: 'Chen, Janizek, Lundberg, Lee 2020: True to the model or true to the data?'
url: https://arxiv.org/pdf/2006.16234
kind: paper
commit: 
for: [correlated-importance]
looked: 2026-10-13
depth: docs (all, 5 pages)
relevance: high
grade: B/fair
description: arXiv 2006.16234 (2020 short paper, Lundberg and Lee group); interventional vs observational Shapley values, argued to answer different questions (explain the model vs explain the data), exact observational Shapley for linear models, NHANES, LendingClub and RNA-seq examples
---
# Chen, Janizek, Lundberg, Lee 2020: True to the model or true to the data?

Why: which SHAP flavour (interventional, as TreeSHAP and KernelSHAP with background
data compute, or observational) answers "how much does gold lead matter" when gold
correlates with XP, kills and towers?

## Assessment

- Evidence: B. Short paper from the SHAP authors' group; linear models only, one small
  simulation (3 features), three real-data illustrations, no intervals.
- Reasoning: fair. Clear framing of the choice, honest that it is application
  dependent; evidence is illustrative, not systematic, and nonlinear models are out of
  scope.
- Interests: authors maintain shap; the framing defends Shapley values against Kumar et
  al. 2020 ([[kumar-2020-shapley-problems]]).
- Weigh: trust the framing (the two value functions answer different questions) and the
  linear results. The 6-hour cost is for exact Gaussian observational values with 1000
  features, not typical.

## Findings

- [method] Two value functions: observational v(S) = E[f(X) | X_S = x_S] and
  interventional v(S) = E[f(X) | do(X_S)], which breaks dependence between features in
  S and the rest. Section 1.1 ^f1
  > where we “intervene” on the features by breaking the dependence between features in S and the remaining features
- [method] Known problems: observational values credit features the model never uses
  (fails the Dummy axiom); interventional values evaluate the model off the data
  manifold. Section 1.2 ^f2
  > the observational Shapley value can attribute importance to irrelevant features – features which were not used by the model
  > will lead to evaluating the model on “impossible data points” that lie off the true data manifold
- [method] The choice is about the question asked: explain this model, or explain the
  data. Section 1.2 ^f3
  > we argue that this choice depends on whether you want attributions that reflect the behavior of a particular model, or attributions that reflect the correlations in the data
- [method] For a linear model the interventional Shapley value is beta_i (x_i - mu_i),
  regardless of correlation. Section 2.1 ^f4
  > φi (f, x) = βi (xi − µi )
- [method] [stats] Observational values split a coefficient's credit between correlated
  features, and higher correlation slows their convergence. Section 3.1 ^f5
  > correlation splits the β as credit between correlated variables and 2.) higher levels of correlation leads to slower convergence of the observational Shapley value estimates
- [method] Observational values give importance to a feature left out of the model
  (BMI) through its correlation with included ones, and shrink the others. Section 3.2 ^f6
  > even though BMI is not included in the model, the correlation between BMI and other features makes BMI important under observational Shapley values
- [method] True to the data: on simulated drug response from real gene expression (40
  causal of 1000), observational Shapley on a Lasso found more true features than
  interventional; interventional on an Elastic Net (which spreads credit itself) did as
  well and was far cheaper (seconds vs 6 hours). Sections 4.2, 5 ^f7
  > ranking the features according to the observational Shapley values recovers more of the true causal features at each position in the ranked list than the interventional Shapley values
  > Estimating the transform matrices for the observational conditional with 1000 samples took 6 hours using the CPUs on a 2018 MacBook Pro
- [method] Authors' default: true to the model for most explainable AI uses. Section 4.1 ^f8
  > Being true to the model is the best choice for most applications of explainable AI, where the goal is to explain the model itself.
- [method] (inferred) For us the question "how much does each thing matter to winning at
  minute t" is about the game, not about one GBDT, so it is a true-to-the-data question:
  interventional TreeSHAP on a GBDT will hand gold lead's credit to whichever of gold,
  XP or kills the trees happened to split on. Either sum SHAP within groups of
  correlated features, or use a data-level measure (refit, conditional). ^f9

## Read

- Whole paper (5 pages).

## Not read

- Supplementary derivations of the linear observational algorithm (shap LinearExplainer
  correlation_dependent mode).
