---
title: 'Tango: The 2004 Marcels (Marcel the Monkey forecasting system, the recipe)'
url: https://tangotiger.net/archives/stud0346.shtml
kind: article
commit: 
for: [early-patch-forecast]
looked: 2026-11-14
depth: docs (post and comments)
relevance: high
grade: A/fair
description: Tom Tango's 2004 post giving the Marcel recipe in six steps (season weights 5/4/3, 1200 PA of league average, age), the baseline every baseball projection system is scored against
---
# Tango: The 2004 Marcels (Marcel the Monkey forecasting system, the recipe)

Why: the canonical "old periods plus regression to the mean" forecast; we want its
functional form and numbers to compare with Meio's weight on older patches.

## Assessment

- Evidence: A. The standard baseline of baseball forecasting since 2004, by the field's
  best-known analyst; projection systems (ZiPS, PECOTA, Steamer) are judged by whether
  they beat it, and they beat it by little. The post itself shows no scoring.
- Reasoning: fair. A recipe with a worked example; the weights are stated, not derived
  here (Tango's earlier threads fit them).
- Interests: none known; Tango disowns the forecasts as a minimum bar.
- Weigh: trust the form (decayed counts plus a fixed number of mean games). The numbers
  (5/4/3, 1200) are for a year between periods and baseball's talent spread, not ours.

## Findings

- [method/dynamics] [stats] Older periods are down-weighted by a fixed ratio per period:
  the latest season counts 5, the one before 4, two back 3 (so 1, 0.8, 0.6). ^f1
  > "Weight each season as 5/4/3. 2003 counts as "5" and 2001 counts as "3"."
- [stats] Regression to the mean is a fixed count of league-average play added to the
  weighted counts: 1200 PA, the same for every player, in weighted units (two weights of
  600 PA). ^f2
  > "I then forced in that player's league average to come in at a total of 1200 PA for each player (2 weights x 600 PA). This is the regression towards the mean component."
- [stats] The worked example is plain count addition: weighted own counts (318 HR in
  7938 weighted PA) plus the league's rate over 1200 PA, then divide. So the weight on
  own data is weighted PA / (weighted PA + 1200), 0.87 for an everyday player. ^f3
  > "PA: 7938 + 1200 = 9138"
  > "Bobby Abreu shows a .87. That means that I regressed towards the mean 13%."
- [stats] That weight is published per player as "reliability" and offered as the way
  to a range. ^f4
  > "That shows how much of the forecast is based on his performance, and how much was regression towards the mean."
- [method/dynamics] Pitchers, noisier, get a steeper decay with the same mean count
  relative to it (3/2/1). Comment by Tango ^f5
  > "1 - Weights are 3/2/1."
- [method] A unit with no history is projected at the mean. ^f6
  > "Any 2004 rookie with no MLB experience will project at the league average."
- [method] The author's framing: this is the bar, not a good forecast. ^f7
  > "These forecasts are the minimum level of competence that you should expect from any forecaster."
- [method/dynamics] Checked, not there: no rule for mixing in the new season's first
  games (Marcel is preseason only), no per-player change of weight when something known
  changed (team, park, injury), no scoring against outcomes in this post. ^f8
- [method/dynamics] (inferred) Marcel in our terms: games on patch p-k count w^k each,
  plus K mean games; weight on the new patch's own n games = n / (n + w x n_old + K),
  and with n = 0 the old data's weight is w x n_old / (w x n_old + K). One full season
  alone gives 5 x 600 / (5 x 600 + 1200) = 71% own data, the size of Meio's ~70% lean on
  older patches at day 0, but Marcel's falls with the unit's sample and Meio's weight
  should too. ^f9

## Read

- Whole post and the comment thread (recipe, worked example, pitcher variant).

## Not read

- Tango's 2003 threads fitting the weights (stud0214, stud0098): where 5/4/3 came from.
