---
title: 'Agarwal et al. 2021: Neural additive models, interpretable machine learning with neural nets'
url: https://arxiv.org/pdf/2004.13912
kind: paper
commit: 
for: [distil-explainable]
looked: 2026-10-13
depth: skimmed (abstract, 1-2, Table 1)
relevance: medium
grade: B/fair
description: NeurIPS 2021 Google/Caruana paper; additive model with one small neural net per feature, trained by backprop on GPU, compared with EBMs, XGBoost and DNNs on four tabular tasks
---
# Agarwal et al. 2021: Neural additive models, interpretable machine learning with neural nets

Why: an additive student that trains on GPU with the same tooling as the teacher, then
exports per-feature tables for CPU.

## Assessment

- Evidence: B. NeurIPS, Google Research with Caruana; four datasets, 5-fold CV with
  standard deviations; open code.
- Reasoning: fair. Clear on what NAMs cost (need strong regularisation, ensembles of
  feature nets); fitted to labels, not distilled.
- Interests: authors' own model class.
- Weigh: NAMs and EBMs are within noise of each other on the tasks shown; the point for
  us is form, not accuracy.

## Findings

- [method] NAM = sum of per-feature neural nets; the learned graphs are the exact model,
  not an approximation of it. Section 1 ^f1
  > Graphs learned by NAMs are not just an explanation but an exact description of how NAMs compute a prediction.
- [method] At prediction time each feature net acts as a lookup table of contributions,
  summed and passed through the link. Figure 5 ^f2
  > each feature net in the NAM acts as a lookup table and returns a contribution term.
- [method] Train on GPUs with deep learning toolkits; tree GAMs cannot. Section 1 ^f3
  > NAMs are more scalable as inference and training can be done on GPUs/TPUs or other specialized hardware using the same toolkits developed for deep learning over the past decade
- [method] [stats] MIMIC-II AUC: logistic 0.791, NAM 0.830, EBM 0.835, XGBoost 0.844,
  DNN 0.832; Credit AUC: NAM 0.980, EBM 0.976, XGBoost 0.981. Table 1 (cells split; quote
  is the caption) ^f4
  > Table 1: Single-task learning NAM results. Means and standard deviations are reported from 5-fold cross validation.
- [method] Shape functions overfit without strong regularisation (dropout, weight decay,
  output penalty, feature dropout). Section 2 ^f5
  > To avoid overfitting when fitting NAMs with ExUs, we employ various regularization methods including dropout, weight decay, output penalty, and feature dropout
- [method] (inferred) With categorical inputs a NAM feature net is just an embedding
  scalar per category, i.e. our additive model with learned per-champion and per-pair
  weights. An "additive head" trained on GPU against the teacher logits (or jointly, as a
  constrained net) then exports exactly as the CPU lookup table; no new student
  machinery is needed. ^f6

## Read

- Abstract, sections 1-2 intro, Table 1, Figure 5 caption.

## Not read

- Sections 3-4 (COVID parameter generation, multitask); appendix.
