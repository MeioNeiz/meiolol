---
title: 'Efron 2014: Two modeling strategies for empirical Bayes estimation'
url: https://arxiv.org/pdf/1409.2677
kind: paper
commit:
for: [thin-cell-ranges]
looked: 2026-11-04
depth: docs (sections 1-2, 5, 7; 3-4 and 6 skimmed)
relevance: medium
grade: A/strong
description: Statistical Science 2014 paper contrasting g-modelling (a smooth exponential-family prior on a grid of theta) with f-modelling, with delta-method accuracy formulas for the estimated posterior
---
# Efron 2014: Two modeling strategies for empirical Bayes estimation

Why: Efron's g-modelling is the smooth alternative to the lumpy NPMLE prior; how is it
built, how accurate is an estimated posterior, and is it worth it for per-cell ranges.
(The Biometrika 2016 "Empirical Bayes deconvolution estimates" paper is paywalled; this
open precursor has the same g-model.)

## Assessment

- Evidence: A. Statistical Science 2014, by the founder of modern EB practice; method
  later shipped as R deconvolveR.
- Reasoning: strong. Gives accuracy formulas and shows when accuracy is poor.
- Interests: none known.
- Weigh: discrete theta and x grids, unit-variance normal sampling; examples are
  z-values, not heteroscedastic cells. Accuracy numbers are for one-dimensional theta.

## Findings

- [stats/eb] g-modelling models the prior on the theta scale; f-modelling models the
  marginal of the observations. Abstract ^f1
  > "There are two main estimation strategies: modeling on the θ space, called “g-modeling” here, and modeling on the x space, called “f -modeling.”"
- [stats/eb] Discrete set-up: prior g on a grid of m theta values, sampling matrix
  P (p_ij = Pr{x_i | theta_j}), f = P g; the posterior for any x_i is
  diag(p_i) g / p_i g, so any posterior quantity is a weighted sum over the grid.
  Section 2 ^f2
  > "Pr{θj |xi } = pij gj /fi"
- [stats/eb] Efron's g-model: g(alpha) = exp(Q alpha - phi(alpha)) on the grid, Q a
  natural spline basis with a few degrees of freedom (5-6), fitted by maximum
  likelihood. Section 5 ^f3
  > "Here α is the unknown q-dimensional natural parameter of exponential family (5.1), which determines the prior distribution g = g(α)."
- [stats/eb] Known shape can be added to Q, e.g. an atom at 0 as an extra column
  (spline plus spike). Section 5 ^f4
  > "We can accommodate this by including in model matrix Q (5.1) a column e0"
- [stats/eb] g-modelling advantages: positive, constraint-respecting prior estimates; often
  smaller sd of posterior estimates, especially for discontinuous targets such as
  Pr{theta <= 0 | x}. Section 5 ^f5
  > "With some important exceptions, discussed in Section 6, g-modeling often yields smaller values of sd(Ê), as typified in the bottom panel of Figure 5."
- [stats/eb] Cost: the g-model likelihood is non-convex (curved exponential family) and
  needs numerical optimisation; the NPMLE version needs Laird's EM. Section 7 ^f6
  > "We pay the price up front with “g-modeling,” where models such as (5.2) require difficult nonconvex maximum likelihood computations, while the subsequent Bayesian computations become straightforward."
- [stats/eb] Accuracy of an estimated posterior can be poor: the posterior tail
  probability at x > 2 would need over 20,000 observations for a 10% coefficient of
  variation; fewer spline degrees of freedom help at the risk of bias. Section 7 ^f7
  > "would still require more than N = 20,000 independent observations Xk to get the coefficient of variation down to 0.1 when x exceeds 2."
  > "More aggressive g-modeling, reducing the degrees of freedom for Q, improves accuracy, at the risk of increased bias."
- [stats/eb] Even with 6033 cases, local false discovery rate estimates from the g-model
  had coefficients of variation around 25%. Section 6 ^f8
  > "Even with N = 6033 cases, the standard deviations of c fdr(x) are considerable, having coefficients of variation in the 25% range."
- [stats/eb] Efron's warning: EB outside the classic cases is ill-posed and may need
  strong model choices. Section 7 ^f9
  > "empirical Bayes estimation has an ill-posed aspect that may call for draconian model choices."
- [stats/eb] Theory has centred on the NPMLE prior; parametric g-modelling mostly on the
  normal-normal case. Section 5 ^f10
  > "Much of that work involves the nonparametric maximum likelihood estimation of the prior distribution g(θ), some notable references being Laird (1978), Zhang (1997) and Jiang and Zhang (2009)."
- [stats/eb] (inferred) For us: a g-model is a middle way between our Gaussian prior and
  the NPMLE, a smooth log-spline density on the same grid that can grow a heavy tail or
  a second bump without the NPMLE's lumpy atoms. With 10^4-10^5 cells per family we are
  in the range where Efron's accuracy is acceptable for central quantities, but the far
  tail of the prior (where a lone outlier lives) is estimated from a handful of cells
  and stays uncertain (^f7). Neither g-model nor NPMLE alone guarantees per-cell
  coverage there. ^f11
- [stats/eb] (inferred) Fit cost in Zig: q = 5-7 parameters, likelihood is a sum over
  cells of log(P g) with P n x m; Newton or L-BFGS with an analytic gradient
  (Lemma 1 gives the Fisher information) on 10^5 x 300 is seconds. Non-convex, so start
  from the Gaussian fit. ^f12

## Read

- Sections 1, 2, 5 (method, advantages, spike example), 7 discussion.

## Not read

- Sections 3-4 (f-modelling, Bayes rule in terms of f, Theorems 1-3) and Section 6
  (Robbins, James-Stein, fdr as f-modelling) beyond the prostate fdr result.
- Efron 2016 Biometrika "Empirical Bayes deconvolution estimates" (paywalled; covariates
  in the g-model, penalised likelihood): logged as a lead via deconvolveR JSS 2020.
