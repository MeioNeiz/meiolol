---
title: 'Lopez, Matthews and Baumer 2018: How often does the best team win? State-space models across four leagues'
url: https://arxiv.org/pdf/1701.05976
kind: paper
commit: 
for: [context-aware-models]
looked: 2026-11-06
depth: skimmed (abstract, 3 model, 5.2 variance parameters, 5.4 prediction checks)
relevance: high
grade: B/fair
description: Annals of Applied Statistics 2018; Bayesian state-space model of team strength on betting-market log-odds for NFL, NBA, MLB, NHL, with separate season-to-season (known break) and week-to-week evolution variances and autoregressions, after Glickman and Stern 1998
---
# Lopez, Matthews and Baumer 2018: How often does the best team win?

Why: a fitted example of a known break (the off-season) given its own evolution variance
and mean reversion, next to small within-season steps; the analogue of a patch boundary.

## Assessment

- Evidence: B. Peer reviewed (AoAS), ten seasons per league, posterior SDs reported,
  agrees with Glickman and Stern 1998 on the NFL.
- Reasoning: fair. Explains each variance; no comparison against a model without the
  separate break variance, so the break's forecast gain is not measured.
- Interests: none.
- Weigh: trust the variance ratios as how much one known break carries relative to
  ordinary steps; the forecast checks (AUC) are against betting lines, not ablations.

## Findings

- [method/dynamics] Strength evolves by two AR(1) steps: a season-to-season step with its
  own autoregression and variance at the known break, a week-to-week step within season.
  Section 3 ^f1
  > we allow the strength parameters of the teams to vary auto-regressively from season-to-season and from week-to-week.
- [method/dynamics] [stats] Posterior means (Table 4, cells split; quote is the caption):
  sigma_season vs sigma_week: NBA 0.44 vs 0.166, NFL 0.331 vs 0.147, NHL 0.121 vs 0.053,
  MLB 0.093 vs 0.027 (logit); gamma_season 0.54-0.69, gamma_week 0.977-1.002. ^f2
  > Mean posterior draw (standard deviation) by league.
- [method/dynamics] (inferred) So one known break carries the variance of about 5 to 12
  ordinary weeks ((sigma_season / sigma_week)^2: NFL 5.1, NHL 5.2, NBA 7.0, MLB 11.9) and
  pulls strength back 31-46% to the mean. ^f3
- [method/dynamics] Reversion at the break: NHL 46%, NBA 38%, MLB 38%, NFL 31%; they
  credit the draft, which hands the worst teams the best new players. Section 5.2 ^f4
  > Reversion towards the mean is largest in the NHL (estimated γN HL,season = 0.54, implying 46% reversion), followed by the NBA (38%), MLB (38% reversion), and the NFL (31%).
- [method/dynamics] Their NFL estimates (week 0.98, season 0.69) are close to Glickman and
  Stern 1998 (0.99, 0.82), with narrower intervals from ten seasons, not five. Section 5.2
  ^f5
  > do not substantially diverge from the estimates observed by Glickman and Stern (1998) (0.99 and 0.82).
- [method/dynamics] [stats] With five seasons Glickman and Stern's season reversion
  interval was 0.52-1.28: few breaks estimate the break parameters poorly. Section 5.2 ^f6
  > our 95% credible interval for γNFL,season of (0.61, 0.77) is entirely contained within the interval of (0.52, 1.28) reported by Glickman and Stern (1998).
- [method] Sequential (forward) fits vs betting-market AUC: NBA 0.756 vs 0.756,
  NFL 0.685 vs 0.682, NHL 0.589 vs 0.595, MLB 0.573 vs 0.605 (Table 5; caption quoted). ^f7
  > AUC values and Brier scores (p-values) by sport.
- [method/dynamics] Checked, not there: per-team break variance from known roster moves
  (trades, injuries are named as unmodelled noise, not used as inputs). Section 5.2 ^f8
  > Injuries, the resting of starters, and in-season trades would seemingly have a larger impact in a sport like basketball
- [method/dynamics] (inferred) For us: a patch boundary is the season break; the shared
  break variance is our per-patch offset variance, and the 2 known breaks we have are
  fewer than their 5 to 10, so the break variance needs a prior or pooling across
  champions (one variance, many champions) rather than per-champion estimation. ^f9

## Read

- Abstract, model (Section 3), variance parameters (5.2), prediction checks (5.4).

## Not read

- Section 5.5 parity measure, appendices (contour plots, MCMC details).
