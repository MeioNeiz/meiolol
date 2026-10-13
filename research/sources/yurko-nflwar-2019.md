---
title: 'Yurko, Ventura and Horowitz 2019: nflWAR, a reproducible method for offensive player evaluation in football'
url: https://arxiv.org/pdf/1802.00998
kind: paper
commit:
for: [effect-isolation]
looked: 2026-10-13
depth: docs (sections 1, 3, 4.1-4.4, 6)
relevance: high
grade: A/strong
description: CMU paper (JQAS 2019) behind nflscrapR; multinomial expected points and GAM win probability per play, EPA/WPA as play values, multilevel varying-intercept models to split credit, drive resampling for intervals
---
# Yurko, Ventura and Horowitz 2019: nflWAR, a reproducible method for offensive player evaluation in football

Why: the reference open EPA/WPA pipeline in American football, and the clearest on
(a) the "team already ahead" problem in a points model, (b) partial pooling to split a play
value between contributors, (c) resampling at the right level for intervals.

## Assessment

- Evidence: A. JQAS 2019; nflscrapR and its EP/WP models became the base of public NFL
  analytics (nflfastR descends from it); data 2009-2017 play by play, leave-one-season-out
  calibration.
- Reasoning: strong. Explains each choice (multinomial over averaging, weighting over
  dropping plays, drive over play resampling) and its limits.
- Interests: academic, own open-source package.
- Weigh: trust the method; NFL numbers do not transfer.

## Findings

- [method] Play value = post-play minus pre-play expected points (EPA) or win
  probability (WPA). Section 1.1 ^f1
  > Using these metrics, one can obtain pre-snap and post-snap values of a play (expected points or win probability) and, taking the difference in these values, the value provided by the play itself
- [method] Expected points come from a multinomial model of the next scoring event in
  the same half (seven outcomes, touchdown to opponent touchdown), not the final result.
  Section 3.1.1 ^f2
  > For each play, we find the next scoring event within the same half (with respect to the possession team) as one of the seven possible events
- [method] [stats] "Already ahead" problem in a points model: teams far ahead trade points
  for time, so they keep all plays but down-weight large score differentials, scaled
  linearly to zero at the maximum. Section 3.1.2 ^f3
  > When a team is leading by a large number of points at the end of a game they will sacrifice scoring points for letting time run off the clock.
  > we don’t exclude any observations but instead use a weighting approach.
- [method] Win probability is a GAM (logit link) on expected score differential, time
  remaining and timeouts, using the expected points as input, so smooth non-linear
  effects stay interpretable. Section 3.2 ^f4
  > We use a generalized additive model (GAM) to estimate the possession team’s probability of winning the game conditional on the current game situation.
- [stats] Models picked by leave-one-season-out calibration error across all outcome
  classes, not by accuracy. Section 3.1.3 ^f5
  > We calculate the model calibration error using leave-one-season-out cross-validation
- [method] [stats] Credit split by multilevel models: play values regressed on varying
  intercepts per player group plus covariates, so low-sample players shrink to the group
  mean; fitted with lme4. Section 4.2 ^f6
  > In order to arrive at individual player effects we use varying-intercepts for the groups involved in a play.
  > QBs and receivers involved in fewer plays will be pulled closer to their overall group averages
- [method] Opponent and team context enter as covariates or intercepts (opposing defence,
  team rushing strength), which is how they control for teammate and opposition quality.
  Section 1.3, 4.2 ^f7
  > the multilevel model framework accounts for quality of teammates and competition.
- [stats] Intervals by resampling whole drives (1000 simulated seasons), because events
  within a drive are dependent and player usage depends on team decisions. Section 4.4 ^f8
  > Rather than resampling plays in which a particular player is involved to arrive at estimates for their performance variability, we resample entire team drives.
  > drive-resampling approach, with 1000 simulated seasons.
- [method] EPA converts to wins with a regression of season wins on score differential,
  i.e. a points to wins exchange rate. Section 4.3 ^f9
  > However, for the EPA-based play value response, the iPAR values represent the individual expected points added above replacement, and thus require a conversion from points to wins.
- [method] (inferred) LoL analogue: "expected gold" or "next objective" is the EPA layer
  and our win-by-minute model the WPA layer; a gold equivalent per event is the WPA of
  the event divided by the local slope of win chance in gold lead (their points to wins
  conversion, done per minute). ^f10
- [stats] (inferred) Our resampling unit should be the game (or the cluster of events in
  one fight), not the event: events in a game share the outcome, so event-level bootstrap
  intervals would be too narrow. ^f11
- [stats] (inferred) Their weighting fix maps to snowballed LoL games: an inhibitor at
  95% win chance carries little information; down-weight or report value by leverage
  (win chance band) rather than drop. ^f12

## Read

- Sections 1, 3 (EP, WP), 4.1-4.4 (play values, multilevel, replacement, resampling), 6.3

## Not read

- Section 5 results (NFL players), appendix model details
