---
title: 'Ghosh, Hastie, Owen 2022: Scalable logistic regression with crossed random effects'
url: https://arxiv.org/pdf/2105.13747
kind: paper
commit: 
for: [hierarchical-comp-terms]
looked: 2026-10-18
depth: docs (sections 1, 3-3.1, 5.1, 6, 7)
relevance: high
grade: A/strong
description: EJS 2022 (Stanford); logistic GLMM with crossed random effects fitted by Schall's penalised quasi-likelihood with backfitting, O(N) per iteration; 5M Stitch Fix ratings, 744k clients x 3.5k items
---
# Ghosh, Hastie, Owen 2022: Scalable logistic regression with crossed random effects

Why: how to fit a logistic model with several batches of random effects (ours: role,
kit group, champion levels of a slope) and estimate each batch's variance at millions
of rows without MCMC.

## Assessment

- Evidence: A. Hastie and Owen, Electronic Journal of Statistics 2022; builds on their
  Annals 2022 backfitting paper; proofs plus timings against glmer and a 5M-row real
  dataset.
- Reasoning: strong. States the cost problem, why plain IRLS and glmer fail, what the
  approximation costs and where the theory stops (iteration count not bounded).
- Interests: authors' own algorithm; data from a sponsor (Stitch Fix).
- Weigh: trust the algorithm and the cost argument; their crossed factors are 744k x
  3.5k, far bigger than our ~170 champions x 16 traits, so cost is not our problem but
  the variance update and the clubbing trick are.

## Findings

- [stats] [method] GLS and Gibbs for crossed random effects cost more than N^(3/2);
  backfitting inside penalised quasi-likelihood brings it to O(N) per iteration.
  Abstract ^f1
  > The cost of both generalized least squares (GLS) and Gibbs sampling in a crossed random effects model can easily grow faster than N 3/2 for N observations.
- [method] Fit: Schall (1991) penalised IRLS. Each step is a weighted ridge on a
  working response, with each random-effect batch penalised by 1 / sigma^2 of that
  batch. Section 3.1, eq. 14 ^f2
  > we solve the penalized weighted least squares problem
- [stats] [method] Variance update per batch: sigma^2 = ||a||^2 / (R - nu), where nu
  is the trace of the batch's block of the inverse penalised Hessian over sigma^2, a
  degrees-of-freedom estimate; an EM step after the Laplace approximation. Section
  3.1, eq. 16 ^f3
  > From these formulas it is clear that the ν parameters function as degrees of freedom estimates.
- [stats] The estimate is the posterior mode under a diffuse prior on the fixed part and
  zero-mean Gaussian priors on the random effects, close to the MLE except near 0 or
  1 probabilities. Section 3.1 ^f4
  > the posterior mode of β under a diffuse prior on β independent of a zero-mean Gaussian prior for (a, b).
- [method] Gotcha: a fixed predictor that is a property of the row level (an item's
  material, a customer's profile) overlaps the random effects' span, slowing
  alternating updates; the penalised estimates for that subset must sum to zero.
  Fix: update fixed effects together with each random-effect block ("clubbing").
  Section 1, 4 ^f5
  > In such cases there is an overlap of vector spaces like the one described above for the intercept.
  > The penalized likelhood estimate for the corresponding subset of a must sum to zero.
- [method] Clubbing mattered much more for binary outcomes than for least squares.
  Section 1 ^f6
  > we found it made a much greater difference in the binary regression case than we saw in the generalized least squares setting.
- [stats] Timings: glmer grows about N^1.68 for their design; backfitting about O(N),
  in both per-iteration and total time. Section 5.1 ^f7
  > At the largest values of N , the timings follow the same asymptotic rates, approximately O(N 1.68 ) and O(N ), as we saw for individual iterations.
- [stats] Stitch Fix: 5,000,000 ratings, 744,482 clients, 3,547 items, 34 fixed
  parameters including item material (items nested within material, as our champions
  within a kit group); converged in 14 iterations. Section 6 ^f8
  > There were N = 5,000,000 ratings from 744,482 clients on 3,547 items.
  > the item factor is nested within the levels of the material predictor
- [stats] Ignoring the random effects, plain logistic regression understated the
  variance of item-level fixed coefficients by 2.7x to 1467x; the worst were material
  indicators. Section 6 ^f9
  > They range from 2.72 to 1467.05 and can be interpreted as factors by which logistic regression naively overestimates its sample size.
- [stats] Checked, not there: random slopes, three or more crossed factors, held-out
  prediction comparison; the paper is about estimation and variance, not predictive
  gain. ^f10
- [method] (inferred) For us: a group-level slope fitted as a fixed coefficient with
  champion-role random slopes nested inside it is exactly their material/item case.
  ^f9 says the group slope's se from a fit without the champion level is far too
  small (the kit groups' p values from pooled seat rows would be overconfident unless
  the champion-level spread is in the model, as champgroups' 1/(se^2 + tau^2) weights
  partly do); ^f5 says the group and champion parts must be updated together or
  alternating fits converge slowly. ^f11
- [method] (inferred) ^f2/^f3 is a no-MCMC recipe for us: penalised IRLS with one
  ridge penalty per batch (role slopes, group slopes, champion-role slopes), and
  Schall's update for each batch's variance between IRLS passes; at ~8M seat rows and
  a few thousand slope parameters the exact Hessian blocks fit in memory, so the trace
  needs no approximation. ^f12

## Read

- Abstract, 1, 2 (skimmed), 3-3.1, 5.1, 6, 7.

## Not read

- Section 3.2+ (trace approximation proofs), 4 (clubbing details), 5.2 accuracy
  simulation, Appendix A tables.
