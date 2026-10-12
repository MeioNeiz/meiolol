---
title: 'Which Heroes to Pick? Learning to Draft in MOBA Games with Neural Networks and Tree Search (JueWuDraft, 2020)'
url: https://arxiv.org/pdf/2012.10171
kind: paper
commit:
for: [draft-predictor-methods]
looked: 2026-10-12
depth: docs (win-rate predictor sections III.C, IV.A-B)
relevance: medium
grade: C/weak
description: Tencent AI Lab (IEEE ToG 2021); MCTS drafting for Honor of Kings with a draft-only NN win-rate predictor trained on 30M top-5% human games, compared with LR and GBDT
---
# Which Heroes to Pick? Learning to Draft in MOBA Games with Neural Networks and Tree Search (JueWuDraft, 2020)

Why: the largest draft-only dataset found (30M human games); does a neural predictor
beat LR and GBDT at that scale?

## Assessment

- Evidence: C for the predictor result. Industrial lab (Tencent), huge data, but the
  predictor is a side component: architecture and baselines barely described, results
  only as a bar chart, random 10-fold CV, no log loss or calibration.
- Reasoning: weak on this point. The NN beats LR by 5 accuracy points on human games,
  far more than every other paper's NN vs LR gap; no explanation, and the LR input
  encoding is not stated (the NN takes hero indices into an embedding).
- Interests: authors' own system.
- Weigh: shows a 30M-game draft-only NN reaching AUC 0.69 in Honor of Kings top 5%;
  treat the size of the NN-over-LR gain as unverified.

## Findings

- [method] Win-rate predictor: a simple 3-layer network over the 10 hero indices,
  sigmoid output, used as the reward for tree search. Section III.C ^f1
  > a simple 3-layer neural network with an output layer connected by a sigmoid activation function
  > The input feature is represented by the indices of all 10 picked heroes.
- [data] Human dataset: 30 million Honor of Kings matches by top 5% players over ten
  days, 1 to 10 Aug 2020, 95 heroes (so about one patch). Section IV.A ^f2
  > played by top 5% human players between August 1st, 2020 to August 10th, 2020
  > this match dataset is set to contain 30 million matches
- [method] Evaluation: accuracy, AUC and F1 averaged over 10-fold cross validation
  (random folds, not time). Section IV.B ^f3
  > accuracy, area under ROC curve (AUC), and the harmonic mean of the precision and recall (F1-Score) for each kind of methods in Fig. 7(a) and Fig. 7(b), averaged over 10-fold cross validation
- [method] Human games (Fig. 7b): NN accuracy 0.617, AUC 0.694; LR 0.568, AUC 0.642;
  GBDT 0.561, AUC 0.648. AI self-play games: NN 0.847 accuracy, AUC 0.908. ^f4
  > 8.6% better on the accuracy, 8.1% better on AUC and 11.4% better on F1-Score than the second best method (LR) for the Human Dataset
- [method] Every model does worse on human games than AI self-play games, which the
  authors put down to varied human players. ^f5
  > Note that all classification methods perform worse on the Human Dataset.
- [method] (inferred) At 30M one-patch games, an embedding NN over picks beat LR by
  0.05 AUC, unlike the 0.00-0.03 gaps elsewhere ([[chen-avatar-embedding-2018#^f4]],
  [[draftrec-2022#^f4]]). Possible reasons: much more data supports more interaction
  terms, or a weak LR baseline; unresolved. ^f6

## Read

- Abstract, sections III.C (predictor), IV.A-B, Fig. 7

## Not read

- MCTS drafting details, multi-round (BO3/BO5) results
