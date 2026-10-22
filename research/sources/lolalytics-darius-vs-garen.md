---
title: 'LoLalytics: Darius vs Garen build (matchup page)'
url: https://lolalytics.com/lol/darius/vs/garen/build/
kind: docs
commit: 
for: [league-tools-landscape, champion-matchup-gap]
looked: 2026-10-22
depth: docs (whole rendered page; 22 Oct: screenshots at 1920x1080 and 390x844, rendered text with positions)
relevance: high
grade: B/fair
description: A LoLalytics matchup page (patch 16.20, Emerald+): what a leading stats site shows for one lane matchup, and which numbers need timeline data
---
# LoLalytics: Darius vs Garen build (matchup page)

Why: what does a stats site's matchup page actually show, and is any of it
timeline-derived (gold at 15, lane diffs, power curves)?

## Assessment

- Evidence: B. LoLalytics is a long-running high-sample site (global rank ~10,000,
  [[similarweb-opgg-competitors#^f3]]); live patch 16.20 page.
- Reasoning: fair. Explains its normalised matchup delta in one sentence.
- Interests: vendor (ads; cross-links its own sister sites).
- Weigh: text snapshot only; any charts drawn client-side may be missing.

## Findings

- [tools] [draft] Matchup headline is win rate vs the opponent, its delta vs the average opponent, and a delta normalised for both champions' win rates. ^f1
  > Darius wins against Garen 53.41% of the time which is 5.81% different against Garen than the average opponent. After normalising both champions win rates Darius wins against Garen 4.17% different than would be expected.
- [data] Large samples: Emerald+ only, 7.3M champion-games, 1,801 games for this one matchup. ^f2
  > Emerald+ Champions Analysed: 7,326,654
- [tools] Matchup page content is build-centric: highest-win and most common build, skill order, runes, summoner spells, starting items, boots and items by slot with win rate, pick rate and games. ^f3
  > Highest Win Build
  > Most Common Build
- [data] Some timeline-derived numbers: early items by 10 minutes, and a purchase "Time" column on item tables. ^f4
  > Early Items (10 min)
- [data] Objective secure/yield table for the matchup (first blood, first tower, drakes, soul) with win rate when secured: end-of-game event flags, not per-minute. ^f5
  > | First Tower | 52.8 | 72.98 | 46.47 | 31.3 |
- [data] End-of-game averages ranked against the role (damage, kills, gold, CS). ^f6
  > Minions Killed:
- [tools] [ux/features] Checked, not there: no gold or XP difference at 10 or 15 minutes, no per-minute lead curve, no explanation of how the lane plays out or when each champion spikes. ^f7
- [market] Cross-links sister sites (pros.lol, XDX.gg) and Mobalytics as "friends". ^f8
  > Quality alternative Darius build stats and more from our friends at Mobalytics.

### 22 Oct: layout and how it differs from the champion page (for champion-matchup-gap)

Raw: lolalytics-darius-vs-garen.2026-10-22.md (text), .dom-1920x1080.txt and
.dom-390x844.txt (rendered text with page y, x, font size). Screenshots in the session
scratchpad shots/lolalytics/darius-vs-garen-*.png.

- [ux/layout] Opponent choice: the sticky filter bar gains a VS block after the patch tile:
  a swap arrow, the opponent's portrait with its own six role tiles (Garen top 91.2%) and an
  X to drop back to the champion page. Lane and opponent lane are URL parameters (lane,
  vslane). Getting here is by clicking a counter card or a strip portrait; no search box
  for the opponent seen. (seen in screenshot darius-vs-garen-1920-fold.png) ^f9
  > y=89 x=950 9px: 91.2%
  > y=66 x=1153 12px: X
- [ux/features] Hero (y 140 to 440): both portraits with a swap arrow, the stock photo, the
  prose with win rate, delta vs the average opponent and normalised delta, and only a
  two-figure box: Win Rate and Games. The two deltas exist only in the prose. ^f10
  > Darius wins against Garen 56.03% of the time which is 8.1% different against Garen than the average opponent
  > y=348 x=1011 16px: 780
- [ux/features] Same build block as the champion page, filtered to the matchup, fully on the
  first screen (y 525 to 855), then the same item, skill and rune tables below; summoner
  spell strip starts at y 975. ^f11
  > y=659 x=526 14px: Summoner Spells
- [ux/uncertainty] On 780 matchup games the Highest Win Build picks thin options and shows
  them like solid ones: core first item 73.17% on 41 games, an Item 4 choice at 100% on 4
  games, in the same green as 66.04% on 106. ^f12
  > y=809 x=730 12px: 73.17
  > y=825 x=964 12px: 4
- [ux/uncertainty] Winning Items, sorted by win rate, leads with five items at 100.00% on 2
  games each. ^f13
  > Winning Items Win Rate Pick Rate Games Time 100.00 0.26 2 33 100.00 0.26 2 22
- [ux/features] Dropped from the champion page: the counters and synergy strips, the
  trend legend and four daily charts, and Game Length Distribution. Kept and matchup
  specific: objectives Secure/Yield (Blue Side 37.56% of games here vs 48.37% on the
  champion page) and Win Rate vs Game Length (y 2156). Kept but champion-wide: Best on
  Darius, the leaderboard, the player base quadrant and Darius Stats (same values as the
  champion page within rounding). Page height 5,240 px vs 5,682. ^f14
  > | Blue Side | 37.56 | 60.41 |
  > y=2156 x=1281 16px: Win Rate vs Game Length
- [ux/features] Checked, not there (22 Oct, full render): no lane stats of any kind (gold,
  XP or CS difference at any minute, first blood share in lane, solo kills), no matchup
  tips or difficulty, no power-spike or level comparison, no opponent's build. ^f15
- [ux/density] First screen at 1920x1080: about 68 numeric figures (count of number-only
  text nodes above y 1080); phone 390x844 about 25, page 10,846 px tall. ^f16
  > garen/build/ at viewport 1920x1080, 2026-10-22 ... height 5240

## Read

- Whole rendered page text
- 22 Oct: screenshots (1920x1080, 390x844, whole page) and rendered-text dumps

## Not read

- Counter list: noted separately, [[lolalytics-darius-counters]]
