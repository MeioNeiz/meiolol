---
title: 'Adjileye 2024: RisingBALLER, a player is a token, a match is a sentence'
url: https://arxiv.org/pdf/2410.00943
kind: paper
commit: 
for: [nn-draft-models]
looked: 2026-10-13
depth: docs (sections 2-3, appendix Table 7)
relevance: medium
grade: C/fair
description: StatsBomb Conference 2024 single-author paper; BERT-style masked player prediction pretraining over football lineups (1,792 matches), then fine-tuning for next-match team stats, with a pretrained vs from-scratch ablation
---
# Adjileye 2024: RisingBALLER, a player is a token, a match is a sentence

Why: does masked-token pretraining of player (for us champion) embeddings over rosters
help a downstream predictor at small data, compared with the same net trained from
scratch?

## Assessment

- Evidence: C. Single author, conference research stage, no released code at time of
  writing; but it contains the rare pretrained vs scratch ablation.
- Reasoning: fair. Clear setup and configs; downstream target is team stats, not win;
  pretraining used the same 1,792 matches the downstream task is evaluated on, and the
  split is by augmented sample, so held-out matches may have been seen in pretraining.
- Interests: author's own framework.
- Weigh: direction (pretraining helped by 11-13% MSE at under 2k matches) is plausible;
  the size is inflated by possible overlap and does not transfer to a win label.

## Findings

- [method] Pretraining task: masked player prediction, 25% of a match's players masked
  and predicted, like BERT. Section 3.1 ^f1
  > for each match, 25% of the input players are randomly masked, and the model is trained to predict these masked players.
- [method] [data] Data: StatsBomb 2015-16 top five leagues, 1,792 matches, 2,600
  players; augmentation by 10 different maskings per match (about 18,000 samples), split
  80/20 by sample. Sections 2.1, 3.1 ^f2
  > To enhance the model’s generalization capabilities given the relatively small dataset size, I augmented the data by creating 10 different MPP inputs per match, each with different players masked.
- [method] Configs: one transformer layer, D 64 or 128, AdamW lr 1e-4, batch 256, linear
  decay; fine-tune with warmup 0.1 and weight decay 0.01 to protect pretrained weights,
  all weights updated. Sections 3.1-3.2 ^f3
  > These last two hyperparameters were used to prevent rapid changes in the pre-trained weights, which could lead to unstable fine-tuning.
- [method] Pretrained vs from scratch on the downstream task (next match team stats,
  global MSE): 1 layer 64d 529.65 vs 607.29, 1 layer 128d 510.33 vs 574.33, so
  pretraining cut eval MSE by about 11-13%. Appendix Table 7 (table cells split across
  lines, quote is the caption) ^f4
  > Evaluation Loss Comparison for NMSP with and without MPP Pre-training: the values are the global average MSE over all statistics.
- [method] (inferred) The pretraining corpus is the downstream corpus, so the gain is
  semi-supervised reuse of the same lineups, not transfer from more data; with a sample
  level split the held-out matches likely appeared in pretraining. ^f5
- [method] Checked, not there: no win or result prediction downstream; no comparison
  with a simpler embedding (co-occurrence or stats-derived) or with linear models on the
  same target. ^f6

## Read

- Abstract, 1, 2 (data, architecture), 3 (MPP, NMSP results), appendix Table 7

## Not read

- Section 4 embedding analyses (positions, cohesion, similar players), appendix A.1
  architecture search
