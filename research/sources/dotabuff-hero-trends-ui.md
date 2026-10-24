---
title: 'Dotabuff: hero trends (winners and losers)'
url: https://www.dotabuff.com/heroes/trends
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (rendered text, viewport screenshots 1280x900)
relevance: high
grade: A/fair
description: Dotabuff hero trends: per hero win and pick rate start, current, change and a daily sparkline, sorted by change
---
# Dotabuff: hero trends (winners and losers)

Why: a non-League "what moved" table. Shot: data/team/2026-10-24-ui/refs/patch/dotabuff-trends.png.

## Assessment

- Evidence: A. Dota's main stats site.
- Reasoning: weak.
- Interests: vendor.
- Weigh: screenshot and text.

## Findings

- [ux/density] Two header groups, win rate and pick rate, each Start, Current, Change, Trend. ^f1
  > | Hero | Start | Current | Change | Trend | Start | Current | Change | Trend |
- [ux/charts] Trend is an eight-point daily sparkline with its min and max labelled and a date tick, in every row (seen in screenshot dotabuff-trends.png). ^f2
- [ux/colour] Change is sorted (arrow on the header) and coloured green up, red down, left blank when tiny (seen in screenshot dotabuff-trends.png). ^f3
  > Biggest Winners and Losers, This Week, By Day
- [ux/features] Checked, not there: no patch text or cause beside the moves (screenshot 24 Oct). ^f4

## Read

- Page text; one shot

## Not read

- Month view
