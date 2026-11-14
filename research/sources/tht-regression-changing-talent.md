---
title: 'The Hardball Times: Regression with Changing Talent Levels, the Effects of Variance (Dorhauer, 2017)'
url: https://tht.fangraphs.com/regression-with-changing-talent-levels-the-effects-of-variance/
kind: article
commit: 
for: [early-patch-forecast]
looked: 2026-11-14
depth: docs (whole article)
relevance: medium
grade: B/strong
description: How drifting talent changes the regression-to-the-mean constant (the K in n/(n+K)), with a day-to-day talent correlation of ~0.999 estimated two ways for baseball OBP
---
# The Hardball Times: Regression with Changing Talent Levels, the Effects of Variance (Dorhauer, 2017)

Why: Meio shrinks with n/(n+K) and down-weights old patches; this is the sabermetric
treatment of how those two interact when the true value drifts.

## Assessment

- Evidence: B. Careful analyst's derivation with a simulation and one real estimate
  (player-months 2000-2016); maths and R code in a linked supplement, not checked.
- Reasoning: strong. States assumptions, limits (ratios of small numbers, estimates
  can come out above 1) and that the full interaction with weighting is not covered.
- Interests: none known.
- Weigh: trust the principles; the 0.999 is baseball's and gradual, a patch is a jump.

## Findings

- [stats] The regression constant K is the number of observations where reliability is
  0.5, i.e. noise variance equals the spread of true values. ^f1
  > "The regression constant represents the number of observations you need for the reliability of your sample to reach 0.5."
- [method/dynamics] [stats] Down-weighting old data lowers K (long-run limit about half);
  drift in the true values raises it, so the two partly cancel. ^f2
  > "while weighting past data increases the proportion of variance attributable to talent, the changes in talent implied by weighting decrease that proportion"
- [method/dynamics] If values drift and the spread across units is not growing, values
  must be reverting to the centre: drift implies mean reversion. ^f3
  > "Either the spread in talent across baseball will increase steadily over time, or individual player talent levels will tend to drift back toward the center."
- [method/dynamics] [stats] The drift rate is estimated from data two ways that agreed:
  how the spread of true values shrinks with window length (0.9989 a day) and how the
  correlation between windows falls with the gap between them (0.9990 a day). ^f4
  > "Adding an extra 30-day gap between the samples lowered the correlation by a factor of 0.9704, which is equivalent to lowering it by a factor of 0.9704^(1/30) = 0.9990 each day."
- [stats] These estimates are fragile. ^f5
  > "we are dealing with ratios of very small numbers, and a small amount of randomness in the measurements can have an amplified effect"
- [method/dynamics] Checked, not there: a known break (a trade, an injury, a rule
  change) as a one-off drop in the correlation; the combined formula for weights plus
  drift (left to a later piece). ^f6
- [method/dynamics] (inferred) For us: the patch is one known step whose correlation
  rho we can estimate the second way, as the correlation of champion-role rates across
  the boundary against the same-length gap within a patch (noise taken out). The old
  patch's games then count rho^2-ish each and the prior needs widening by (1 - rho^2) x
  spread: the same number as Meio's offset sd, reached from the correlation side, and a
  cross-check on it. ^f7

## Read

- Whole article.

## Not read

- The supplement (3-dbaseball.net, github kitikami/THT-regression-changing-talent): the
  variance formula's derivation. The companion "Elo vs. Regression to the Mean".
