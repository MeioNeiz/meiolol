---
title: 'Bergstra and Bengio 2012: Random Search for Hyper-Parameter Optimization'
url: https://www.jmlr.org/papers/volume13/bergstra12a/bergstra12a.pdf
kind: paper
commit: 
for: [draft-predictor-methods]
looked: 2026-10-12
depth: skimmed (abstract, 1, 2.1-2.2 neural net experiments, 3 effective dimension intro)
relevance: medium
grade: A/strong
description: JMLR 2012: random search beats grid search because only a few hyperparameters matter per dataset; 8 to 64 trials matched or beat 100-trial grids
---
# Bergstra and Bengio 2012: Random Search for Hyper-Parameter Optimization

Why: how big a tuning budget a new model family (FM, set net, GBDT) needs before we
can say it does or doesn't beat our logistic baseline.

## Assessment

- Evidence: A. JMLR 2012, one of the most cited tuning papers; random search is the
  standard baseline (Grinsztajn, McElfresh use it).
- Reasoning: strong. Empirical and theoretical (effective dimensionality), with
  trial-count curves and confidence intervals.
- Interests: none known.
- Weigh: neural nets of 2007 on image tasks; the trial counts transfer as an order of
  magnitude, not exactly.

## Findings

- [method] Random trials are more efficient than grid trials; same-quality models in
  a small fraction of the compute. Abstract ^f1
  > Compared with neural networks configured by a pure grid search, we find that random search over the same domain is able to find models that are as good or better within a small fraction of the computation time.
- [method] Only a few hyperparameters matter per dataset, and which ones differ
  between datasets, so grids waste trials. Abstract ^f2
  > for most data sets only a few of the hyper-parameters really matter, but that different hyper-parameters are important on different data sets.
- [method] Budget: 8 random trials beat a ~100-trial grid in the small space; a larger
  space needed 32 to consistently win and 64+ to find better models. Section 2.2 ^f3
  > In the larger space, 32 trials were necessary to consistently outperform grid search rather than 8, indicating that there are many harmful ways to preprocess the data.
  > Often the extent of a search is determined by a computational budget, and with random search 64 trials are enough to find better models in a larger less promising space.
- [method] (inferred) Before rejecting a model family, give it ~30 to 60 random trials
  over its few key knobs (L2, latent size, learning rate, epochs); McElfresh used 30
  ([[mcelfresh-nn-vs-gbdt-2023#^f2]]). ^f4

## Read

- Abstract, 1, 2 (neural network experiments, Figures 5-6), start of 3

## Not read

- 3 Gaussian process analysis, 4 quasi-random sets, 5 DBN experiments
