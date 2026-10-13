---
title: 'Bransen, Van Haaren 2020: Player chemistry, striving for a perfectly balanced soccer team'
url: https://arxiv.org/pdf/2003.01712
kind: paper
commit:
for: [effect-isolation]
looked: 2026-10-13
depth: docs (sections 1-4, start of 5)
relevance: medium
grade: B/fair
description: Sloan 2020 (Other Sports track winner); pair chemistry in football as joint VAEP of a pair's on-ball interactions (offence) and opponents' under-expectation (defence), plus CatBoost to predict it for unseen pairs from player features
---
# Bransen, Van Haaren 2020: Player chemistry in football

Why: the football pair-chemistry reference; how does it define and predict a pair value,
and does it separate pair chemistry from the two players' own quality?

## Assessment

- Evidence: B. Sloan 2020 track winner from SciSports (industry), 106k matches, a time
  split for the predictive part. Proprietary features and data.
- Reasoning: fair. Clear definitions, but the metric is joint impact, not impact beyond
  the sum of the parts, and the defensive model barely beats the mean.
- Interests: vendor (SciSports sells recruitment analytics).
- Weigh: useful for the predictive design (pair features, time split, min exposure
  threshold); not as an estimate of true synergy size.

## Findings

- [data] Data: Wyscout events, 106 competitions, 361 seasons, 106,496 matches, 38,447
  players. ^f1
  > Our extensive dataset covers 361 seasons, 106,496 matches, 2,154 teams and 38,447 players from 106 domestic and international competitions across the world.
- [method] Offensive chemistry (JOI) is the summed VAEP of consecutive two-action
  interactions between the two players, per 90 minutes together. ^f2
  > We compute the joint offensive impact for a pair of players in a match by summing the VAEP ratings for their interactions in that match
- [method] [stats] Defensive chemistry (JDI) credits opponents' offensive impact below
  their expectation to the pair, weighted by a positional responsibility share. ^f3
  > the rationale behind our JDI metric is that when an opponent underperforms their expected offensive impact, then the pairs of players that are responsible for defending this opponent likely have done well
- [stats] Shrinkage is ad hoc: under 700 minutes, the expected impact is a linear blend
  of a position prior and the player's own average. ^f4
  > We compute a weighted average between a position-specific prior and the earlier computed expected offensive impact, where the weights are linearly proportional to the share of the required 700 minutes the player has played.
- [method] [stats] Unseen pairs: CatBoost regressors on pair features (roles, physique,
  shared nationality and language, matches together), trained 2015-17, validated
  2017/18, tested 2018-19; only pairs with 700+ minutes together. ^f5
  > Our training set covers the 2015/2016 through 2016/2017 seasons, our validation set covers the 2017/2018 season and our test set covers the 2018/2019 and 2019/2020 seasons
- [stats] Held-out gain is small offensively and near nil defensively: RMSE 0.0446 vs
  0.0545 mean baseline (JOI), 0.8891 vs 0.8908 (JDI). Table 3 (no single-line quote
  in raw) ^f6
- [draft] Predictors: role scores and matches played together matter (chemistry rises
  fast over the first few games, flat past ~50); shared nationality or language
  barely does. ^f7
  > Beyond the mark of 50 matches together (i.e., slightly more than a season in most competitions), this effect is much weaker.
- [stats] Checked, not there: JOI does not subtract what each player does with other
  partners, so a pair of two good players scores high without any synergy; no
  intervals, no check that chemistry adds to match outcome prediction. ^f8
- [method] (inferred) Their predictive model is the attribute route to pair values:
  predict a pair's value from both members' features so unseen or thin pairs borrow
  strength. For us, champion pair effects predicted from class or attribute features,
  then shrunk toward that prediction rather than toward zero. ^f9
- [stats] (inferred) The confound to avoid: a pair metric must be measured relative
  to the two members' own effects (interaction beyond additive), or it rewards
  strong champions; fitting pairs jointly with main effects in one model does this. ^f10

## Read

- Sections 1-4, start of section 5 (Team Builder formulation).

## Not read

- Observations and use cases (sections 6-7): anecdotes about named players.
