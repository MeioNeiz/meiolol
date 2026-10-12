---
title: 'Hestness et al. 2017: Deep Learning Scaling is Predictable, Empirically'
url: https://arxiv.org/abs/1712.00409
kind: paper
commit: 
for: [draft-predictor-methods]
looked: 2026-10-12
depth: skimmed (abstract, 1, 2 related work, 3 method)
relevance: medium
grade: A/fair
description: Baidu Research 2017 study of learning curves in four DL domains: error falls as a power law in training size with exponents -0.07 to -0.35, between a best-guess region and an irreducible-error floor
---
# Hestness et al. 2017: Deep Learning Scaling is Predictable, Empirically

Why: our log loss falls ~0.0008 per doubling of games; whether learning curves can be
extrapolated to say what 10^6 or 10^7 games would buy, and how to measure them.

## Assessment

- Evidence: A. The first large empirical scaling-law study (Baidu), precursor of
  Kaplan et al. 2020; much cited.
- Reasoning: fair. Careful method (tune model size per shard), honest that exponents
  are unexplained; domains are translation, LM, images, speech, not tabular.
- Interests: Baidu argues for more compute.
- Weigh: trust the curve shape and the method; exponents are domain specific.

## Findings

- [method] [stats] Generalisation error falls as a power law in training-set size;
  empirical exponents sit between -0.07 and -0.35, flatter than the -0.5 theory
  predicts. Section 1 ^f1
  > Unfortunately, in real applications, we find empirically that βg usually settles between −0.07 and −0.35, exponents that are unexplained by prior theoretical work.
- [method] Better architectures and optimisers shift the curve down (intercept) but
  do not change its steepness. Section 1 ^f2
  > Improved model architectures and optimizers can improve the power-law intercept, but not the exponent; models for a single domain show the same learning curve steepness.
- [method] [stats] Three regions: best guessing at small data, then power-law scaling,
  then a floor at irreducible (Bayes) error. Section 1 ^f3
  > we find that models transition from a small training set region dominated by best guessing to a region dominated by power-law scaling. With sufficiently large training sets, models will saturate in a region dominated by irreducible error
- [method] [stats] A counting model for a weighted coin flip converges with exponent
  -0.5, the textbook rate. Section 2 ^f4
  > a counting model used to predict the probability of a weighted coin-flip converges with the power-law exponent of βg = −0.5.
- [method] Method cost: for each data shard, re-tune model size (best-fit capacity
  grows sublinearly with data), so curve points are each tuned, not one fixed
  model. Section 3 ^f5
  > given the best-fit model size for shard Ti , we project forward to shard Ti+1 —often increasing model sizes linearly or sublinearly in the shard size
- [stats] (inferred) For a win model the floor is huge: Bayes log loss is near 0.69
  because outcomes are mostly noise. Fit the power law to excess loss over the floor
  (or to AUC), with the floor as a free parameter, else extrapolation is meaningless;
  per f2, a better model buys a shift, while more games buy steady gains along the
  same slope. ^f6

## Read

- Abstract, 1, 2, 3 methodology

## Not read

- 4 per-domain results in detail, 5 implications for systems
