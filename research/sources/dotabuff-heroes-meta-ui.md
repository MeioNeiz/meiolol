---
title: 'Dotabuff: hero meta statistics'
url: https://www.dotabuff.com/heroes/meta
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (rendered text, viewport screenshots 1280x900)
relevance: high
grade: A/fair
description: Dotabuff hero meta table: pick and win rate per rank bracket side by side, inline bars under every number, a show / compare by / filtered by builder
---
# Dotabuff: hero meta statistics

Why: a non-League champions table that compares brackets in one view.
Shot: data/team/2026-10-24-ui/refs/tier-list/dotabuff-meta.png.

## Assessment

- Evidence: A. Dota's main stats site for over a decade.
- Reasoning: weak.
- Interests: vendor, Plus subscription, ads.
- Weigh: screenshot and text.

## Findings

- [ux/density] One row per hero, then a pick % and win % pair for each of five rank brackets side by side (ten numeric columns), so brackets compare without switching pages (seen in screenshot dotabuff-meta.png). ^f1
- [ux/charts] Every number has a thin inline bar under it (red for pick, green for win) and the best value in a column is bold (seen in screenshot dotabuff-meta.png). ^f2
- [ux/controls] A three-step builder: Show (metric), Compare By (the dimension spread across columns: rank, skill bracket, faction, lane), Filtered By (period, faction, lane, region). ^f3
  > Pick and Win Rates, This Month, Ranked MMR, Any Faction, All Lanes
- [ux/density] Rows about 34 px; no prose between the builder and the table (seen in screenshot dotabuff-meta.png). ^f4

## Read

- Page text; one desktop shot

## Not read

- Other "Show" metrics
