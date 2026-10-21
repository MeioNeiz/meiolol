---
title: 'Josephs, Upton 2024: Hypergraph adjusted plus-minus'
url: https://arxiv.org/pdf/2403.20214
kind: paper
commit: 
for: [frontier-interactions]
looked: 2026-10-21
depth: docs (abstract, 1-5.3)
relevance: medium
grade: C/fair
description: arXiv 2024-25 (NC State, Williams); ranks NBA players, pairs, trios and lineups by ridge regression on an extended design of all sub-lineups (HAPM) or a line-graph smoothness prior (LAPM); pair-interaction columns judged not tenable beyond pairs; checked only by rank correlations, no held-out test of trio effects
---
# Josephs, Upton 2024: Hypergraph adjusted plus-minus

Why: does any team-sport work measure 3-way (trio) effects beyond pairs, and how.

## Assessment

- Evidence: C. Statistics preprint (stat.ME), 10 NBA seasons; evaluation is rank
  correlation with raw plus-minus and year-over-year stability, not held-out
  prediction of trio effects.
- Reasoning: fair. Honest that explicit trio interaction columns don't scale; its trio
  "rankings" are additive predictions on sub-lineup rows, not trio effects.
- Interests: authors' method.
- Weigh: useful as the state of the art being thin; no evidence for 3-way synergy.

## Findings

- [method] [draft] Pairs adjusted plus-minus (PAPM): add one column per pair of
  teammates to the ridge plus-minus design, so pairs and players are fitted together.
  Section 3.1 ^f1
  > An intuitive and relatively straightforward approach to account for lower-order combinations in the current construction of APM is to add interaction terms as new columns in the design matrix.
- [stats] With pair columns the design is p >> n; regularisation makes it computable but
  explicit interaction terms beyond pairs are not tenable. Section 3.1 ^f2
  > Regularization techniques can be used to make the regression computationally possible but the results are not tenable for interaction terms composed of more than two players.
- [method] HAPM: the same ridge regression, but rows are every sub-lineup (players,
  pairs, trios, full lineups) with its own raw plus-minus, coefficients per player only;
  combinations are ranked by their predicted values. Section 4.2.1 ^f3
  > we have the predicted values ybHAPM that correspond to the combinations/rows. Therefore, we have a natural solution to rank combinations of any size.
- [stats] Validation was rank correlation year to year and between season halves against
  raw plus-minus, which the authors call problematic as a ground truth. Section 5.3 ^f4
  > this evaluation interprets PM as the ground truth, which is somewhat problematic given our starting argument is that PM is not a complete reflection of an individual player’s talent.
- [method] Checked, not there: no held-out log-likelihood or error comparison of models
  with and without trio terms, no planted effects, no variance share by order. ^f5
- [draft] (inferred) The best team-sport attempt at trios models them through additive
  player terms or graph smoothing, not as separate trio effects; with
  [[hok-team-composition-2019]] finding 3-5-way role terms add nothing, there is no
  measured 3-way effect in team games to aim at. ^f6

## Read

- Abstract, 1-3.1, 4.2, 5.3.

## Not read

- 4.2.2 LAPM prior details, 5.4 case study, appendix.
