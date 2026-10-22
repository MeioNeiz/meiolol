---
title: 'OP.GG: Darius synergies tab (patch 16.21)'
url: https://op.gg/lol/champions/darius/synergies/top
kind: docs
commit: 
for: [champion-matchup-gap]
looked: 2026-10-22
depth: docs (rendered text; 1920x1080 full-page screenshot)
relevance: medium
grade: B/fair
description: OP.GG synergies tab: four role columns (jungle, middle, bottom, support), top 10 teammates each by pick rate with games and raw win rate
---
# OP.GG: Darius synergies tab (patch 16.21)

Why: how the biggest site shows teammates.

## Assessment

- Evidence: B. Largest LoL stats site ([[similarweb-opgg-competitors#^f1]]); live page.
- Reasoning: weak. Numbers shown, not explained.
- Interests: vendor (ads, membership, desktop app).
- Weigh: layout from screenshot opgg-darius-synergies-desk-full.png in the session scratchpad
  (shots/ugg-opgg/), 1920x1080.

## Findings

- [ux/features] [draft] Four side-by-side tables, one per teammate role, 10 rows each: icon with a tier badge, name, pick rate over games, win rate; sorted by pick rate, sortable by win rate (seen in screenshot opgg-darius-synergies-desk-full.png). ^f1
  > Synergies with Jungle
  > **5.53%** 991 | **46.62%**
- [draft] [ux/trust] (inferred) The win rate is the pair's raw rate, not a synergy above the two champions' own rates, and the default sort is by how often they meet, so the top rows are the most common junglers (Lee Sin at 46.62%), not the best partners. ^f2
- [ux/density] All 40 rows fit about one and a half screens: the tables start near y 750 at 1920x1080, about 49 px per row (seen in screenshot). ^f3

## Read

- Whole rendered text; screenshot

## Not read

- Win rate sort; phone layout
