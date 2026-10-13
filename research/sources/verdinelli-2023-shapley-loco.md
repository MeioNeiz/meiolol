---
title: 'Verdinelli, Wasserman 2023: Feature importance, a closer look at Shapley values and LOCO'
url: https://arxiv.org/pdf/2303.05981
kind: paper
commit: 
for: [correlated-importance]
looked: 2026-10-13
depth: docs (1-6, 8 opening, 10; 7 and 9 skimmed)
relevance: high
grade: A/strong
description: arXiv 2303.05981 (CMU statistics; Statistical Science); population-level LOCO vs Shapley under correlated features, "correlation distortion" vs "low density bias", decorrelated LOCO, intervals by cross-fitting or HulC, groups of variables; recommends a normalised LOCO over Shapley
---
# Verdinelli, Wasserman 2023: Feature importance, a closer look at Shapley values and LOCO

Why: a statistician's head-to-head of LOCO (drop-and-refit) and Shapley under
correlation, with inference: the closest thing to a direct answer to our question.

## Assessment

- Evidence: A. Wasserman (CMU, co-author of the LOCO paper Lei et al. 2018); worked
  linear cases with closed forms, small simulations (random forests, d=20,
  correlation up to 0.9), interval coverage check.
- Reasoning: strong. Names the trade-off (correlation distortion vs low density bias)
  rather than claiming a winner; admits uniform intervals near zero are unsolved.
- Interests: co-author of LOCO, so not neutral between LOCO and Shapley.
- Weigh: trust the four-case analysis and the trade-off; the normalised LOCO is defined
  for a single feature, and its benefit in nonlinear models is shown only in small
  simulations.

## Findings

- [method] LOCO (drop X_j, refit, compare risk) is easy to estimate and interpret but
  depends on X_j's correlation with the rest; under perfect dependence it is 0
  ("correlation distortion"). Section 2.1 ^f1
  > its value depends not just on how strongly µ(X) depends on Xj , but also on the correlation between Xj and the other features. In the extreme case of perfect dependence, it is 0.
- [method] Shapley values do not fix correlation: with perfectly dependent features and
  only X1 mattering, LOCO is 0 and Shapley beta^2/d; with X1 irrelevant but correlated
  to relevant ones, Shapley can be large. Section 3 ^f2
  > Contrary to some claims, Shapley values do not eliminate feature correlation.
  > Here the Shapley value can be large even though Y has no functional relationship with X1 .
- [method] Removing correlation is a Faustian bargain: any correlation-free measure
  must evaluate the regression where p(w)p(z) is large but p(w, z) small, i.e.
  extrapolate; LOCO integrates over the joint and avoids it. Section 6.1 ^f3
  > correcting for correlation eliminates correlation distortion at the expense of introducing a new bias
  > any nonparametric, correlation free functional requires estimating µ(w, z) over sets of low density which contain little data
- [method] Population Shapley needs O(n) submodel refits for accurate inference
  (Williamson and Feng 2020); the cost should not be underestimated. Section 2.3 ^f4
  > This could mean refitting the model thousands of times when the sample size is large. The computational burden should not be underestimated.
- [stats] Intervals for these quadratic measures break down near zero (rate and limit
  change); intervals with uniform coverage are unsolved. Cross-fitting or the HulC (B
  blocks, fit on 4/5 and evaluate on 1/5 of each, interval from min to max) give
  "variability intervals". Sections 6.2, 6.3, 10 ^f5
  > Finding a confidence interval with uniformly correct coverage, with length n−1/2 away from the null and length n−1 at the null is, to the best of our knowledge, an unsolved problem.
  > These intervals are best interpreted as variability intervals not confidence intervals due to the estimation bias.
- [method] Groups are another way to deal with correlation: compute LOCO for X_j
  together with its correlated features, or for nested groups grown stepwise by
  correlation. Section 8 ^f6
  > In fact, looking at groups of features is another way to deal with correlation.
- [method] Normalised LOCO divides by the residual variance of X_j given the rest,
  E[(X_j - E[X_j | X_-j])^2]; correlation-free in linear models and often less distorted
  otherwise. Section 4.2 ^f7
  > This normalized version of LOCO is the version we will use from now on.
  > Interestingly, this version often suffers less correlation distortion even in nonlinear models, although it does not eliminate it in general.
- [method] [stats] Random forests bias estimated LOCO towards 0 as correlation rises
  (true value 5 on the square root scale). Section 7, Figure 3 ^f8
  > The standard forest is biased toward 0.
- [method] Recommendation: normalised LOCO; Shapley is expensive, hard to interpret and
  still distorted, not recommended for general use. Section 10 ^f9
  > The Shapley value is very expensive to compute, is difficult to interpret and still suffers correlation distortion.
  > we do not recommend them for general use
- [stats] (inferred) The HulC splits data into blocks; splitting by game (all minutes of
  a game in one block) makes the interval game-clustered for free, and with 230k games
  each of 5 blocks still has 46k games. ^f10
- [method] (inferred) For us: report group LOCO (economy, objectives, towers, draft
  prior...) and also the "everything but group G" fit, so a reader sees both the unique
  share and the stand-alone share; between them lies the shared part no method can
  assign without a convention. ^f11

## Read

- Sections 1-6, 8 (groups, opening), 10 (conclusions, Table 4).

## Not read

- Section 7 detail (four simulation scenarios, coverage figure), Section 9 (modified
  Shapley weights), the decorrelated LOCO influence-function derivation.
