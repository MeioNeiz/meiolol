---
title: 'Williamson, Gilbert, Simon, Carone 2023: A general framework for inference on algorithm-agnostic variable importance'
url: https://arxiv.org/pdf/2004.03683
kind: paper
commit: 
for: [correlated-importance]
looked: 2026-10-13
depth: docs (1-3, 5, 7; examples 1-2; supplement not read)
relevance: high
grade: A/strong
description: JASA 2023 (arXiv 2004.03683 v2); drop-and-refit importance (LOCO-style) as a population parameter, oracle predictiveness with all features minus without a group, any measure (R2, deviance, AUC, accuracy), efficient plug-in estimator, cross-fitting, Wald intervals and a sample-split test of zero importance; R package vimp
---
# Williamson, Gilbert, Simon, Carone 2023: A general framework for inference on algorithm-agnostic variable importance

Why: how to put valid confidence intervals on "how much does a group of features add",
with flexible learners (GBDT), for a binary outcome (win).

## Assessment

- Evidence: A. JASA, Fred Hutch and University of Washington biostatistics; theorems
  (asymptotic linearity, efficiency), simulations of coverage and type I error across
  GAM, GLM, random forest and Super Learner, an HIV antibody application with 13
  feature groups; maintained R package vimp (Python port vimpy).
- Reasoning: strong. Separates the population target from any algorithm, states when
  cross-fitting and sample-splitting are needed, admits the correlated-feature problem
  and the power cost of sample-splitting.
- Interests: none beyond promoting their framework.
- Weigh: trust the inference recipe. It assumes independent observations: our rows are
  per game, so at a fixed minute one row per game is independent; pooling minutes
  needs a game-clustered version (not in the paper). The estimand is intrinsic
  (oracle) importance, so a weak learner understates it.

## Findings

- [method] [stats] Importance of a group X_s = oracle predictiveness with all features
  minus oracle predictiveness without X_s (drop-and-refit), defined for the data, not
  for one fitted model. Section 2.2 ^f1
  > We define the population-level importance of the variable (or subgroup of variables) Xs relative to the full covariate vector X as the amount of oracle predictiveness lost by excluding Xs from X.
- [method] Predictiveness can be deviance for a binary outcome: the information gain
  over the base rate in a Kullback-Leibler sense, so importance is the drop in log-loss
  skill. Example 2 ^f2
  > This measure quantifies in a Kullback-Leibler sense the information gain from using X to predict Y relative to the null model that does not use X at all.
- [method] Groups are as easy as single features. Section 1 ^f3
  > It can be used to describe the importance of groups of variables as easily as individual variables.
- [stats] The plug-in estimator (difference of held-out predictiveness of the two fits)
  needs no debiasing for a large class of measures, so intervals come from influence
  functions. Section 3.1 ^f4
  > Williamson et al. (2020) noted the intriguing fact that the plug-in estimator of the R2 VIM did not require debiasing, being itself already efficient. Below, we show that the same holds true for a large class of VIMs.
- [stats] Cross-fitting (K folds, fit on K-1, evaluate on the held-out fold) is critical
  with flexible learners; without it coverage fails. Section 5 ^f5
  > Our findings suggest that cross-fitting is critical when flexible algorithms are used
  > case the estimation procedure without cross-fitting performs poorly while its cross-fitted counterpart instead shows good performance
- [stats] At zero importance the estimator is degenerate; a valid test needs
  sample-splitting (full and reduced fits evaluated on different halves), at a cost in
  power. A beta-null (importance at most beta) tests for meaningful size, since tiny
  effects become significant in large samples. Section 3.4 ^f6
  > Sample-splitting is used to ensure valid inference under the zero-importance null hypothesis, whereas cross-fitting is used to eliminate the need for Donsker class conditions
  > a group of variables may be considered scientifically unimportant even when ψ0,s is nonzero but small, yet such grouping would be deemed statistically significant in large enough samples
- [method] Correlated features: the authors recommend grouping features expected to be
  highly correlated (from domain knowledge) or a causal model; alternatives are
  marginal importance (each feature alone vs nothing) or Shapley population VIM, at
  much higher cost. Section 7 ^f7
  > we recommend making use of any available background scientific knowledge either to group variables that are expected to be highly correlated or to develop an appropriate causal model
  > use of this approach comes at the cost of significantly increased complexity
- [stats] Correlated null features did not worsen bias or coverage beyond what extra
  dimensions do; both fade with sample size. Section 5.3 ^f8
  > A similar pattern was seen in the presence of correlated null features.
- [stats] A bootstrap that keeps the fitted functions fixed gave similar intervals to
  the influence-function ones. Section 7 ^f9
  > a nonparametric bootstrap scheme could be used in which f0 and f0,s are not re-estimated over bootstrap samples but rather fixed at their original estimates
- [stats] Assumes independent observations. Section 2.1 ^f10
  > Suppose that observations Z1 , . . . , Zn are drawn independently from a data-generating distribution P0
- [stats] (inferred) For us: fit per minute t (or per minute bucket) one row per game, so
  the iid assumption holds and the influence-function interval is already clustered by
  game. If minutes are pooled into one model, the per-row influence values must be
  summed within a game before taking the variance (cluster-robust), or bootstrap games
  with fitted models held fixed (^f9). ^f11
- [method] (inferred) Drop-and-refit for 5-7 groups (economy, objectives, towers,
  vision, draft prior, levels) at 5 folds is ~35 GBDT fits per minute bucket; cheap on
  the gpu-box with LightGBM at 230k rows. ^f12

## Read

- Sections 1-3 (definitions, plug-in, cross-fitting, null testing), 5 (simulations,
  main text), 7 (discussion).

## Not read

- Section 4 (complex predictiveness, counterfactual outcomes), supplement (per-example
  estimators, extra simulations, bootstrap), Section 6 detail.
