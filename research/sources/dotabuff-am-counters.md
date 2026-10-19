---
title: 'Dotabuff: Anti-Mage counters and matchups'
url: https://www.dotabuff.com/heroes/anti-mage/counters
kind: dataset
commit:
for: [dense-stat-layout]
looked: 2026-10-20
depth: skimmed (page and fold screenshot)
relevance: high
grade: A/fair
description: Dotabuff hero counters page: best and worst matchups, then a full matchup table with bars in every numeric cell, dark theme
---
# Dotabuff: Anti-Mage counters and matchups

Why: the closest outside-League analogue to meio.lol's champion matchup list, on a dark
theme.

## Assessment

- Evidence: A. Dotabuff is the largest Dota 2 stats site, over a decade old.
- Reasoning: fair. Disadvantage has a tooltip, not read.
- Interests: stats site with a Plus subscription.
- Weigh: screenshot dotabuff-am-counters.png (`data/team/2026-10-19-night/design-shots/`).

## Findings

- [ux/layout] Two short tables first, side by side: the 5 heroes that counter this hero
  and the 5 it counters, each with the matchup measure and win rate; the full matchup
  table follows below. Answer first, detail after. ^f1
  > Learn how to counter and when to pick Anti-Mage from our list of counters and matchups updated for the current meta.
- [ux/density] Every numeric cell has a thin bar under the number (about 3 px), length
  proportional to the value within its column: Disadvantage in white, win rate in
  green, matches played in red. The bars make a whole column scannable without reading
  digits. (seen in screenshot dotabuff-am-counters.png) ^f2
- [ux/uncertainty] Sample size is its own column with a bar (Matches Played), as
  prominent as win rate, so a 25k-game row and a 180k-game row look different. ^f3
  > | Hero | Disadvantage | Anti-Mage Win Rate | Matches Played |
- [ux/colour] On dark, colour encodes the column (which measure), not good or bad: green
  win rate bars stay green at 41% and at 55%. Value judgement comes from bar length and
  the sort, not hue. (seen in screenshot dotabuff-am-counters.png) ^f4
- [ux/density] Rows about 34 px with a small hero portrait; alternating row shades on a
  dark panel; numbers in a small sans at two decimals.
  (seen in screenshot dotabuff-am-counters.png) ^f5
- [ux/layout] A period filter (This Month) sits above the tables; the header shows
  popularity rank and overall win rate (15th, 51.15%), the reference point for every
  matchup row. (seen in screenshot dotabuff-am-counters.png) ^f6

## Read

- Fold and matchup table text.

## Not read

- Disadvantage tooltip definition; lanes and trends tabs.
