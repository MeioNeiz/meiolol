---
title: 'DPM.LOL: Darius build, runes and counters (patch 16.20)'
url: https://dpm.lol/champions/Darius/build?lane=top&tier=emerald_plus&platform=all&timeframe=16.20
kind: docs
commit: 
for: [dense-stat-layout]
looked: 2026-10-20
depth: docs (rendered text, fold and full-page screenshots)
relevance: high
grade: B/fair
description: DPM.LOL champion page: role split under role icons, stat strip, matchup chips with win rate difference, games and a Good or Bad Lane label, 30-day trend charts, item and rune grids faded by pick rate, champion stats list
---
# DPM.LOL: Darius build, runes and counters (patch 16.20)

Why: a newer, denser site; how it packs many item and matchup numbers per screen.

## Assessment

- Evidence: B. Popular newer site (dpm.lol); live page.
- Reasoning: weak. Layout only.
- Interests: vendor (Premium, desktop app).
- Weigh: screenshots in data/team/2026-10-19-night/design-shots/dpm-darius*.png.

## Findings

- [ux/density] Matchup chips: portrait, signed win rate difference in colour (blue up, red down), games under it, and a word label below (Good Lane, Average, Bad Lane), so one chip answers both "game" and "lane" (seen in screenshot dpm-darius-full.png). ^f1
  > MATCHUPS AS DARIUS GOOD AGAINST
- [ux/density] Item grid rows labelled once on the left (winrate, pickrate, games), values in columns under each item icon, so labels are not repeated per cell (seen in screenshot dpm-darius-full.png). ^f2
- [ux/uncertainty] Rarely picked items and runes are drawn faded (icon and numbers at low opacity), common ones bright: opacity carries the sample, as OP.GG does for runes ([[opgg-darius-build#^f3]]) (seen in screenshot dpm-darius-full.png). ^f3
- [ux/colour] Win rates in three tones: blue or purple above about 51%, white near 50%, red below about 49%; the per cent sign smaller (seen in screenshot dpm-darius-full.png). ^f4
- [ux/layout] Role split shown under each role icon in the filter (87.8% top, 9.9% jungle), a filter that doubles as a stat (seen in screenshot dpm-darius.png). ^f5
- [ux/charts] Small multiples: three equal 30-day charts (win, pick, ban rate) with patch lines marked; in the capture the lines did not render, leaving empty axes (seen in screenshot dpm-darius-full.png). ^f6
  > Darius WR last 30d
- [ux/trust] Failure: a "Dragon Souls" list puts 85 to 90% win rates on display, a selection effect (teams that get a soul were already winning) shown as if it were a property of Darius. ^f7
  > Darius Dragon Souls
- [ux/density] Failure: the rune grid prints win rate and pick rate under every rune, including 100.0 on 0.0 pick rate; dozens of faded numbers that read as noise (seen in screenshot dpm-darius-full.png). ^f8

## Read

- Page text; screenshots at 1440 wide

## Not read

- Matchups tab (dpm.lol/champions/Darius/matchups); Pro Builds
