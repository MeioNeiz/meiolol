---
title: 'Xenopoulos and Silva 2022: ESTA, an esports trajectory and action dataset (win probability benchmarks)'
url: https://arxiv.org/pdf/2209.09861
kind: paper
commit: 
for: [nn-draft-models]
looked: 2026-10-13
depth: docs (sections 4-5, win probability benchmark)
relevance: low
grade: B/fair
description: NYU 2022 CS:GO dataset paper (NeurIPS datasets track submission); benchmarks Deep Sets and Set Transformer over players against XGBoost, LightGBM and an MLP on team-aggregated vectors for round win probability
---
# Xenopoulos and Silva 2022: ESTA, an esports trajectory and action dataset (win probability benchmarks)

Why: one of the few head-to-head tests of set models (Deep Sets, Set Transformer) over
the players of a team against vector models on aggregated team features, for win
probability, with log loss.

## Assessment

- Evidence: B. Established sports-analytics author (awpy, earlier CS:GO win
  probability papers); log loss and ECE averaged over 10 runs with standard errors.
- Reasoning: fair. Honest that set models lost; tiny data (130-290 demos per map, one
  state per round), default hyperparameters, random split; in-game state, not draft.
- Interests: dataset authors, no stake in which model wins.
- Weigh: directionally useful (set models need more data or tuning to beat aggregated
  features); not about drafts, so effect sizes do not transfer.

## Findings

- [method] [data] Set inputs: each player is an element (position, HP, equipment,
  flags) with global state copied in; vector inputs aggregate per team. One game state
  sampled per round, random 70/10/20 split, per map. Section 5.2-5.3 ^f1
  > Then, we randomly select 70% of these game states for the train set, 10% for the validation set, and the remaining 20% for the test set.
- [method] Configs: Deep Sets with one dense layer encoder and one dense layer decoder,
  mean pooling; Set Transformer with one ISAB and one head, PMA decoder; hidden 128,
  batch 32, Adam 1e-3, 100 epochs, early stop 10. Section 5.3 ^f2
  > Our Deep Sets model uses one fully connected layer in the encoder and one fully connected layer in the decoder. We use the mean as the final aggregation.
  > When training our Deep Sets and Set Transformer models, we use a batch size of 32 and a hidden vector size of 128 for all layers.
- [method] [data] Data: 1,558 demos in all, 132-289 per map (one sampled state per
  round). Section 4 ^f3
  > In total, ESTA contains 1,558 parsed JSONs which contain 8.6m actions, 7.9m frames, and 417k trajectories.
- [method] Result: vector models, especially the plain MLP, beat both set models on log
  loss; Deep Sets slightly beat Set Transformer. Dust2 LL: LightGBM 0.433, XGBoost 0.437,
  MLP 0.415, Deep Sets 0.435, Set Transformer 0.458. Section 5.5, Table 1 ^f4
  > the models considering vector-based input, such as LightGBM, XGBoost, and in particular, the MLP achieved strong performance against our set-based approaches. Concerning the set-based models, we observed that the Deep Sets slightly outperformed the Set Transformer.
- [method] (inferred) At small data the attention model was the worst of five: a set
  architecture is not a free win over sensible aggregate features, and the simplest
  permutation-invariant pooling beat attention. ^f5

## Read

- Sections 4 (dataset), 5 (win probability benchmark), Table 1 (two maps cleanly)

## Not read

- Other maps' rows (table interleaved in raw), trajectory and action sections
