---
title: 'Patch 16.21 first day: champion win rate jump vs within-patch control (our measurement, 2026-10-21)'
url: https://meio.lol/lab/patch-jump-16-21
kind: dataset
commit: 
for: [patch-transfer, frontier-dynamics]
looked: 2026-10-21
depth: ran
relevance: high
grade: B/strong
description: Our drafts table, 16.20 vs 16.21's first day: true spread of champion-role win rate changes, within platform, against two later 16.20 days as a control
---
# Patch 16.21 first day: champion win rate jump vs within-patch control (our measurement, 2026-10-21)

Why: does a patch move champions enough to matter, and is the move in the champions the patch touched?

## Assessment

- Evidence: B. Our own games, 1.37M, one boundary, first day of the new patch only; write-up docs/model.md "Patch 16.21's first day".
- Reasoning: strong. Noise subtracted per cell, a within-patch control on the same cells, platform mix held fixed.
- Interests: none.
- Weigh: raw rates, not draft-adjusted; day one only (patch-day players and adoption mixed in); "changed" from Data Dragon only, which misses ability-number changes.

## Findings

- [method/dynamics] 16.21's first day moved champion-role win rates by 0.75 pp RMS within platform; two later 16.20 days moved 0 against the same old window. ^f1
  > all cells: 2421 cells, 495923 new picks, tau patch 0.0075, tau control 0.0
- [method/dynamics] Champions with Data Dragon changes moved about four times as far as the rest (1.9 vs 0.5 pp). ^f2
  > changed champions (Data Dragon 16.21.1 differs from 16.20.1, 12 champions): 174 cells, 45368 new picks, tau patch 0.0192, tau control 0.0029
  > unchanged champions: 2247 cells, 450555 new picks, tau patch 0.005, tau control 0.0
- [method/dynamics] No mean reversion beyond noise overall (slope equals the control's); changed champions -0.42 vs -0.27, a hint on 12 champions. ^f3
  > slope -0.318, slope control -0.307
- [data] The new patch's first day is a different platform mix (KR and VN2 heavy), so pooled-platform comparisons inflate the control. ^f4
  > 16.21 first day KR 34.5%, VN2 24.0%, EUW1 19.2%, NA1 2.1%
- [method/dynamics] (inferred) Ignoring the jump costs about 20 tau^2 nats per game, ~1.1 milli-nats on day one; a shrunk offset recovers tau^2/(tau^2 + 0.25/n) of a cell's jump, about 9% for an unchanged cell and 60% for a changed one at 1,000 new picks. ^f5

## Read

- All of it (we ran it).

## Not read

- Days 2+ of 16.21: rerun as the patch fills.
