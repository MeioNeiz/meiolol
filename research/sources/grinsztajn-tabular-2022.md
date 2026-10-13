---
title: 'Grinsztajn, Oyallon, Varoquaux 2022: Why do tree-based models still outperform deep learning on tabular data?'
url: https://arxiv.org/abs/2207.08815
kind: paper
commit: 
for: [draft-predictor-methods, nn-draft-models]
looked: 2026-10-12
depth: skimmed (abstract, 1, 3 benchmark rules, 4 results, 6, appendix A.2 large-sized, A.3 NN hyperparameter spaces)
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
- [method] NN protocol: 300 epochs with early stopping and checkpointing (best
  validation model kept), patience 40 for MLP, ResNet and FT-Transformer; their MLP adds
  ReduceOnPlateau lr scheduling. Appendix, 4.1 ^f8
  > All neural networks are run for 300 epochs, with early stopping and checkpointing (the best model on the validation set is kept).
  > Early stopping patience is 40 for MLP, Resnet, and FT Transformer, and 10 for SAINT.
  > The only improvement beyond a simple MLP is using Pytorch’s ReduceOnPlateau learning rate scheduler.
- [method] MLP space and default: 1-8 layers (default 4), width 16-1024 (256), dropout
  0-0.5 (0.2), lr LogUniform[1e-5, 1e-2] (1e-3), category embedding 64-512 (128), lr
  scheduler on, batch {256, 512, 1024} (512). Table 3 ^f9
  > Table 3: MLP hyperparameters space
  > LogUniform[1e − 5, 1e − 2] 1e − 3
- [method] FT-Transformer space reuses Gorishniy's (default 3 layers, 192 dims, attention
  dropout 0.2, FFN dropout 0.1, lr 1e-4, wd 1e-5) and adds batch {256, 512, 1024},
  default 512, no lr scheduler by default. Table 1 ^f10
  > Table 1: FT Transformer hyperparameters space
  > LogUniform [1e − 6, 1e − 3] 1e − 5
- [method] ResNet default: 8 blocks of 256, hidden factor 2, hidden and residual dropout
  0.2, lr 1e-3, weight decay 1e-7, batchnorm, scheduler on, batch 512. Table 2 ^f11
  > Table 2: Resnet hyperparameters space

## Read

- Abstract, 1, 3 (dataset criteria, benchmark procedure), 4 results, 6, A.2
- Appendix hyperparameter spaces (Tables 1-3)

## Not read

- 5 inductive-bias experiments in detail, per-dataset tables
