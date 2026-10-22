---
title: LoLalytics Kai'Sa vs Jinx bottom matchup page (22 Oct 2026)
url: https://lolalytics.com/lol/kaisa/vs/jinx/build/
kind: docs
commit: 
for: [champion-matchup-gap]
looked: 2026-10-22
depth: docs (whole page: text, rendered text with positions, 1920x1080 screenshots)
relevance: high
grade: B/weak
description: LoLalytics matchup page for a bot lane pair, read for what a 2v2 lane's matchup page shows and how its headline deltas read
---
# LoLalytics Kai'Sa vs Jinx bottom matchup page (22 Oct 2026)

Why: champion-matchup-gap. Bot lane is two against two; does the matchup page show the
supports, lane stats or anything beyond the 1v1 build? Layout detail shared with
[[lolalytics-darius-vs-garen]] (^f9 to ^f16).

Raw: lolalytics-kaisa-vs-jinx.md (page text) and .dom-1920x1080.txt (rendered text with
page y, x, font size). Screenshot kaisa-vs-jinx-1920-fold.png and -full.png in the session
scratchpad shots/lolalytics/.

## Assessment

- Evidence: B. Live page, 4,441 Emerald+ games for the pair on patch 16.21.
- Reasoning: weak. Headline numbers in prose without definitions on the page.
- Interests: ad funded.
- Weigh: same template as Darius vs Garen; differences are data, not layout.

## Findings

- [ux/layout] Same matchup template as top lane: the filter bar's VS block with Jinx's role
  tiles (bottom 99.7%) and an X, hero with two portraits and a swap arrow, prose, a Win
  Rate and Games box, then the build block filtered to the pair. (seen in screenshot
  kaisa-vs-jinx-1920-fold.png) ^f1
  > y=89 x=1070 9px: 99.7%
  > y=348 x=1006 16px: 4,441
- [ux/trust] The two prose deltas can point opposite ways with no figure to reconcile them:
  0.65% better than against the average opponent, but -0.53% after normalising, and the
  win rate itself is 47.69%, below 50. ^f2
  > Kai'Sa wins against Jinx 47.69% of the time which is 0.65% different against Jinx than the average opponent. After normalising both champions win rates Kai'Sa wins against Jinx -0.53% different than would be expected.
- [ux/features] Checked, not there: no support or duo information on a bot lane matchup
  page (which supports either side had, how the 2v2 pairs fare), no lane stats (gold, XP
  or CS difference at any minute), no tips. ^f3
- [ux/features] Matchup-specific sections are the build tables, objectives (first blood
  secured 54.06% here vs 52.41% on the Kai'Sa page) and Win Rate vs Game Length; the
  Kai'Sa Stats block is champion-wide, identical to the build page (Physical Damage 14,774
  on both). ^f4
  > | First Blood | 54.06 | 53.56 | 45.94 | 40.78 |
  > y=2156 x=1281 16px: Win Rate vs Game Length
- [ux/density] First screen at 1920x1080: about 69 numeric figures; page 5,240 px. ^f5
  > jinx/build/ at viewport 1920x1080, 2026-10-22 ... height 5240

## Read

- raw/lolalytics-kaisa-vs-jinx.md and .dom-1920x1080.txt, whole page
- Screenshots: fold and whole page at 1920x1080

## Not read

- Matchup pages with vslane set to support (Kai'Sa vs an enemy support), linked from the
  filter bar
