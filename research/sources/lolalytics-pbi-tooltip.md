---
title: LoLalytics PBI column tooltip (Pick Ban Influence)
url: https://lolalytics.com/lol/tierlist/?col=pbi
kind: docs
commit:
for: [ban-impact-score]
looked: 2026-10-20
depth: listed (the tooltip)
relevance: high
grade: B/weak
description: lolalytics' own definition of PBI, from the tier list's server HTML
---
# LoLalytics PBI column tooltip (Pick Ban Influence)

Why: the exact formula behind lolalytics' PBI, which Jacob asked for (J20).

## Assessment

- Evidence: B. The site's own definition on its most visited page.
- Reasoning: weak. Formula and a one-line purpose, no rationale for the terms.
- Interests: stats site; "optimal global bans" is their marketing wording.
- Weigh: the formula is clear; small samples are not handled (raw win rate).

## Findings

- [stats] [draft] PBI = win rate edge over the tier's average, times pick rate divided by the share of games the champion was not banned (pick rate when available). ^f1
  > PBI = (win-AvgWinofTier) x 100 x pick / (100 - ban)
- [draft] Purpose: high PBI marks contested, strong champions and good bans. ^f2
  > Champions with a high PBI are very likely to be contested picks, very strong in the current meta and are optimal global bans against the enemy team.
- [stats] (inferred) The edge uses the raw win rate, so a rarely played champion with a lucky few hundred games gets the full edge; its small pick rate keeps PBI small, which partly hides the noise. ^f3

## Read

- The tooltip text.
