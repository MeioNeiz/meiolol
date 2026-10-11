---
title: LoLalytics Darius top counters page (matchup game counts, patch 16.20)
url: https://lolalytics.com/lol/darius/counters/
kind: dataset
commit:
for: [riot-api-data-depth]
looked: 2026-10-11
depth: listed (whole page, game counts per matchup)
relevance: medium
grade: B/weak
description: Snapshot of how many Emerald+ games a popular top laner's matchups reach a few days into patch 16.20
---
# LoLalytics Darius top counters page (matchup game counts, patch 16.20)

Why: real per-matchup sample sizes on a big aggregate site, to compare with what our own
crawl could reach.

## Assessment

- Evidence: B. Live numbers from a major site; snapshot on 2026-10-11, patch 26.20 notes
  dated 2026-10-06, so a few days into the patch.
- Reasoning: weak. Page shows counts only, no method.
- Interests: stats site.
- Weigh: region scope not stated on the page (default view, probably all regions);
  Darius is a very popular top laner, so most champions see fewer games.

## Findings

- [data] Emerald+ view on patch 16.20 counts about 7.3 million champion picks analysed,
  i.e. roughly 730k games (inferred: 10 picks per game). ^f1
  > Emerald+ Champions Analysed: 7,289,340
- [data] Only matchups with 100+ games are listed; 61 top-lane opponents qualified. ^f2
  > Below is a detailed breakdown of [Darius](https://lolalytics.com/lol/darius/counters/) top counters against top champions with a minimum of 100 games.
- [data] Even for a popular champion, a few days in, most top matchups sit in the hundreds
  of games: the largest is 2,082 (vs Sett), several are just over 100 (Zed 150). ^f3
  > Δ1 0.67 • Δ2 -2.46 47.94% VS 2,082 Games
  > Δ1 -3.41 • Δ2 -6.54 47.41% VS 150 Games
- [data] [method] Matchup rows show win rate vs, opponent's overall win rate, and two
  delta measures (Δ1, Δ2) adjusting for champion strength. ^f4
  > WR vs All Champs WR Δ1 Δ2 Games
- [data] Checked, not there: no per-minute or gold@15 numbers by matchup on this page. ^f5
