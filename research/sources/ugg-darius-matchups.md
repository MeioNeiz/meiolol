---
title: 'U.GG: Darius matchups table (patch 26.20)'
url: https://u.gg/lol/champions/darius/matchups
kind: docs
commit: 
for: [dense-stat-layout, champion-matchup-gap]
looked: 2026-10-22
depth: docs (rendered text; fold and full-page screenshots at 1440 on 20 Oct, 1920x1080 and 390x844 on 22 Oct)
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
- [ux/layout] The table is the "More Stats" tab, not a tab named Matchups; filters are role, rank, queue, patch, region and a Show All checkbox (re-read 22 Oct, raw/ugg-darius-matchups/2026-10-22.md). ^f7
  > Ranked Solo 26.21 World Show All
- [ux/features] Win rate here is Darius's against the opponent (Trundle 58.20%, Garen 53.87%), while the Counters page lists the same pairs as the opponent's win rate (Trundle 41.8%, Garen 46.13%, same game counts); neither page says whose rate it is ([[ugg-darius-counter#^f12]]). ^f8
  > Garen 53.87% 528 435 0.55 14.5 0.2 659
- [ux/colour] Win rate cells now show four steps at 1920 wide: orange for the top (55.5% and up in this shot), blue above about 51%, white near 50%, pink and red below; the @15 columns stay plain white (seen in screenshot ugg-darius-matchups-desk-fold.png, 22 Oct). ^f9
- [ux/density] First 1920x1080 screen: header and filters take the top 430 px, then 11 rows of 7 numbers (about 77 numbers); 48 opponents in all, page 3,532 px tall; the table is about 1,014 px wide in a 1,920 window (seen in screenshot ugg-darius-matchups-desk-fold.png). ^f10
- [ux/uncertainty] Rows go down to 122 games (Trundle, the top row) with no flag; the sort is by raw win rate, so the thinnest samples sit at the extremes (22 Oct snapshot). ^f11
  > Trundle 58.20% 379 681 0.69 14

## Read

- Whole page text; fold and full-page screenshots (cookie dialog covers the header row)

## Not read

- Hover states, mobile layout
