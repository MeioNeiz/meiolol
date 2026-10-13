---
title: 'Fakoor, Mueller, Erickson, Chaudhari, Smola 2020: Fast, accurate, and simple models for tabular data via augmented distillation'
url: https://arxiv.org/pdf/2006.14284
kind: paper
commit: 
for: [distil-explainable]
looked: 2026-10-13
depth: docs (abstract, 1, 4-6, Table 1)
relevance: high
grade: B/fair
description: NeurIPS 2020 Amazon (AutoGluon) paper, FAST-DAD; distils AutoGluon stacked ensembles into single LightGBM, CatBoost, random forest or NN students on 30 tabular datasets, comparing plain soft labels, MUNGE, GAN and Gibbs-sampled synthetic rows
---
# Fakoor, Mueller, Erickson, Chaudhari, Smola 2020: Fast, accurate, and simple models for tabular data via augmented distillation

Why: measured accuracy kept when distilling a big tabular ensemble into GBDTs and other
single models, the binary loss used, and how much synthetic inputs add over soft
labels on real rows.

## Assessment

- Evidence: B. 30 public datasets (UCI, OpenML; 12 binary), several student types,
  one-sided tests against standard training; NeurIPS. Teacher is AutoGluon, the authors'
  own system.
- Reasoning: fair. Clean ablation of strategies (KNOW, MUNGE, GAN, GIB-k) on equal
  footing; mean accuracy over heterogeneous datasets hides spread.
- Interests: Amazon AutoGluon team, teacher and Gibbs sampler are theirs.
- Weigh: trust the ordering (soft labels help; on-manifold synthetic rows help more);
  the absolute points are dataset averages, not our regime.

## Findings

- [method] Binary loss: Brier score (squared error), regressing the student on the
  teacher's positive-class probability for synthetic rows and on 0/1 for real rows;
  it slightly beat their multiclass strategy, as in Bucila. Section 4 ^f1
  > For binary classification tasks, we employ the Brier score [34] as our loss function for all students, treating both the probabilities assigned to the
- [method] Synthetic rows: Gibbs sampling from a masked self-attention model of each
  feature given the rest, started at real rows; one round (GIB-1) was best; ten times
  the training rows, capped at 10^6. Section 5 ^f2
  > we add m synthetic datapoints to the training set for the student, where m “ 10ˆ the number of original training samples (up to at most 106 ).
- [method] [stats] Binary tasks, mean test accuracy of the best single student: standard
  training 82.85, Hinton soft labels on real rows only (KNOW) 83.89, MUNGE 83.72, GIB-1
  84.21, teacher ensemble 84.40: GIB-1 keeps about 88% of the teacher's gain, soft labels
  alone about 67%. Table 1 (cells split; quote is the caption) ^f3
  > Table 1: Average ranks/performance achieved by the Selected model under each training strategy across the datasets from each prediction task.
- [method] Distillation gave nothing where the teacher was no better than the best single
  model. Section 5.3 ^f4
  > the only datasets where Gibbs augmentation fails to produce better models than the BASE training strategy are those where the teacher ensemble fails to outperform the best individual BASE model
- [method] Neural students gain most; tree students (LightGBM, CatBoost, RF) gain less
  but are often still the best single model after distillation. Section 5.3 ^f5
  > Overparameterized deep networks tend to benefit from distillation more than the tree models in our experiments
- [method] Distilled single models were over 10x faster and more accurate than
  H2O/AutoSklearn ensembles. Abstract ^f6
  > Our individual distilled models are over 10ˆ faster and more accurate than ensemble predictors produced by AutoML tools like H2O/AutoSklearn.
- [method] Longer Gibbs chains drift from the data distribution and hurt: stay close to
  real rows. Section 5.2 ^f7
  > Running the Gibbs sampling for longer is ill-advised as its stationary distribution appears to less closely approximate p than intermediate samples from a partially burned-in chain
- [method] (inferred) The draft analogue of GIB-1: take a real draft, resample one
  slot's champion from its conditional given the other nine (we can estimate it from pick
  rates by role and co-pick counts), label with the teacher ensemble. One swap per
  synthetic draft keeps it near the manifold (^f7) and multiplies coverage of rare pairs
  that touch the swapped slot. ^f8
- [method] (inferred) Expect soft labels on real games alone to give the smaller share
  (^f3: ~67% vs ~88% with synthetic rows); synthetic drafts are the cheap extra and run
  on the gpu-box (teacher inference) once per teacher. ^f9

## Read

- Abstract, sections 1, 4, 5.1-5.3, 6, Table 1.

## Not read

- Self-attention pseudolikelihood details (section 3); appendix per-dataset tables.
