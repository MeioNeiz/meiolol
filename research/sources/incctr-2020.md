---
title: A Practical Incremental Method to Train Deep CTR Models
url: https://arxiv.org/pdf/2009.02147
kind: paper
commit: 
for: [patch-shift-nets]
looked: 2026-10-23
depth: docs (full paper)
relevance: high
grade: B/fair
description: Wang, Guo, Tang, Liu, He (Huawei Noah's Ark, 2020, IncCTR); daily incremental training of a deep CTR model (DCN) warm-started from yesterday's model, one epoch on the new day, new ids admitted by count and randomly initialised, optional distillation from the previous model; compared day by day with sliding-window full retrains with 0-5 days' delay
---
# A Practical Incremental Method to Train Deep CTR Models

Why: the cleanest published comparison of "warm start and train on the new day only"
against "retrain on a sliding window", with a next-day evaluation protocol and log loss.

## Assessment

- Evidence: B. Huawei AppGallery production data (60 days) plus Criteo (24 days); one
  model (DCN), mean over consecutive test days, no error bars or seeds; the data
  (reservoir) module is unfinished.
- Reasoning: fair. Clear protocol and baselines with delay; little on why the
  incremental model beats a full retrain on Criteo.
- Interests: authors' own method.
- Weigh: trust the protocol and the direction (incremental is about as good as a full
  retrain at 60-270x less compute; staleness costs more than either choice); gaps of
  0.0001-0.001 AUC between variants are within what one seed could move.

## Findings

- [method/dynamics] Batch baseline retrains on a sliding fixed-size window (day 1-10,
  then 2-11...); incremental warm-starts from the existing model and trains on the new
  day only. 2.2 ^f1
  > The model trained in the batch mode is iteratively learned based on the data from a fixed-size time window.
  > With incremental mode, the model is trained based on the existing model and new data.
- [method/dynamics] Protocol: walk forward over consecutive days; the first incremental
  model is warm-started by a batch model on the first w days (7 Criteo, 30 HuaweiApp),
  then each day's model is tested on the next day; mean AUC and log loss over test days.
  4.2 ^f2
  > Warm-start is performed for the incremental models with a model trained with batch mode before the first incremental step.
  > To mimic the training procedure in industrial scenarios, experiments are conducted over consecutive days.
- [method/dynamics] Staleness is the bigger cost: a model not updated for 5 days loses
  0.66% AUC on HuaweiApp; batch models with 1-5 days' delay lose steadily. 1, Table 1 ^f3
  > if the model stops updating for 5 days, the model performance degrades 0.66% in terms of AUC
  > On both datasets, severe performance degradation is observed as the delayed period extends
- [method/dynamics] Incremental fine-tune (one epoch on the new day) matched or beat the
  ideal full retrain on Criteo (AUC 0.7982 vs 0.7977, log loss 0.5431 vs 0.5438) and
  was close on HuaweiApp (0.8527 vs 0.8543), at 60x and 270x less training time.
  Table 1, 4.5 ^f4
  > Surprisingly, IncCTR achieves comparable performance to Batch-0 (which is an ideal model with upper bound performance).
  > Tremendous advantage on efficiency is revealed, as we are able to get 60x and 270x improvement over average
- [method/dynamics] Fine-tune recipe: inherit all embeddings and network weights, use a
  lower learning rate for existing embeddings than for new ones, train one epoch. 3.2 ^f5
  > we conduct a lower learning rate for Eexist compared to that for Enew
  > We train the model for a fixed number of epochs, where empirically we set the number to be 1
- [method/dynamics] New ids: counted as data arrives; an id rare so far sits in a shared
  "Others" bucket and gets its own embedding once its count passes a threshold (20 on
  Criteo); new embeddings start random, existing ones inherit. 3.1, 4.1 ^f6
  > It is possible that a feature x, which is previously treated as Others, is considered as a unique feature if its occurrence S[x] is above the threshold T HR after new data coming in.
  > For a new feature, its embedding is randomly initialized as no prior knowledge is available
- [method/dynamics] Freezing the id vocabulary (no new ids) cost 0.08% AUC on Criteo and
  0.055% on HuaweiApp, growing over days past 0.1%. 4.4 ^f7
  > the consistent performance degradation demonstrates the necessity of expanding new features
- [method/dynamics] Distillation from the previous model (KD-self) or an older batch
  model (KD-batch) to limit forgetting was no better than plain fine-tune on Criteo and
  only slightly better on HuaweiApp. 4.4 ^f8
  > Compared with fine-tune, two KD methods (KD-batch and KD-self) achieve similar performance on Criteo and slight better performance on HuaweiApp dataset.
- [method/dynamics] Replay of old data (reservoir) was planned but not built; whether to
  mix history into the incremental step is left open. 3.3 ^f9
  > The implementation of data module is not finished for now and will be a part of future work to accomplish our framework.
- [method/dynamics] Checked, not there: nothing for an existing id whose behaviour
  changes abruptly; existing ids get a lower learning rate, the opposite of what a
  patched champion needs. ^f10
- [method/dynamics] (inferred) For us: a daily warm-started one-pass update of the set
  net on yesterday's games, scored on the next day's games before it trains on them, is
  the cheap baseline to beat; a full retrain over a sliding window is the reference.
  For patched champions the learning-rate rule should be reversed (higher for changed
  champion-role embeddings). ^f11

## Read

- Full paper (sections 1-5, Tables 1-2)

## Not read

- Figures 1, 4, 5 (images only; numbers taken from text)
