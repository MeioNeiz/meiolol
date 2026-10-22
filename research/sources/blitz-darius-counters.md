---
title: 'Blitz: Darius top counters (patch 26.20)'
url: https://blitz.gg/lol/champions/darius/counters
kind: docs
commit: 
for: [champion-matchup-gap]
looked: 2026-10-22
depth: docs (rendered text, fold and full screenshots at 1920x1080 and 390x844)
relevance: medium
grade: B/fair
description: Blitz counters tab, three sortable tables side by side (score, game win rate, lane win rate), each with games and in-cell bars; rows link to the opponent's build, not a matchup page
---
# Blitz: Darius top counters (patch 26.20)

Why: the 20 Oct capture of [[blitz-darius]] did not scroll; what Blitz's counters tab
shows and how. Raw is the page's plain innerText (the Markdown capture held only the
consent banner).

## Assessment

- Evidence: B. Big site (Blitz app), live page.
- Reasoning: weak. No definitions on the page.
- Interests: vendor (premium, app).
- Shots: scratchpad shots/others/blitz-darius-counters-1920-{fold,full}.png.

## Findings

- [ux/layout] Three equal tables side by side, one per question: a matchup score, game win
  rate and lane win rate, each with games; same champion list three times, sorted
  differently. ^f1
  > CHAMPION SCORE GAMES Sion 101 280
  > CHAMPION GAME WR GAMES Zilean 62% 187
- [ux/density] Each value has a thin dashed bar under it (green under the stat, purple
  under games), rows about 47 px, about 14 rows visible per table before its own inner
  scroll (seen in screenshot blitz-darius-counters-1920-full.png). ^f2
- [ux/features] Lane win rate per opponent is a column of its own, beside game win rate,
  so "wins lane" and "wins game" are separate answers (as dpm's chip labels do,
  [[dpm-darius#^f1]]). ^f3
  > CHAMPION LANE WR GAMES Aurora 66% 492
- [ux/trust] Failure: Score (101 to -91) is undefined, and no header says whose win rate
  the columns hold; Sion tops Score (101) and sits at the bottom of Game WR (40%), so
  (inferred) the win rates are the opponent's against Darius while Score is Darius's
  edge, opposite directions in adjacent tables. ^f4
  > Sion 101 280 K'Sante 75 216
- [ux/layout] Failure: lists mix roles, mid laners and junglers among top opponents
  (Aurora, Corki, Zed lead Lane WR), as League of Graphs does
  ([[leagueofgraphs-darius-counters#^f6]]) (seen in screenshot
  blitz-darius-counters-1920-full.png). ^f5
- [ux/layout] Rows link to the opponent's own build page, not to a Darius vs X page; the
  matchup view is the build page's opponent filter ([[blitz-darius-vs-garen]]). ^f6
- [ux/uncertainty] Smallest samples about 190 games (Zilean 187 at 62%), so a floor near
  that is applied (inferred from the lowest counts shown); counts sit beside every rate. ^f7
  > Zilean 62% 187 Maokai 56% 386

## Read

- Plain text of the whole page; screenshots

## Not read

- Synergies tab
