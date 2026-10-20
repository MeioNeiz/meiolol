---
title: 'Game length by lobby rank in ranked solo (our measurement, 2026-10-20)'
url: https://meio.lol/?measured=game-length-by-rank-measured
kind: dataset
commit: 
for: [coach-stat-claims]
looked: 2026-10-20
depth: ran
relevance: high
grade: A/fair
description: Game length and first baron to end by lobby tier (median post-game tier) in 364k ranked solo games on 16.19-16.20, cross-checked on the local 86k
---
# Game length by lobby rank in ranked solo (our measurement, 2026-10-20)

Why: check [[coachrogue-game-length]] ("about 30 minutes in low elo, about 25 in
Challenger") on our games.

## Assessment

- Evidence: A. 363,927 ranked solo games (lab snapshot snap-20261013T2253Z) and the
  local 85,693 (data/snap), patches 16.19-16.20, all regions; the local set largely
  overlaps the lab set, so it is a consistency check, not a second sample.
- Reasoning: fair. Plain distributions; lobby tier is the median post-game tier of the
  players with a known tier (6+ of 10). Baron to end from events.tsv (290,807 games).
- Interests: none.
- Weigh: our crawl starts at Platinum IV, so lobbies below Platinum are few (Bronze 593,
  Silver 1,344, Gold 15,989) and reached through Plat+ players' histories: real low elo
  is not in this data. Ranks are looked up after the game (sometimes days later), so a
  lobby's tier partly reflects recent results. No control for region or surrender
  votes. Script: games.py, length.py, ev2.awk in the session scratchpad.

## Findings

- [data] Games get shorter as lobby rank rises: median 31.3 minutes in Bronze-median
  lobbies, 30.5 Gold, 29.7 Platinum, 27.1 Master, 26.1 Challenger. ^f1
  > Bronze | 593 | 31.2 | 31.3 | 26.0-36.5 | 9% | 13% | 21% | 28% | 30% | 49%
  > Gold | 15989 | 30.3 | 30.5 | 26.1-34.9 | 8% | 12% | 27% | 28% | 25% | 56%
  > Platinum | 115990 | 29.5 | 29.7 | 25.6-33.9 | 9% | 13% | 30% | 28% | 20% | 58%
  > Master | 30284 | 26.9 | 27.1 | 23.2-31.1 | 14% | 22% | 33% | 21% | 9% | 55%
  > Challenger | 570 | 25.9 | 26.1 | 22.1-30.2 | 19% | 25% | 30% | 19% | 7% | 49%
- [data] The change is mostly in the tails: games under 20 minutes go from 8-9% (Gold,
  Platinum) to 17-19% (Grandmaster, Challenger), games of 35+ minutes from 25-30% to
  7-8%. ^f2
  > Grandmaster | 3143 | 26.3 | 26.4 | 22.5-30.5 | 17% | 24% | 32% | 20% | 8% | 52%
- [data] Overall the median game is 29 minutes and 58% end between 25 and 35. ^f3
  > all | 363927 | 28.8 | 29.0 | 24.9-33.1 | 10% | 16% | 31% | 27% | 17% | 58%
- [data] The local 16.19-16.20 snapshot gives the same picture (Gold 30.5, Platinum 29.8,
  Master 27.1, Challenger 26.6 median). ^f4
  > Gold | 4853 | 30.2 | 30.5 | 26.2-34.9 | 8% | 12% | 27% | 28% | 24% | 56%
  > Challenger | 211 | 26.2 | 26.6 | 22.4-30.6 | 16% | 25% | 30% | 20% | 8% | 51%
- [data] After the first baron, the baron team wins 80-81% at every tier; Master+
  baron teams close a little faster (57% end within 5 minutes against 52% for Gold and
  below and Platinum), a small gap next to the video's replay contrast. ^f5
  > Gold and below | 10790 | 80% | 34% | 52% | 4-5
  > Master+ | 19820 | 81% | 35% | 57% | 4-5
- [data] (inferred) Shorter high-rank games come with fewer kills a game (69.7 Gold and
  below to 58.6 Master+, [[kill-gold-by-rank-measured#^f2]]), but kills per minute
  barely differ (about 2.3 vs 2.2). ^f6

## Read

- `raw/game-length-by-rank-measured.md`: all
