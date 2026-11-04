---
title: 'Koenker and Mizera 2014: Convex optimization, shape constraints, compound decisions, and empirical Bayes rules'
url: http://www.econ.uiuc.edu/~roger/research/ebayes/brown.pdf
kind: paper
commit:
for: [thin-cell-ranges]
looked: 2026-11-04
depth: docs (sections 1-8, preprint of 20 Nov 2013)
relevance: high
grade: A/strong
description: JASA 2014 paper recasting the Kiefer-Wolfowitz NPMLE prior on a fixed grid as a convex problem solved by interior point methods; simulations, batting averages and a binomial mixture
---
# Koenker and Mizera 2014: Convex optimization, shape constraints, compound decisions, and empirical Bayes rules

Why: can a nonparametric (grid) prior replace our Gaussian prior, how is it fitted, how
fast, and does it work with heteroscedastic cells, a regression mean and binomial data.

## Assessment

- Evidence: A. JASA 2014; Koenker (quantile regression) and Mizera; method shipped as R
  REBayes (CRAN), the standard NPMLE implementation since; reproduces Jiang-Zhang and
  Johnstone-Silverman simulation tables.
- Reasoning: strong. Reports where its own method loses (baseball: IP worse than EM
  out of sample) and explains the cost limits (dense n x m matrix).
- Interests: authors' own method and package.
- Weigh: timings are 2013 Mosek in R; the dense-matrix limit (n = 10^4 about an hour)
  is before binning and before later fast solvers. Point prediction (squared error) is
  judged, not intervals.

## Findings

- [stats/eb] Kiefer-Wolfowitz NPMLE: maximise the marginal likelihood over all mixing
  distributions F; convex objective over a convex set; the solution is discrete with at
  most n atoms. Section 3, Theorem 2 ^f1
  > "The solution, F̂, of (6) exists, and is an atomic probability measure, with not more than n atoms."
- [stats/eb] On a fixed grid u_1..u_m it is a finite convex problem: weights f on the
  simplex, A_ij = phi(Y_i - u_j); solved via its dual with interior point methods; the
  posterior mean is a weighted average over grid points. Section 4.2 ^f2
  > "Let A be the n by m matrix, with the elements ϕ(Yi − uj ) in the i-th row and j-th column."
- [stats/eb] EM (the older fixed-point fit, as in Jiang-Zhang) converges very slowly; the
  interior point solver got a higher likelihood in 15 iterations and 1 s than EM in
  100,000 iterations and 559 s (n = 200, m = 300). Section 4.2, Table 1 ^f3
  > "Although the EM procedure makes steady progress toward its goal, it leaves something to be desired even after 100,000 iterations, and nearly 10 minutes of computation."
- [stats/eb] Scale limit: with a dense A, n = 10,000 took about an hour in Mosek; binning
  observations on a fine grid and weighting by bin counts made it cheap (600-point grid).
  Section 5 ^f4
  > "Solving a single problem with n = 10, 000 requires about one hour using the Mosek interior point algorithm"
  > "it is possible to bin the observations on a fairly fine grid and employ a slight variant of the proposed interior point approach in which the likelihood terms are weighted by the relative (multinomial) bin counts."
- [stats/eb] The NPMLE finds a small real cluster away from the bulk: 15 of 200 at mu = 2,
  rest at 0, it puts a mass point near 2 (and one spurious point near -1). Section 4.2 ^f5
  > "remarkably the procedure does find, in this particular sample, a mass point near 2, as well as much more significant mass point near 0. A spurious mass point near -1 is also identified."
- [stats/eb] On sparse designs (most means 0, a few at 3-7) the NPMLE rule (GMLEB-IP)
  beats James-Stein-type and kernel rules and is about the best of Johnstone-Silverman's
  18 procedures; e.g. k = 500 at mu = 7: 18 against 505 for the best of the 18.
  Section 5, Table 2 ^f6
  > "However, the GMLEB rules have a clear advantage when k is 50 and 500."
- [stats/eb] Covariates and unequal variances work: Y_i = z_i'beta + xi_i + u_i with
  u_i ~ N(0, sigma_i^2), xi_i from the NPMLE; alternate between beta and F (each F step
  convex, the joint problem is not). Section 6 ^f7
  > "although the mixture likelihood problem is convex for each value of the regression parameter, β, the joint problem of optimizing over β and F is not convex"
- [stats/eb] Batting averages (arcsine transform, 567 players): the NPMLE was not better
  than a James-Stein shrink to a good regression; with pitcher x at-bats covariates EBJS
  scored TSE 0.171 against 0.178-0.206 for the NPMLE variants, and the IP fit, though
  higher likelihood, predicted worse than EM. Section 6, Table 4 ^f8
  > "we find that the interior point predictive performance is consistently worse than the EM results."
- [stats/eb] (inferred) So when the regression mean is good and the residual spread is
  near normal, a nonparametric prior buys little on average squared error; its gain is in
  sparse or clustered or heavy-tailed effect distributions. ^f9
- [stats/eb] Binomial data directly: the same dual with A built from binomial likelihoods
  p^y (1-p)^(n-y) on a grid of p; thumbtack data (320 x 9 flips) solved in 0.012 s against
  10 minutes for 1,000,000 EM steps. Section 7 ^f10
  > "While the convex optimization requires only 0.012 seconds in R, the fixed point EM implementation requires 599 seconds for 1,000,000 iterations"
- [stats/eb] The NPMLE posterior mean is monotone in y whatever the prior, unlike kernel
  estimates of Tweedie's formula. Section 1 ^f11
  > "the implied decision rule, obtained by substituting this estimate for F, is automatically monotone—as the latter property holds regardless of the form of the prior."
- [stats/eb] Checked, not there: no intervals or coverage; the paper judges squared-error
  prediction only. ^f12
- [stats/eb] (inferred) For a lone real outlier: the NPMLE has no fixed shape, so if one
  cell's data sit far from the rest it can place an atom near it (as with the cluster at
  2, ^f5), and that cell is then shrunk towards its own atom rather than to the bulk.
  A Gaussian prior with estimated sd cannot do this: its tail is set by the bulk. The
  catch: one point's atom carries mass about 1/n, so for a thin cell (large sigma_i) the
  posterior still mostly goes to the bulk; the outlier is spared only once its own data
  are strong. That is the behaviour we want ("extraordinary claims need extraordinary
  evidence"), with no tail parameter to tune. ^f13
- [stats/eb] (inferred) Cost for us in Zig: one grid prior per pooled family (e.g. ~300
  points), 10^4-10^5 cells. One EM step is n x m multiply-adds (10^5 x 300 = 3e7, tens of
  ms); a convex solve of the dual or many EM steps in src/par.zig fits in seconds to
  minutes on the gpu-box or Mac. Heteroscedastic sigma_i stops simple binning on y alone
  (A_ij = phi((Y_i - u_j)/sigma_i)/sigma_i), but binning on (y, sigma) or working on
  t-statistics keeps it small. ^f14

## Read

- Sections 1-8 closely; Appendix A proofs skipped.

## Not read

- Appendix proofs. Koenker's later notes on the same page: "cieb.pdf" (EB confidence
  intervals from the NPMLE vs Efron's logspline) and "Empirical Bayes for the reluctant
  frequentist" (logged as leads).
