---
title: 'LoLalytics: home page patch performance block (16.21)'
url: https://lolalytics.com/?tier=emerald_plus
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (rendered text, viewport screenshots 1280x900)
relevance: high
grade: B/fair
description: LoLalytics home page 16.21 Patch Notes Champions Performance: Riot's buffed and nerfed champions as cards with win, pick and ban rate and each change coloured
---
# LoLalytics: home page patch performance block (16.21)

Why: the closest any site comes to stats beside the patch notes. Extends [[lolalytics-home#^f2]].
Shot: data/team/2026-10-24-ui/refs/patch/lolalytics-home-patch.png.

## Assessment

- Evidence: B. Live page.
- Reasoning: weak.
- Interests: vendor.
- Weigh: numbers moved between the shot and the snapshot (live data).

## Findings

- [ux/features] The block follows Riot's lists: Buffed Champions and Nerfed Champions, 27 champions, each a card with games, win rate and its change, pick and ban with changes. ^f1
  > Buffed Champions
  > Win Rate: 52.60% (+1.17%)
- [ux/layout] The header names both samples. ^f2
  > Patch 16.20 - 27,114,869 Champions
- [ux/colour] Every number and its change is coloured, green up and red down, including per-role lines (Miss Fortune support 42.71 (-0.20) in red) (seen in screenshot lolalytics-home-patch.png). ^f3
- [ux/uncertainty] Checked, not there: no interval or sample cut on the change, so +0.20 on about 12,900 games is as green as +1.17 on 43,000 (seen in screenshot lolalytics-home-patch.png). ^f4
- [ux/features] Checked, not there: the change text itself (no ability or values) and champions that moved without being touched (seen in screenshot lolalytics-home-patch.png). ^f5

## Read

- Home page text; one shot of the block

## Not read

- Item changes
