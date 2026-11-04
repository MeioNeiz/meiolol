---
title: 'Pfeffermann 2013: New important developments in small area estimation'
url: https://arxiv.org/pdf/1302.4907
kind: paper
commit:
for: [thin-cell-ranges]
looked: 2026-11-04
depth: docs (abstract, sections 5.1-5.2, 6.1-6.3, 6.5, remark 5, 9)
relevance: high
grade: A/fair
description: Statistical Science 2013 review of small area estimation (Southampton, Hebrew University); Fay-Herriot area-level model, EBLUP and EB, prediction MSE with estimated variance (Prasad-Rao and successors), prediction intervals, benchmarking, t random effects and robust EB for outlying areas
---
# Pfeffermann 2013: New important developments in small area estimation

Why: thin-cell-ranges sub-question: how small area estimation gives per-area MSE and
ranges when the between-area variance is estimated, and how it treats outlying areas.
Stands in for Fay and Herriot 1979 and Rao's book, which are not open.

## Assessment

- Evidence: A. Statistical Science review by a leading survey statistician, covering
  the literature after Rao (2003); two-thirds of the field's standard methods in one
  place.
- Reasoning: fair. A survey: states results and orders of error, defers proofs to the
  originals; candid on open choices (which t model, Bayes vs frequentist).
- Interests: none.
- Weigh: secondary for Prasad-Rao, Datta-Lahiri, Bell-Huang and Ghosh-Maiti-Roy;
  cite their results through it, check the originals before relying on exact terms.
  pdftotext interleaves the two columns in places; quotes taken from clean runs.

## Findings

- [stats/eb] Fay-Herriot area-level model: direct estimate = true area value + sampling
  error with known variance; true value = covariates times beta + area effect with
  variance sigma_u^2. The predictor shrinks the direct estimate towards the synthetic
  (regression) estimate with weight gamma_i = sigma_u^2 / (sigma_u^2 + sigma_Di^2).
  Section 5.2.1 ^f1
  > The model, studied originally for SAE by Fay and Herriot (1979) is defined as
  > ei represents the sampling error, assumed to have zero mean and known design
- [stats/eb] With sigma_u^2 unknown and replaced by an estimate, this is the EBLUP or
  (under normality) the EB predictor; hierarchical Bayes puts priors on beta and
  sigma_u^2 instead. Section 5.2.1 ^f2
  > In practice, the variance σu2 is seldom known and is replaced in γi and β̂GLS by a sample estimate, yielding what is known as the empirical BLUP (EBLUP) under the frequentist approach, or the empirical Bayes (EB) predictor when assuming normality.
- [stats/eb] Bayes handles accuracy automatically from the posterior; frequentist MSE
  and intervals are harder because estimating the hyperparameters adds variability.
  Prasad and Rao (1990) gave MSE estimators with bias o(1/m), m the number of sampled
  areas. Section 6.1 ^f3
  > estimation of the prediction MSE (PMSE) and the computation of confidence intervals (C.I.) under the frequentist approach is complicated because of the added variability induced by the estimation of the model hyper-parameters.
  > Prasad and Rao (1990) developed PMSE estimators with bias of order o(1/m), (m is the number of sampled areas)
- [stats/eb] The MSE splits into the error of the best predictor with known parameters
  (M1) plus the extra error from estimating them (M2); jackknife and bootstrap estimate
  both, for logistic mixed models too. Section 6.1, eq. 6.2 ^f4
  > M2i is the contribution to the PMSE from estimating the model parameters
- [stats/eb] Unconditional MSE averages over the random effects; Lohr and Rao (2009)
  estimate the MSE conditional on the area's own data instead. Section 6.1 ^f5
  > The jackknife estimator estimates the unconditional PMSE over the joint distribution of the random effects and the responses.
- [stats/eb] The plug-in interval (EB estimate plus or minus z times root MSE) has
  coverage error of order O(1/m); recent work cuts it with a parametric bootstrap
  (Hall and Maiti; Chatterjee, Lahiri and Li, whose error is in total sample size n).
  Section 6.2 ^f6
  > use of this prediction interval has coverage error of
  > order O(1/m), which is not sufficiently accurate.
  > coverage error via parametric bootstrap.
- [stats/eb] Benchmarking forces model predictions to add up to a reliable aggregate
  direct estimate, as a guard against a misspecified model. Section 6.3 ^f7
  > Benchmarking robustifies the inference by forcing the model-based predictors to agree with a designbased estimator for an aggregate of the areas for which the design-based estimator is reliable.
- [stats/eb] Outliers: Bell and Huang put a Student-t on the area effects (a normal
  scale mixture, delta_i around 1, a large delta_i flags an outlying area), which pushes
  that area's prediction towards its own direct estimate; t on sampling errors pushes
  towards the synthetic part instead; which to use is open. Section 6.5 ^f8
  > A large value δi signals the existence of an outlying area mean θi .
  > The effect of assuming the model for the random effects is to push the small area predictor (the posterior mean) toward the direct estimator
  > at present it is not clear how to choose between the two models.
- [stats/eb] Ghosh, Maiti and Roy: robust EB caps the standardised residual with a
  Huber function, so an outlying area is shrunk by at most a fixed amount, with an
  MSE estimator correct to O_p(1/m). Section 6.5 ^f9
  > the authors propose therefore to replace the EB predictor obtained from (5.2) by the robust EB predictor
- [stats/eb] The spread of EB estimates understates the true range of area means (and
  direct estimates overstate it); constrained EB shrinks less. Remark 5 ^f10
  > the range of the direct estimators overestimates the true range, whereas the range of the empirical Bayes estimators underestimates the true range
- [stats/eb] The review favours Bayes for flexibility and because its MSE and
  credibility intervals do not rest on asymptotics. Section 9 ^f11
  > the computation of PMSE (Bayes risk) or credibility intervals under BA does not rely on asymptotic properties.
- [stats/eb] (inferred) For us m is the number of cells in a pair kind (thousands of
  matchups per role pair), so the Prasad-Rao term for estimating sigma_u^2, of order
  1/m (f3, f6), is tiny next to each thin cell's own posterior variance; it matters only
  for a pair kind with few cells (a bracket x region slice) or when the variance
  estimate sits near 0. Integrating over the hyperparameters (a grid over 1-3
  numbers per kind) covers both cases at little cost. ^f12
- [stats/eb] (inferred) The bigger risk to per-cell coverage is not M2 but the prior's
  shape: a Gaussian Fay-Herriot range is right on average over cells (unconditional,
  f5) and too narrow and too far from the data for the few real outliers; a t or
  mixture on the pair term (f8) is the SAE answer, and it is the same idea as a
  spike-and-slab. ^f13
- [stats/eb] (inferred) Benchmarking (f7) maps to us as: the shrunk matchup terms for
  a champion should add back to its well-measured overall rate; an additive model with
  zero-sum pair terms does this by construction. ^f14

## Read

- Abstract, sections 5.1-5.2 (model definitions), 6.1-6.3, 6.5, remark 5 in 6.7,
  section 9.

## Not read

- Design-based section 4, measurement errors 6.4, informative sampling 7, model
  checking 8: off our question, though 8 may help test the prior's shape.
