---
title: 'Mobalytics: LoL tier list for low elo (patch 26.20)'
url: https://mobalytics.gg/lol/tier-list
kind: docs
commit: 
for: [dense-stat-layout]
looked: 2026-10-20
depth: docs (page innerText, fold and full-page screenshots)
relevance: medium
grade: B/fair
description: Mobalytics' expert-curated tier list: per role a pick-of-the-patch blurb, then S, A and B columns of round champion portraits with names and no numbers
---
# Mobalytics: LoL tier list for low elo (patch 26.20)

Why: the opposite of a dense table; what an icon-only tier list gains and loses.

## Assessment

- Evidence: B. Major LoL site; live page.
- Reasoning: fair. Says the list is curated by people, not computed.
- Interests: vendor.
- Weigh: no statistics on the page at all; layout from screenshots
  (data/team/2026-10-19-night/design-shots/mobalytics-tier-list*.png).

## Findings

- [ux/features] The tier list is curated by players, not computed from games. ^f1
  > Our tier lists are curated our team of challenger experts.
  > based on the assessment of our high elo game experts
- [ux/layout] Per role: one featured champion with a short written reason and its build icons, then three tier columns (S, A, B) of 48 px round portraits with names, four across (seen in screenshot mobalytics-tier-list-full.png). ^f2
- [ux/density] No numbers at all: not win rate, games or pick rate. The grid answers "which tier" in one glance and nothing else (seen in screenshot mobalytics-tier-list-full.png). ^f3
- [ux/colour] Portrait rings are coloured (red, orange, blue, grey) with no legend on the page, so the colour carries a meaning the reader cannot recover (seen in screenshot mobalytics-tier-list.png). ^f4
- [ux/layout] Separate lists by skill bracket, with advice on when to switch. ^f5
  > We recommend using the Low ELO list for as long as you can before switching the High ELO list.

## Read

- Page innerText; screenshots

## Not read

- High Elo list; the Stats tab (their computed tier list)
