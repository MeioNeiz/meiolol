---
title: dpm.lol Darius build page, element by element (24 Oct 2026)
url: https://dpm.lol/champions/darius/build
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: docs (rendered text and a 1280-wide full-page screenshot)
relevance: high
grade: B/fair
description: dpm.lol champion build page re-read per element: role share picker, named build variants, item slot strips, rune grid, trend and game-length charts
---
# dpm.lol Darius build page, element by element (24 Oct 2026)

Why: lol-site-ui, kind 3 (champion page). Earlier note [[dpm-darius]] (20 Oct, patch 16.20
filter URL) has colour, fading and the role share; this one adds what rendered now.
Screenshots in data/team/2026-10-24-ui/refs/champion/ (gitignored): dpm-darius-header-build.png,
dpm-darius-trends.png, dpm-darius-items-runes.png. Raw is the page's innerText after consent.

## Assessment

- Evidence: B. Popular newer site; 38,855 Emerald+ Darius games all regions on 16.21.
- Reasoning: fair. Faded thin data and games on every item cell show care for samples.
- Interests: ad funded, Premium and app upsells inside the page.
- Weigh: the closest thing to lolalytics' density with better hierarchy; copy freely.

## Findings

- [ux/controls] Role picker: five role icons with the champion's share of games under each
  (80.6% top, 17.4% jungle, 1.2%, 0.3%, 0.5%), in the same row as Ranked/ARAM, rank,
  region (All regions default) and patch. (seen in screenshot dpm-darius-header-build.png) ^f1
  > 80.6% 17.4% 1.2% 0.3% 0.5%
- [ux/density] Header strip: six big figures on one row, tier letter, rank (2 / 48), win
  rate, pick rate, ban rate, games, labels lower case and small under each; a purple rule
  under the strip; no prose. (seen in screenshot dpm-darius-header-build.png) ^f2
- [ux/controls] Build variants are named tabs carrying games and win rate before you open
  them: Lethality 9,780 games 54%, Bruiser chase 2,586 games 53%; the open tab holds both
  rune trees, spells, spell order, boots, starter and a core path that forks into options
  at items 4 and 5. Two variants side by side, not a most-common/highest-win toggle. ^f3
  > Lethality 9,780 Games 54% Bruiser chase 2,586 Games 53%
- [ux/density] Items by slot as strips: one panel per slot (ITEM 1 to ITEM 5), row labels
  winrate, pickrate, games written once at the left, nine items per slot; items under
  about 4% pick fade. ITEM SETS above it has tabs 2, 3, 4, 5 for sets of that size. (seen
  in screenshot dpm-darius-items-runes.png) ^f4
  > ITEM 1|winrate|pickrate|games
- [ux/density] Full rune grid: all five trees, each rune with win rate and pick rate under
  it (no games), unpicked runes dimmed so the chosen page lights up inside the full grid.
  (seen in screenshot dpm-darius-items-runes.png) ^f5
- [ux/charts] Trends rendered this time (they were empty axes on 20 Oct, [[dpm-darius#^f6]]):
  three equal 30-day line charts, WR, Pick, Ban, one line each with a soft fill, patch
  starts marked as labelled vertical lines (26.20, 26.21). (seen in screenshot
  dpm-darius-trends.png) ^f6
  > Darius WR last 30d
- [ux/charts] Win rate by game length sits in the right column as "WR over time", a small
  line chart on an axis of 15m, 30m, 45m (47% to 53%), under the Dragon Souls box. ^f7
  > WR over time 15m 30m 45m
- [ux/density] Matchups strip under the build: good and bad against, each a tall portrait
  with a signed difference (+5.9%), games (912) and a word label (Good Lane, Average, Bad
  Lane), five each side, "Full List" between them. ^f8
  > GOOD AGAINST|+5.9%|912|Good Lane
- [ux/layout] An in-page app promo and an ad box overlap the matchups strip at 1280
  (the ad sits over the content, not beside it). (seen in screenshot, 24 Oct) ^f9

## Read

- raw/dpm-champion-ui.txt; full-page screenshot at 1280

## Not read

- Phone layout; Matchups and Pro Builds tabs
