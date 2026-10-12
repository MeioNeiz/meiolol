---
title: "CHAMP: Cross-domain Hybrid Architecture for Matchmaking and Prediction in Online Multi-Player Games (2026)"
url: https://arxiv.org/pdf/2609.04870
kind: paper
commit:
for: [draft-predictor-methods]
looked: 2026-10-12
depth: docs (abstract, intro, datasets 5.1, Table 1)
relevance: high
grade: B/fair
description: Cupid follow-up (Sept 2026) on a large MOBA's matchmaking logs (30M ranked), chronological split; pre-match player-history predictors reach only 50.4-56.9% on ranked
---
# CHAMP: Cross-domain Hybrid Architecture for Matchmaking and Prediction in Online Multi-Player Games (2026)

Why: the same team as [[moba-cupid-rematchmaking]], now with a time split: what do
player-history features honestly give inside matchmade ranked games?

## Assessment

- Evidence: B. Industrial logs, about 40M casual, 30M ranked, 0.1M elite games;
  chronological split; online A/B tests. arXiv preprint, game unnamed.
- Reasoning: fair. States the split choice and why; reports accuracy and RMSE.
- Interests: authors' own system against baselines.
- Weigh: the ranked column is the honest ceiling for history-based pre-match features in
  a matchmade queue. RMSE values (0.42 at 57% accuracy) look too low for those accuracies;
  don't rely on them.

## Findings

- [method] Split chronologically to avoid temporal leakage: earliest matches train,
  latest test. ^f1
  > To prevent any temporal leakage, we partition each dataset chronologically rather than by random sampling
- [method] Ranked ("League") accuracy, time split: LR 50.40%, MLP 51.53%, LSTM 52.31%,
  Transformer 54.29%, OwO (Cupid's model) 55.65%, their DAWN 56.85%. Casual mode
  reaches 66.1%, elite 67.7%. ^f2
  > Offline, DAWN achieves 67.73% win-rate prediction accuracy
- [method] (inferred) OwO scored 64.3% on ranked with Cupid's random split and 55.65% on
  ranked here with a time split (datasets similar, maybe not identical): most of that gap
  is likely the split. Ranked is the hardest mode because matchmaking is tightest. ^f3
- [data] Cold start: many queued players have few ranked games this season; using their
  other modes' history helps. ^f4
  > A large fraction of queueing players have very limited match history in the target mode
- [data] (inferred) For LoL: match-v5 history by PUUID covers normals and ARAM too
  (queue id per match), so cross-queue history is available for an internal model. ^f5

## Read

- Abstract, intro challenges, 5.1 setup, Table 1

## Not read

- Architecture (DAKE, encoders), ablations, online A/B results
