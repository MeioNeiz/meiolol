---
title: 'Tan, Hooker, Koch, Gordo, Caruana 2023: Considerations when learning additive explanations for black-box models'
url: https://arxiv.org/pdf/1801.08640
kind: paper
commit: 
for: [distil-explainable]
looked: 2026-10-13
depth: docs (1-5, Tables 1-3)
relevance: high
grade: B/strong
description: arXiv 1801.08640 v4 (2023; began as "Learning global additive explanations for neural nets using model distillation"); distils MLPs into additive students (spline and bagged-tree GAMs, with and without pairs) and compares them with partial dependence, global SHAP and gradients
---
# Tan, Hooker, Koch, Gordo, Caruana 2023: Considerations when learning additive explanations for black-box models

Why: distilling a net into an additive model: how much accuracy is kept, how
interactions get folded into main effects, and does the student explain the teacher?

## Assessment

- Evidence: B. Caruana group (InterpretML, EBM); 5 datasets (9.9k-42.5k rows), 5
  train-validation splits with standard errors, synthetic functions with known main and
  total effects, a user study. Teacher is one 2x512 MLP, not an ensemble.
- Reasoning: strong. States that additive decompositions are not unique, measures
  against known ground truth, reports where pairs help and where they hurt.
- Interests: authors built the additive students (InterpretML).
- Weigh: trust the ordering (distilled additive beats PD, gSHAP and gradient
  explanations; pairs help only where real interactions exist). Datasets are small and
  less noisy than ours; accuracy gaps will differ.

## Findings

- [method] Distilled additive student: fit h0 + sum h_i(x_i) by mean squared error to
  the teacher's prediction function; pairwise terms h_ij can be added (SAT + pairs).
  Section 3.2.3 ^f1
  > where the ℎˆ𝑖 are obtained by minimizing the mean-squared error between the teacher model’s prediction function
- [method] Distilled additive explanations are generally the most accurate additive
  ones; non-additive students that model interactions are more accurate still.
  Abstract ^f2
  > Even though distilled explanations are generally the most accurate additive explanations, non-additive explanations such as tree explanations that explicitly model non-additive components tend to be even more accurate.
- [method] [stats] Accuracy kept on classification (AUC, teacher 2H-512 vs distilled
  additive SAT): Magic 94.06 vs 90.75, Pneumonia 82.18 vs 82.24, FICO 79.37 vs 79.42.
  Adding pairs: Magic 90.75 (no gain), Bikeshare RMSE 0.98 to 0.60. Tables 2 and 3
  (cells split across lines; quote is the text) ^f3
  > When explicitly modeling interactions, the RMSE in Bikeshare improves from 0.98 to 0.60.
- [method] Where data is small and wide the gap to the teacher is smallest and a sparse
  linear student is competitive. Section 5.4 ^f4
  > These datasets are also the ones where the gap between the black-box models and the explanations is the smallest.
- [method] Pairs are not free: unnecessary on some datasets, harmful on others. ^f5
  > Explicitly capturing interactions in the explanations may be unnecessary on some datasets (e.g. FICO) or even pernicious (Pneumonia) while being extremely important in others (e.g. Bikeshare).
- [method] Fidelity check: the student explains the teacher, not the data; a student of
  a 2H teacher got RMSE 0.12 vs teacher 0.14, while a GAM trained on the true labels got
  0.02, so the student's errors are the teacher's. Section 5.1 ^f6
  > Since the additive model has enough capacity to almost-perfectly model the data, we conclude the differences observed in the explanation of the 2H-512,512 neural net must be attributed to the neural net behavior.
- [method] A distilled additive model absorbs a share of each interaction into the
  main effects; how it is split is not unique and no split is "right". Section 5.2 ^f7
  > Although we can use total effect as a point of reference, all allocations are valid, and it is not possible to quantify which characterization is better.
- [method] Correlated features share an effect: a bump injected into temperature also
  showed in feeling-temperature (r 0.988). Section 5.3 ^f8
  > When features are correlated, additive explanations of correlated features distributed effects across them.
- [method] Global distillation beats aggregating local SHAP into a global additive view
  (gSHAP Loan RMSE 5.10 vs SAT 2.35). Section 5.4 ^f9
  > Hence, methods such as gSHAP excel at local explanations and should be used for those, but, to produce global explanations, global model distillation methods optimized to learn the teacher’s predictions perform better.
- [method] (inferred) For us: fit the additive student by squared error on the
  teacher's logit (our ^f1 analogue, see [[ba-caruana-deep-2014]]), and expect a
  champion-role term to absorb part of its pair effects (^f7); report pair terms as
  "beyond the two champions' main effects", fixed by fitting mains first or by a
  purification step, so readable effects do not shift when pairs are added. ^f10
- [method] (inferred) Champion pairs that nearly always co-occur (bot-lane duos)
  will share credit like correlated features (^f8); shrinkage chooses the split, so
  the explanation of such pairs is a modelling choice, not a fact. ^f11

## Read

- Abstract, sections 1-5, Tables 1-3.

## Not read

- Section 6 user study details; appendix.
