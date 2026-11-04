---
title: 'Jiang and Zhang 2009: General maximum likelihood empirical Bayes estimation of normal means'
url: https://arxiv.org/pdf/0908.1709
kind: paper
commit:
for: [thin-cell-ranges]
looked: 2026-11-04
depth: docs (sections 1-2, 5, 6.2-6.3; theory in 3-4 skimmed)
relevance: high
grade: A/strong
description: Annals of Statistics 2009 paper proposing GMLEB, the posterior mean under the Kiefer-Wolfowitz NPMLE prior, with near-oracle risk proofs and simulations against James-Stein and threshold rules
---
# Jiang and Zhang 2009: General maximum likelihood empirical Bayes estimation of normal means

Why: what does a fully nonparametric prior (NPMLE) cost against James-Stein when the
truth is normal, and what does it gain when it is sparse or clustered.

## Assessment

- Evidence: A. Annals of Statistics 2009, the reference modern NPMLE EB paper (Zhang is
  a leading figure in compound decisions); oracle inequality plus four simulation tables
  on the Johnstone-Silverman design.
- Reasoning: strong. Frames the trade-off explicitly (greedier benchmark vs more
  degrees of freedom) and reports where JS wins.
- Interests: own method.
- Weigh: homoscedastic, unit variance, no covariates, squared-error loss only; no
  intervals. Koenker-Mizera extends to covariates and unequal variances.

## Findings

- [stats/eb] GMLEB: estimate the prior by the generalised MLE over all distributions,
  then use that prior's Bayes rule (posterior mean). No tuning. Section 2.2 ^f1
  > "the GMLEB estimator (2.15) is completely nonparametric and does not require any restriction, regularization, bandwidth selection or other forms of tuning."
- [stats/eb] Theory: average MSE within an infinitesimal fraction of the best separable
  rule (the oracle Bayes rule for the empirical distribution of the true means) once the
  risk exceeds (log n)^5/n. Abstract ^f2
  > "the average mean squared error (MSE) of the GMLEB is within an infinitesimal fraction of the minimum average MSE among all separable estimators which use a single deterministic estimating function on individual observations"
- [stats/eb] James-Stein is a restricted EB: best linear rule given the first two
  moments, so it is near-optimal only when the true means look normal. Section 1 ^f3
  > "it achieves the general EB optimality when the empirical distribution of the unknown means are approximately normal."
- [stats/eb] Fit: discrete prior on a fine grid (999-1000 points over the data range),
  weights by EM; posterior mean is a weighted sum over grid points. 100 EM iterations in
  their simulations. Section 2.3 ^f4
  > "We ran 100 EM-iterations (2.19) in our simulations."
- [stats/eb] The NPMLE puts all its mass inside [min X_i, max X_i]. Section 2.3 ^f5
  > "the generalized MLE (2.12) puts all its mass in the interval I0 = [min1≤i≤n Xi , max1≤i≤n Xi ]"
- [stats/eb] Sparse or clustered means (n = 1000, k at mu, rest 0): GMLEB and S-GMLEB beat
  James-Stein by large margins, e.g. k = 50 at mu = 5: 58 against 556; dense and
  moderately sparse cases are clear wins over threshold rules too. Section 2.4, Table 1 ^f6
  > "with the S-GMLEB and GMLEB clearly outperforming all other methods by large margins for dense and moderately sparse signals."
- [stats/eb] Truly normal means: James-Stein is best and tracks the oracle; the GMLEB
  is close behind (n = 1000, sigma^2 = 0.1: JS 92-93, GMLEB 94-95). Section 5, Table 4 ^f7
  > "Indeed, the James–Stein estimator is the top performer throughout all the columns and tracks the oracle risk extremely well, while the GMLEB is not so far behind."
- [stats/eb] Overall: big gains over JS for sparse means and over thresholds for dense
  means, little downside. Section 6.3 ^f8
  > "the gain of the GMLEB is huge against the James–Stein estimator for sparse means and against threshold estimators for dense means."
- [stats/eb] Grid size and EM stopping have a data-driven guarantee: m about
  sqrt(n) log n points and stop when the max log weight ratio falls below a bound.
  Section 6.2 ^f9
  > "m ≍ (log n) n and ε ≍ (n log n)−1/2"
- [stats/eb] The NPMLE is not unique and EM's start matters with a fixed iteration count;
  starting with mass at 0 helps sparse signals (S-GMLEB). Section 2.3 ^f10
  > "This nonuniqueness persists even when we run infinitely many EM-iterations."
- [stats/eb] Checked, not there: no intervals, coverage or posterior spread; squared
  error only. ^f11
- [stats/eb] (inferred) For us: the downside of swapping our Gaussian prior for an
  NPMLE prior, if our cells were truly Gaussian, is a few percent MSE (^f7); the upside
  if they are heavy-tailed or have a few real outliers is large (^f6). The posterior from
  a grid prior also gives a full per-cell posterior (weights over grid points), so an 80%
  range is two quantiles of a discrete distribution, no extra fit. ^f12
- [stats/eb] (inferred) Range caveat: because all mass sits inside the observed range
  (^f5) and the prior is lumpy (few atoms), raw NPMLE posterior quantiles can be too
  narrow or jumpy for thin cells; a smoothed grid prior (Efron's g-modelling) or a
  small floor of a broad component is the usual guard. ^f13

## Read

- Sections 1, 2.1-2.4, 5 (tables), 6.2-6.3.

## Not read

- Sections 3-4 and the appendix proofs (oracle inequality, l_p minimaxity).
