---
title: 'Czado, Gneiting, Held 2009: Predictive model assessment for count data'
url: https://mediatum.ub.tum.de/doc/1072660/18284.pdf
kind: paper
commit: 
for: [forecast-judging]
looked: 2026-11-04
depth: listed (all of sections 1-6; appendices skipped)
relevance: high
grade: A/strong
description: Biometrics 2009 paper (read as the September 2007 preprint on TUM's repository) adapting PIT, marginal calibration and proper scores to counts; source of the non-randomised PIT histogram
---
# Czado, Gneiting, Held 2009: Predictive model assessment for count data

Why: our truth test targets are counts (wins out of n games, picks out of n); how
should PIT and scores work when the predictive distribution is discrete?

## Assessment

- Evidence: A. Biometrics 2009, the standard reference for PIT on counts; implemented
  in R packages (surveillance, tscount). Read as the authors' preprint dated
  September 5, 2007 on TUM's mediatum repository, not the final journal text.
- Reasoning: strong. Simulation with known truth (NB vs Poisson), two case studies,
  and it shows where scores disagree and why.
- Interests: none known.
- Weigh: trust the non-randomised PIT and the score properties. Case studies are small
  (70 firms, 60 dependent projections); says little on testing differences.

## Findings

- [stats/scoring] For a discrete predictive distribution the plain PIT is not uniform
  even for an ideal forecast; the randomised PIT u = P(x-1) + v(P(x) - P(x-1)), v
  uniform, is. Section 2.1 ^f1
  > In the case of count data, the predictive distribution is discrete. Here, the PIT is no longer uniform under the hypothesis of an ideal forecast
  > To remedy this, several authors have suggested a randomized PIT.
- [stats/scoring] Non-randomised PIT: replace each randomised value by its conditional
  CDF given the count (uniform on [P(x-1), P(x)]), average these over cases, and plot
  bin j's height as Fbar(j/J) - Fbar((j-1)/J); expectation is uniform under
  calibration. J = 10 or 20. Section 2.1 ^f2
  > Here we propose a non-randomized yet uniform version of the PIT histogram.
  > Typically, J = 10 or J = 20 are good choices for the number of bins in the PIT histogram.
- [stats/scoring] Shapes read as for continuous PIT: U shaped is underdispersed (too
  narrow), hump shaped overdispersed, skewed means biased centre. Section 2.1 ^f3
  > U-shaped histograms indicate underdispersed predictive distributions, hump or inverse-U shaped histograms point at overdispersion, and skewed histograms occur when central tendencies are biased.
- [stats/scoring] A uniform PIT histogram is equivalent to every prediction interval
  having nominal coverage; coverage of one interval is a special case. With the
  non-randomised PIT, coverage of [alpha, beta] is Fbar(beta) - Fbar(alpha), the
  expectation of the randomised coverage. Section 2.1 ^f4
  > uniformity of the PIT histogram is a strong requirement, being equivalent to all prediction intervals showing nominal coverage
  > the empirical coverage is computed as the difference F̄ (β) − F̄ (α) of the mean non-randomized PIT (5) at the probability limits α and β
- [stats/scoring] Marginal calibration diagram: average predicted mass per count value
  or bin against observed frequencies. Section 2.2 ^f5
  > A marginal calibration diagram illustrates the predicted probability mass for
- [stats/scoring] Interval width as a sharpness measure is less useful for discrete
  predictive distributions because the intervals are ambiguous; they judge sharpness
  through proper scores instead. Section 2.3 ^f6
  > we have found these tools to be less useful for discrete
  > Our preferred way of addressing sharpness is indirectly, via proper scoring rules
- [stats/scoring] Proper scores for counts: log score (-log p_x, the only proper score
  depending only on the mass at the outcome; predictive deviance is a variant with a
  standardising term they set to zero), quadratic (Brier), spherical, ranked
  probability score, Dawid-Sebastiani. Section 3.2 ^f7
  > This is the only proper scoring rule that depends on the predictive distribution P only through the probability mass px at the observed count
  > propose for simplicity that the standardizing term is taken to be zero
- [stats/scoring] The ranked probability score (discrete CRPS) generalises absolute
  error and reduces to it for a point forecast, so it compares point and
  distributional forecasts directly. Section 3.2 ^f8
  > The ranked probability score generalizes the absolute error, to which it reduces if P is a point forecast.
- [stats/scoring] No automatic choice of score without a clear decision problem; use
  several. Section 3.2 ^f9
  > There is no automatic choice of a proper scoring rule to be used in any given situation, unless there is a unique and clearly defined underlying decision problem.
- [stats/scoring] Scale dependence: RPS and squared error grow with the size of the
  counts, so a few high-count cases can dominate the mean; in the larynx case the
  scale-free scores (log, quadratic, spherical, DSS) picked Model 1 while RPS and
  squared error picked Model 4, driven by the mid age groups with the highest counts.
  Sections 3.2, 5 ^f10
  > Hence, a few, or even a single high count case can dominate and obscure differences in the mean score.
  > Hence the results in the mid age groups, where the counts are highest and Model 4 is more competitive, dominate the mean score.
- [stats/scoring] Mean squared error is proper but not strictly proper (blind to
  spread); in the simulation all three forecasters had the same MSE while the PIT and
  proper scores told them apart. Sections 3.3, 3.4 ^f11
  > Viewed as a scoring rule for probabilistic forecasts, this score is proper, but not strictly proper.
  > Of course, the predictive mean, and therefore the mean squared error, is the same for all three forecasts.
- [stats/scoring] The mean squared Pearson residual (should be near 1) is non-robust:
  outliers gave 12.5 and 91.6, reversing the verdict of the PIT and proper scores.
  Section 4 ^f12
  > However, the mean normalized squared error can blow up under outliers, which is the case here.
- [stats/scoring] Formal inference is feasible but often not the goal; tools are
  mainly diagnostic, with proper scores used to rank. Section 6 ^f13
  > Formal inference is often feasible (Clements, 2005; Jolliffe, 2007), but may not be the goal.
- [stats/scoring] (inferred) For a win count k out of n games with predictive
  Beta-binomial or binomial P, PIT on the count is discrete and uneven when n is
  small (n = 5 gives only 6 steps). Use the non-randomised PIT (or the randomised one
  with a fixed seed) per kind and mode: a calibrated Meio shows flat bars; raw modes,
  whose ranges ignore prior uncertainty on thin cells, should show a U. ^f14
- [stats/scoring] (inferred) Our 80% coverage check is the PIT mass between 0.1 and 0.9:
  with non-randomised PIT it is Fbar(0.9) - Fbar(0.1) averaged over cells, which
  removes the noise and the rounding bias of counting "inside" on a discrete grid. ^f15
- [stats/scoring] (inferred) Pooling cells with very different n (a champion with 50k
  games, a duo with 40) makes count-scale scores dominated by the big cells; score
  rates (win rate) rather than counts, or use a scale-free score, or report per
  sample-size band. ^f16

## Read

- Sections 1-6 of the preprint.

## Not read

- Appendices (Poisson and NB formulas, ordered categorical generalisation): only
  needed when implementing.
