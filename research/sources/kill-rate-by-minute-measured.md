---
title: 'Kill rate and kill gold by game time in ranked solo (our measurement, 2026-10-20)'
url: https://meio.lol/
kind: dataset
commit: 
for: [kill-vs-farm-value]
looked: 2026-10-20
depth: ran
relevance: high
grade: A/strong
description: Every champion kill in 290k ranked solo timelines (lab snapshot 13 Oct) and 86k games on 16.19-16.20, binned by 5-minute band over the minutes games were still running
---
# Kill rate and kill gold by game time in ranked solo (our measurement, 2026-10-20)

Why: check the video's kill-rate claims ([[coachrogue-moneyball-stats]]) on our data.

## Assessment

- Evidence: A. 18.7M kills in 290,807 ranked solo games with full timelines, all
  regions; per game totals cross-checked on 85,693 games of 16.19-16.20.
- Reasoning: strong. The rate divides by game minutes still running in each band, so
  games that already ended don't pull the late bands down.
- Interests: none.
- Weigh: all ranks and regions pooled; no split by rank or role yet. Kill gold is the
  timeline's bounty plus shutdown, assist gold not included.

## Findings

- [data] Ranked solo games average about 64 kills and 28.9 minutes, 2.2 kills a minute (a kill every 27 s): close to the video's 67 and 2.32. ^f1
  > games 85693, kills per game 64.2, mean length 28.9 min, kills per minute 2.22
  > games 290807 kills 18714920 kills/game 64.4 mean min 28.9 kpm 2.23
- [data] Kill rate rises from 1.16 a minute in the first 5 minutes to 2.33 at 10-15 and 2.68 at 20-25. ^f2
  > 0-5 min | 290807 | 1.16 | 52 | 312
  > 10-15 min | 288382 | 2.33 | 26 | 317
  > 20-25 min | 262333 | 2.68 | 22 | 363
- [data] No late decline: per minute of games still running, the rate levels off at 2.8 from 25 minutes to 45+. ^f3
  > 25-30 min | 217100 | 2.82 | 21 | 374
  > 45+ min | 3097 | 2.80 | 21 | 388
- [data] Gold per kill (bounty plus shutdown) rises only about 30% over the game: 295 at 5-10 minutes to about 385 after 35. ^f4
  > 5-10 min | 290255 | 1.91 | 31 | 295
  > 35-40 min | 48821 | 2.83 | 21 | 385
- [data] (inferred) The video's 25-30 minute dip is what dividing by all games (not those still running) gives: a quarter of games have ended by 25 minutes. ^f5

## Read

- `raw/kill-rate-by-minute-measured.md`: all
