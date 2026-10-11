---
title: 'Eilers and Marx 2010: Splines, Knots, and Penalties'
url: https://www.stat.cmu.edu/~brian/valerie/617-2022/617-2021/0%20-%20nonparametric%20methods/splines/Splines,%20Knots%20and%20Penalties%20(Eilers%20&%20Marx).pdf
kind: paper
commit:
for: [curve-statistics-method]
looked: 2026-10-11
depth: docs (sections 1, 4, 9, mixed model and variance estimation)
relevance: high
grade: A/strong
description: The P-spline inventors' review (WIREs Comp Stat 2010 preprint) of penalised smoothing, incl. the discrete Whittaker smoother and choosing lambda from a variance ratio
---
# Eilers and Marx 2010: Splines, Knots, and Penalties

Why: how to smooth a per-minute curve (gold diff at minutes 1..30) with a closed-form,
dependency-free method that also handles thin or missing late minutes.

## Assessment

- Evidence: A. Authors invented P-splines (1996 Statistical Science paper, widely
  cited); this is their 2010 review preprint, author copy on a CMU course page.
- Reasoning: strong. Compares two schools, gives equations, admits trade-offs.
- Interests: they advocate their own approach (B-splines vs truncated power functions);
  irrelevant to us since we only need the discrete case.
- Weigh: the discrete (Whittaker) case is exactly a per-minute series: one coefficient
  per minute, a banded linear system, trivial in Zig.

## Findings

- [stats] [method] P-splines: many equally spaced basis functions plus a difference
  penalty on neighbouring coefficients; smoothness is set by the penalty weight alone. ^f1
  > By using equally spaced knots and a large number of B-splines, the role of the basis is reduced to little more than a convenient smooth interpolation device. The penalty is the core ingredient of the model: smoothness is tuned by changing its weight.
- [stats] Large lambda tends to a straight line (second-order penalty) or a quadratic
  (third order); d = 2 or 3 is usual. ^f2
  > Mostly d = 2 or d = 3 is used.
  > In the limit of a very large λ a linear (d = 2) or quadratic (d = 3) fit is obtained.
- [stats] [method] For data already on an equally spaced discrete grid, use the
  identity basis: one value per point, a banded system; this is Whittaker's 1923
  smoother for life tables. ^f3
  > In such a setting a Bspline basis of degree zero, with a knot at every observation, may be an attractive choice.
  > This brings us back full circle to Whittaker (1923), who used this approach to smooth life tables.
- [stats] The discrete smoother is fast even for 100,000 points, including leave-one-out
  cross-validation (Eilers 2003). ^f4
  > a series of a hundred thousand observations can be smoothed in a few seconds, including leave-one-out crossvalidation.
- [stats] Gaps with no data are interpolated smoothly by the penalty (zero weights);
  extrapolation past the data continues as a polynomial of lower degree. ^f5
  > Notice that in large parts of the domain of x there are no data but ample knots. Yet the automatically generated interpolating curves are smooth and look natural. This is the work of the penalty.
- [stats] [method] Lambda need not be hand-tuned: in the mixed-model view it is the
  ratio of residual variance to the variance of the differences, re-estimated in a
  few iterations. ^f6
  > In the mixed model sense, λ can be interpreted as the ratio between the variance of y − Bα, σ 2 , and the variance of Dα, τ 2 .
  > One repeats smoothing, estimating the variances and recomputing λ until convergence. This generally occurs surprisingly fast, often in less than 10 iterations.
- [stats] Alternatively choose the penalty by AIC or cross-validation against the
  effective dimension. ^f7
  > plot an information criterion (e.g. AIC) or a cross-validation measure against the effective dimension
- [stats] [method] (inferred) For a matchup curve: y_t = mean diff at minute t, weight
  w_t = n_t / s_t^2 (games alive at t over within-minute variance); solve
  (W + lambda D2'D2) z = W y, a pentadiagonal system of ~30 unknowns. Thin late
  minutes get small weight and follow the smooth trend instead of noise. ^f8
- [stats] (inferred) Smoothing across minutes and shrinkage across matchups are the same
  idea (penalised least squares with a variance-ratio penalty), which makes one
  coherent story for the method page. ^f9

## Read

- Sections 1, 4 (penalties), interpolation, 9 (discrete smoothing), mixed models and
  the hybrid variance-ratio lambda estimate

## Not read

- PT-spline comparisons, multidimensional smoothing, derivative estimation; Eilers 2003
  "A perfect smoother" (paywalled, ACS)
