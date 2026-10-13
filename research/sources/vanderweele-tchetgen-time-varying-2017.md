---
title: 'VanderWeele and Tchetgen Tchetgen 2017: Mediation analysis with time varying exposures and mediators (JRSS B)'
url: https://pmc.ncbi.nlm.nih.gov/articles/PMC5560424/
kind: paper
commit:
for: [draft-mediation]
looked: 2026-10-13
depth: skimmed (sections 1-3; estimation and example skimmed)
relevance: medium
grade: A/strong
description: JRSS B 2017; interventional (randomised analogue) direct and indirect effects for exposures and mediators that vary over time, identified by the "mediational g-formula" even with time-varying confounders affected by earlier exposure and mediator
---
# VanderWeele and Tchetgen Tchetgen 2017: Mediation analysis with time varying exposures and mediators (JRSS B)

Why: the game state is a mediator measured every minute, each minute's state confounds
the next; this is the theory for mediation through a trajectory.

## Assessment

- Evidence: A. JRSS B, leading authors; the mediational g-formula is the reference
  result for longitudinal mediation.
- Reasoning: strong. Proves identification, says exactly when natural effects coincide
  with interventional ones and when they cannot be identified.
- Interests: academic.
- Weigh: trust the identification results. Our exposure (draft) is fixed at time 0, the
  simplest special case; we need the mediator-trajectory part only.

## Findings

- [method] With time-varying confounders affected by earlier exposure and mediator,
  natural direct and indirect effects are not identified; a randomised interventional
  analogue is, via the "mediational g-formula". Abstract ^f1
  > When there are time-varying confounders affected by prior exposure and mediator, natural direct and indirect effects are not identified. However, we define a randomized interventional analogue of natural direct and indirect effects that are identified in this setting.
- [method] Exposure-induced confounding is the norm in longitudinal data, and the
  non-identification holds even if the confounder is measured. Introduction ^f2
  > In particular whenever there is a mediator-outcome confounder affected by the exposure, these natural direct and indirect effects are not non-parametrically identified irrespective of whether data is available on the exposure-induced confounder or not
  > In longitudinal settings such exposure-induced confounding may be very common.
- [method] The interventional indirect effect is non-zero only if the exposure shifts the
  mediator's distribution and that shift changes the outcome; when natural effects are
  identified, the two coincide. Interventional analogues ^f3
  > the interventional indirect effect, { E ( Y āG ā | v | v ) − E ( Y āG ā * | v | v )}, will be non-zero only if the exposure changes the distribution of the mediator and that change in the distribution of the mediator changes the outcome.
- [method] The mediator at each time may be a vector of mediators. Time-varying setting ^f4
  > it is in principle possible to allow the mediator at each time M ( t ) to denote a vector of mediators
- [method] For a continuous exposure, compare two levels a standard deviation apart
  around the mean (any two trajectories are allowed). Time-varying setting ^f5
  > For a continuous exposure one possible choice would be taking ā and ā * each as a constant separated by one standard deviation difference in the exposure distribution centered at the mean.
- [method] (inferred) For us: treat the 14:00 state (a vector: gold, CS, towers, drakes,
  heralds, kills, levels) as one mediator and earlier minutes as L; the interventional
  indirect effect then answers "how much of the draft's win effect is carried by the
  14:00 state distribution it produces", and is identified even though minute-5 and
  minute-10 states confound state at 14 and win. ^f6
- [method] (inferred) For us: draft contrast = draft model logit at mean plus or minus
  half a standard deviation (or between our draft-score quintiles), per their
  continuous-exposure suggestion; report effect per one sd of draft logit. ^f7

## Read

- Sections 1-3 (definitions, identification); skimmed estimation and the example.

## Not read

- Online supplement proofs; MSM weighting estimator details; the empirical example.
