---
title: 'Maymin, Maymin, Shen 2013: NBA chemistry, positive and negative synergies in basketball'
url: https://iacss.org/wp-content/uploads/2024/09/IJCSS-Volume12_2013_Edition2.pdf
kind: paper
commit:
for: [effect-isolation]
looked: 2026-10-13
depth: docs (abstract, introduction, synergy sections; probit details skimmed)
relevance: medium
grade: B/fair
description: IJCSS 2013 (pages 4-23 of the issue PDF); synergy derived from skill ratings pushed through nested probit possession simulations instead of estimated per pair; lineup synergy worth up to 1-2 points or 3-6 wins
---
# Maymin, Maymin, Shen 2013: NBA chemistry

Why: an NBA lineup synergy paper; how does it avoid the small-sample problem of pair or
lineup terms and how big are the synergies?

## Assessment

- Evidence: B. Peer-reviewed (IJCSS), ~1M possessions; validation of the synergy
  mechanism is only a calibration plot for steals and offensive rebounds, no held-out
  prediction of lineup results.
- Reasoning: fair. Clear mechanism, but synergies are model outputs, not measured.
- Interests: authors' own framework (SPM).
- Weigh: trust the design idea (synergy from a nonlinear link on attributes); treat the
  sizes as what the model implies, not as measured effects.

## Findings

- [method] [stats] Measuring chemistry as lineup APM minus the sum of player APMs fails
  on small samples: too many lineups, too few minutes each. ^f1
  > The APM’s of the five-player lineups have small sample problems since the minutes played of any given five-player lineup can be small.
- [method] Their way round it: rate each player on six skills (offence and defence for
  scoring, rebounding, ball-handling) in nested probits, simulate possessions with the
  ten players, and call synergy the lineup's result minus the sum of the parts. ^f2
  > We calculate the synergies of each NBA team by comparing their 5-player lineup’s effectiveness to the “sum-of-the-parts.”
- [method] [stats] Synergy comes from the nonlinear link: skills that raise a rare
  event's chance stack positively, skills for an already likely event stack
  negatively (diminishing returns). ^f3
  > Our framework predicts that skills that affect rare events (e.g. steals, offensive rebounds) will have positive synergies, while skills that contribute to common events (e.g. defensive rebounds) will have negative synergies.
- [draft] Skill pair synergies are a fraction of a point, e.g. two offensive scorers
  -0.826 (one ball), two ball-handlers -0.825, ball-handling with offensive rebounding
  +0.550. ^f4
  > Offensive scoring has negative synergies with itself (-0.826) because players must share one ball.
- [stats] [draft] Team lineup synergies range from about +1 point per game (Orlando) to
  about -1 (Minnesota); 1-2 points per game is 3-6 wins a season. ^f5
  > Orlando’s lineup has the highest amount of synergies, over one point per game, while Minnesota’s negative synergies cost their lineup just under one point per game.
  > 1-2 points per game can translate into 3-6 wins per season
- [stats] Teams show positive and negative chemistry equally often. ^f6
  > teams are no more likely to exhibit positive chemistry than negative chemistry
- [stats] Validation: bucketed predicted vs actual steals over 987,343 possessions sit
  inside 95% bands (3 of 100 buckets outside); a calibration check of the mechanism,
  not of lineup synergy values. ^f7
  > only three points out of one hundred fall outside, two below and one above
- [stats] Checked, not there: no shrinkage, no intervals on lineup synergies, no
  out-of-sample test of lineup results. ^f8
- [draft] [method] (inferred) The champion version: give each champion a few attribute
  scores (damage type, engage, waveclear, scaling) and let synergy arise from a
  nonlinear team function of the summed attributes; pairs then share strength through
  attributes instead of needing games per pair. That is the comp-attribute route
  ([[comp-attribute-features]]), with the same caveat: the synergy is only as real as
  the link function. ^f9
- [draft] (inferred) Their saturation result maps to League: two picks covering the same
  need (two AP threats, two engages) should show negative synergy; complementary
  needs positive. A testable sign prediction for our pair estimates. ^f10

## Read

- Abstract, introduction, synergy sections (skill pairs, empirical evidence, team
  synergies).

## Not read

- Nested probit details and trade analysis.
