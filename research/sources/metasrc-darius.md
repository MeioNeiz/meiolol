---
title: 'METAsrc: Darius top build (patch 26.20)'
url: https://www.metasrc.com/lol/build/darius/top
kind: docs
commit: 
for: [dense-stat-layout]
looked: 2026-10-20
depth: docs (page innerText, fold and full-page screenshots)
relevance: medium
grade: C/fair
description: METAsrc champion page: one-line stat strip with an opaque Score, then cards of item, rune and champion icons each with two or three rounded numbers beneath and the row labels written once on the left
---
# METAsrc: Darius top build (patch 26.20)

Why: a compact icon-plus-numbers card layout used for bans and synergies.

## Assessment

- Evidence: C. Long-running, smaller site; live page.
- Reasoning: weak. Score not explained.
- Interests: vendor.
- Weigh: screenshots in data/team/2026-10-19-night/design-shots/metasrc-darius*.png.

## Findings

- [ux/density] Small multiples of icons: each card is a row of icons with two or three numbers stacked under each, the row labels (Win %, Diff, Games) written once at the left. ^f1
  > Win %|Diff|Games|51%|+2.0%|20K
- [ux/colour] Only the difference row is coloured (green +2.0%); win rate and games stay grey-white, so the eye goes to the one number that answers "better or worse than usual" (seen in screenshot metasrc-darius-full.png). ^f2
- [ux/colour] Synergy cards are grouped under role pills and every icon gets a border in its role colour (jungle green, mid blue, ADC red, support teal), a categorical colour that does not compete with the green numbers (seen in screenshot metasrc-darius-full.png). ^f3
- [ux/density] Games abbreviated (20K, 43.4K, 98.6K), and win rates rounded to whole per cent in the cards (seen in screenshot metasrc-darius-full.png). ^f4
- [ux/trust] Failure: whole-per-cent rounding makes most cards read 50% or 51% across the row, hiding the differences that the Diff row then has to carry; and the headline "Score" is never explained. ^f5
  > Games: 1,254,002 Score: 64.52
  > Ban champions like Kennen, Jayce, Riven, and Ornn to increase the win rate of Darius.

## Read

- Page innerText; screenshots

## Not read

- Counters tab
