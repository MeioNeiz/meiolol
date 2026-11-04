---
title: 'Johnstone and Silverman 2004: Needles and straw in haystacks, empirical Bayes estimates of possibly sparse sequences'
url: https://arxiv.org/pdf/math/0410088
kind: paper
commit:
for: [thin-cell-ranges]
looked: 2026-11-04
depth: docs (abstract, sections 1, 2.1-2.3, 3 conclusions, 4.2)
relevance: high
grade: A/strong
description: Annals of Statistics 2004 (Stanford, Oxford); empirical Bayes spike-and-slab for normal means, a point mass at 0 plus a heavy-tailed slab (Laplace or quasi-Cauchy), weight and scale by marginal maximum likelihood, posterior median thresholding; R package EbayesThresh
---
# Johnstone and Silverman 2004: Needles and straw in haystacks, empirical Bayes estimates of possibly sparse sequences

Why: thin-cell-ranges sub-question: an empirical Bayes spike-and-slab fitted by
marginal likelihood, and whether a Gaussian slab is good enough to keep a lone real pair
effect.

## Assessment

- Evidence: A. Canonical reference for EB sparse normal means, by two recognised
  experts; rate-optimality proofs plus a simulation study; EbayesThresh software.
- Reasoning: strong. States assumptions, proves risk bounds, compares 10+ rival
  threshold rules and says where theirs loses (hard universal threshold wins at
  mu0 = 7).
- Interests: own method.
- Weigh: unit, known, equal noise variance and independent errors; point estimation
  risk only, no intervals or coverage. Our cells have unequal standard errors and a
  binomial likelihood.

## Findings

- [stats/eb] Setting: many normal means each seen once with N(0, 1) noise; prior is a
  mixture of an atom at zero (weight 1 - w) and a heavy-tailed density gamma (weight
  w), w by marginal maximum likelihood, which adapts between sparse and dense.
  Abstract, section 1.2 ^f1
  > The prior considered is a mixture of an atom of probability at zero and a heavy-tailed density γ, with the mixing weight chosen by marginal maximum likelihood, in the hope of adapting between sparse and dense sequences.
- [stats/eb] They argue against the normal slab used in earlier wavelet work: heavier
  tails (Laplace, or polynomial tails) have advantages. Section 1.2 ^f2
  > the density γ is a normal density, but we shall see that there are advantages in using a heavier-tailed prior, for example, a double exponential distribution or a distribution with tails that decay at polynomial rate.
- [stats/eb] Their theory needs slab tails exponential or heavier, so the Gaussian slab
  is ruled out; tails no heavier than Cauchy. Section 2.1 ^f3
  > Thus, the tails of γ have to be exponential or heavier, and the Gaussian model for γ is ruled out.
- [stats/eb] Bounded shrinkage: with a slab whose log-density slope is bounded
  (Laplace), a large observation is pulled in by at most the threshold plus a constant,
  for posterior median and mean alike; a large real effect keeps its size. Section 2.3 ^f4
  > |x − δ(x, t)| ≤ t + b
  > the posterior median will be a thresholding rule and will have the bounded shrinkage property if |(log γ)′ | is bounded
- [stats/eb] Fitting is cheap: the score in w is monotone so its root is found
  numerically; a Laplace slab's scale can be fitted by marginal maximum likelihood
  too with a gradient routine. Section 1.2, 2.2 ^f5
  > The function ℓ′ (w) is a monotonic function of w, so its root is very easily found numerically
  > If γ is the Laplace density, the tractability of the procedure is not affected by the inclusion of a scale parameter into the prior.
- [stats/eb] Simulation (n = 1000, 5/50/500 nonzero of size 3-7): the Cauchy slab is
  nearly as good as the Laplace one; posterior mean slightly worse than median;
  estimating the slab scale beats fixing it; EB is more stable than FDR, SURE and
  block methods. Section 3 ^f6
  > The Cauchy method is always nearly, but not quite, as good as the exponential method.
  > Estimating the scale parameter a is probably preferable to using a fixed value
  > This is an indication of the stability of the empirical Bayes methods.
- [stats/eb] The threshold must be tuned to the sparsity; a dense-signal threshold on a
  sparse signal, or the reverse, is disastrous. Section 1.1 ^f7
  > if a threshold appropriate for dense signals is used on a sparse signal, or vice versa, the results are disastrous.
- [stats/eb] Checked, not there: credible intervals or coverage of the EB posterior;
  unequal noise variances (all errors N(0, 1)); uncertainty from estimating w. ^f8
- [stats/eb] (inferred) Why the slab's tail matters for us: under a normal slab of sd c
  the posterior mean of a slab member is x * c^2 / (c^2 + se^2), a fixed fraction, so a
  real counter seen in a thin cell (se comparable to c) is still halved; a Laplace slab
  pulls it in by a bounded amount (f4). A two-normal mixture keeps a lone outlier only
  if the slab is wide relative to the thin cells' standard errors. ^f9
- [stats/eb] (inferred) A three-component normal mixture (spike, medium slab, wide
  slab) approximates a heavy-tailed slab and stays closed form per cell (EM on
  normal-normal convolutions with per-cell se); Laplace-slab posteriors need normal CDF
  terms but are also closed form. Either fits by marginal maximum likelihood per pair
  kind as here (f5). ^f10
- [stats/eb] (inferred) Toy check (our arithmetic, win rate in pp, se = 50/sqrt(n), a
  real counter observed at its true +8): Gaussian prior sd 1.5 gives 80% ranges
  [-1.2, 2.5] at n = 100, [0.5, 3.8] at n = 400, [3.5, 6.0] at n = 1600, missing +8
  every time; a mixture 0.9 x N(0, 1) + 0.1 x N(0, 6) gives [-0.9, 2.6], [0.5, 9.2],
  [6.1, 9.2] (slab probability 0.13, 0.64, 1.00). At 100 games no prior can find the
  needle; from a few hundred the mixture keeps it and the Gaussian never does. ^f11

## Read

- Abstract; section 1 (all); 2.1-2.3; section 3 conclusions list; 4.2.

## Not read

- Theorems and proofs (sections 2.4 onwards, 5-10): rates, not needed for a choice.
- Table 1 numbers in full.
