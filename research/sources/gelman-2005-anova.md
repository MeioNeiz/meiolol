---
title: 'Gelman 2005: Analysis of variance, why it is more important than ever'
url: https://arxiv.org/pdf/math/0504499v2
kind: paper
commit:
for: [curve-statistics-method]
looked: 2026-10-11
depth: docs (abstract, sections 1, 3.1-3.3)
relevance: high
grade: A/strong
description: Annals of Statistics 2005 discussion paper: ANOVA as a hierarchical model with one batch of effects per row (main effects, interactions), each with its own variance component that sets the shrinkage
---
# Gelman 2005: Analysis of variance, why it is more important than ever

Why: canonical framing for the additive champion-baseline model: matchup = grand mean +
champion A effect + champion B effect + A x B interaction, with the interaction batch
shrunk by its own estimated variance.

## Assessment

- Evidence: A. Annals of Statistics discussion paper by a leading applied Bayesian;
  widely cited basis of multilevel ANOVA.
- Reasoning: strong. Argues why, handles the classical/Bayesian split, discusses when
  point estimates of variances fail.
- Interests: none (some self-promotion of Bayesian computation).
- Weigh: general theory; we need only the two-way case (A main, B main, A x B).

## Findings

- [stats] [method] Treat every ANOVA row (main effects, interactions) as a batch of
  random effects with mean 0 and a standard deviation estimated from data. ^f1
  > we treat every row in the table as a batch of “random effects”; that is, a set of regression coefficients drawn from a distribution with mean 0 and some standard deviation to be estimated from the data.
- [stats] Coefficients are pulled toward zero by an amount set by the batch's variance
  component; batches with near-zero variance are shrunk most. ^f2
  > From the hierarchical model the coefficient estimates will be pulled toward zero, with the amount of shrinkage determined by the estimated variance components.
  > There will be more shrinkage for batches of effects whose standard deviations σm are near zero, which will occur for factors that contribute little variation to the data.
- [stats] Classical (point estimate of variances) and Bayesian inference agree given
  the variances; the difference matters only when a variance is hard to tell from 0. ^f3
  > The main difference between classical and Bayesian methods here is between using a point estimate for the variance parameters or including uncertainty distributions.
  > Only when these variances are hard to distinguish from 0.
- [stats] Setting such a variance to zero gives falsely precise estimates; near-zero
  variances are expected for higher-order interactions. ^f4
  > Setting the variance parameter to zero in such a situation is generally not desirable because it would lead to falsely precise estimates
  > we expect (in fact, we hope) to see various near-zero variances at higher levels of interaction.
- [stats] [method] (inferred) For us: the matchup interaction gamma_AB (beyond A's
  average lead and B's average deficit) is the batch to shrink; if its estimated
  variance per role and minute is small, most thin matchups should collapse to the
  additive prediction. Floor tau^2 above zero (or report it) rather than claim
  matchups are exactly additive. ^f5

## Read

- Abstract, section 1, 3.1-3.3 (regression formulation, batching, classical vs Bayesian)

## Not read

- Examples (Latin square, internet connect times), discussions and rejoinder
