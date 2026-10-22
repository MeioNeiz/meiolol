---
title: LoLalytics Darius top counters page (matchup game counts, patch 16.20)
url: https://lolalytics.com/lol/darius/counters/
kind: dataset
commit:
for: [riot-api-data-depth, champion-matchup-gap]
looked: 2026-10-22
depth: docs (whole page; 22 Oct: 1920x1080 screenshot and rendered text with positions)
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

### 22 Oct: layout (for champion-matchup-gap)

Raw: lolalytics-darius-counters.2026-10-22.md and .dom-1920x1080.txt (rendered text with
page y, x, font size). Screenshot darius-counters-1920-fold.png and -full.png in the
session scratchpad shots/lolalytics/.

- [ux/layout] Filter bar swaps queue and region for an enemy-role picker after VS (TOP,
  JNG, MID, BOT, SUP), so counters can be read against any enemy role. ^f6
  > y=89 x=897 9px: TOP
  > y=89 x=1057 9px: SUP
- [ux/density] Counters are cards, not a table: six per row, each about 118 by 255 px
  with a large splash portrait (about 118 by 118), WR vs, a Δ1 • Δ2 line, the opponent's
  overall win rate, and games; each card links to the vs page. A sort bar above (Name, WR
  vs, All Champs WR, Δ1, Δ2, Games). Default order is worst matchup first (Kennen 45.99%).
  (seen in screenshot) ^f7
  > y=573 x=758 13px: All Champs WR
  > y=738 x=517 12px: 45.99
  > y=830 x=505 12px: 237 Games
- [ux/density] First screen at 1920x1080: the same hero and prose as the build page (y 140
  to 480) pushes the cards to y 598, so 6 full cards and the top of 6 more show; 48
  matchups in all, page 2,940 px. A right column holds an ad and an unlabelled grid of
  about 170 champion icons (purpose not determined). (seen in screenshot) ^f8
  > counters/ at viewport 1920x1080, 2026-10-22 ... height 2940
- [ux/density] (inferred) A splash image per opponent spends about 45% of each card on
  identity that a 32 px icon would carry; the build page's strip fits 12 opponents with 5
  numbers each in the height of one card row. ^f9
