---
title: 'Bisberg and Ferrara 2022: GCN-WP, semi-supervised graph convolutional networks for win prediction in esports (CoG)'
url: https://arxiv.org/pdf/2207.13191
kind: paper
commit: 
for: [gnn-match-outcome]
looked: 2026-10-13
depth: docs (full paper)
relevance: low
grade: D/weak
description: USC IEEE CoG 2022 paper; pro LoL team-game nodes linked to the opponent and the team's previous game, Kipf GCN on post-game stat deltas; trains on LPL, tests on one LCS season; 61.9% vs Elo 59.7%, no intervals
---
# Bisberg and Ferrara 2022: GCN-WP, semi-supervised graph convolutional networks for win prediction in esports (CoG)

Why: (a)/(c) the only LoL paper found that puts a GNN over the match graph itself; does
the graph beat ratings?

## Assessment

- Evidence: D. Pro LoL only (Oracle's Elixir), test set one league's 2020 regular season
  (a few hundred games at most), a single accuracy number per model, no intervals or
  repeats; selection by grid search over many configs.
- Reasoning: weak. The undirected graph lets convolutions see neighbouring future
  games; the authors shift labels to compensate, which is hard to check. Node features
  are the team's in-game stats.
- Interests: first author also wrote SCOPE, the main baseline.
- Weigh: a 2.2-point edge over Elo on a few hundred games is within noise; do not cite
  as evidence that GNNs help.

## Findings

- [method] Graph: one node per team-game with that game's stat deltas (gold, kills,
  objectives, vision vs opponent), edges to the opponent's node and the team's previous
  game; homogeneous Kipf GCN, semi-supervised node classification. Algorithm 1,
  section IV-A ^f1
  > For each team the games are ordered in ascending order and a node is added with the features from that game. A connection is drawn from that node to an opponents node and to that teams previous node.
- [method] Leak handling by label shifting: the symmetric adjacency lets convolution
  look forward, so a one-convolution model predicts further ahead. Section IV-C ^f2
  > if there is more than one graph convolution, the network would effectively be allowed to look in to the future.
- [data] Train on LPL, validate on LCK, test on LCS, 2020 regular seasons only. Section
  VI-A ^f3
  > The validation network is the LCK in Korea, which has the second most games.
  > LCS, or the American league.
- [method] Table IV accuracy: GCN-cheby 1 layer delta 0.619, SCOPE (tuned Elo) 0.597,
  random forest on last-5-game deltas 0.578, GCN-cheby 2 layers 0.568, plain GCN 0.551.
  More layers hurt. ^f4
  > More layers reduced prediction accuracy.
- [method] Checked, not there: no game counts for the test season, no intervals or
  repeated runs, no log loss, no LR or TrueSkill baseline, no draft or player-level
  inputs, no solo-queue data. ^f5
- [method] (inferred) For us: nothing transferable. Pro leagues are a dense
  round-robin graph of 10 fixed teams; ranked solo queue is a sparse graph of ad hoc
  teams, where the "neighbourhood" of a game is mostly strangers. ^f6

## Read

- Full paper

## Not read

- Code fork of Kipf's GCN (reference 34)
