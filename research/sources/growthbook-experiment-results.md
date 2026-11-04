---
title: 'GrowthBook docs: Experiment Results'
url: https://docs.growthbook.io/app/experiment-results
kind: docs
commit: 
for: [showing-ranges]
looked: 2026-11-04
depth: docs (results table, Bayesian and frequentist engines)
relevance: high
grade: A/fair
description: GrowthBook's results page: Bayesian Chance to Win with green/red/grey thresholds and a violin (posterior density) per metric, or p-value and CI bar in the frequentist engine
---
# GrowthBook docs: Experiment Results

Why: how an open-source experiment tool shows "chance to beat" and the spread of an
effect.

## Assessment

- Evidence: A for what the product shows (widely used open-source tool).
- Reasoning: fair. Explains each column's meaning in plain words; no user testing
  cited.
- Interests: vendor docs.
- Weigh: the thresholds (95% / 5%) are decision conventions, not lay-reader research.

## Findings

- [ux/uncertainty] [ux/colour] Bayesian engine headlines "Chance to Win": over 95%
  green (clear winner), under 5% red (clear loser), in between grey (inconclusive). Bayesian Engine ^f1
  > "Chance to Win tells you the probability that the variation is better. Anything above 95% (a customizable threshold set at the organization level) is highlighted green indicating a very clear winner."
  > "Anything in between is grayed out indicating it’s inconclusive."
- [ux/trust] Grey is explained in words as either no real difference or not enough data
  yet. Bayesian Engine ^f2
  > "If that’s the case, there’s either no measurable difference or you haven’t gathered enough data yet."
- [ux/charts] [ux/uncertainty] The effect is drawn as a probability density (violin),
  thicker where the true change is more likely; tails shrink with data. Bayesian Engine ^f3
  > "It is a probability density graph and the thicker the area, the more likely the true percent change will be there."
- [ux/charts] Frequentist engine swaps the density for a CI bar and a p-value cell with
  the same green/red colouring by preferred direction. Frequentist Engine ^f4
  > "The graph now represents a 95% confidence interval"
- [ux/uncertainty] Baseline and variation columns show raw numerator and denominator in
  grey under each value. Results table ^f5
  > "For both columns, the raw data in grey underneath shows the numerator and denominator totals."

## Read

- results table, Bayesian and frequentist engine sections

## Not read

- dimensions, health checks, decision framework sections: not about display of ranges
