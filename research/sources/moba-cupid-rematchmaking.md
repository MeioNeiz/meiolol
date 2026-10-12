---
title: "Cupid: Improving Battle Fairness and Position Satisfaction in Online MOBA Games with a Re-matchmaking System (Tencent, 2024)"
url: https://arxiv.org/pdf/2406.19720
kind: paper
commit:
for: [draft-predictor-methods]
looked: 2026-10-12
depth: docs (features 4.2, datasets 5.1, feature-group and MMR results 5.3)
relevance: high
grade: B/fair
description: Industrial re-matchmaking for an unnamed mobile MOBA (30M ranked games); pre-match predictor from player history and MMR logged at match time; MMR alone 52.8%, all player features 64.3% (random split)
---
# Cupid: Improving Battle Fairness and Position Satisfaction in Online MOBA Games with a Re-matchmaking System (Tencent, 2024)

Why: a matchmaking-aware study at scale: how much do player features predict beyond MMR
inside matchmade games, with features captured at queue time (no post-game snapshot)?

## Assessment

- Evidence: B. 30M ranked and 4M normal training games, deployed with online A/B tests;
  game unnamed (NDA), mobile MOBA, before hero picks. Random 80/20 split.
- Reasoning: fair. Clear feature groups and ablations; accuracy only, no calibration.
- Interests: authors built and sell the system internally; MMR baseline is theirs to beat.
- Weigh: the MMR-alone number and feature-group ordering are the useful part. The random
  split likely flatters the 64%: the follow-up with a chronological split
  ([[moba-champ-matchmaking#^f2]]) reports 55.7% for the same model on ranked games.

## Findings

- [data] Player features: short-term (last K games: kills, deaths, positions, champions),
  long-term (last 30 games: averages, position counts, top champions), real-time (MMR,
  pre-selected position), team (team MMR mean and variance). ^f1
  > These features encapsulate the detailed game performance of the player in the last 𝐾 games.
- [data] Features are logged by the game backend at match time for offline training, so
  no post-game snapshot. ^f2
  > the processed features are logged into an offline database to support offline model training
- [data] Data: 30M train, 3M validation, 8M test ranked games; random 80/20 split. ^f3
  > we adopted a standard approach by randomly dividing the samples into a training
- [method] Under one-step MMR matchmaking, an MMR-based (TrueSkill) predictor gets 52.83%;
  their player-history model 63.19%. ^f4
  > in one-step matchmaking, OwO significantly outperforms MMR-based methods that use TrueSkill
- [method] Ranked accuracy by feature group: team (MMR) features 56.3%, short-term 58.9%,
  long-term 58.2%, all 64.3%. Recent games beat long-term stats. ^f5
  > models utilizing short-term features outperformed those using long-term features
- [method] After re-matchmaking with the predictor, MMR prediction falls below 50% and
  their own to 52.55%: matchmaking that uses a predictor removes what it predicts. ^f6
  > In two-step matchmaking, the MMR-based method is nearly ineffective, with an accuracy below 50%
- [method] Players' position preferences and proficiency matter beyond MMR: equal team
  MMR with misassigned positions still gives lopsided games. ^f7
  > Even if players possess the same overall MMR rating, the actual performance of a team can significantly differ due to variations in individual players’ proficiency across different positions
- [method] (inferred) For LoL: role/autofill is the analogue of position satisfaction;
  match-v5 gives teamPosition but not queue preferences, so autofill must be inferred
  from a player's role history. ^f8

## Read

- Abstract, intro, 4.2 features, 5.1 datasets, 5.3 ablations and MMR comparison

## Not read

- OwO architecture (4.4), online A/B engagement results, latency
