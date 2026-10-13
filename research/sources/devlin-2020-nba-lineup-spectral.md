---
title: 'Devlin, Uminsky 2020: Identifying group contributions in NBA lineups with spectral analysis'
url: https://arxiv.org/pdf/2006.14188
kind: paper
commit:
for: [effect-isolation]
looked: 2026-10-13
depth: docs (abstract, intro, method overview, regression comparison, stability, effect-space importance)
relevance: medium
grade: C/fair
description: arXiv 2020 (USF); orthogonal decomposition of a team's lineup plus-minus into individual, pair, triple, four and five-player parts (ANOVA on lineups), with a permutation null for how much mass each order carries
---
# Devlin, Uminsky 2020: spectral analysis of NBA lineups

Why: a measure of how much of the outcome signal sits in pair terms versus main effects,
with a null to compare against.

## Assessment

- Evidence: C. arXiv preprint, one NBA season (2015-16), a handful of teams, 15-man
  rosters; descriptive, no out-of-sample test.
- Reasoning: fair. Explains orthogonality versus ridge interaction regression and adds
  a permutation null; admits sensitivity to noisy low-possession lineups.
- Interests: none (authors' method).
- Weigh: trust the design lesson (compare each order's share against a permuted null);
  the numbers come from raw plus-minus on tiny samples.

## Findings

- [method] [stats] Team success as a function on lineups splits orthogonally into
  first (individual), second (pair) up to fifth-order parts; ANOVA is a special case. ^f1
  > our analysis decomposes the team success signal into components that are naturally understood as the contributions of player groups of a given size: individuals, pairs, triples, fours, and full five-player lineups
- [stats] Orthogonality means a pair's part excludes what its members do alone; a
  ridge regression with interaction terms does not separate the orders this cleanly. ^f2
  > the contribution of a group of, for example, 5 players is not necessarily separate from a constituent group of four (or any other number of) players despite the use of shrinkage methods
- [method] [stats] Raw shares are misleading because higher-order spaces have more
  dimensions; they compare against the shares after randomly permuting lineup values. ^f3
  > We then take f and randomly permute the values so that there is no connection between the lineup and the value associated with that lineup.
- [stats] [draft] Pair-space share of squared mass across seven teams: 0.027 to 0.092,
  against a permuted null of 0.030; individual space 0.004 to 0.031 vs 0.005. Pairs
  and individuals sit near or modestly above noise in one season of lineup data.
  Table 13 (column layout in raw, no clean quote) ^f4
- [stats] Better teams carry more mass in first to third order: correlation with win
  percentage 0.51, 0.58, 0.55. ^f5
  > we compute correlations of r = 0.51, r = 0.58 and r = 0.55, respectively, between win-percentage and the projected mass f in the first, second, and third-order spaces
- [stats] Uncertainty by bootstrap over plays (500 resampled seasons): a triple's
  plus-minus SD was 82.8 around a mean of 145.9, so group values are noisy even at
  2,500 possessions. ^f6
  > the standard deviation of the plus-minus values is 82.8 versus only 47.7 for possessions
- [stats] Checked, not there: no shrinkage of spectral parts, no held-out test, no
  opponent adjustment (contributions are aggregated over all opponents). ^f7
  > In particular, note that we model group contributions aggregated over all opponents
- [stats] [method] (inferred) The permutation null is cheap and transfers directly:
  fit our pair block (ally role pairs, enemy role pairs) on real data and on data with
  outcomes shuffled within patch, and compare the pair-block share of explained log
  loss (or the fitted pair variance) with the shuffled one. That is the variance-share
  test for "do pairs carry signal beyond noise at 230k games". ^f8
- [draft] (inferred) Bootstrap over games gives intervals for any pair estimator we
  pick (ridge, FM), at refit cost per resample; cheaper than MCMC. ^f9

## Read

- Abstract, introduction, sections on data, regression comparison, stability and
  importance of effect spaces, conclusion.

## Not read

- Representation theory details (section 3), per-team tables of named groups.
