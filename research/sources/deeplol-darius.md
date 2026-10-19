---
title: 'DeepLoL: Darius top build (patch 16.20)'
url: https://www.deeplol.gg/champions/darius/build/top
kind: docs
commit: 
for: [dense-stat-layout]
looked: 2026-10-20
depth: docs (rendered text, fold and full-page screenshots)
relevance: medium
grade: C/fair
description: DeepLoL champion build page: builds as tabs with games and win rate, skill order grid, then three side-by-side tables (weak against, strong against, good synergy) sorted by win rate with games beside
---
# DeepLoL: Darius top build (patch 16.20)

Why: a smaller OP.GG-style site; how its matchup tables handle thin data.

## Assessment

- Evidence: C. Smaller site ([[deeplol-home]]); live page.
- Reasoning: weak. Layout only.
- Interests: vendor.
- Weigh: screenshots in data/team/2026-10-19-night/design-shots/deeplol-*.png.

## Findings

- [ux/layout] Three equal tables side by side, each topped by a coloured rule (red for weak against, blue for strong against, orange for synergy) so the table's meaning shows before its title is read (seen in screenshot deeplol-darius-full.png). ^f1
- [ux/density] Tight rows (about 48 px) with icon, name, games, win rate, and the per cent sign set smaller and lighter than the digits (seen in screenshot deeplol-darius-full.png). ^f2
- [ux/uncertainty] Failure: tables sort by raw win rate, so tiny samples lead: weak against opens with Urgot on 52 games at 38.5% and Ryze on 44 games. ^f3
  > Urgot 52 38.5% Ryze 44 38.6%
- [ux/uncertainty] Synergy column adds a signed difference, again led by the smallest samples (Skarner, 42 games, +16.8%). ^f4
  > Skarner 42 66.7% +16.8%
- [ux/colour] Win rates two-colour only: red below 50%, blue above, no neutral band and no step for size (seen in screenshot deeplol-darius-full.png). ^f5

## Read

- Page text; screenshots

## Not read

- OTPs tab; mastery pages
