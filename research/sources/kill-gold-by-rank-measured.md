---
title: 'Kill gold and early leads by lobby rank in ranked solo (our measurement, 2026-10-20)'
url: https://meio.lol/?measured=kill-gold-by-rank-measured
kind: dataset
commit: 
for: [coach-stat-claims]
looked: 2026-10-20
depth: ran
relevance: high
grade: A/fair
description: Kill gold (bounty plus shutdown) by lobby tier, game time and the killer team's lead, chained early kills, and team gold leads at 10 and 14 by tier, over 18.7M kills in 291k ranked solo games
---
# Kill gold and early leads by lobby rank in ranked solo (our measurement, 2026-10-20)

Why: check [[coachrogue-challenger-kill-gold]] (high-rank kills mean more, leads come by
10 minutes) and [[coachrogue-bounty-system]] (bounties reward the losing team) on our
games.

## Assessment

- Evidence: A. Every champion kill (18,714,920) in 290,807 ranked solo games with
  timelines (events.tsv, snap-20261013T2253Z), patches 16.19-16.20, all regions; team
  gold at 10 and 14 for 274,175 lab games and 60,541 local ones.
- Reasoning: fair. Simple sums and shares; the lead before a kill comes from the last
  minute frame, up to a minute stale; "over 450" is a proxy for an active bounty or
  shutdown (base is 300-420, first blood 400).
- Interests: none.
- Weigh: crawl floor Platinum IV, so Gold and below is small and atypical; post-game
  ranks. Kill gold excludes assist gold. "Chained" counts any team kill within 30 s,
  teamfights included, not the coach's deliberate follow-up plays. Script: ev.awk,
  report.py, lead.py in the session scratchpad.

## Findings

- [data] A kill pays the same gold at every lobby tier: 341 a kill in Gold and below and
  Platinum, 337 at Master+, and within 3 gold of each other in every 5-minute band. ^f1
  > Gold and below | 14425 | 1005132 | 69.7 | 341 | 28.8% | 9.3%
  > Master+ | 25987 | 1523315 | 58.6 | 337 | 29.3% | 8.9%
  > Master+ | 311 | 294 | 318 | 348 | 363 | 374 | 381
- [data] Higher-rank games have fewer kills: 69.7 a game in Gold and below, 66.6
  Platinum, 58.6 Master+. ^f2
  > Platinum | 91218 | 6072966 | 66.6 | 341 | 28.7% | 9.2%
- [data] Kill gold follows the team lead, as the bounty rules intend: from 10:00, a
  killer 3k+ behind gets 481 gold a kill on average and a bounty or shutdown in 37% of
  kills; within 1k of even, 330 and 5%; 3k+ ahead, 294 and none. ^f3
  > behind 3k+ | 2788670 | 481 | 37.3%
  > within 1k | 2599521 | 330 | 5.0%
  > ahead 3k+ | 4519167 | 294 | 0.0%
- [data] The comeback pattern is the same at every tier (36-38% of kills by teams 3k+
  behind pay a bounty, 5% near even). ^f4
  > Gold and below | 36.3% | 4.8% | 0.0%
  > Master+ | 38.2% | 5.0% | 0.0%
- [data] 29% of kills pay under 300 (a victim who has died a lot) and 9% over 450. ^f5
  > all | 290807 | 18714920 | 64.4 | 340 | 28.7% | 9.2%
- [data] Kills before 15:00 come in clusters equally at every tier: 66.4% have another
  kill by the same team within 30 s in Gold and below, 67.3% at Master+. ^f6
  > Gold and below | 385482 | 66.4%
  > Master+ | 704701 | 67.3%
- [data] Leads come only slightly earlier at high rank: the median team gold gap at 10
  minutes is 1,408 in Gold and below and 1,470 at Master+; the eventual winner is 1k+
  ahead at 10 in 47.5% vs 49.9% of games, at 14 in 59.9% vs 62.6%. The local snapshot
  agrees. ^f7
  > Gold and below | 14239 | 1408 | 2318 | 68.2% | 47.5% | 59.9% | 82.9%
  > Master+ | 25749 | 1470 | 2557 | 69.7% | 49.9% | 62.6% | 84.3%
  > Master+ | 6306 | 1478 | 2571 | 69.8% | 49.9% | 62.5% | 84.2%
- [data] A team 2k+ ahead at 14 wins 83% of games, 82.7% Platinum to 84.3% Master+. ^f8
  > Platinum | 90030 | 1410 | 2337 | 68.4% | 47.3% | 59.5% | 82.7%

## Read

- `raw/kill-gold-by-rank-measured.md`: all
