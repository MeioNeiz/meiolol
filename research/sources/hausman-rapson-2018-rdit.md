---
title: 'Regression Discontinuity in Time: Considerations for Empirical Applications (Hausman, Rapson; NBER w23602 2017/2018, Annual Review of Resource Economics 2018)'
url: https://www.nber.org/system/files/working_papers/w23602/w23602.pdf
kind: paper
commit:
for: [frontier-causal]
looked: 2026-10-21
depth: docs (abstract, 3.3 sorting and anticipation, 4 recommendations)
relevance: medium
grade: A/strong
description: Practitioners' guide to regression discontinuity with time as the running variable: why it is closer to an event study, short vs long-run effects, untestable sorting, and a checklist (placebos, donut, covariate RDs)
---
# Regression Discontinuity in Time (Hausman, Rapson 2018)

Why: a patch or mid-patch hotfix is a sharp change at a known time; what can a
before/after-the-cutoff comparison identify, and how is it checked?

## Assessment

- Evidence: A. The standard reference on RD in time (Annual Review), surveys the applied
  literature's practice.
- Reasoning: strong; separates each bias source, gives a checklist, admits there is no
  sufficient test.
- Interests: none.
- Weigh: written for pollution policy; the sorting point maps directly onto players
  changing what they pick when a patch lands.

## Findings

- [method/causal] [stats] With time as the running variable the design is closer to an
  event study than an RD; effects can be biased by autoregression or when short- and
  long-run effects differ. ^f1
  > tests for sorting or bunching near the threshold are often irrelevant, making the framework closer to an event study than a regression discontinuity design
  > estimates may be biased if the time-series properties of the data are ignored
- [method/causal] Sorting and anticipation at the cutoff cannot be tested with time as
  the running variable, so an RD-in-time estimate is a compound of the effect and any
  behavioural response. ^f2
  > estimates retrieved from RDiT are of a compound effect: the causal treatment effect of interest
  > any unobserved sorting/anticipation/adaptation/avoidance effects that may exist but cannot be tested for
- [method/causal] Checklist: plot raw data and residuals, robustness to bandwidth and
  polynomial, placebo cutoffs and untreated units, a parallel RD on control variables
  to show continuity, a donut RD dropping data near the cutoff, test for autoregression,
  augmented local linear (covariates fitted on the full sample first). ^f3
  > Estimate a “donut” RD (removing observations near the threshold; see Barreca et al.
  > Plot a parallel RD estimated on control variables (e.g. weather, economic activity) to
- [method/causal] Passing every check is necessary but not sufficient. ^f4
  > Passing these diagnostic tests is necessary but insufficient for identification
- [method/causal] (inferred) For a patch or hotfix in LoL: the "sorting" is pick
  response (a buffed champion draws new, low-mastery pickers; a nerf leaves mains), and
  the "long-run" effect includes players learning; so run the parallel RD on picker
  covariates (mastery, rank, games on champion) as the continuity check, use unchanged
  champions as placebos, and estimate within the same player-champion pairs across the
  cutoff to remove the composition shift. Mid-patch hotfixes (a few days, one or two
  champions) are the sharpest cutoffs we have. ^f5

## Read

- Abstract, section 3.3, section 4 and its tables.

## Not read

- Section 3.1-3.2 simulations (AR(1) air quality examples).
