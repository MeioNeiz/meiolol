---
title: LoLalytics Kalista top counters page (100-game matchup minimum)
url: https://lolalytics.com/lol/kalista/counters/?lane=top
kind: docs
commit:
for: [riot-api-data-depth]
looked: 2026-10-11
depth: listed (whole page)
relevance: medium
grade: B/weak
description: Counters page for an off-role pick; states lolalytics' 100-game minimum for showing a matchup
---
# LoLalytics Kalista top counters page (100-game matchup minimum)

Why: what sample threshold a leading stats site uses before showing a matchup.

## Assessment

- Evidence: B. Live page of a major stats site (patch 16.20, Emerald+), its own rule.
- Reasoning: weak. Threshold stated, not justified.
- Interests: stats site; low thresholds mean more content.
- Weigh: 100 games is a display floor, not a reliability standard; at 100 games a 50%
  win rate has a 95% interval of roughly +/- 10 points (inferred, binomial).

## Findings

- [data] [ux/uncertainty] LoLalytics shows a matchup only once it has 100 games. ^f1
  > A matchup requires a minimum of 100 games to be displayed.
- [data] Off-role picks often lack data for a whole patch view: Kalista top had too few
  games to rank counters on patch 16.20 at Emerald+. ^f2
  > Presently there is insufficent games played by
  > top on Patch 16.20 to determine the strongest top counters.
- [data] [ux/uncertainty] (inferred) At the 100-game floor a matchup win rate is noisy: binomial standard
  error at p = 0.5 and n = 100 is 5 points, so 95% interval +/- 10 points. ^f3
