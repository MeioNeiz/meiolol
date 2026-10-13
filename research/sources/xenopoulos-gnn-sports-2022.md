---
title: 'Xenopoulos and Silva 2022: Graph neural networks to predict sports outcomes'
url: https://arxiv.org/pdf/2207.14124
kind: paper
commit: 
for: [gnn-match-outcome]
looked: 2026-10-13
depth: docs (sections III-IV, Table I)
relevance: low
grade: C/fair
description: NYU 2022 (IEEE Big Data); in-game states as fully connected graphs of player nodes (position, health, kit), GAT or GCN vs a flat state vector, on NFL rushing plays and pro CS:GO round win probability; graph alone loses on CS:GO, graph plus vector gains 1.7% log loss
---
# Xenopoulos and Silva 2022: Graph neural networks to predict sports outcomes

Why: (a) the closest measured comparison of a graph over the 10 players vs a flat
vector model for team win probability, from the authors of [[esta-csgo-2022]].

## Assessment

- Evidence: C. Two tasks, NFL 4,038 plays (30 repeated splits, t-tests) and 7,222 pro
  CS:GO games (14M states, one split). Peer-reviewed workshop-level paper.
- Reasoning: fair. Compares graph-only, vector-only and combined models; reports log
  loss. But the split is over game states, not games or time, and the headline "20%"
  is against their own earlier model, not the vector baseline in the same table.
- Interests: authors' method.
- Weigh: in-game spatial states, not a draft; read only for "graph over 10 players vs
  flat vector" and note the graph helped only when added to the vector.

## Findings

- [method] Game state as a fully connected graph: one node per player with
  coordinates, health, armour, equipment and side; GAT learns edge weights, the GCN
  uses inverse distance. Section III ^f1
  > Sports situations can be represented with fullyconnected graphs using nodes as players.
- [method] Split: 70/10/20 over game states, not by game or date. Section III-D3 ^f2
  > We use 70% of game states for training, 10% for model validation, and 20% for testing in both of our prediction tasks.
- [method] Table I, CS:GO log loss (AUC): state vector 0.4351 (0.8715), GCN 0.6111,
  GAT 0.4465 (0.8684), GCN + state 0.4357, GAT + state 0.4276 (0.8753). The graph
  alone loses to the flat vector; graph plus vector gains 0.0075 log loss (1.7%). ^f3
  > In Table I, we see that the combined GAT + State model outperformed the state model.
- [method] Headline gains are against prior work: 9% on NFL (vs the state model, 30
  repeats, significant), 20% on CS:GO vs their earlier published model. Abstract ^f4
  > reducing test set loss by 9% and 20%, respectively.
- [method] Checked, not there: no game-level or time split for CS:GO, a single split
  there, no player identity or skill in the nodes, no draft or loadout-only
  (pre-round) model. ^f5
- [method] (inferred) For us: matches [[esta-csgo-2022#^f4]] in spirit; over 10 player
  slots a structured set or graph model adds little or nothing over a good flat model
  unless the nodes carry rich per-player continuous state. Our draft nodes would carry
  champion ids and a few history numbers, the weak case. ^f6

## Read

- Abstract, sections III (graph, models, tasks) and IV-A/B, Table I

## Not read

- Attention head ablation (Table II), keypoint features, what-if case studies
