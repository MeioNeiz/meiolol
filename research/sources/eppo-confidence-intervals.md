---
title: 'Eppo docs: Lift estimates and confidence intervals'
url: https://docs.geteppo.com/statistics/confidence-intervals/
kind: docs
commit: 
for: [showing-ranges]
looked: 2026-11-04
depth: docs (whole page)
relevance: low
grade: A/fair
description: Eppo's plain-words explanation of what a confidence interval means and what sets its width
---
# Eppo docs: Lift estimates and confidence intervals

Why: how a vendor explains an interval in words to non-statisticians.

## Assessment

- Evidence: A for Eppo's wording.
- Reasoning: fair.
- Interests: vendor docs.
- Weigh: a wording model for a method page, nothing on display.

## Findings

- [ux/uncertainty] Explains the interval as the plausible range; outside it is possible
  but unlikely. Basics of calculating confidence intervals ^f1
  > "the range of lifts that could be plausibly supported by the data from the experiment; lifts outside that confidence interval are possible, but unlikely."
- [ux/uncertainty] Lists what makes an interval wide in lay terms: spread, sample size,
  confidence level, method. Basics of calculating confidence intervals ^f2
  > "In general, the width of a particular confidence interval is determined by four factors:"
- [ux/trust] Warns that Bayesian estimates can differ a lot from the naive split when
  data is thin (prior pulls them). Basics of estimating lift ^f3
  > "the prior can influence the estimate a lot, particularly if the sample size is not large"

## Read

- whole page
