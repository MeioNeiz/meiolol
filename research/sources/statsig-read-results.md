---
title: 'Statsig docs: How to Read Experiment Results (formerly Pulse)'
url: https://docs.statsig.com/experiments/interpreting-results/read-results.md
kind: docs
commit: 
for: [showing-ranges]
looked: 2026-11-04
depth: docs (whole page)
relevance: medium
grade: A/fair
description: Statsig's guide to its experiment Scorecard: relative lift, confidence interval and a three-colour significance code per metric, with a 80-99% interval picker
---
# Statsig docs: How to Read Experiment Results (formerly Pulse)

Why: how a leading experiment tool shows an estimate, its interval and whether it is a
real difference.

## Assessment

- Evidence: A for what the product shows (large commercial tool, docs updated
  2025-09-18). Says nothing about whether readers understand it.
- Reasoning: fair. Describes the UI, little on why.
- Interests: vendor docs.
- Weigh: a convention for analysts and PMs, not lay readers.

## Findings

- [ux/uncertainty] [ux/colour] Each metric row shows relative lift, its interval and a
  significance colour: green up, red down, grey not significant. Scorecard ^f1
  > "Whether the result is statistically significant. Positive lifts are green, negative lifts are red, and non-significant results are grey."
- [ux/uncertainty] Interval width is user-picked from 80% to 99%; the docs frame 80% as
  trading more false positives for faster directional reads. Significance level settings ^f2
  > "Choose from 80%, 90%, 95%, 98%, or 99%. A lower confidence interval accepts a higher false-positive rate in exchange for faster, directional results."
- [ux/uncertainty] Default 95%, shown as estimate +/- 1.96 standard errors. Daily Scorecard ^f3
  > "Statsig reports confidence intervals at the selected significance level (95% by default)."
- [ux/trust] Early (real-time) results are shown without intervals and with a warning
  not to decide on them. Real-time results ^f4
  > "Metric lifts don't have confidence intervals."
- [ux/charts] Default view is the cumulative lift with its interval; hover reveals the
  raw counts behind the lift. Experiment results views ^f5
  > "Hover over a metric to view the raw statistics behind the lift calculation and the topline impact."
- [ux/uncertainty] Checked, not there: this page shows no Bayesian "chance to beat" or
  expected loss; it is interval plus significance colour only. ^f6

## Read

- whole page (markdown version)

## Not read

- Statsig Bayesian docs (`/experiments/statistical-methods/methodologies/bayesian`):
  how its Bayesian mode labels chance to beat control
