---
title: 'Piironen and Vehtari 2017: Sparsity information and regularization in the horseshoe and other shrinkage priors'
url: https://arxiv.org/pdf/1707.01694
kind: paper
commit:
for: [thin-cell-ranges]
looked: 2026-11-04
depth: docs (abstract, sections 2, 3.1-3.3, 3.5 start, 5, 6)
relevance: high
grade: A/strong
description: Electronic Journal of Statistics 2017 (arXiv 1707.01694, Aalto); regularised horseshoe (horseshoe with a finite Gaussian slab), the shrinkage-factor view tying horseshoe to spike-and-slab, and a prior for the global scale tau from a guess of the number of nonzero terms
---
# Piironen and Vehtari 2017: Sparsity information and regularization in the horseshoe and other shrinkage priors

Why: thin-cell-ranges sub-question: what sparse, heavy-tailed prior keeps a lone real
pair effect (a hard counter) while shrinking the many near-zero pair terms, and what it
costs to fit.

## Assessment

- Evidence: A. Standard reference for the regularised horseshoe (Stan, brms and rstanarm
  default sparse prior); Vehtari a recognised expert; experiments on synthetic and 4
  real datasets.
- Reasoning: strong. Derives the shrinkage profile, ties it to spike-and-slab, admits
  costs (MCMC time, divergences, multimodality) and that no tau prior is globally best.
- Interests: none beyond the authors' own method and Stan ecosystem.
- Weigh: written for regression with full Bayes by MCMC; we have a normal-means
  setting (one pair term per cell, X = I), where its formulas simplify. Interval
  coverage is not measured: it compares predictive accuracy, not range honesty.

## Findings

- [stats/eb] Horseshoe: each coefficient is normal with scale tau times a local
  half-Cauchy lambda_j; the global tau pulls everything to zero, the Cauchy tails let
  a few escape. Section 2.1 ^f1
  > the global parameter τ pulls all the weights globally towards zero, while the thick halfCauchy tails for the local scales λj allow some of the weights to escape the shrinkage
- [stats/eb] For any scale mixture of normals the posterior mean is (1 - kappa_j) times
  the raw estimate, with shrinkage factor kappa_j = 1 / (1 + n sigma^-2 tau^2 lambda_j^2);
  under the horseshoe kappa has a Beta(1/2, 1/2) (horseshoe-shaped) prior, so a priori
  terms are either kept or zeroed. Section 2.1, eq. 2.3-2.5 ^f2
  > The result (2.4) holds for any prior that can be written as a scale mixture of Gaussians like (2.2), regardless of the prior for λj .
  > a priori, we expect to see both relevant
- [stats/eb] The spike-and-slab is a two-component normal mixture (narrow spike eps,
  wide slab c, inclusion probability pi); its shrinkage factor has mass at only two
  values, and with an infinitely wide slab it resembles the horseshoe; the two have
  performed comparably. Section 2.2 ^f3
  > The prior is often written as a two-component mixture of Gaussians
  > Given the similarity of the shrinkage profiles between the horseshoe and spike-and-slab, it is not surprising that the two priors have shown comparable performance in a variety of experiments
- [stats/eb] The plain horseshoe leaves strong signals unshrunk (posterior mean tends
  to the raw estimate as it grows), which harms weakly identified parameters; the
  regularised horseshoe adds a finite Gaussian slab of width c so even the largest
  terms get some shrinkage. Section 2.3 ^f4
  > While this guarantees that the strong signals will not be overshrunk – and is often considered to be one of the key assets of the prior – this property can also be harmful, especially when the parameters are weakly identified.
  > the prior will shrink the small signals as the horseshoe but will also regularize even the largest coefficients as a Gaussian slab with variance c2 .
- [stats/eb] The regularised horseshoe is the continuous counterpart of spike-and-slab
  with a finite slab; c states the largest effect we expect. Abstract, section 2.3 ^f5
  > the new prior can be considered as the continuous counterpart of the spike-and-slab prior with a finite slab width
  > allows us also to specify our prior information about the maximum effect βj we expect to see.
- [stats/eb] A point estimate of tau by maximum marginal likelihood (empirical Bayes)
  can collapse to tau = 0 when the vector is very sparse, and plug-in ignores tau's
  uncertainty; they recommend full Bayes for tau. Section 3.1 ^f6
  > The maximum marginal likelihood estimate has the drawback that it is always in danger of collapsing to τ̂ = 0 if the parameter vector happens to be very sparse.
  > fails to account for the posterior uncertainty
- [stats/eb] Tau should be set from a guess p0 of how many terms are nonzero:
  tau0 = p0 / (D - p0) * sigma / sqrt(n); for the normal-means case (X = I) the
  reference is p0 / (D - p0) * sigma, matching the optimal rate of van der Pas et al.
  Section 3.3, eq. 3.12-3.13 ^f7
  > if our prior guess for the number of relevant variables is p0 , it is reasonable to choose the prior so that most of the prior mass is located near the value
  > in terms of mean squared error and posterior contraction rates
- [stats/eb] For non-Gaussian likelihoods (logistic for win rates) the same analysis
  holds approximately with sigma replaced by a pseudo-variance from the Taylor
  expansion of the log-likelihood. Section 3.5 ^f8
  > The discussion in Section 3.3 therefore also approximately holds for the nonGaussian observation model, except that σ 2 is replaced by σ̃ 2 .
- [stats/eb] Cost: full Bayes by MCMC took 30-60 minutes on the two biggest problems
  versus under a second for Lasso; the plain horseshoe had 1-30% divergent transitions,
  the regularised one very few. Section 4.2 ^f9
  > the computation starts to get quite involved for the two biggest problems (around 30–60 minutes for Prostate and Leukemia datasets), which is the price for the full Bayesian inference.
  > for the original horseshoe the fraction varies between 1–30% which is really a lot.
- [stats/eb] Recommendation: regularised horseshoe with a weakly informative prior on
  c (inverse gamma, a Student-t slab) and tau ~ half-Cauchy(0, tau0^2) from the p0
  guess, checked against a looser c. Section 5 ^f10
  > we recommend using the regularized horseshoe with a weakly informative prior on c
- [stats/eb] Checked, not there: interval coverage or calibration of per-coefficient
  ranges; only predictive accuracy and sampling robustness are compared. ^f11
- [stats/eb] (inferred) For us a pair term is a normal mean (X = I) with its own known
  standard error from the cell's games, so the shrinkage factor per cell is closed form
  given (tau, lambda_j); only the hyperparameters need integrating, which is cheap in
  one dimension per pair kind but the per-cell lambda_j mixture has no closed-form
  posterior, unlike a finite normal mixture. ^f12
- [stats/eb] (inferred) A two-component normal mixture (spike sd eps, slab sd c) is the
  discrete version of the regularised horseshoe by the paper's own account (f3, f5),
  so we lose little in shape by fitting the mixture, and gain a closed-form posterior
  per cell; c caps the largest counter we believe, which guards against a thin cell's
  noise being read as a huge counter. ^f13
- [stats/eb] (inferred) The tau collapse (f6) is our risk if pair-kind
  hyperparameters are fitted by marginal likelihood: a spike variance at 0 would make
  every cell's range too narrow. Floor it, or integrate over it. ^f14

## Read

- Abstract, sections 2 (all), 3.1-3.3, start of 3.5, 4.2 summary, 5, 6.

## Not read

- Section 4.1 synthetic experiments and Appendix A derivation: detail of the toy runs.
