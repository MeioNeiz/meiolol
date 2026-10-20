---
title: LoLalytics tier list (patch 16.20, Emerald+)
url: https://lolalytics.com/lol/tierlist/
kind: docs
commit:
for: [ban-impact-score]
looked: 2026-10-20
depth: skimmed (header text, columns, top row)
relevance: medium
grade: B/weak
description: lolalytics' tier list page: columns and what ranks the tiers, PBI among them
---
# LoLalytics tier list (patch 16.20, Emerald+)

Why: what lolalytics shows beside PBI and how it uses it. The PBI formula itself is in
[[lolalytics-pbi-tooltip]].

## Assessment

- Evidence: B. Live page of a major stats site, its own method.
- Reasoning: weak. Says what ranks tiers, not how they are weighed.
- Interests: stats site.
- Weigh: shows PBI as a plain number column beside win, pick, ban and games.

## Findings

- [ux/features] Tier list ranks use win rate, PBI and the best players' win rate and elo. ^f1
  > LoL Tier List ranks are based upon champion win rate, PBI index, best on champion win rate and best on champion average elo.
- [ux/density] Tier list columns: rank, name, tier, lane, win, pick, ban, PBI, games, then the best players' block; top row Cho'Gath win 53.48 (+1.97), pick 6.29, ban 7.98, PBI 12, games 160,096. ^f2
- [ux/uncertainty] Checked, not there: no sample floor or shrinkage stated for PBI. ^f3

## Read

- Page header text and column headers, first row.

## Not read

- Lower tiers and filters.
