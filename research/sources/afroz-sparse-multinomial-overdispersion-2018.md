---
title: 'Afroz 2018: Estimating Overdispersion in Sparse Multinomial Data (PhD thesis, Otago)'
url: https://ourarchive.otago.ac.nz/view/pdfCoverPage?instCode=64OTAGO_INST&filePid=13397251820001891&download=true
kind: paper
commit:
for: [share-drift-ranges]
looked: 2026-11-04
depth: skimmed (abstract, 1.4, 2.2, 2.4, 4.1, 5)
relevance: high
grade: B/strong
description: PhD thesis (Afroz, supervised by Fletcher and Parry; published as Biometrics 2020) on estimating the quasi-likelihood dispersion phi for sparse multinomial data, comparing Pearson, Farrington, deviance and a new Fletcher-type estimator, with beta-binomial and Dirichlet-multinomial variance derivations
---
# Afroz 2018: Estimating Overdispersion in Sparse Multinomial Data (PhD thesis, Otago)

Why: our shares (item, keystone within a champion) are multinomial counts clustered by
player; how to estimate phi robustly when many categories are rare, and whether one phi
per slot is enough.

## Assessment

- Evidence: B. PhD thesis whose core result was published in Biometrics 76(3) 2020
  (Afroz, Parry, Fletcher); builds on Wedderburn 1974, Farrington 1996, Fletcher 2012.
  Simulation evidence only, no large real-data benchmark.
- Reasoning: strong. Derives variances, states the third-cumulant assumption behind
  the new estimator and reports where it loses (mixtures).
- Interests: none (proposes its own estimator, so read its comparison with that in mind).
- Weigh: the variance formulas are textbook and safe; the estimator ranking is from
  simulations under DM and mixtures, plausible for us but worth a check on our data.

## Findings

- [stats/shares] Quasi-likelihood needs only var = phi x multinomial variance, so it is
  likely more robust than a fully specified Dirichlet-multinomial. Abstract ^f1
  > Use of quasilikelihood has the advantage of only requiring specification of the first two moments of the
  > response variable, and is therefore likely to be more robust than use of a specific model
- [stats/shares] Clustered binary trials (random P per cluster, or correlation rho between
  trials in a cluster) give var = [1 + (m - 1) tau] m pi (1 - pi): the design effect
  form; no overdispersion with clusters of size 1. Section 2.2.2 ^f2
  > = mi E(Pi )(1 − E(Pi )) + mi (mi − 1)var(Pi )
  > Note that overdispersion can only occur if mi > 1.
- [stats/shares] Dirichlet-multinomial: the covariance is the multinomial covariance
  times one factor phi = 1 + (m - 1) tau, common to all categories, but phi grows with
  the cluster size m. Section 4.1 ^f3
  > and the term 1 + (mi − 1)τ measures the amount of overdispersion φ.
  > hence overdispersion will vary according to the
- [stats/shares] A logistic-normal model (random normal error on the logit) is an
  alternative way to represent binomial overdispersion. Section 2.2.3 ^f4
  > An alternative means of representing overdispersion in binomial data involves adding
  > a random error term to the linear predictor
- [stats/shares] The usual estimator is phi_P = X^2 / (n - p) (Pearson over residual
  df), but X^2 is unreliable for sparse data. Section 2.4.1 ^f5
  > It is well known in the lack of fit setting that X 2 , may not be reliable for sparse
- [stats/shares] The Fletcher-type estimator divides phi_P by 1 + s-bar, s-bar the mean
  of (y - mu) / mu; with little sparsity s-bar is near 0 and the estimators agree.
  Section 2.5 ^f6
  > When there is little sparsity, the size of s̄ will be very small and
- [stats/shares] In simulations the new estimator had the lowest RMSE on sparse DM
  data, but on mixtures of DMs Farrington's was sometimes better (the new one up to 52%
  higher RMSE). Sections 4.5, 5 ^f7
  > sparse, our estimator φ̂N ew had the lowest root mean squared error (RMSE).
  > Here, φ̂N ew is worse compared to φ̂F in some places giving up to 52% higher RMSE.
- [stats/shares] Checked, not there: no method for a confidence interval on phi itself
  (left as future work, expected to be fragile on sparse data). Section 5 ^f8
  > It would also be interesting to develop a good method of calculating a confidence interval for
- [stats/shares] (inferred) For us: one phi per slot is consistent with DM and
  quasi-multinomial (one factor for all items in the slot), but phi = 1 + (m - 1) tau
  scales with games per player m, so a phi fitted on a 3-day window understates a
  14-day window and differs between one-trick-heavy and casual champions. Better: fit
  tau (intra-player correlation) per slot or role, and compute phi per cell from its own
  m-bar (sum m_i^2 / sum m_i over players), the clustering design effect. ^f9
- [stats/shares] (inferred) For sparse item slots (many items under 2%), estimate phi by
  Pearson X^2 over players divided by (1 + s-bar), not by the deviance; with player as
  the cluster this is cheap per slot and robust to the long tail. ^f10

## Read

- Abstract, 1.4, 2.2 (binomial overdispersion models), 2.4 (estimators), 4.1 (DM), 5

## Not read

- Chapter 3 (mark-recovery examples), most of chapter 4 simulations, appendices
  (derivations of third and fourth moments)
