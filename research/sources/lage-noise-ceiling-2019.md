---
title: 'Lage-Castellanos et al. 2019: Methods for computing the maximum performance of computational models of fMRI responses'
url: https://pmc.ncbi.nlm.nih.gov/articles/PMC6426260/
kind: paper
commit:
for: [frontier-ceiling]
looked: 2026-10-21
depth: docs (abstract, methods: noise ceiling definitions)
relevance: medium
grade: B/strong
description: PLoS Comput Biol 2019; compares split-half (Spearman-Brown), Monte Carlo and an analytical noise ceiling = sqrt((observed variance - mean noise variance) / observed variance)
---
# Lage-Castellanos et al. 2019: Methods for computing the maximum performance of computational models of fMRI responses

Why: neuroscience's noise ceiling is the same problem (best achievable fit given
measurement noise) with three estimators; which transfers to win rates?

## Assessment

- Evidence: B. Peer reviewed, simulation-validated, one group; noise ceilings are
  standard practice in computational neuroscience.
- Reasoning: strong. Derives the analytical form and shows it equals Monte Carlo.
- Interests: none known.
- Weigh: the variance algebra is general; normal noise assumed, fine for win rates
  over many games, not for thin cells.

## Findings

- [method/ceiling] The noise ceiling bounds any model's accuracy by the share of
  response variance that is not measurement noise. Abstract ^f1
  > the prediction accuracy is bounded by the proportion of the variance of the brain response which is related to the measurement noise and not to the stimuli
- [method/ceiling] [stats] Split-half: correlate two independent estimates of the same
  items, then Spearman-Brown 2r / (1 + r); non-parametric, catches every noise source,
  set to zero when the split correlation is negative. Methods ^f2
  > The split-half noise ceiling is a non-parametric procedure since it does not rely on the estimation of the β ^ variances.
- [method/ceiling] [stats] Analytical: true-signal variance = observed variance between
  items minus mean within-item noise variance; ceiling correlation = sqrt(true /
  observed). Equals the Monte Carlo estimate without simulation. Methods ^f3
  > the noise ceiling can be expressed as the square root of the ratio between the variance of the true brain response ( σ ^ β 2 ) and the variance of estimated brain response
  > the analytical solution results in the same estimate of the noise ceiling as the Monte Carlo method.
- [method/ceiling] The basic ceiling is model-free: the performance of the true model
  with infinite training data. Methods ^f4
  > This definition of the noise ceiling is a function of the variability of the test data, is by construction independent of the computational model
- [method/ceiling] (inferred) For us: split-half reliability of per-cell win rates
  (champion-role, role pair after additive terms) from two random halves of games, with
  Spearman-Brown, gives the share of each table's spread that is real; it is the same
  number as Tango's excess variance ([[gelman-luck-skill#^f1]]) but needs no binomial
  formula, so it also covers overdispersion from players and patches. ^f5

## Read

- Abstract, introduction, methods (noise ceiling definitions and estimators).

## Not read

- Results on simulated and real fMRI, regularisation section.
