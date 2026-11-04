---
title: 'Gneiting, Balabdaoui, Raftery 2007: Probabilistic forecasts, calibration and sharpness'
url: https://sites.stat.washington.edu/raftery/Research/PDF/Gneiting2007jrssb.pdf
kind: paper
commit: 
for: [forecast-judging]
looked: 2026-11-04
depth: listed (sections 1-3 in full, 4.2-4.4 and 5 read, 4.1 and appendix skipped)
relevance: high
grade: A/strong
description: JRSS B 2007 paper that sets the "maximise sharpness subject to calibration" paradigm, shows PIT uniformity is not enough, and ranks forecasters with CRPS
---
# Gneiting, Balabdaoui, Raftery 2007: Probabilistic forecasts, calibration and sharpness

Why: how should the truth test judge an 80% range plus a point estimate: what is
calibration, what is sharpness, and which one number ranks Meio against raw modes?

## Assessment

- Evidence: A. JRSS B, the canonical reference for the calibration-sharpness paradigm;
  the authors are the field's leading names in forecast evaluation; thousands of
  citations.
- Reasoning: strong. Theory (modes of calibration, theorems with proofs), a simulation
  with four forecasters that all pass the PIT check, and a real case study (5136 wind
  speed forecasts, three methods).
- Interests: one of the compared methods (RST) is the authors' own.
- Weigh: trust the paradigm and the PIT counter-example. Written for continuous
  targets; the discrete case is Czado et al 2009. Testing guidance is thin (refers to
  Diebold and Mariano).

## Findings

- [stats/scoring] The paradigm: maximise sharpness of the predictive distributions
  subject to calibration. Calibration is a joint property of forecasts and outcomes;
  sharpness is a property of the forecasts only. Summary ^f1
  > based on the paradigm of maximizing the sharpness of the predictive distributions subject to calibration
  > Sharpness refers to the concentration of the predictive distributions and is a property of the forecasts only.
- [stats/scoring] A uniform PIT histogram is necessary but not sufficient: a
  climatological forecaster (always the long-run marginal) and two biased forecasters
  give PIT histograms as uniform as the ideal one, and 50% and 90% coverage near
  nominal. Section 1, Table 3 ^f2
  > Fig. 1 shows that the PIT histograms for the four forecasters are essentially uniform.
  > Nevertheless, the PIT cannot distinguish between the ideal forecaster and her competitors.
- [stats/scoring] What separates them is width: the ideal forecaster's 90% intervals
  average 3.29 against 4.65 for the climatological one, with the same coverage.
  Table 4 ^f3
  > Climatological 1.91 4.65
- [stats/scoring] Empirical coverage of central intervals is read straight off the PIT
  histogram (area of the central bins), so coverage adds nothing beyond the PIT.
  Section 3.1 ^f4
  > This information is redundant, since the empirical coverage can be read off the PIT histogram
- [stats/scoring] Reading a PIT histogram: hump shaped means intervals too wide,
  U shaped means too narrow, triangle shaped means biased. 10 or 20 bins. Section 3.1 ^f5
  > Hump-shaped histograms indicate overdispersed predictive distributions with prediction intervals that are too wide on average.
  > U-shaped histograms often correspond to predictive distributions that are too narrow.
  > Triangle-shaped histograms are seen when the predictive distributions are biased.
- [stats/scoring] Formal uniformity tests are hindered by dependence, especially when
  PIT values are pooled; use the histogram as a diagnostic. Section 3.1 ^f6
  > the use of formal tests is often hindered by complex dependence structures
- [stats/scoring] Marginal calibration: compare the average predictive CDF with the
  empirical CDF of outcomes (forecast climate against actual climate); a separate
  check that PIT does not cover. Section 3.2 ^f7
  > Marginal calibration concerns the equality of forecast climate and actual climate.
- [stats/scoring] Sharpness is assessed by the width of central prediction intervals:
  average width, or box plots of widths (sharpness diagram) when widths vary a lot
  between forecasts. Section 3.3 ^f8
  > To assess sharpness, we use numerical and graphical summaries of the width of prediction intervals.
  > The average width then is insufficient to characterize sharpness
- [stats/scoring] Proper scoring rules address calibration and sharpness at once and
  rank competing forecasters; scores are penalties to minimise. Section 3.4 ^f9
  > in that they address calibration and sharpness simultaneously
- [stats/scoring] CRPS is proper, in the units of the observation, more robust than the
  log score, and reduces to absolute error for a point forecast, so CRPS and MAE can
  sit side by side. Sections 3.4, 4.4 ^f10
  > the continuous ranked probability score generalizes the absolute error, to which it reduces if F is a point forecast
  > The logarithmic score is the negative of the logarithm of the predictive density evaluated at the observation
  > it lacks robustness
- [stats/scoring] CRPS equals the Brier score integrated over all thresholds. Section 3.4 ^f11
  > the area under each forecaster’s curve equals the CRPS value
- [stats/scoring] Comparing methods: they score month by month and use a sign test
  (RST beat autoregressive in all 7 months, p = 1/128), choosing blocks that are
  roughly independent; for tests they defer to Diebold and Mariano 1995.
  Section 4.4 ^f12
  > care needs to be taken to avoid dependences in the forecast differentials
  > Diebold and Mariano (1995) gave a thoughtful discussion of these issues
- [stats/scoring] Their single recommendation: assess sharpness, especially when
  ranking; earlier comparisons looked only at point accuracy and PIT uniformity.
  Section 5 ^f13
  > If we were to reduce our conclusions to a single recommendation, we would close with a call for the assessment of sharpness, particularly when the goal is that of ranking.
- [stats/scoring] (inferred) Our "raw last 30 days" mode is close to their
  climatological forecaster when a cell is stable: it can show good coverage while
  being wide. So "holds ~80%" alone cannot gate Meio; the gate must reward width at
  fixed coverage, which a proper score does. ^f14
- [stats/scoring] (inferred) Their monthly sign test maps to us as per-day (or
  per-patch) blocks of the truth test: score each block, count the blocks Meio wins;
  days are closer to independent than single cells that share champions. ^f15

## Read

- Summary, sections 1-3 in full; 4.2-4.4 (PIT, sharpness, CRPS results); 5 discussion.

## Not read

- Section 4.1 (the wind forecast models) and Appendix A proofs: not needed for scoring.
