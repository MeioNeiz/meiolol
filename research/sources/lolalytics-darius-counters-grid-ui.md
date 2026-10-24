---
title: 'LoLalytics: Darius counters grid (patch 16.21)'
url: https://lolalytics.com/lol/darius/counters/?lane=top
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (rendered text, viewport screenshots 1280x900)
relevance: medium
grade: B/fair
description: LoLalytics counters page as a grid of opponent cards with sort headers and a hover tooltip spelling each number out
---
# LoLalytics: Darius counters grid (patch 16.21)

Why: how the reference site lists every opponent. Extends [[lolalytics-darius-counters]].
Shot: data/team/2026-10-24-ui/refs/matchups/lolalytics-counters.png.

## Assessment

- Evidence: B. Live page.
- Reasoning: fair (tooltip explains the deltas).
- Interests: vendor.
- Weigh: screenshot and text.

## Findings

- [ux/layout] 64 top-lane opponents as cards, eight a row, each about 260 px tall: splash, Darius' rate against it, two deltas, the opponent's overall rate, games (seen in screenshot lolalytics-counters.png). ^f1
  > Δ1 -6.09 • Δ2 -10.21
- [ux/controls] Sort headers above the grid: Name, WR vs, All Champs WR, Δ1, Δ2, Games (seen in screenshot lolalytics-counters.png). ^f2
- [ux/uncertainty] A hover tooltip spells each number out in sentences, including the normalised delta (seen in screenshot lolalytics-counters.png). ^f3
- [ux/uncertainty] Opponents need 100 games to be listed. ^f4
  > minimum of 100 games
- [ux/layout] Failure: at 260 px per row of eight, 64 opponents take about 2,000 px (seen in screenshot lolalytics-counters.png). ^f5

## Read

- Page text; one desktop shot

## Not read

- Other lanes
