---
title: 'Guan, Javed, Lu 2023: NBA2Vec, dense feature representations of NBA players'
url: https://arxiv.org/pdf/2302.13386
kind: paper
commit: 
for: [nn-draft-models]
looked: 2026-10-13
depth: docs (sections 1-2, model, validation)
relevance: low
grade: C/weak
description: MIT student arXiv paper (2023); 8-dim player embeddings learnt by a mean-pooled offence and defence lineup net predicting 23 possession outcomes on 4.5M NBA plays, used for series simulation; no baseline
---
# Guan, Javed, Lu 2023: NBA2Vec, dense feature representations of NBA players

Why: the "2vec" name suggests co-occurrence pretraining of player embeddings for lineup
prediction; what it actually trains and whether it measures a lift.

## Assessment

- Evidence: C. Student arXiv paper, no code, no baseline model, validation by KL
  divergence on lineup pairs with 15+ plays and by playoff series simulation.
- Reasoning: weak. Describes the net; no comparison with plus-minus, ratings or
  scratch vs pretrained.
- Interests: none known.
- Weigh: useful only as a worked example of a DeepSets-style two-team net with a rich
  multi-class target; no effect size to cite.

## Findings

- [method] Despite the name, embeddings are learnt supervised, end to end, from
  possession outcomes, not word2vec-style co-occurrence. Section 2.B ^f1
  > The entire network is trained end-to-end with a cross entropy loss function that stochastically minimizes the K–L divergence between the true play outcomes from the data and the predicted distribution from the model.
- [method] Architecture: 8-dim shared player embedding, separate means over the 5
  offensive and 5 defensive players, concatenated, one 128 ReLU hidden layer, softmax
  over 23 play outcomes. Section 2.B ^f2
  > For each play, we first embed the 10 players on the court using an 8 dimensional shared player embedding. We then separately average the 5 offensive and 5 defensive player embedding vectors.
  > fed through one additional hidden layer of size 128 with a ReLU activation before outputting 23 outcome scores.
- [method] [data] Data: 4.5M plays, 3.7M train, rest validation; 1,551 players. Section 2.A
  ^f3
  > This preprocessing resulted in 4.5 million plays, of which we used 3.7 million for a training set and the remainder as a validation set.
- [method] Checked, not there: no baseline (plus-minus, logistic, ratings) and no
  pretrained vs scratch comparison; validation is KL divergence on lineup pairs with more
  than 15 plays and series simulation. ^f4
- [method] (inferred) Shows the pattern of a richer target (23 outcome classes per
  possession) to train small embeddings; for us the analogue is predicting per-game
  stats rather than only win, but this paper gives no measure of how much it helps. ^f5

## Read

- Abstract, 1, 2 (data, model, validation)

## Not read

- Embedding cluster analyses, lineup optimisation case study in detail
