---
title: 'League of Items: Darius (patch 26.20)'
url: https://leagueofitems.com/champions/122
kind: docs
commit: 
for: [dense-stat-layout]
looked: 2026-10-20
depth: skimmed (page text, first-screen screenshots of the champion page and the builds table)
relevance: medium
grade: C/fair
description: League of Items champion page and builds table: every number paired with last patch's value in small text beneath, tiles of runes with win and pick rate, builds sorted by win rate increase with trend arrows
---
# League of Items: Darius (patch 26.20)

Why: a patch-change site; how it shows a value and its previous value together.

## Assessment

- Evidence: C. Small fan site (DraftGap's author links it); live page.
- Reasoning: weak.
- Interests: none known (no ads seen on first screen).
- Weigh: data source picker shows U.GG; screenshots in
  data/team/2026-10-19-night/design-shots/leagueofitems-*.png.

## Findings

- [ux/density] Each headline number has last patch's value in small grey text beneath it, a before-and-after in one cell. ^f1
  > 51.42%Winrate 51.55%Last patch
- [ux/density] Rune and item tiles: icon, then WINRATE and PICKRATE labels in small caps with large values; win rates over about 52% in blue, under about 45% in red (seen in screenshot leagueofitems-darius-full.png). ^f2
- [ux/density] Builds table: each value with last patch's value beneath, and the change in its own column with an up or down trend arrow, orange for win rate rises and blue or pink for pick rate (seen in screenshot leagueofitems-builds.png). ^f3
  > | Build | WR increase | Winrate | PR increase | Pickrate ▼ |
- [ux/uncertainty] Failure: the builds table sorted by win rate increase opens with +20.28% on a 1.45% pick rate build, small-sample swings ranked as the biggest news, with no games shown (seen in screenshot leagueofitems-builds.png). ^f4
- [ux/colour] Failure: the role tiles colour 44.51% red on 0.8% of games the same as a real weakness would be (seen in screenshot leagueofitems-darius-full.png). ^f5

## Read

- Champion page first screen and text; builds table first screen

## Not read

- Item and rune tier lists
