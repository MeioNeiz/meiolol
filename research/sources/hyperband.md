---
title: 'Li et al. 2018: Hyperband, a Novel Bandit-Based Approach to Hyperparameter Optimization'
url: https://arxiv.org/pdf/1603.06560
kind: paper
commit: 
for: [smart-experiment-search]
looked: 2026-10-12
depth: skimmed (abstract, sections 2.1, 3.1-3.5, 4.2.1, 4.4.1-4.4.3, appendix A.3)
relevance: high
grade: A/strong
description: JMLR 2018 paper; early stopping by successive halving across several aggressiveness brackets, with iterations, data subsets or features as the resource
---
# Li et al. 2018: Hyperband

Why: how to spend a fixed run budget across many cheap partial runs vs few full ones,
and when data subsets are a usable cheap fidelity.

## Assessment

- Evidence: A. JMLR 2018, CMB/Google; canonical multi-fidelity HPO method, built into
  most HPO libraries; theory plus benchmarks (117 OpenML datasets, over a CPU-year).
- Reasoning: strong. Explains the n versus B/n trade-off, reports where it loses
  (small data, resource-dependent hyperparameters, aggressive bracket would have won).
- Interests: authors' own method.
- Weigh: trust the trade-off analysis and failure modes; speedups are on tasks with
  training cost at least linear in data size and much larger search spaces than ours.

## Findings

- [lab] [method] Hyperband treats tuning as allocating a resource (iterations, data
  samples or features) to sampled configurations, stopping poor ones early. Abstract ^f1
  > a predefined resource like iterations, data samples, or features is allocated to randomly sampled configurations.
- [lab] [stats] Telling two candidates apart needs more resource when partial results
  are noisier or their final scores are closer. Section 3.1 ^f2
  > more resources are needed to differentiate between the two configurations when either (1) the envelope functions are wider or (2) the terminal losses are closer together.
- [lab] The n versus B/n trade-off: if quality shows only late, or candidates are
  similar, try few; if it shows early, try many. Section 3.1 ^f3
  > if more resources are required before configurations can differentiate themselves in terms of quality (e.g., if an iterative training method converges very slowly for a given data set or if randomly selected hyperparameter configurations perform similarly well), then it would be reasonable to work with a small number of configurations.
- [lab] With prior knowledge of the right trade-off, use it; Hyperband's brackets are a
  grid over the trade-off for when you don't know. Section 3.1, 3.2 ^f4
  > if meta-data or previous experience suggests that a certain tradeoff is likely to work well in practice, one should exploit that information and allocate the majority of resources to that tradeoff.
- [lab] Data subset size as the resource; worthwhile mainly when training time grows
  super-linearly with data. Section 3.4 ^f5
  > we treat the resource as the size of a random subset of the data set with R corresponding to the full data set size.
- [lab] On small data sets subsampling buys nothing: startup overhead dominates; and
  failures may only appear on the full data. Appendix A.3 ^f6
  > For very small data sets that are trained in seconds, the initialization overheads dominate the computation and subsampling provides no computational benefit.
  > A searcher like Hyperband that uses a subsampled data set could spend significant time training on a subsample only to error out when attempting to train it on the full data set.
- [lab] [stats] On 117 data sets, Bayesian methods won on validation rank by more than
  on test rank, a sign of overfitting the validation set; random search at twice the
  budget beat all. Section 4.2.1 ^f7
  > Bayesian methods outperform Hyperband and random search in test error performance but also exhibit signs of overfitting to the validation set, as they outperform Hyperband by a larger margin on the validation error rank. Notably, random 2× outperforms all other methods.
- [lab] Hyperband suits hard, higher-dimensional spaces; for low dimensions random or
  Bayesian search already covers the space and the speedup is small. Section 4.4.1 ^f8
  > Hyperband leverages downsampling to boost the number of configurations that are evaluated, and thus is better suited for ‘hard’ problems where more evaluations are actually necessary to find a good setting.
- [lab] When a setting's best value depends on the resource (e.g. regularisation vs data
  size), small-resource results mislead; normalise the setting by data size to remove
  the dependence. Section 4.4.3 ^f9
  > the rate of convergence to the true loss is usually slow because the performance on a smaller resource is not indicative of that on a larger resource.
  > the dependence can oftentimes be removed with simple normalization.
- [lab] Prior knowledge can narrow the brackets tried; in hindsight one aggressive
  bracket would have beaten full Hyperband in most of their experiments. Section 4.4.2 ^f10
  > We believe prior knowledge about a task can be particularly useful for limiting the range of brackets explored by Hyperband.
- [lab] (inferred) For meiolol: shrinkage strength and priors depend on games per
  champion pair, so a 10% subset will favour stronger shrinkage than the full data;
  subsets can screen out broken or clearly worse ideas, not rank near-tie ones. ^f11

## Read

- Abstract, sections 2.1 end, 3.1-3.5, 4.2.1, 4.4.1-4.4.3, appendix A.3

## Not read

- Section 5 theory (infinite horizon, guarantees), 4.1 and 4.3 experiments
