---
title: Revisiting Pretraining Objectives for Tabular Deep Learning
url: https://arxiv.org/pdf/2207.03208
kind: paper
commit: 
for: [frontier-pretrain]
looked: 2026-10-21
depth: docs (sections 1-4)
relevance: high
grade: B/strong
description: Rubachev, Alekberov, Gorishniy, Babenko (Yandex, 2022); systematic test of contrastive, reconstruction and mask-prediction pretraining on the same fully labelled data, for tuned MLPs and embedding MLPs on 11 datasets, 15 seeds, significance tests
---
# Revisiting Pretraining Objectives for Tabular Deep Learning

Why: the controlled test of "pretrain on the same table, then fine-tune" against tuned
from-scratch nets, the critic's check on masked-pick or contrastive pretraining for us.

## Assessment

- Evidence: B. Yandex tabular DL group (rtdl, FT-Transformer authors), 11 datasets of
  6k-500k rows, 15 seeds, Tukey HSD, tuned baselines; code public.
- Reasoning: strong. Compares objectives under one protocol and reports where
  pretraining hurts.
- Interests: authors of the embedding MLPs tested.
- Weigh: datasets are mostly numeric, few categoricals, none near coin flip; gains are
  for nets, and strongest for the plain MLP, the weakest baseline.

## Findings

- [method/pretrain] Setting: pretraining on the downstream dataset itself, all labels
  available, against tuned from-scratch baselines. 1, 3.1 ^f1
  > we focus on the setup with fully labeled tabular datasets to understand if pretraining helps tabular DL in a fully supervised setting
  > Pretraining is always performed directly on the target dataset
- [method/pretrain] Contrastive pretraining is not better than simpler self-prediction
  (reconstruct corrupted columns, or predict which columns were corrupted). 3.2 ^f2
  > Both the reconstruction and the mask prediction objectives are preferable to the contrastive objective.
- [method/pretrain] Gains are smaller for the stronger embedding models than for vanilla
  MLPs; mask prediction sometimes drops performance for embedding models. 3.2 ^f3
  > However, the improvement is typically less noticeable compared to the vanilla MLPs.
  > the mask prediction objective sometimes leads to unexpected performance drops for models with numerical embeddings
- [method/pretrain] Sizes (Table 2, 15-seed means): Adult ROC AUC, MLP 0.908 to 0.912
  with mask pretraining; MLP-PLR 0.926 to 0.927; Higgs accuracy MLP 0.801 to 0.814. ^f4
- [method/pretrain] Target-aware objectives (label used during pretraining: supervised
  loss on corrupted inputs plus reconstruction, or target-conditioned mask prediction)
  beat unsupervised ones. 4 ^f5
  > Target-aware objectives help further increase the downstream performance, improving upon their unsupervised counterparts.
- [method/pretrain] Supervised loss on corrupted inputs alone (a masking augmentation)
  is a strong baseline for the MLP but inconsistent, sometimes worse than scratch, for
  embedding models. 4 ^f6
  > for models with numerical embeddings the supervised objective with corruptions is less consistent and sometimes is inferior to training from scratch
- [method/pretrain] Ensembles of pretrained nets still gain: pretraining does not
  remove much seed diversity. 1 ^f7
  > The ensembling of pretrained models is beneficial.
- [method/pretrain] (inferred) For us: pretraining on our own games is semi-supervised
  reuse of the same rows; the measured gains are largest for the weakest nets and
  shrink for strong ones, and our nets already sit on a fitted logistic offset. Expect
  little from unsupervised masked-pick pretraining of a win net; if tried, the
  target-aware form (win loss plus masked-pick reconstruction) is the one with evidence. ^f8

## Read

- Sections 1-4, Tables 1-3

## Not read

- 4.2 comparison with GBDT, 5 ablations, appendices
