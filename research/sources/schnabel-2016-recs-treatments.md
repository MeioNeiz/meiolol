---
title: 'Recommendations as Treatments: Debiasing Learning and Evaluation (Schnabel, Swaminathan, Singh, Chandak, Joachims; ICML 2016)'
url: https://arxiv.org/pdf/1602.05352v2
kind: paper
commit:
for: [frontier-causal]
looked: 2026-10-21
depth: docs (abstract, sections 1, 3.3, 5, 6.4)
relevance: high
grade: A/strong
description: Classic paper treating a recommendation as an intervention: inverse-propensity (IPS, SNIPS) estimators make evaluation and training unbiased under self-selected observations; estimated propensities suffice
---
# Recommendations as Treatments (Schnabel et al. 2016)

Why: a pick recommender is judged on games where players chose their own champion; how
do we evaluate "what if they had followed our pick" from self-selected data?

## Assessment

- Evidence: A. ICML 2016, widely cited and the basis of later off-policy recommender
  work; semi-synthetic (ML100K) and real (Yahoo! R3, Coat) experiments.
- Reasoning: strong; bias and variance of each estimator derived, robustness tested.
- Interests: none.
- Weigh: ratings setting, not win outcomes, but the estimator carries over directly to
  "win when the player picked what we would have recommended".

## Findings

- [method/causal] Recommender data is selected by users' own choices, so it is missing
  not at random; showing an item is an intervention like a treatment. ^f1
  > Virtually all data for training recommender systems is subject to selection biases.
  > exposing a user to an item in a recommendation system is an intervention analogous to exposing a patient to a treatment in a medical study
- [method/causal] [stats] Weighting each observed outcome by the inverse of its
  probability of being observed (IPS) is unbiased for any probabilistic assignment;
  the self-normalised version (SNIPS) has lower variance at a small bias. ^f2
  > the IPS estimator is unbiased for any probabilistic assignment mechanism
  > The SNIPS estimator often has lower variance than the IPS estimator but has a small bias
- [method/causal] Propensities need not be perfect, only better than uniform; estimated
  ones (naive Bayes, logistic regression) never did worse than the naive estimator. ^f3
  > we merely need estimated propensities that are “better” than the naive assumption of observations being revealed uniformly
  > Under no condition do the IPS and SNIPS estimator perform worse than Naive.
- [method/causal] (inferred) For meiolol's replay eval (does the lane card's top option
  win more?): the champion a player picked is the "observed item"; a pick model gives
  each seat P(champion | draft so far, player's pool), and the value of a policy "pick
  our top option" is the IPS or doubly robust average of wins over seats where the
  player happened to pick it, weighted by 1/P. Only champions with real pick chance
  (the player's pool) have overlap, which matches the app's pool-ranking use case. ^f4

## Read

- Abstract, introduction, 3.3 (IPS, SNIPS), 5 (propensity estimation), 6.4 (robustness).

## Not read

- MF-IPS learning bounds (section 4); Coat dataset details.
