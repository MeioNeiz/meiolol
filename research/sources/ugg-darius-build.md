---
title: 'U.GG: Darius build page (patch 26.20)'
url: https://u.gg/lol/champions/darius/build
kind: docs
commit: 
for: [dense-stat-layout]
looked: 2026-10-20
depth: docs (rendered text plus fold and full-page screenshots)
relevance: medium
grade: B/fair
description: U.GG's champion build page: summary stat strip, runes, toughest matchups as cards, skill path grid, item slots each with win rate and matches
---
# U.GG: Darius build page (patch 26.20)

Why: how a champion page groups many small numbers into cards.

## Assessment

- Evidence: B. Top-two LoL stats site; live page.
- Reasoning: weak. Layout only.
- Interests: vendor.
- Weigh: layout read off screenshots
  (data/team/2026-10-19-night/design-shots/ugg-darius-build*.png).

## Findings

- [ux/density] Every choice carries its win rate and its sample in one fixed pattern, number then matches in brackets. ^f1
  > 49.94% WR (39,010 Matches)
- [ux/layout] Toughest matchups are a row of eight cards (icon, name, red win rate, matches), the counters page compressed to one strip (seen in screenshot ugg-darius-build-full.png). ^f2
  > Toughest MatchupsThese champions counter Darius
- [ux/density] Skill path is an 18-column grid with one blue numbered square per level per row, readable at a glance because only filled cells have colour (seen in screenshot ugg-darius-build-full.png). ^f3
- [ux/features] A Plus upsell sits inside the matchup strip: blurred "Personal Counters" cards with placeholder numbers. ^f4
  > PLUSPersonal Counters
- [ux/uncertainty] Failure: late item slots show win rates from 968 to 1,410 matches beside 23,587, in the same weight and colour (seen in screenshot ugg-darius-build-full.png). ^f5

## Read

- Whole page text; screenshots

## Not read

- ARAM and Pro Builds tabs
