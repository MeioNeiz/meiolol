---
title: 'Grinsztajn, Oyallon, Varoquaux 2022: Why do tree-based models still outperform deep learning on tabular data?'
url: https://arxiv.org/abs/2207.08815
kind: paper
commit: 
for: [draft-predictor-methods]
looked: 2026-10-12
depth: skimmed (abstract, 1, 3 benchmark rules, 4 results, 6, appendix A.2 large-sized)
relevance: medium
grade: A/strong
description: NeurIPS 2022 datasets track benchmark (Inria) of 45 tabular datasets with 20,000 compute hours of random search: trees beat NNs at ~10k rows; why (uninformative features, irregular targets, rotation)
---
# Grinsztajn et al. 2022: Why do tree-based models still outperform deep learning on tabular data?

Why: whether GBDT or a neural net is the better default for our model, and whether
the benchmark covers data like ours (one-hot champions, 10^5 to 10^7 rows, weak
signal).

## Assessment

- Evidence: A. NeurIPS 2022, the most cited tabular benchmark; 45 datasets, 20,000
  compute hours per learner, results shared.
- Reasoning: strong. Accounts for tuning budget, states its exclusions and open
  questions.
- Interests: none known.
- Weigh: the regime is narrow and not ours: train sets truncated to 10k (50k in an
  appendix), categoricals over 20 levels removed, "too easy" sets removed. Treat as
  evidence about mid-size dense tabular data, not about sparse high-cardinality
  categorical sets.

## Findings

- [method] Tree-based models remain state of the art on medium-sized tabular data
  (~10k samples), even ignoring their speed. Abstract ^f1
  > Results show that treebased models remain state-of-the-art on medium-sized data (∼10K samples) even without accounting for their superior speed.
- [method] The benchmark excludes high-cardinality categoricals and caps training
  size, so our regime (170-level categorical slots, 10^5+ rows) is outside it.
  Section 3 ^f2
  > Low cardinality categorical features We remove categorical features with more than 20 items.
  > We truncate the training set to 10,000 samples for bigger datasets.
- [method] At 50k rows the gap between NNs and trees shrinks in most cases (not
  rigorously studied). Appendix A.2 ^f3
  > However, it seems that, in most cases, increasing the train set size reduces the gap between neural networks and tree-based models.
- [method] Tuning does not close the gap: trees win at every random search budget;
  each NN search iteration is also slower. Section 4 ^f4
  > Tree-based models are superior for every random search budget, and the performance gap stays wide even after a large number of random search iterations.
- [method] Why NNs lose: they are hurt by uninformative features, their rotation
  invariance, and difficulty learning irregular functions. Abstract ^f5
  > 1. be robust to uninformative features, 2. preserve the orientation of the data, and 3. be able to easily learn irregular functions.
- [method] Very large data and high-cardinality categoricals are listed as open
  questions. Section 6 ^f6
  > How would our evaluation change on very small datasets? On very large datasets? What is the best way to handle specific challenges like missing data or high-cardinality categorical features
- [method] (inferred) Our draft data is the opposite of their regime: no
  uninformative or skewed numerical features, a smooth additive target (champion
  strength) plus small interactions, and 10x to 1000x more rows. Their result does
  not transfer; it neither favours nor rules out NNs for us. ^f7

## Read

- Abstract, 1, 3 (dataset criteria, benchmark procedure), 4 results, 6, A.2

## Not read

- 5 inductive-bias experiments in detail, per-dataset tables
