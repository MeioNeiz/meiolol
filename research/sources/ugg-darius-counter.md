---
title: 'U.GG: Darius counters (patch 26.20)'
url: https://u.gg/lol/champions/darius/counter
kind: docs
commit: 
for: [league-tools-landscape]
looked: 2026-10-11
depth: docs (whole rendered page, text only)
relevance: high
grade: B/fair
description: U.GG's counter page for one champion: best picks by matchup win rate and best lane counters by gold difference at 15 minutes (GD@15), Emerald+ world
---
# U.GG: Darius counters (patch 26.20)

Why: does a top stats site use timeline data on its matchup pages?

## Assessment

- Evidence: B. Top-two LoL stats site ([[similarweb-opgg-competitors#^f3]]); live page.
- Reasoning: fair. One-line definitions of each list.
- Interests: vendor.
- Weigh: shows GD@15 is mainstream; samples per matchup are small (hundreds to ~1,700).

## Findings

- [tools] [data] U.GG ranks lane counters by gold difference at 15 minutes (GD@15), a timeline-derived stat, beside matchup win rate. ^f1
  > These picks counter Darius during early game laning phase. Highest gold differential at 15 (GD@15) vs Darius in World Emerald +.
  > Use win rate and GD15 to find the best Top Lane champion who counters Darius.
- [tools] Two lists per champion: best picks by overall matchup win rate, and best lane counters by GD@15; plus worst picks. ^f2
  > These picks are strong against Darius at many stages of the game. Champs listed by highest win rate matchups vs Darius in World Emerald +.
  > Worst Picks vs Darius
- [data] Example: Heimerdinger +661 GD15 over 229 games; matchup samples run from about 200 to 1,700 games at Emerald+ world. ^f3
  > Heimerdinger +661 GD15 229 games
- [draft] (inferred) The two lists disagree (Kayle top by win rate, Heimerdinger top by GD15), which is exactly the "wins lane vs wins game" distinction a matchup-learning tool could explain. ^f4
- [tools] Checked, not there: no per-minute curve (only a single 15-minute snapshot), no XP or CS diff, no explanation of why a matchup wins. ^f5

## Read

- Whole page text

## Not read

- u.gg/lol/champions/darius/matchups (full matchup table, may have more columns)
