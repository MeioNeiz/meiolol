---
title: 'U.GG: Darius counters (patch 26.20)'
url: https://u.gg/lol/champions/darius/counter
kind: docs
commit: 
for: [league-tools-landscape, dense-stat-layout, champion-matchup-gap]
looked: 2026-10-22
depth: docs (whole rendered page 11 Oct; re-read with 1920x1080 and 390x844 screenshots 22 Oct)
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

- [tools] [data] [ux/features] U.GG ranks lane counters by gold difference at 15 minutes (GD@15), a timeline-derived stat, beside matchup win rate. ^f1
  > These picks counter Darius during early game laning phase. Highest gold differential at 15 (GD@15) vs Darius in World Emerald +.
  > Use win rate and GD15 to find the best Top Lane champion who counters Darius.
- [tools] Two lists per champion: best picks by overall matchup win rate, and best lane counters by GD@15; plus worst picks. ^f2
  > These picks are strong against Darius at many stages of the game. Champs listed by highest win rate matchups vs Darius in World Emerald +.
  > Worst Picks vs Darius
- [data] Example: Heimerdinger +661 GD15 over 229 games; matchup samples run from about 200 to 1,700 games at Emerald+ world. ^f3
  > Heimerdinger +661 GD15 229 games
- [draft] (inferred) The two lists disagree (Kayle top by win rate, Heimerdinger top by GD15), which is exactly the "wins lane vs wins game" distinction a matchup-learning tool could explain. ^f4
- [tools] [ux/features] Checked, not there: no per-minute curve (only a single 15-minute snapshot), no XP or CS diff, no explanation of why a matchup wins. ^f5
- [ux/layout] Three side-by-side lists (best picks, worst picks, lane counters by GD@15), each a header card with a one-line definition then about 10 rows (seen in screenshot ugg-darius-counter.png). ^f6
- [ux/density] Each row: icon, name, a short horizontal bar under the name for magnitude, the value right-aligned in colour and the game count small and grey beneath it, so one row carries value, magnitude and sample (seen in screenshot ugg-darius-counter.png). ^f7
  > Heimerdinger +661 GD15 229 games
- [ux/colour] Each list has its own hue: blue win rates for best picks, red text on a red-tinted panel for worst picks, green bars and values for gold leads; the hue says which list you are in before you read a number (seen in screenshot ugg-darius-counter.png). ^f8
- [ux/layout] Filter bar: five role icons, rank, queue, patch and region chips; the description names the role order the page falls back through (re-read 22 Oct, raw/ugg-darius-counter/2026-10-22.md). ^f9
  > Main Role Order: Top Lane > Jungle > Mid Lane > Support > ADC
- [ux/density] First 1920x1080 screen: three 330 px columns of 10 rows (about 61 px each) under a 120 px definition card; about 27 of the 30 rows show, 2 numbers each (about 55 numbers); full page 1,584 px (seen in screenshot ugg-darius-counter-desk-fold.png, 22 Oct). ^f10
- [ux/density] Phone (390x844): the three lists stack; the first screen holds an ad, the header, tabs, filters and one row of Best Picks (seen in screenshot ugg-darius-counter-phone-fold.png). ^f11
- [ux/features] Win rates here are the opponent's: Worst Picks vs Darius lists Trundle at 41.8% and Garen at 46.13%, the same pairs the Matchups table shows as 58.20% and 53.87% for Darius ([[ugg-darius-matchups#^f8]]). ^f12
  > Garen 46.13% WR 659 games
  > Trundle 41.8% WR 122 games
- [ux/uncertainty] The top Best Picks and Worst Picks rows are the thinnest: Kled 138 games, Trundle 122, Heimerdinger 133 (22 Oct), because the lists sort by raw win rate with no minimum shown. ^f13
  > Kled 56.52% WR 138 games

## Read

- Whole page text

## Not read

- u.gg/lol/champions/darius/matchups (full matchup table, may have more columns)
