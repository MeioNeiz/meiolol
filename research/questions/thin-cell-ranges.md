---
status: answered
priority: now
area: stats
tags: [stats, stats/eb]
description: How do we give honest ranges for many thin estimates (champion, matchup, duo, item, keystone cells) when the prior may be wrong or heavy-tailed: robust EB intervals, g-modelling/NPMLE, horseshoe and spike-and-slab, small area estimation, deep interactions?
---
# How do we give honest ranges for many thin estimates (champion, matchup, duo, item, keystone cells) when the prior may be wrong or heavy-tailed: robust EB intervals, g-modelling/NPMLE, horseshoe and spike-and-slab, small area estimation, deep interactions?

Feeds: MeioModel prior (src/meio.zig): mixture or heavy-tailed prior for lone real outliers, honest per-cell 80% ranges, pair (matchup, duo) terms

## Answer

A Gaussian prior is the wrong shape for pair terms: when most terms sit near zero and a
few are real counters, it over-shrinks the large ones at any sample size, and theory for
sparse effects needs a slab with at least exponential tails (C1, C2). Its ranges also
under-cover when the prior's shape is wrong, worst on the most shrunk cells: for an 80%
range, worst-case coverage is about 78% at shrinkage weight w = 0.3, 70% at w = 0.1 and
59% at w = 0.02 (C3). And no shrinkage range can hold 80% in every cell while being much
shorter than an unshrunk one: EB ranges promise average coverage over cells, and the
cells they miss are the ones far from the prior mean, a lone real outlier first, which
are the cells a recommender shows (C4, C5, C6).

So: (1) keep shrinking towards the structured prior mean, but give each term class a
non-Gaussian prior. Spike-and-slab and the regularised horseshoe behave alike (C7), a
two- or three-normal scale mixture by EM is closed form and keeps a +8 point counter
from a few hundred games where the Gaussian never does (C8), and a grid prior by NPMLE
(convex, handles binomial data and unequal variances) is the general version, winning
big on sparse or clustered effects and losing little when effects are normal (C9, C10).
meio.zig's `pair_mix` (two normals per class, EM) is the first step; scoring it on
16.21 decides. (2) Take each cell's 80% range from its posterior quantiles, not mean
plus or minus z times sd: a mixture posterior can be bimodal (C11). (3) Guard the fit:
the scale fitted by marginal likelihood can collapse to zero, which would make every
range in the class too narrow; floor it (C12). The plug-in error from estimating the
variance is O(1/m), negligible at our cell counts except small slices (C13). (4) Promise
and check 80% within groups: by w bucket, residual size, games per cell, and the top-k
cells the site shows (C6, C14). Optionally a robust EBCI half-width per cell (closed
form from w and the residuals' kurtosis) as a floor or a report of how often our range
is narrower (C15). (5) Brackets and regions: nested deviation batches, each with its
own scale, added only where residual variance beats binomial variance (C16). The tail
of any fitted prior stays imprecise even with thousands of cells: cap the slab at the
largest effect we believe in (C17).

## Claims

- C1: A Gaussian prior on sparse effects over-shrinks large real effects; heavy-tailed or
  spike-and-slab priors avoid it. for: [[johnstone-silverman-2004-needles#^f2]], [[johnstone-silverman-2004-needles#^f3]], [[johnstone-silverman-2004-needles#^f4]], [[piironen-vehtari-2017-regularised-horseshoe#^f4]]
- C2: Theory for sparse effects needs slab tails at least exponential; a Laplace slab
  pulls a large observation in by a bounded amount. for: [[johnstone-silverman-2004-needles#^f3]], [[johnstone-silverman-2004-needles#^f4]]
- C3: Gaussian-prior EB ranges with the right variance but wrong shape under-cover, worst
  where shrinkage is strongest. for: [[armstrong-2022-robust-ebci#^f1]], [[armstrong-2022-robust-ebci#^f2]], [[armstrong-2022-robust-ebci#^f3]], [[armstrong-2022-robust-ebci#^f17]], [[armstrong-2022-robust-ebci#^f19]]
- C4: Ranges that cover every cell cannot be much shorter than unshrunk ones; EB ranges
  promise average coverage. for: [[armstrong-2022-robust-ebci#^f8]], [[armstrong-2022-robust-ebci#^f9]]
- C5: The cells EB ranges miss are those whose true value is far from the prior mean.
  for: [[armstrong-2022-robust-ebci#^f10]]
- C6: Average coverage is the wrong promise for selected or extreme units.
  for: [[armstrong-2022-robust-ebci#^f11]], [[armstrong-2022-robust-ebci#^f12]]
- C7: Spike-and-slab and the regularised horseshoe have similar shrinkage and perform
  comparably; the finite slab sets the largest believed effect.
  for: [[piironen-vehtari-2017-regularised-horseshoe#^f3]], [[piironen-vehtari-2017-regularised-horseshoe#^f4]], [[piironen-vehtari-2017-regularised-horseshoe#^f5]]
- C8 (inferred): A two-normal mixture keeps a real +8 point counter from a few hundred
  games (80% range at 400 games: Gaussian 0.5 to 3.8, mixture 0.5 to 9.2; at 1600: 3.5 to
  6.0 against 6.1 to 9.2); the Gaussian misses it at every size. from: C1, C2; toy check
  in [[johnstone-silverman-2004-needles#^f11]]
- C9: An NPMLE grid prior is a convex fit, about 10^4 times faster by interior point
  than EM, and takes binomial data, covariates and unequal variances.
  for: [[koenker-mizera-2014-convex-eb#^f1]], [[koenker-mizera-2014-convex-eb#^f2]], [[koenker-mizera-2014-convex-eb#^f3]], [[koenker-mizera-2014-convex-eb#^f7]], [[koenker-mizera-2014-convex-eb#^f10]], [[jiang-zhang-2009-gmleb#^f4]]
- C10: The NPMLE beats linear shrinkage on sparse, clustered or heavy-tailed effects and
  loses little when they are normal. for: [[jiang-zhang-2009-gmleb#^f6]], [[jiang-zhang-2009-gmleb#^f7]], [[jiang-zhang-2009-gmleb#^f8]], [[koenker-mizera-2014-convex-eb#^f5]], [[koenker-mizera-2014-convex-eb#^f6]], [[brown-2008-batting-eb#^f5]] against: [[koenker-mizera-2014-convex-eb#^f8]]
- C11 (inferred): Under a non-Gaussian prior, ranges must come from posterior quantiles.
  from: C1, C9
- C12: A sparse prior's scale fitted by maximum marginal likelihood can collapse to zero.
  for: [[piironen-vehtari-2017-regularised-horseshoe#^f6]]
- C13: The extra error from estimating the between-cell variance is O(1/m) in MSE and
  coverage. for: [[pfeffermann-2013-sae-developments#^f3]], [[pfeffermann-2013-sae-developments#^f6]], [[pfeffermann-2013-sae-developments#^f12]]
- C14: None of the sparse-prior, NPMLE or MRP papers checks per-cell interval coverage;
  it has to be measured on our held-out games. for: [[piironen-vehtari-2017-regularised-horseshoe#^f11]], [[johnstone-silverman-2004-needles#^f8]], [[ghitza-gelman-2013-deep-mrp#^f10]]
- C15: A robust EBCI is cheap: closed form or two one-dimensional searches, from the
  noise-to-spread ratio and the residuals' kurtosis; with fitted kurtosis it stays
  within about 11% of the Gaussian width when w >= 0.1. for: [[armstrong-2022-robust-ebci#^f4]], [[armstrong-2022-robust-ebci#^f5]], [[armstrong-2022-robust-ebci#^f6]], [[armstrong-2022-robust-ebci#^f15]]
- C16: Deep-interaction MRP gives each interaction batch its own scale, nests coarser
  groupings, and adds a batch only when residual cell variance beats binomial variance;
  small area estimation treats outlying areas with t or Huber area effects.
  for: [[ghitza-gelman-2013-deep-mrp#^f1]], [[ghitza-gelman-2013-deep-mrp#^f3]], [[ghitza-gelman-2013-deep-mrp#^f6]], [[pfeffermann-2013-sae-developments#^f8]], [[pfeffermann-2013-sae-developments#^f9]]
- C17: The far tail of an estimated prior is imprecise even with thousands of units; an
  NPMLE spares a lone outlier only once its own data are strong.
  for: [[efron-2014-two-modeling-strategies#^f7]], [[efron-2014-two-modeling-strategies#^f8]], [[koenker-mizera-2014-convex-eb#^f13]]

## Disagreements

- NPMLE against James-Stein to a good regression: on batting averages the latter won
  (koenker-mizera-2014-convex-eb ^f8, A) while Jiang-Zhang's sparse simulations favour
  the NPMLE (A). Both fit: the gain depends on how non-normal the residuals are after a
  good structured mean. Settled by truth: pair_mix and a grid prior against the Gaussian.
- All sources assume independent per-cell estimates; MeioModel is a joint logistic fit,
  so the methods apply to each cell's unshrunk logit and its variance as input.

## Open

- Score pair_mix on 16.21 (matchup, duo, two-lock, gold), per-cell coverage by w bucket
  and by residual size, and on the top cells the site would show.
- Does a third, wider component or a grid prior beat two normals?
- Leads: Koenker cieb.pdf (EB intervals from the NPMLE), Koenker and Gu "Empirical Bayes
  for the reluctant frequentist", deconvolveR (JSS 2020), Carvalho Polson Scott 2010,
  Rockova and George 2018, Fay and Herriot 1979.
