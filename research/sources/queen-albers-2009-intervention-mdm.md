---
title: 'Queen and Albers 2009: Intervention and causality, forecasting traffic flows using a dynamic Bayesian network (JASA)'
url: https://oro.open.ac.uk/17545/1/jasa%23A08-028R.pdf
kind: paper
commit: 
for: [early-patch-forecast, context-aware-models]
looked: 2026-11-14
depth: docs (sections 3-5; the causal-identification argument skimmed)
relevance: medium
grade: B/fair
description: JASA 2009 (accepted version) on forecasting hourly traffic flows with linked dynamic linear models, using West and Harrison's external intervention at a known or detected change, a mean shift plus added variance, with two worked examples
---
# Queen and Albers 2009: Intervention and causality, forecasting traffic flows using a dynamic Bayesian network (JASA)

Why: the state-space form of "something known changed here": what exactly is done to
the model at the change, and what sets the sizes. A patch is our known change.

## Assessment

- Evidence: B. Peer-reviewed (JASA), real data (Kent County Council counts on a London
  motorway junction), following West and Harrison's long-used technique. Gains are
  shown as error plots and forecast tables for two events, no aggregate score.
- Reasoning: fair. Clear on the mechanics and on which series an intervention reaches;
  admits the sizes were set by hand or from hindsight.
- Interests: none known.
- Weigh: trust the form of the intervention. The sizes are not evidence: one shift was
  fitted on the data it then forecasts.

## Findings

- [method/dynamics] An intervention is made before the period's forecast and changes a
  distribution, not a value: the observation gets an expected shift h and extra
  variance H; a state gets a new transition and a wider evolution variance. Section 4 ^f1
  > "The values of ht (i) and Gt (i)∗ reflect the"
  > "reflect the uncertainty regarding the changes."
- [method/dynamics] Two triggers are named: poor recent forecasts, or outside knowledge
  of an event such as planned roadworks. Section 4 ^f2
  > "model forecast performance or by expert information regarding external events (such"
- [method/dynamics] A one-off shock is handled on the observation (shift plus a large
  variance); the added variance was arbitrary and results were robust to it once large
  enough. Section 5.1 ^f3
  > "tribution (3) was set to be 10,000. This value was fairly arbitrary: it was chosen to"
  > "the choice of Ht (i), provided that it is large enough, around 50% of Vt (167) in this"
- [method/dynamics] A lasting change (four days of roadworks) is handled on the state:
  scale its mean by a factor and add a small variance, then undo both when the change
  ends. Section 5.2 ^f4
  > "the reductions in flows are persistent over four days and not just one or two time"
  > "the variances for θ 265 (161.171) and θ 265 (161). These are regression parameters and,"
- [method/dynamics] The mean shift is the hard part: ideally from an expert, here read
  off the very data being forecast; the authors suggest a prior on it learnt on line. Section 5.2 ^f5
  > "mation should be used to estimate α. However, unfortunately no expert information"
  > "It is possible that a prior could be placed on α, and"
- [method/dynamics] An intervention on one series changes forecasts only for series
  downstream of it in the network, and that is what the error plots show. Section 5.1 ^f6
  > "one-step forecasts for Yt (i) and its descendants, but should not affect the one-step"
- [method/dynamics] Checked, not there: an aggregate forecast score with and without
  interventions, an automatic rule for the variance step, repeated breaks from which
  the step could be estimated (our patches every two weeks). ^f7
- [method/dynamics] (inferred) For us: Meio's d[cr, patch] ~ N(0, sd^2) is this
  intervention with shift 0 and a fitted variance step, and we are better placed than
  the paper: the break recurs, so the step is estimated from past patches (MacKay or by
  forecast error). What the paper adds is the split: variance step for every unit,
  mean shift only where outside knowledge gives one (notes, exposure to a changed item:
  PT7), and "downstream" units (matchups against a changed champion) inherit the widening. ^f8

## Read

- Sections 3 (model), 4 (intervention and its reach), 5 (two examples).

## Not read

- Sections 1-2 in detail, section 6 (identifying causal direction by intervention).
- West and Harrison 1997 chapter 11 (the technique's source; no open copy).
