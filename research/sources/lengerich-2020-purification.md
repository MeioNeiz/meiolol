---
title: 'Lengerich, Tan, Chang, Hooker, Caruana 2020: Purifying interaction effects with the functional ANOVA'
url: https://arxiv.org/pdf/1911.04974
kind: paper
commit: 
for: [hierarchical-comp-terms, distil-explainable]
looked: 2026-10-18
depth: docs (abstract, 1-5.2)
relevance: high
grade: A/strong
description: AISTATS 2020 (CMU, Microsoft Research, Cornell); main and interaction terms are only identifiable once each interaction slice has weighted mean 0 (fANOVA); mass-moving algorithm, used in InterpretML/EBM; the weighting changes the answer
---
# Lengerich et al. 2020: Purifying interaction effects with the functional ANOVA

Why: our levels (role, kit group, champion) are the same slope at nested resolutions,
like a main effect and an interaction; what makes each part's number unique, so a
reason's share isn't an arbitrary split.

## Assessment

- Evidence: A. AISTATS 2020, Caruana and Hooker; the algorithm ships in InterpretML
  (EBM), widely used; proofs of convergence; three real datasets.
- Reasoning: strong. Shows the non-identifiability with exact examples, gives a
  unique definition, an algorithm, and the cost (the weight choice matters).
- Interests: authors' library (InterpretML).
- Weigh: trust the definition and the warning; their models are tree ensembles, ours
  is a penalised linear logit, but the identifiability argument is the same.

## Findings

- [method] [stats] Mains and interactions are not identifiable: mass can move between
  them with identical predictions, so contradictory readings describe one model.
  Abstract ^f1
  > effects can be freely moved between main effects and interaction effects without changing the model prediction.
- [method] Pure interaction: the variance no smaller subset of features can describe;
  equals the functional ANOVA decomposition. Abstract, Section 3 ^f2
  > we propose pure interaction effects: variance in the outcome which cannot be represented by any smaller subset of features.
- [method] [stats] Even centring is not enough with correlated inputs: x1 x2 terms
  move strength between mains depending on the chosen centres. Section 1.2 ^f3
  > This challenge of selecting α, β is not overcome by simply mean-centering all of the effects.
- [method] Condition: each effect tensor's every one-dimensional slice has mean zero
  under a weight w; for discrete features fANOVA under uniform w is effect coding.
  Section 3.2, 4.1 ^f4
  > if we represent each fu as a tensor of effect sizes, the fANOVA is recovered when every slice has mean zero with respect to a density w.
  > the use of effect coding exactly corresponds to the fANOVA representation under a uniform weight function.
- [method] Mass-moving: subtract each slice's weighted mean and add it to the
  lower-order term, highest order first, down to the intercept; predictions never
  change; converges in one pass for uniform weights, a few otherwise. Section 4.2 ^f5
  > we can move any value from Tu into Tu\i without changing the model predictions.
  > the mass-moving algorithm moves almost all of the mass in the first iteration.
- [stats] The weight choice (uniform, empirical, smoothed) changes the purified
  effects, sometimes a lot; the right one is the data distribution. Section 4.4 ^f6
  > the choice of distribution can change (sometimes dramatically) the purified effects.
- [stats] Two-stage fitting (mains first, as GA2M) leaves less mass to move but
  purification still changed GA2M's mains; unconstrained depth-2 boosting needed big
  changes, flipping signs on COMPAS. Section 5 ^f7
  > This two-stage training procedure reduces the mass that needs to be moved by purification
  > The magnitude – and occasionally the sign – of the effects are changed by the selection of data distribution.
- [method] Checked, not there: overlapping (multiple-membership) groups, shrinkage or
  priors, uncertainty of purified effects. ^f8
- [method] (inferred) For us: champion-role slope = role part + group part + own part
  is a nested additive model; naming each part needs the fANOVA rule: the own parts
  have game-weighted mean 0 within each group (and the group parts mean 0 within each
  role), weights = seat counts in the data (^f6: empirical w). Post hoc, after any
  fit, this is a weighted mass move that leaves every prediction unchanged, so the
  displayed shares can be made unique without refitting. ^f9
- [method] (inferred) With overlapping groups (Fiora in G1 and G5, Sivir in G3 and G6),
  slice-means don't nest; the analogue is a weighted projection: own parts orthogonal
  (by seat weight) to the membership columns and role indicators, i.e. the residual of
  a weighted regression of own parts on memberships; the fitted part moves to the
  group slopes. A shrunk fit with a group-level predictor
  ([[gelman-2006-multilevel-can-cant#^f9]]) satisfies this only approximately, so
  project after fitting before naming shares. ^f10

## Read

- Abstract, 1, 2, 3, 4 (algorithm, convergence statement, weight estimators), 5.1-5.2.

## Not read

- Proofs (Theorem 2), 5.3 MIMIC-II results, supplement.
