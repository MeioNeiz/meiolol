---
title: 'Eppo docs: Progress Bar'
url: https://docs.geteppo.com/experiment-analysis/reading-results/progress-bar/
kind: docs
commit: 
for: [showing-ranges]
looked: 2026-11-04
depth: docs (whole page)
relevance: medium
grade: A/fair
description: Eppo shows how much data an experiment has as a progress bar towards a target interval width (precision), progress = (target / current precision) squared
---
# Eppo docs: Progress Bar

Why: a way to show "how much data is enough" without showing an interval.

## Assessment

- Evidence: A for what Eppo shows.
- Reasoning: fair. Explains the formula and the square.
- Interests: vendor docs.
- Weigh: an analyst tool; the idea (data so far against a target precision) may carry to
  thin cells.

## Findings

- [ux/uncertainty] Progress is measured against precision, the interval's half-width. Precision ^f1
  > "Precision is the uncertainty in the point estimate as defined by the width of the confidence interval."
- [ux/uncertainty] Progress = (target precision / current precision) squared; e.g.
  target 5%, interval (-10%, 10%) gives 25%. Mathematical details ^f2
  > "The square comes from the fact that if we want to detect an effect twice as small, we need roughly 4 times more data."
- [ux/trust] The bar's purpose is to say when a flat result has had enough data to call
  it flat. Progress Bar ^f3
  > "use the progress bar to help you stop experiments that look flat once these hit 100% progress"
- [ux/uncertainty] (inferred) For meio.lol a "how sure" bar per thin cell (games so far
  against games needed for a target range width) could replace a raw interval for lay
  readers. ^f4

## Read

- whole page
