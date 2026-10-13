---
title: 'Gelman 2018: You need 16 times the sample size to estimate an interaction'
url: https://statmodeling.stat.columbia.edu/2018/03/15/need-16-times-sample-size-estimate-interaction-estimate-main-effect/
kind: article
commit: 
for: [comp-attribute-features]
looked: 2026-10-13
depth: docs (post body, not comments)
relevance: medium
grade: A/strong
description: Andrew Gelman's blog post deriving that an interaction half the size of a main effect needs 16x the sample to estimate, and that significant interaction estimates at low power are overestimated about 3x
---
# Gelman 2018: You need 16 times the sample size to estimate an interaction

Why: how much data does a comp interaction (damage mix x enemy resists) need compared
with a champion's main effect?

## Assessment

- Evidence: A. Recognised expert (Columbia statistician, Bayesian Data Analysis
  author); textbook algebra plus simulation.
- Reasoning: strong. Shows the algebra and the assumption (interaction half the main
  effect, balanced groups).
- Interests: none.
- Weigh: the 16x depends on the assumed half size; the 2x standard error is general.

## Findings

- [stats] An interaction's standard error is about twice a main effect's at the same sample size (four cells of N/4 against two of N/2). ^f1
  > The standard error of an interaction is roughly twice the standard error of the main effect
- [stats] If interactions are half the size of main effects, a study with 80% power for the main effect has 10% power for the interaction. ^f2
  > if you have 80% power to estimate the main effect, you have 10% power to estimate the interaction.
- [stats] Under low power, the estimates that reach significance overstate the true effect about threefold (2.4 vs 0.7 standard errors). ^f3
  > the 10% of results which do appear to be statistically significant give an estimate of 2.4, on average, which is over 3 times higher than the true effect.
- [stats] Take-home: 16 times the sample for an interaction; interactions found by looking after the main analysis are mostly noise. ^f4
  > you need 16 times the sample size to estimate an interaction than to estimate a main effect
  > what you think of as interesting exploratory findings could be just a bunch of noise.

## Read

- Post body and the take-home point.

## Not read

- The R simulations section and comments.
