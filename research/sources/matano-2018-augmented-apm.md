---
title: 'Matano et al. 2018: Augmenting adjusted plus-minus in soccer with FIFA ratings'
url: https://arxiv.org/pdf/1810.08032
kind: paper
commit: 
for: [hierarchical-comp-terms]
looked: 2026-10-18
depth: docs (whole paper, 6 pages)
relevance: medium
grade: C/fair
description: CMU student paper (arXiv 2018); EPL plus-minus ridge recast as Bayes with each player's prior centred on a scaled FIFA rating; 10-fold CV MSE over three seasons beats plain APM and FIFA only
---
# Matano et al. 2018: Augmenting adjusted plus-minus in soccer with FIFA ratings

Why: the plus-minus case of "shrink towards what an attribute predicts" (the paper
[[hvattum-2019-plusminus-review#^f10]] cites), and whether it beats both parts.

## Assessment

- Evidence: C. Five CMU students, arXiv only, 6 pages; three EPL seasons; results
  only in figures (no numbers in text), no intervals; tau and sigma fixed by hand.
- Reasoning: fair. Clear model and baselines; honest that APM beat FIFA alone in two
  seasons; no ablation of the prior strength.
- Interests: none.
- Weigh: trust the model form and the direction; the size is unknown (figures only).

## Findings

- [stats] [method] Ridge APM is the MAP of beta ~ N(0, tau^2): every player shrunk
  towards the average player. Section 2 ^f1
  > One problem with the traditional ridge penalty for players is that it assumes all players should be regularized towards zero
- [method] Augmented APM: beta | alpha ~ N(alpha x rating, tau^2), alpha ~ N(mu,
  sigma^2): the prior mean is a fitted multiple of the centred FIFA rating, so beta
  is still relative to the average-rated player. Section 2 ^f2
  > the “prior” for player ratings is no longer zeroed, and is instead centered at a scaled value of their subjective ratings score.
- [stats] Collinear players (always on together) are split by the attribute: ridge
  gives both the same credit, the attribute prior gives the higher-rated one more.
  Section 2, 4 ^f3
  > While under a ridge regression model both players would receive the same attribution of credit for game results, the Augmented APM model gives the higher subjectively rated player a greater share of the credit.
- [stats] 10-fold CV MSE of game results, three EPL seasons: Augmented APM best;
  FIFA-only beats intercept; plain APM beat FIFA-only in 2015 and 2017. Section 4 ^f4
  > mented APM model has the best predictive accuracy.
  > standard APM out-predicts the FIFA only model in 2015 and 2017
- [stats] By time in season: the attribute model predicts best early (little
  data), APM catches up by February; the prior matters most when ids are thin.
  Section 4 ^f5
  > FIFA starts the season as the best predictor, and both APM and Augmented APM out-predict FIFA by February.
- [stats] Checked, not there: numeric gains, intervals, a fitted tau (set to 0.1 by
  hand), several attributes or groups at once. ^f6
- [stats] (inferred) Same direction as [[agarwal-chen-2009-rlfm#^f8]]: the attribute
  prior's gain is front-loaded where the id data is thin. For champions, a new patch
  or a rarely played champion-role is the "early season". ^f7
- [method] (inferred) ^f3 is the double-counting mechanism in reverse: with a group
  prior, two collinear explanations (a kit group and its members' own slopes) are not
  split arbitrarily; the group gets what the members share, each member only its
  deviation. ^f8

## Read

- Whole paper.

## Not read

- Their R packages (PlusMinusModels, apm), the online tables.
