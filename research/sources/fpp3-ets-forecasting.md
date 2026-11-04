---
title: 'Hyndman and Athanasopoulos, FPP3 chapter 8: Exponential smoothing (ETS state space models, prediction intervals)'
url: https://otexts.com/fpp3/ets-forecasting.html
kind: book
commit:
for: [share-drift-ranges]
looked: 2026-11-04
depth: docs (8.1, 8.5 ETS(A,N,N), 8.7)
relevance: medium
grade: A/fair
description: Open textbook chapter (Forecasting Principles and Practice, 3rd ed.) on simple exponential smoothing as a local-level innovations state space model, with closed-form h-step forecast variances
---
# Hyndman and Athanasopoulos, FPP3 chapter 8: Exponential smoothing

Why: the simplest closed-form answer to "how wide is a local-level forecast range h days
ahead", to compare with our fixed drift term tau2.

## Assessment

- Evidence: A. The standard open forecasting textbook (Hyndman, fable/forecast package
  author); formulas from Hyndman et al. 2008.
- Reasoning: fair. States the models and formulas, defers derivations to the 2008 book.
- Interests: none (promotes its own R packages only as tools).
- Weigh: Gaussian additive errors on the observed scale; for us apply on the logit with
  the binomial noise handled separately.

## Findings

- [method/dynamics] Simple exponential smoothing is a weighted average with weights
  decaying geometrically by (1 - alpha) into the past; alpha near 1 tracks the latest
  value, near 0 averages the whole history. Section 8.1 ^f1
  > Forecasts are calculated using weighted averages, where the weights decrease exponentially as observations come from further in the past
- [method/dynamics] Its forecast is flat: every horizon gets the last level. Section 8.1
  ^f2
  > That is, all forecasts take the same value, equal to the last level component.
- [method/dynamics] SES is the point forecast of a local-level state space model
  ETS(A,N,N) (observation = previous level + error; level moves by alpha times the
  error); alpha = 0 is a constant level, alpha = 1 a random walk. Section 8.5 ^f3
  > If α\=0α\=0, the level of the series does not change over time; if α\=1α\=1, the model reduces to a random walk model
- [method/dynamics] Prediction intervals come from the model, not the method: the
  h-step forecast variance of ETS(A,N,N) is sigma^2 [1 + alpha^2 (h - 1)], growing
  linearly with the horizon; trend models grow faster (cubic terms in h). Section 8.7,
  Table 8.7 ^f4
  > A big advantage of the statistical models is that prediction intervals can also be generated
  > For most ETS models, a prediction interval can be written as
- [method/dynamics] (inferred) For us: a fixed drift term tau2 is a local level at one
  horizon only. In a local level, the extra variance at lead h is h x q (q = per-day
  level variance), so the drift term should scale with the gap between the estimation
  window's centre and the target day: q x (h_centre). Our halves estimate gives q if we
  divide tau2 by the distance in days between the two halves' centres. ^f5
- [method/dynamics] (inferred) Day-1-to-3 adoption after a patch is trend-like (a new
  build rises for days, then flattens), so a random walk under-states early drift and a
  linear trend over-extrapolates; the damped-trend family is the textbook middle ground
  if a local level fails the truth test on day 8+. ^f6

## Read

- 8.1, 8.5 (ETS(A,N,N) only), 8.7 and Table 8.7

## Not read

- 8.2-8.4 trend and seasonal methods in detail, 8.6 estimation and AIC selection
