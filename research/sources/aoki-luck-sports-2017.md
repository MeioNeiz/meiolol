---
title: 'Aoki, Assuncao, Vaz de Melo 2017: Luck is hard to beat, the difficulty of sports prediction'
url: https://arxiv.org/abs/1706.02447
kind: paper
commit:
for: [frontier-ceiling]
looked: 2026-10-21
depth: docs (abstract, sections 1-3, 5.1)
relevance: medium
grade: B/fair
description: KDD 2017; skill coefficient = excess variance of season scores over the all-equal (luck only) model, with Monte Carlo null intervals, on 1503 seasons of 4 sports
---
# Aoki, Assuncao, Vaz de Melo 2017: Luck is hard to beat, the difficulty of sports prediction

Why: the standard luck-vs-skill decomposition from sports, to transfer to champion,
comp and pair win rates.

## Assessment

- Evidence: B. KDD 2017, 198 leagues, 1503 seasons; the variance comparison it uses is
  older (Spiegelhalter, Tango; see [[gelman-luck-skill]]).
- Reasoning: fair. Simple estimator with a Monte Carlo null; the graphical model part is
  less clear.
- Interests: none known.
- Weigh: trust the method (observed variance minus the luck-only variance, schedule
  simulated under the null); the per-sport numbers are not ours.

## Findings

- [method/ceiling] [stats] Skill coefficient phi = (s^2 - sigma^2 under equal skill) /
  s^2: the share of the observed spread of results not explained by luck. Sec. 3.1 ^f1
  > We compare the observed variability of Y2k relatively to its expected value under the equal skills assumption
- [method/ceiling] [stats] phi near 0 means a luck-only league; negative values mean
  less spread than luck alone (an offsetting mechanism). Sec. 3.1 ^f2
  > Values smaller than zero indicate that the teams’ outcomes have a variability much smaller than that expected due to the luck factor.
- [method/ceiling] [stats] Null intervals by simulating the actual schedule under equal
  skill, not a normal formula. Sec. 3.2 ^f3
  > we generate Multinomial trials playing the teams against each other according to the same game schedule followed during the season.
- [method/ceiling] Luck is large even in the most competitive leagues, which is why
  complex feature models rarely beat simple ones. Abstract ^f4
  > luck is substantially present even in the most competitive championships, which partially explains why sophisticated and complex feature-based models hardly beat simple models
- [method/ceiling] Even the NBA, the most skill-driven sport, has the underdog win 36%
  of games. Abstract ^f5
  > estimate as 0.36 the probability that an underdog team wins in the NBA league
- [method/ceiling] (inferred) For us: the same excess-variance test on champion-role
  win rates per patch, on role-pair cells after the additive model, and on whole-comp
  cells, each with a schedule-matched null (refit on outcomes resampled from the model),
  gives the true spread at each level; matchmaking that offsets strength would show as
  phi below zero (cf. docs/learned.md player-champion spread). ^f6

## Read

- Abstract, sections 1-3, 5.1.

## Not read

- Section 4 (Bayesian Bradley-Terry with random luck effects), 5.2-5.4.
