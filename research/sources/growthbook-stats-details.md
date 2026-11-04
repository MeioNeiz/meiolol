---
title: 'GrowthBook docs: Statistical Details'
url: https://docs.growthbook.io/statistics/details.md
kind: docs
commit: 
for: [showing-ranges]
looked: 2026-11-04
depth: docs (Bayesian section)
relevance: medium
grade: A/fair
description: GrowthBook's maths for Chance to Win, Risk (expected loss, computed but no longer shown in the app) and the Bayesian interval it plots
---
# GrowthBook docs: Statistical Details

Why: what "chance to win" and "risk" are exactly, and whether risk survived in the UI.

## Assessment

- Evidence: A for what GrowthBook computes and shows.
- Reasoning: fair. Formulas, prior advice; no reason given for dropping risk from the UI.
- Interests: vendor docs.
- Weigh: the dropped risk metric is a signal, not a study.

## Findings

- [ux/uncertainty] Chance to Win is the share of the posterior on the treatment's side
  of zero. Chance To Win ^f1
  > "Chance to Win is the percentage of the posterior that is greater than 0 in favor of the treatment variation"
- [ux/uncertainty] Risk (expected loss, zero when the variation is better) is still
  computed but no longer shown in the app. Risk ^f2
  > "Note: we no longer use risk in the GrowthBook app, but still compute it in the experiment results database."
- [ux/charts] The Bayesian interval plotted is the 2.5th to 97.5th posterior percentile,
  with the posterior drawn between those points. Confidence Interval ^f3
  > "We plot the posterior between these two points in the GrowthBook UI."
- [ux/trust] They still call the Bayesian interval a "confidence interval" in the UI, not
  a credible interval. Confidence Interval ^f4
  > "Our “confidence interval” in the Bayesian engine is an interval from the 2.5th to the 97.5th percentile of the posterior distribution"
- [ux/uncertainty] (inferred) A mature tool dropped expected loss from the UI while
  keeping chance to win: the simpler probability is what survives in front of users. ^f5

## Read

- Bayesian section: prior, Chance To Win, Risk, Confidence Interval

## Not read

- frequentist and sequential maths: not about display
