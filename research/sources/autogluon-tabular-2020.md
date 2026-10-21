---
title: 'Erickson et al. 2020: AutoGluon-Tabular: Robust and Accurate AutoML for Structured Data'
url: https://arxiv.org/pdf/2003.06505
kind: paper
commit: 
for: [frontier-tabular-ensembles]
looked: 2026-10-21
depth: skimmed (1, 2.5-2.7, 4.3)
relevance: medium
grade: A/fair
description: Amazon 2020: AutoGluon's multi-layer stack ensembling (stackers see base predictions plus raw features, ensemble selection on top) with repeated k-fold bagging for out-of-fold predictions; ablation of each piece
---
# AutoGluon-Tabular (Erickson et al. 2020)

Why: the reference design for multi-layer stacking, and how it keeps stackers from
training on leaked or overfit lower-layer predictions.

## Assessment

- Evidence: A. Widely used AutoML system (Kaggle, TabArena baseline), 50 AutoML Benchmark
  and 11 Kaggle datasets, ablation.
- Reasoning: fair. Mechanisms explained; the ablation removes features cumulatively, so
  each step's own effect is not isolated.
- Interests: Amazon's product.
- Weigh: k-fold bagging assumes IID rows; under our time split, out-of-fold predictions
  for old games come from models that saw newer games.

## Findings

- [method/ensemble] Multi-layer stacking: base models' predictions are concatenated and
  fed to stackers of the same model types, which also see the raw features (a skip
  connection); ensemble selection combines the last layer. 2.5 ^f1
  > Our final stacking layer applies ensemble selection (Caruana et al., 2004) to aggregate the stacker models’ predictions
  > (input vectors are data features concatenated with lowerlayer model predictions)
- [method/ensemble] Stackers must train only on out-of-fold lower-layer predictions;
  in-sample ones amplify overfitting and shift covariates at test time. 2.6 ^f2
  > In stacking, it is critical that higher-layer models are only trained upon lower-layer OOF predictions.
- [method/ensemble] Even OOF predictions leak a little, through early stopping on the OOF
  fold, and stackers amplify it layer by layer; repeated k-fold bagging over n random
  partitions averages it away, mostly mattering for small data. 2.6 ^f3
  > The training process of certain models can be influenced by OOF data through factors such as the early stopping criterion, which can lead to minor over-fitting in OOF predictions.
  > OOF over-fitting can thus become amplified through each layer of the stack.
- [method/ensemble] Ablation (4h, AutoML Benchmark): removing repeats, then multi-layer
  stacking, then bagging, then the net each made results worse (avg rescaled loss 0.166,
  0.220, 0.524, 0.720, 0.817). 4.3 ^f4
  > Table 5 shows that overall predictive performance dropped each time we removed the next feature in this list.
- [method/ensemble] (inferred) For us: the analogue under a time split is forward
  stacking (fold k fitted from folds before k), which meiolol-97 already uses; repeated
  bagging maps to several seeds or resamples per base model. Early stopping on the fold
  that also feeds the stacker is the leak to avoid. ^f5

## Read

- Sections 1, 2.5-2.7, 4.3 ablation (raw/autogluon-tabular-2020.txt)

## Not read

- Benchmarks by dataset; the neural net design (2.4)
