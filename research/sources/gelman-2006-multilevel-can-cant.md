---
title: 'Gelman 2006: Multilevel (hierarchical) modeling, what it can and cannot do'
url: http://www.stat.columbia.edu/~gelman/research/published/multi2.pdf
kind: paper
commit: 
for: [hierarchical-comp-terms]
looked: 2026-10-18
depth: docs (whole paper, 4 pages)
relevance: high
grade: A/fair
description: Technometrics 2006 short paper; radon in 85 Minnesota counties, county intercepts shrunk towards a regression on a county-level predictor (uranium), cross-validated against no and complete pooling
---
# Gelman 2006: Multilevel (hierarchical) modeling, what it can and cannot do

Why: the canonical statement of a group-level predictor in the shrinkage target (shrink
a unit's coefficient towards what its attributes predict, not towards 0), with a
held-out comparison, and the warning about correlated unit errors.

## Assessment

- Evidence: A. Technometrics, by the field's best-known applied Bayesian; the radon
  model is the textbook example (Gelman and Hill ch. 12). One dataset, 919 houses.
- Reasoning: fair. Short; shows the model, two cross-validations and a causal caveat;
  no varying slopes, no crossed or multiple-membership groups.
- Interests: none (promotes multilevel modelling in general).
- Weigh: trust the structure and the direction of the CV gains; the sizes are for one
  small linear dataset with a strong group predictor.

## Findings

- [stats] [method] Multilevel model: the coefficients get a model of their own whose
  parameters are estimated from the data. Abstract ^f1
  > regression coefficients are themselves given a model, whose parameters are also estimated from data.
- [stats] [method] County intercept alpha_j ~ N(gamma0 + gamma1 u_j, sigma_alpha^2):
  shrunk towards a regression on the county-level predictor u_j (uranium), and
  sigma_alpha is the spread left beyond what u_j explains. Section 2.1 ^f2
  > beyond what is explained by the county-level uranium predic-
- [stats] The two-step version (fit units unpooled, then regress their estimates on
  group predictors) is possible; the multilevel fit does both levels at once and
  counts each unit's estimation uncertainty. Section 2.2 ^f3
  > first fitting the no-pooling model to estimate the αj ’s and then
  > fitting county-level regression to the α̂j ’s. The multilevel model
- [stats] Held-out (leave one house out) RMSE: complete pooling 0.84, no pooling 0.86,
  multilevel with the county predictor 0.79. Section 2.3 ^f4
  > are .84 for complete pooling, .86 for no pooling, and .79 for
- [stats] Leave one county out (a new unit, predicted from its group predictor only):
  0.50 complete pooling vs 0.40 multilevel; the gain is largest for unit averages and
  unseen units. Section 2.3 ^f5
  > dictive errors at the county level are .50 for complete pooling
  > The multilevel model gives more accurate predictions than
- [stats] The model assumes unit errors are independent of the row-level predictor; if
  not, add the unit's mean of that predictor to the group-level regression. Section
  2.4 ^f6
  > low for possible correlation by including x̄j , the average of x
- [stats] Group-level coefficients (contextual effects) are predictive, not causal:
  easy to misread with observational data. Section 2.4, 3 ^f7
  > ability to separately estimate the predictive effects of an indi-
- [stats] Checked, not there: varying slopes, several or overlapping group predictors,
  logistic outcomes, fitting at scale (85 groups, full Bayes). ^f8
- [method] (inferred) Our kit-group slope maps to gamma: a champion-role's slope on an
  enemy trait ~ N(role mean + sum over its groups of gamma_g, tau^2). The champion's
  own part is then its deviation from what role and groups predict, so the group part
  and the champion part don't overlap by construction, and tau^2 measures what is left
  after the groups. Membership is a 0/1 group-level predictor; several groups just add. ^f9
- [stats] (inferred) ^f5 says where to look for the gain: thin and new champion-roles
  (leave-one-champion-out), not the per-game log loss averaged over all seats, where a
  0.84 to 0.79 type gain shrinks to whatever share of seats the thin cells hold. ^f10

## Read

- Whole paper (Technometrics 48(3), 432-435).

## Not read

- Gelman and Hill 2007 ch. 12-13 (varying slopes with group predictors; book, no open
  copy fetched); Price, Nero and Gelman 1996 (the fuller radon CV).
