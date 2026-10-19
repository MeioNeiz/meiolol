---
title: 'OP.GG: Darius build for top (patch 16.20)'
url: https://op.gg/lol/champions/darius/build/top
kind: docs
commit: 
for: [dense-stat-layout]
looked: 2026-10-20
depth: docs (rendered text including some table HTML, fold and full-page screenshots)
relevance: high
grade: B/fair
description: OP.GG's champion build page: rune grid with win rate, pick rate and games under each rune, faded when rarely picked; spells, skills and item tables with pick rate, games and win rate, win rate coloured only when notable
---
# OP.GG: Darius build for top (patch 16.20)

Why: the biggest stats site's champion page; how it marks which of many numbers matter.

## Assessment

- Evidence: B. Largest LoL stats site ([[similarweb-opgg-competitors#^f1]]); live page.
- Reasoning: weak. Layout only.
- Interests: vendor (ads, membership, desktop app).
- Weigh: the snapshot kept some table HTML, so class names are real; colours otherwise
  from screenshots (data/team/2026-10-19-night/design-shots/opgg-darius-build*.png).

## Findings

- [ux/density] Numbers are set in tabular figures (Tailwind `tabular-nums`), small (`text-xs`), with the game count in grey under the pick rate (class names in the snapshot HTML, raw line 148; seen in screenshot opgg-darius-build-full.png). ^f1
- [ux/colour] Win rate is grey by default and switches to the brand blue only when notable, so colour marks exceptions rather than painting every cell (classes text-gray-500 against text-main-600 in the snapshot HTML; seen in screenshot opgg-darius-build-full.png). ^f2
- [ux/density] Rune grid: every rune shows win rate, pick rate and games stacked under its icon; runes picked under about 2% are drawn faded (icon and numbers dimmed), the common ones bright, so pick rate is encoded twice, as number and as opacity (seen in screenshot opgg-darius-build-full.png). ^f3
- [ux/layout] Sidebar "Strong against" and "Weak against" strips of five icons with win rate and games, the counters page in miniature (seen in screenshot opgg-darius-build-full.png). ^f4
- [ux/uncertainty] Failure: sixth-item rows show 55.10% on 49 games and 52.38% on 21 games in the same blue as 60.76% on 1,534; the faded-when-rare treatment of runes is not used for items (seen in screenshot opgg-darius-build-full.png). ^f5
- [ux/features] Skill order drawn as a row of 15 small letter squares coloured per ability (Q blue, W teal, E orange, R filled), compact enough to sit in one table row (seen in screenshot opgg-darius-build-full.png). ^f6

## Read

- Page text and the table HTML that survived; screenshots at 1440 wide

## Not read

- Mobile layout; hover tooltips
