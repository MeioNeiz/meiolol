---
title: 'OP.GG: Darius build filtered to Garen (patch 16.21)'
url: https://op.gg/lol/champions/darius/build/top?target_champion=garen
kind: docs
commit: 
for: [champion-matchup-gap]
looked: 2026-10-22
depth: docs (rendered text; 1920x1080 and 390x844 fold and full-page screenshots)
relevance: high
grade: B/fair
description: OP.GG's build tab with an opponent set: runes, spells, skills and every item table refilter to the matchup, down to one or two games per row, while the header keeps champion-wide numbers
---
# OP.GG: Darius build filtered to Garen (patch 16.21)

Why: does OP.GG have a matchup build, and how thin does it get?

## Assessment

- Evidence: B. Largest LoL stats site ([[similarweb-opgg-competitors#^f1]]); live page.
- Reasoning: weak. Numbers shown, not explained.
- Interests: vendor (ads, membership, desktop app, coaching).
- Weigh: layout from screenshots opgg-darius-build-vs-garen-desk-*.png and -phone-*.png in the session
  scratchpad (shots/ugg-opgg/), 1920x1080 and 390x844 (desktop Chrome user agent at
  phone width).

## Findings

- [ux/features] With ?target_champion=garen the build tab refilters every section to the matchup: starter items on 558 games, core builds 65 down to 24 games. ^f1
  > **87.19%**558 Games | **55.02%**
  > **15.15%**65 Games | **49.23%**
- [ux/uncertainty] Failure: late slots fall to single games and still print a coloured win rate: fourth item 85.71% on 14 games, sixth item rows on 1 or 2 games at 100.00% and 0.00%, in the same style as the 558-game starter row. ^f2
  > **85.71%**14 Games | Fifth Item
  > **100.00%**2 Games | | | **0.00%**1 Games
- [ux/uncertainty] The rune grid refilters too: runes taken once show 100% win rate at 0.2% pick, beside the 430-game main page. ^f3
  > **100%****0.2%**1 **100%****0.2%**1 **0%****0%**0 **57.7%****69.4%**430
- [ux/layout] The header stays champion-wide (win rate 50.86%) and does not name the opponent; only the vs. Counter chip in the filter bar shows the filter (seen in screenshot opgg-darius-build-vs-garen-desk-fold.png). ^f4
  > _Win rate_**50.86%**

## Read

- Whole rendered text; screenshots

## Not read

- Whether a minimum sample hides rows (none seen)
