---
title: 'Armstrong, Kolesar, Plagborg-Moller 2022: Robust empirical Bayes confidence intervals'
url: https://arxiv.org/pdf/2004.03448
kind: paper
commit:
for: [thin-cell-ranges]
looked: 2026-11-04
depth: docs (sections 1-5, 7.2, Appendix B)
relevance: high
grade: A/strong
description: Econometrica 2022 paper on EB confidence intervals centred at linear shrinkage that keep coverage for any prior with given second and fourth moments; average vs per-unit coverage
---
# Armstrong, Kolesar, Plagborg-Moller 2022: Robust empirical Bayes confidence intervals

Why: do our Gaussian-prior 80% ranges keep coverage when the true spread of cells is
heavy-tailed, what coverage notion is even achievable, and what a robust fix costs.

## Assessment

- Evidence: A. Econometrica 2022 (arXiv v4), three established econometricians; theory
  plus 48 Monte Carlo designs and a real application (Chetty-Hendren neighbourhoods);
  shipped as R `ebci`, Stata `ebreg`, Matlab packages.
- Reasoning: strong. States exactly what coverage it guarantees and what it gives up
  (per-unit coverage), when not to use it, and where nonparametric methods would win.
- Interests: none known.
- Weigh: theory is for normal Y_i given theta_i with known sigma_i (our cells are
  binomial win rates, near normal only at moderate n); asymptotic in number of cells,
  fine for us (10^4-10^5). Average coverage is the weaker notion; read the 5.1
  caveats before promising per-cell coverage.

## Findings

- [stats/eb] Parametric (Gaussian-prior, Morris) EBCIs can badly undercover when the
  effects are not normal; the distortion grows with the amount of shrinkage. Section 1 ^f1
  > "the parametric EBCI with nominal level 95% can have actual EB coverage as low as 74% for certain non-normal effect distributions. The potential undercoverage is increasing in the degree of shrinkage"
- [stats/eb] Worst-case non-coverage of the parametric EBCI is 1/max{z^2, 1}, reached as
  shrinkage weight w goes to 0; rule of thumb: safe-ish when w >= 0.3. Section 4.3 ^f2
  > "if wEB,i ≥ 0.3, the maximal coverage distortion is less than 5 percentage points for these values of α"
  > "The maximal non-coverage probability 1/ max{z1−α/2 , 1} equals 0.260 for α = 0.05 and 0.370 for α = 0.10."
- [stats/eb] (inferred) For our 80% ranges (alpha 0.2, z = 1.2816, z^2 = 1.642) the
  worst-case non-coverage of a Gaussian-prior range on a heavily shrunk cell is
  1/1.642 = 0.61, i.e. coverage as low as about 39%, for a prior with the right variance
  but the wrong shape. Thin cells (w well under 0.3) are exactly where this bites. ^f3
- [stats/eb] Robust EBCI: keep the usual linear EB point estimate (shrink towards a
  regression X'delta), widen with a critical value cva(sigma_i^2/mu_2, kappa) that bounds
  non-coverage over all priors with the estimated second moment mu_2 and kurtosis kappa.
  Section 3.2 ^f4
  > "Report the robust EBCI θ̂i ± cvaα (σ̂i2 /µ̂2 , κ̂)ŵEB,i σ̂i"
- [stats/eb] Width depends on kurtosis: with the fourth moment constraint the robust EBCI
  is at most 11.4% longer than the parametric one when w >= 0.1, up to 39% longer below
  that; dropping the kurtosis constraint (kappa infinite) makes it much wider. Section 4.2 ^f5
  > "if wEB,i ≥ 0.1 (which is equivalent to µ2 /σi2 ≥ 1/9), the efficiency loss is at most 11.4% for α = 0.05"
  > "When the signal-to-noise ratio is very small, so that wEB,i < 0.1, the efficiency loss of the robust EBCI is higher (up to 39% for α = 0.05 or 0.1)."
- [stats/eb] Cheap to compute: the second-moment-only critical value is closed form (least
  concave majorant of r0); with kurtosis it is two nested univariate optimisations; the
  least favourable prior has at most 4 support points. Appendix B ^f6
  > "Appendix B shows that the infinitedimensional linear program (11) can be reduced to two nested univariate optimizations."
  > "the least favorable distribution—the distribution F maximizing (11)—is a discrete distribution with up to 4 support points"
- [stats/eb] (inferred) In Zig: cva depends on cells only through (sigma_i^2/mu_2, kappa),
  so tabulate it once on a grid of m2 per pooled family (one kappa each) and interpolate;
  cost is negligible beside the fit, even at 10^5 cells. ^f7
- [stats/eb] The guarantee is average coverage across cells, not per cell: at least
  1-alpha of the intervals cover, asymptotically. Per-unit (pointwise) coverage with
  shrinkage gains is impossible. Sections 2, 5.1 ^f8
  > "If the means θ1 , . . . , θn are treated as fixed, the coverage probability, averaged across the n parameters θi , is at least 1 − α."
  > "Thus, undercoverage for some θi ’s must be tolerated if one wants to use shrinkage to improve CI length."
- [stats/eb] Pointwise CIs (each cell covered 1-alpha) cannot be much shorter than the
  unshrunk interval: at most about 15% shorter even for an oracle (Pratt 1961).
  Footnote 3 ^f9
  > "for CIs with coverage 95%, one cannot achieve expected length improvements greater than 15% relative to the usual unshrunk CIs"
- [stats/eb] The cells that undercover are those far from the regression they shrink
  towards (large |eps_i|/sqrt(mu_2)), the same cells where shrinkage loses MSE to the raw
  estimate: a lone real outlier is exactly the cell that misses. Section 5.1 ^f10
  > "the units i for which our EBCI undercovers are those whose covariate-predicted value Xi0 δ fails to approximate their true effect θi well"
- [stats/eb] Not for picking extremes: average coverage is the wrong criterion when one
  cares about the largest theta_i or a specific unit, or the ordering. Section 1 ^f11
  > "This includes settings where one is interested in the magnitude or the identity of the largest θi , or the true effect for the largest observed Yi"
- [stats/eb] (inferred) That is our use: a recommender surfaces the top champion or
  matchup per slot, i.e. the selected extremes. Average-coverage ranges on the shown
  (top-ranked) cells will undercover; per-shown-cell honesty needs a prior that fits the
  tail (NPMLE/mixture) or a selection-aware interval (their Section 6.2, cutoff fixed in
  advance). ^f12
- [stats/eb] Covariates fix systematic coverage gaps: coverage holds conditional on X_i,
  so a group that might sit off the regression (gender in their example; role or
  bracket for us) gets its own coverage by adding it to X. Section 5.1 ^f13
  > "one can simply add gender to the set of covariates Xi : the baseline procedure in Section 3.2 ensures control of average coverage conditional on the covariates Xi"
- [stats/eb] Moment independence: the guarantee needs mu_2 and kappa not to vary with
  (X_i, sigma_i); otherwise use nearest-neighbour local estimates of both (Remark 3.2), or
  shrink t-statistics Y_i/sigma_i. Section 3.1 ^f14
  > "the conditional second moment and kurtosis of εi = θi − Xi0 δ do not depend on (Xi , σi )"
- [stats/eb] Moment estimates are simple weighted sums of residuals with bias corrections
  and truncation at the lower bounds (mu_2 >= 0, kappa >= 1). Section 3.2, Remark 3.4 ^f15
  > "these estimates incorporate truncation on µ̂2 and κ̂"
- [stats/eb] The robust EBCI is not efficient under heavy-tailed or bimodal effects; a
  nonparametric prior (kernels, Efron splines, Kiefer-Wolfowitz NPMLE, Jiang-Zhang,
  Koenker-Mizera) could do better, but EBCIs from those were left open. Section 5.3 ^f16
  > "substantial efficiency gains may be possible if the effect size distribution is, for example, heavy-tailed or bimodal."
  > "An interesting problem for future research is to adapt these methods to EBCI construction"
- [stats/eb] In the real application (90% intervals, low signal-to-noise, fat lower tail)
  the parametric EBCI's potential size distortion averaged 12.7-17.8 points; over 90%
  of cells had w below 0.3. Section 7.2 ^f17
  > "the parametric EBCI exhibits average potential size distortions of 12.7–17.8 percentage points"
- [stats/eb] Monte Carlo: with T >= 20 per unit and normal noise, robust EBCI coverage
  distortion stays below 2.1 points across 24 prior shapes; n >= 100 units is enough.
  Section 4.4 ^f18
  > "For T ≥ 20, the coverage distortion of the robust EBCIs is always below 2.1 percentage points."

- [stats/eb] (inferred) Our own calculation (Proposition B.1, second moment only, kappa
  infinite, so an upper bound on width) for 80% ranges: robust/parametric half-width
  ratio is 1.00 at w = 0.8, 1.05 at w = 0.3, 1.27 at w = 0.1, 1.39 at w = 0.05, 1.50 at
  w = 0.02; worst-case non-coverage of the parametric 80% range is 0.22 at w = 0.3,
  0.30 at w = 0.1, 0.41 at w = 0.02 (nominal 0.20). Using the fitted kurtosis narrows the
  robust widths towards the parametric ones. Script: scratch numpy/scipy, grid over t. ^f19

## Read

- Sections 1-5, 7.2 results, Appendix B propositions: closely.

## Not read

- Section 6.1 (non-linear shrinkage, soft thresholding EBCIs), 6.2 (coverage given Y_i
  passes a cutoff): may matter for ranges on shown (selected) cells.
- Appendix A (finite-n corrections, nearest-neighbour moments), C (proofs, approximate
  normality), supplement.
