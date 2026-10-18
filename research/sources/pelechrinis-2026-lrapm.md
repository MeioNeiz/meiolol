---
title: 'Pelechrinis and Petridis 2026: Lineup regularized adjusted plus-minus (L-RAPM), lineup ratings with informed priors'
url: https://arxiv.org/pdf/2601.15000
kind: paper
commit: 
for: [hierarchical-comp-terms]
looked: 2026-10-18
depth: docs (whole paper, 5 pages)
relevance: medium
grade: C/fair
description: arXiv 2026 (Pittsburgh, Temple); NBA lineup ratings by ridge shrunk towards the sum of the members' previous-season RAPM instead of 0; weekly expanding-window RMSE vs raw lineup ratings, gain largest for thin and unseen lineups
---
# Pelechrinis and Petridis 2026: L-RAPM

Why: a sports case of a coarse level (a lineup) shrunk towards what its finer parts
(players) predict, with gains by sample size; and the plain penalty form of a non-zero
shrinkage target.

## Assessment

- Evidence: C. Two authors (Pelechrinis is an established sports analytics academic),
  short arXiv paper, one test season, results in figures with few numbers.
- Reasoning: fair. Clear expanding-window evaluation and the sample-size breakdown;
  but the baseline is raw lineup ratings, not a ridge shrunk to 0 or to the
  league mean, so the prior's own contribution is not isolated.
- Interests: none.
- Weigh: trust the form (ridge towards pi) and the "gain shrinks with sample size"
  shape; not the size of the prior's part.

## Findings

- [method] [stats] Penalty form of a non-zero target: lambda * sum (beta_j - pi_j)^2,
  where pi_j is the lineup's prior from its members' player ratings, instead of
  lambda * sum beta_j^2. Section 3.2 ^f1
  > unlike with RAPM we are going to shrink the coefficients for the lineups not to 0, but to a different value, informed by the player ratings.
- [method] Prior = league points per possession + the sum of the five players'
  previous-season RAPM (separate offence and defence). Section 3.2 ^f2
  > πλa ,of f = league ppp + γ1,of f + γ2,of f + γ3,of f + γ4,of f + γ5,of f
- [stats] Sparse units: an NBA team uses 600+ lineups a season, about 25-30
  possessions each. Abstract ^f3
  > a National Basketball Association (NBA) team will use more than 600 lineups during a season, which translates to an average lineup having seen the court in approximately 25-30 possessions.
- [stats] Gain over raw lineup ratings grows as the lineup's sample shrinks; at
  several hundred possessions raw ratings do almost as well. Section 1, 4 ^f4
  > for lineups that have played several hundred possessions, using their raw offensive and defensive ratings does almost as good of a job at predicting points per possession as L-RAPM.
- [stats] For unseen lineups the prior alone beats the league-average fallback by about
  5% RMSE. Section 4 ^f5
  > L-RAPM consistently outpeforms the baseline, with a δL−RAPM ∼ 5%.
- [stats] One lambda for the lineup level (no variance estimate); the authors suggest
  separate offence and defence constants. Section 5 ^f6
  > we use a single regularization constant for both the offensive and defensive lineups.
- [stats] Checked, not there: a comparison with lineup ridge shrunk to 0 or to league
  average (which would isolate the informed prior), intervals, overall RMSE numbers.
  The paper also mentions ESPN RPM and 538 RAPTOR shrink players towards box-score
  priors, but these are proprietary and untested here. ^f7
  > other models (e.g., ESPN’s RPM, 538’s RAPTOR etc.) that have appeared since utilize a different prior value for each coefficient to shrink to based on a variety of other factors such as box score statistics
- [method] (inferred) The penalty form ^f1 is a one-line change to a ridge or Newton
  fit: penalise (slope - target) instead of slope, where target = role mean + group
  slopes for the cell's memberships. Re-estimating the targets between fits is the
  two-stage version of [[gelman-2006-multilevel-can-cant#^f3]]. ^f8
- [stats] (inferred) The critic's point for our test: compare the group-target fit
  with the same fit shrunk to the role mean (our shipped champcomp), not with raw
  slopes, or the gain is mostly shrinkage itself (^f7). ^f9

## Read

- Whole paper.

## Not read

- Nothing left.
