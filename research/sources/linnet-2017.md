---
title: 'Pelechrinis 2017: LinNet, probabilistic lineup evaluation through network embedding (NBA)'
url: https://arxiv.org/pdf/1707.01855
kind: paper
commit: 
for: [gnn-match-outcome]
looked: 2026-10-13
depth: docs (full paper)
relevance: low
grade: C/weak
description: Pittsburgh 2017 workshop paper; node2vec on a directed NBA lineup-vs-lineup win network, embeddings into Bradley-Terry logistic; 67% vs 55% for adjusted plus-minus on a random 80/20 split of matchups within a season
---
# Pelechrinis 2017: LinNet, probabilistic lineup evaluation through network embedding (NBA)

Why: (b) does a node2vec embedding of a who-beat-whom graph, fed to a logistic model,
beat id-based ratings? The lead said 67-68% vs 55%.

## Assessment

- Evidence: C. One author, five NBA seasons of aggregate lineup matchups, two baselines
  (PageRank, adjusted plus-minus); accuracy and Brier only, no intervals.
- Reasoning: weak on evaluation. Split is a random 80/20 of matchups within a season,
  so a lineup's other games from the same weeks are in training; the baseline APM is
  per player, the embedding per lineup, so they do not answer the same question.
- Interests: author's method.
- Weigh: the 12-point gap is not evidence that graph embeddings beat ids; it compares
  lineup-level memory against player-level ratings on a leaky split.

## Findings

- [method] Graph: lineups are nodes, a directed edge from i to j when lineup j
  outscored lineup i, weighted by the margin; node2vec embeddings feed a Bradley-Terry
  logistic model. Definition 1.1, section 2 ^f1
  > An edge ei,j ∈ E points from node i ∈ V to node j ∈ V iff lineup j has outperformed lineup i.
  > These features are then utilized to build a logistic regression model for the probability of lineup λi outperforming lineup λj
- [method] Split: random 80% of a season's matchups to fit, 20% to test. Section 3 ^f2
  > For every season, we build each model using 80% of the
  > matchups and we evaluate them on the remaining 20% of the matchups
- [method] Result: LinNet 67% accuracy, APM 55%, PageRank 53%; Brier 0.19 vs 0.25 for
  a constant 0.5. Section 3 ^f3
  > LinNet’s accuracy is 67%, while APM exhibits a 55% average accuracy and PageRank a 53% accuracy.
- [method] Unseen lineups (no node) get a player-overlap weighted average of the team's
  known lineups' vectors; the author names a regression on players as the better
  future fix. Section 2, section 4 ^f4
  > for lineups we have not seen before we use as its latent features a weighted average of already seen lineups of the team, weighted based on their similarity in the players’ space.
- [method] Checked, not there: no time split, no lineup-id logistic or lineup-level
  plus-minus baseline (the like-for-like comparison), no game counts per test lineup. ^f5
- [method] (inferred) For us: no evidence for (b). A graph embedding of who beat whom
  is a smoothed win record; without an id baseline at the same level and a time split,
  the lift says nothing about beating learnt champion embeddings. ^f6

## Read

- Full paper (10 pages)

## Not read

- Nothing material
