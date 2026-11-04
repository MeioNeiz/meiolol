---
title: 'Gneiting and Raftery 2007: Strictly proper scoring rules, prediction, and estimation'
url: https://sites.stat.washington.edu/raftery/Research/PDF/Gneiting2007jasa.pdf
kind: paper
commit: 
for: [forecast-judging]
looked: 2026-11-04
depth: listed (1, 2.3, 4.1-4.2, 6, 8.2-8.3, 9.3, 10; theory of 2.1-2.2, 3, 5, 7 skipped)
relevance: high
grade: A/strong
description: JASA 2007 review article defining proper scoring rules; source of the interval score for central (1 - alpha) intervals, CRPS identities, quantile (pinball) score and the caveat that skill scores are improper
---
# Gneiting and Raftery 2007: Strictly proper scoring rules, prediction, and estimation

Why: which proper score judges an 80% range (and a point estimate) in one number, and
how to compare Meio with the raw 30 day and patch modes on it.

## Assessment

- Evidence: A. JASA review article, the standard reference for proper scoring rules
  and the interval score; very widely cited and used (COVID Forecast Hub, M4/M5).
- Reasoning: strong. Proofs of propriety, case studies showing improper scores
  mislead (linear and probability scores pick near-deterministic forecasts) and an
  interval case where the sharpest nominally calibrated interval loses on the score.
- Interests: none known.
- Weigh: trust the definitions and propriety results. Written for continuous targets;
  says little on testing differences (points to Diebold and Mariano).

## Findings

- [stats/scoring] A scoring rule is proper if quoting your true belief maximises the
  expected score; propriety makes forecasters careful and honest, and scores rank
  competing procedures. Abstract, Section 1 ^f1
  > A scoring rule is proper if the forecaster maximizes the expected score for an observation drawn from the distribution F if he or she issues the probabilistic forecast F
  > scoring rules measure the quality of the probabilistic forecasts, reward probability assessors for forecasting jobs, and rank competing forecast procedures
- [stats/scoring] Procedures are ranked by average score, and scores are only directly
  comparable on exactly the same set of forecast cases. Section 2.3 ^f2
  > competing forecast procedures are ranked by the average score
  > Scores for competing forecast procedures are directly comparable if they refer to exactly the same set of forecast situations.
- [stats/scoring] Skill score: (S_fcst - S_ref) / (S_opt - S_ref), 1 for a perfect
  forecast, 0 for the reference, negative when worse than the reference; the reference
  is usually a climatological forecast. Section 2.3 ^f3
  > takes the value 1 for an optimal forecast
  > and the value 0 for the reference forecast. Negative values of a skill score indicate forecasts that are of lesser quality than the reference.
- [stats/scoring] Skill scores are generally improper even if the underlying score is
  proper (Brier skill only asymptotically proper as forecasts grow); the authors lean
  to "little harm" but want follow-up. Sections 2.3, 10 ^f4
  > Unfortunately, skill scores of the form (8) are generally improper, even if the underlying scoring rule S is proper.
  > Briggs and Ruppert (2005) have argued that skill score departures from propriety do little harm. Although we tend to agree, there is a need for follow-up studies.
- [stats/scoring] Climatological forecasts are calibrated by construction but often
  lack sharpness. Section 2.3 ^f5
  > they are calibrated by construction, but often lack sharpness
- [stats/scoring] Log score is the predictive deviance, strictly proper, but harshly
  penalises low probability events and is highly sensitive to extreme cases; with
  densities on discrete outcomes it rewards spiking on target values. Sections 4.1,
  8.2 ^f6
  > involves a harsh penalty for low probability events and thus is highly sensitive to extreme cases
  > If Lebesgue densities on the real line are used to predict discrete observations, then the logarithmic score encourages the placement of artificially high density ordinates on the target values in question.
- [stats/scoring] CRPS is defined on the CDF (so works for point masses and samples),
  is the integral of Brier scores over thresholds, is sensitive to distance, and in
  negative orientation is in the observation's units and reduces to absolute error
  for a point forecast, so it compares point and probabilistic forecasts directly.
  Section 4.2 ^f7
  > corresponds to the integral of the Brier scores for the associated binary probability forecasts at all real-valued thresholds
  > it generalizes the absolute error to which it reduces if F is a deterministic forecast
  > Thus the CRPS provides a direct way to compare deterministic and probabilistic forecasts.
- [stats/scoring] CRPS = E|X - x| - 0.5 E|X - X'| (negative orientation), closed form
  for a Gaussian, O(n log n) for a sample. Section 4.2 ^f8
  > If the predictive distribution takes the form of a sample of size n, then the right side of (20) can be evaluated in terms of the respective order statistics
- [stats/scoring] Quantile score (tick or pinball loss) S(r; x) = (x - r)(1{x <= r} -
  alpha) is proper for the alpha quantile. Section 6.1 ^f9
  > the econometric literature refers to the scoring rule (41) as the tick or check loss function
- [stats/scoring] Interval score for a central (1 - alpha) interval [l, u]:
  IS = (u - l) + (2/alpha)(l - x)1{x < l} + (2/alpha)(x - u)1{x > u}; negatively
  oriented and proper. Width is rewarded, misses are penalised by distance times
  2/alpha. Section 6.2, eq. 43 ^f10
  > yields the negatively oriented interval score
  > The forecaster is rewarded for narrow prediction intervals, and he or she incurs a penalty, the size of which depends on α, if the observation misses the interval.
- [stats/scoring] The interval score catches what coverage plus width miss: of three
  95% intervals with near nominal coverage, the sharpest (K, width 3.79) loses on the
  score to the true conditional interval (I, width 4.00, score 4.77 vs 5.32), because
  K collapses when uncertainty is highest. Section 6.3, Table 2 ^f11
  > The interval forecasts I, J, and K all showed close to nominal coverage, with the prediction interval K being sharpest on average. Nevertheless, the classical prediction interval I performed best in terms of the interval score.
- [stats/scoring] Comparing interval estimators needs equal nominal coverage (or equal
  width); then the interval score is the loss, and it weighs a miss by distance, not
  only in or out. Section 9.3 ^f12
  > we contend that a meaningful comparison of interval estimators requires either equal coverage or equal width
  > the loss function (61) provides a more flexible assessment of the coverage, by taking the distance between the interval estimate and the estimand into account
- [stats/scoring] The interval score assesses both calibration and sharpness; in the
  case study the inflation factor minimising it (r = 1.72 at 90%) differs from the one
  giving nominal coverage (2.11). Section 8.3 ^f13
  > This scoring rule assesses both calibration and sharpness, by rewarding narrow prediction intervals and penalizing intervals missed by the observation.
- [stats/scoring] Improper scores mislead in practice: the linear and probability
  scores chose inflation r = 0.05 and 0.02, near-deterministic forecasts. Section 8.2 ^f14
  > However, they are improper, and their use may result in misguided scientific inferences, as in this experiment.
- [stats/scoring] Checked, not there: no worked method for testing score differences
  or for discrete targets; points to Diebold and Mariano 1995 and others as future
  work. Section 10 ^f15
- [stats/scoring] (inferred) For our 80% ranges alpha = 0.2, so IS = width + 10 x
  (distance outside the range). A raw mode with no range must be given one (e.g. its
  binomial or bootstrap 80% interval) to be scored; a bare point gets width 0 and
  IS = 10 x |error|, ten times the absolute error, so not comparable with MAE
  unless scaled. ^f16
- [stats/scoring] (inferred) The gate's two conditions map onto one proper score: IS
  at alpha = 0.2 rewards narrower ranges only while misses stay rare, so "beat the
  patch on certainty" is "lower mean IS on the same cells", and coverage is a
  diagnostic beside it, not the gate. ^f17
- [stats/scoring] (inferred) Cells differ in scale (a win rate in percentage points,
  gold14 in gold, shares in fractions), and IS is in the target's units, so average
  within one kind, or divide each cell's IS by the reference's IS on the same cell
  before pooling kinds. ^f18

## Read

- Abstract, 1, 2.3 (skill scores), 4.1-4.2 (log score, CRPS), 6.1-6.3 (quantile and
  interval scores, case study), 8.2-8.3 (case study), 9.3 (interval estimation), 10.

## Not read

- 2.1-2.2, 3, 5, 7 (representation theorems, kernel scores, Bayes factors): theory,
  not needed to choose a score.
