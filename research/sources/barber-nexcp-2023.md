---
title: 'Barber, Candes, Ramdas, Tibshirani 2023: Conformal Prediction Beyond Exchangeability (nonexchangeable conformal, NexCP)'
url: https://arxiv.org/pdf/2202.13415
kind: paper
commit:
for: [share-drift-ranges]
looked: 2026-11-04
depth: listed (abstract, 1, 4.4 examples, 5.1-5.2 experiments, discussion)
relevance: high
grade: A/strong
description: Annals of Statistics 2023 paper giving conformal intervals with fixed decaying weights on past calibration points (e.g. 0.99^age) and a coverage-gap bound in total variation, for drift and changepoints; tested on simulations and ELEC2 electricity data
---
# Barber, Candes, Ramdas, Tibshirani 2023: Conformal Prediction Beyond Exchangeability

Why: the batch counterpart to ACI: calibrate share ranges on past (estimate, outcome)
pairs, weighting recent ones more, with a bound on how much drift costs.

## Assessment

- Evidence: A. Annals of Statistics 2023, four leading conformal authors; code released.
- Reasoning: strong. Bound with no distributional assumption, worked drift and
  changepoint cases, honest about extra width and variability.
- Interests: none.
- Weigh: the bound is only small if the chosen weights put little mass on far-off
  points; the weights must be fixed in advance, not tuned on the same data.

## Findings

- [stats/shares] Conformal needs exchangeable data; under drift it is not, and one may
  also want a fit that favours recent points; NexCP handles both with weighted
  quantiles. Abstract ^f1
  > example, if the data distribution drifts over time, then the data points are
  > employ weighted quantiles to introduce robustness against distribution drift,
- [stats/shares] With fixed weights w_i the coverage gap is at most sum w_i
  dTV(Z, Z^i) / (1 + sum w_i), with no assumption on the joint distribution; with equal
  weights it is ordinary conformal. Section 1.2 ^f2
  > do not make any assumption on the joint distribution of the n + 1 points.
  > First, for wi ≡ 1 and a symmetric algorithm,
- [stats/shares] Weights must be fixed (not data-dependent) for the bound to apply.
  Section 1.2 ^f3
  > the result will only be meaningful if we are able to select fixed (non-data-dependent)
- [stats/shares] [method/dynamics] Under drift, use weights decaying with age, w_i =
  rho^(n+1-i); with drift bounded by eps per step the gap is at most about 2 eps / (1 -
  rho); after a changepoint k steps ago it is at most rho^k. Section 4.4 ^f4
  > we would want to choose weights wi that decay as we move into the distant
  > past, for example, wi = ρn+1−i for some decay parameter ρ ∈ (0, 1).
- [stats/shares] Weighting does not hurt coverage when the data are exchangeable, but
  costs a little width and more variability (fewer effective points). Sections 1.2,
  5.1 ^f5
  > does not hurt coverage if the data are exchangeable.
  > since using decaying weights wi for computing the prediction intervals leads to a
- [stats/shares] In simulated drift, unweighted conformal's coverage declined as drift
  grew (mean 0.838 for a 0.9 target) while NexCP with rho = 0.99 held about 0.89-0.91;
  on ELEC2 0.852 vs about 0.89. Section 5, Tables 1-2 ^f6
  > in Setting 3 the coverage for CP+LS
  > declines gradually over time as the distribution drift grows.
- [stats/shares] Fitting the model itself with recency weights (WLS) gave narrower
  intervals than weighting only the calibration; after a changepoint it briefly
  over-covered, because old residuals still carry weight. Section 5.1 ^f7
  > NexCP+WLS overcovers for a period of time after each
- [stats/shares] Positioned against ACI: ACI adjusts the nominal level online from
  attained coverage; NexCP reweights the calibration scores. Section 1.3 ^f8
  > they iteratively increase (or decrease) the nominal level αt to
- [stats/shares] (inferred) For us: a patch is a changepoint and within-patch adoption
  is drift. Calibrate the share-range multiplier from past (estimate, later outcome)
  pairs per slot kind, weighted by decay in days (and zero weight across a patch
  boundary, which the rho^k bound says costs little if rho is small enough), then a
  conformal quantile of |z| per lead-time bucket. This is the batch, auditable
  counterpart to ACI and fits our daily truth runs. ^f9
- [stats/shares] (inferred) The NexCP+WLS lesson matches ours: the bigger win is a
  base estimate that already weights recent days (or filters, as a local level does);
  conformal then only fixes the leftover miscalibration. ^f10

## Read

- Abstract, 1 (incl. related work), 4.4 (drift and changepoint examples), 5.1-5.2
  (simulations, ELEC2), discussion

## Not read

- 2-3 (full conformal, jackknife+, randomised tags), 4.1-4.3 proofs, 5.3 election
  example
