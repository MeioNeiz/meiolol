---
title: 'U.GG: Darius matchups table (patch 26.20)'
url: https://u.gg/lol/champions/darius/matchups
kind: docs
commit: 
for: [dense-stat-layout]
looked: 2026-10-20
depth: docs (rendered text plus fold and full-page screenshots)
relevance: high
grade: B/fair
description: U.GG's full matchup table for one champion: about 50 rows of win rate, gold, XP, kills, CS and jungle CS differences at 15 minutes and match count, only the win rate column coloured
---
# U.GG: Darius matchups table (patch 26.20)

Why: how the second-biggest stats site lays out a wide per-opponent table, and where it
fails at a glance.

## Assessment

- Evidence: B. Top-two LoL stats site ([[similarweb-opgg-competitors#^f3]]); live page.
- Reasoning: weak. Layout only, no explanation of the colour thresholds.
- Interests: vendor (ads, Plus, desktop app).
- Weigh: colours read off screenshots
  (data/team/2026-10-19-night/design-shots/ugg-darius-matchups*.png), not CSS.

## Findings

- [ux/density] Seven numeric columns per opponent: win rate, then five differences at 15 minutes (gold, XP, kills, CS, jungle CS) and matches. ^f1
  > ± Jungle CS @15
- [ux/colour] Only the win rate column is coloured, in three steps around a neutral band: blue above roughly 51.5%, white from about 48.5% to 51.5%, pink below (seen in screenshot ugg-darius-matchups-full.png). ^f2
- [ux/colour] The sorted column gets a lighter background band down the whole table, so the sort key is visible without reading the header (seen in screenshot ugg-darius-matchups-full.png). ^f3
- [ux/density] Failure: the five @15 difference columns are plain white numbers with no sign colour, bar or scale, so -634 gold and +920 gold look alike; reading them means parsing every cell (seen in screenshot ugg-darius-matchups-full.png). ^f4
- [ux/uncertainty] Failure: match counts (812 to 6,152) sit in the last column, far from the win rate, with no fading or flag on thin rows (seen in screenshot ugg-darius-matchups-full.png). ^f5
- [ux/density] Tall rows (about 54 px at 1440 wide) with a 28 px champion icon and name; roomy rather than dense, about 16 rows per screen (seen in screenshot ugg-darius-matchups-full.png). ^f6

## Read

- Whole page text; fold and full-page screenshots (cookie dialog covers the header row)

## Not read

- Hover states, mobile layout
