---
title: 'METAsrc: Darius counters with matchup detail panel (patch 26.21)'
url: https://www.metasrc.com/lol/champions/darius/counters
kind: docs
commit: 
for: [champion-matchup-gap]
looked: 2026-10-22
depth: docs (plain text of the page, then again after clicking Garen; screenshots at 1920x1080 and 390x844)
relevance: high
grade: B/fair
description: METAsrc counters tab, strong/even/weak icon cards, an opponent list sorted by games, and a master-detail panel comparing both champions stat by stat with range bars and a generated summary
---
# METAsrc: Darius counters with matchup detail panel (patch 26.21)

Why: [[metasrc-darius]] left the Counters tab unread; METAsrc has no separate vs page, so
this panel is its matchup page.

## Assessment

- Evidence: B. Long-running site, 14.1M champion games processed per its header.
- Reasoning: weak. Generated text, no method notes.
- Interests: vendor (heavy ads: a full-width takeover banner and a floating video).
- Shots: scratchpad shots/others/metasrc-darius-counters-{1920,390}-{fold,full}.png,
  metasrc-darius-vs-garen-Overall.png (panel with Garen selected).

## Findings

- [ux/layout] Counters tab in three bands: role pills, three icon cards (Strong, Even, Weak
  against: 8 champions each with win rate and games, as in [[metasrc-darius#^f1]]), then
  a master-detail block: opponent list left, matchup comparison right; clicking a row
  swaps the panel without leaving the page. ^f1
  > Darius counters champions such as K'Sante, Yasuo, and Fiora.
- [ux/uncertainty] The opponent list is sorted by games by default (Sett 7471, Garen 5942,
  Yone 5854), each row win rate, signed diff from Darius's average, games, so the common
  lanes come first rather than the extreme small samples. ^f2
  > Sett 47.54% -2.66% 7471
- [ux/density] Comparison rows: Darius's value and his diff from his own average left, a
  pair of horizontal bars (green Darius, red opponent) on an axis labelled with the min
  and max across all matchups, then the opponent's value and diff; rows are win rate, CS,
  KDA, gold, CS at 15, gold at 15, first level 2 time, first blood rate (seen in
  screenshot metasrc-darius-vs-garen-Overall.png). ^f3
  > 6062 +103 Gold at 15 5009 6478 5699 -208
- [ux/features] Lane-specific numbers not seen elsewhere: the time each reaches level 2 and
  first blood rate per matchup. ^f4
  > 3:21 -0:09 First Level 2 2:18 4:25 3:27 -0:06
- [ux/features] [learning] A generated Matchup Summary names who outperforms whom on which
  stat, the only "how the lane goes" text in this panel. ^f5
  > Darius outperforms Garen on CS (184.80), KDA (1.82), Gold (12.4K), CS at 15 (104.48), Gold at 15 (6062), First Level 2 (3:21), and First Blood (16.9%). Garen does not outperform Darius on any stats.
- [ux/trust] Failure: the summary doubles the edge: 47.54% vs 52.46% is reported as Sett
  "having an advantage of 4.91%", the gap between both sides, not the 2.5 points from
  50%. ^f6
  > with Sett having an advantage of 4.91%
- [ux/charts] Failure: the win rate and first blood bars run on a 0% to 100% axis, so a
  50.9% vs 49.1% matchup draws two almost equal bars; range bars only help where the
  span is narrow (CS 147.5 to 220.0) (seen in screenshot
  metasrc-darius-vs-garen-Overall.png). ^f7
  > Win Rate 0.0% 100.0%
- [ux/layout] First screen at 1920x1080: a full-width game advert (about 350 px) and the
  champion header and filters; the strong/even/weak cards start near the fold and the
  comparison panel sits about 1400 px down (seen in screenshot
  metasrc-darius-counters-1920-full.png). ^f8
- [ux/features] Category tabs on the panel (Performance, Combat, Defense, Utility,
  Objectives, Income, Lane Control); clicking them in the capture did not change the rows,
  so their content is not recorded. ^f9
  > Overall Performance Combat Defense Utility Objectives Income Lane Control
- [ux/trust] Disagrees with Mobalytics on the same pair: Darius 50.86% over 5942 games
  here (all ranks) against 55.1% over 729 in Emerald+ on Mobalytics on the same day
  ([[mobalytics-darius-vs-garen#^f8]]); rank filters differ, but neither page shows an
  interval. ^f10
  > Garen 50.86% +0.65% 5942

## Read

- Whole page text; panel with Sett (default) and Garen selected; screenshots

## Not read

- Panel category tabs (clicks did not register); 390 layout of the panel in detail
