---
title: LoLalytics Darius top build page (layout read, 20 Oct 2026)
url: https://lolalytics.com/lol/darius/build/
kind: docs
commit: 
for: [dense-stat-layout, champion-matchup-gap]
looked: 2026-10-22
depth: docs (22 Oct: whole page section by section, 1920x1080 and 390x844 screenshots, rendered text with positions, help tooltips by hover)
relevance: high
grade: A/weak
description: LoLalytics champion page and tier list, read for how it packs numbers and where it stops being readable
---
# LoLalytics Darius top build page (layout read, 20 Oct 2026)

Why: Jacob (20 Oct): lolalytics "makes an attempt at showing more info but it's actually
not great, not easy to read". What exactly makes it dense, and what makes it hard.

Screenshots in data/team/2026-10-19-night/design-shots/ (gitignored): lolalytics-darius-fold.png,
lolalytics-darius.png (full page), lolalytics-tierlist.png, lolalytics-vs-fold.png.

## Assessment

- Evidence: A for use (one of the big League stat sites, Similarweb top 10 by affinity
  to op.gg), but that proves traffic, not that the layout reads well.
- Reasoning: weak. No stated design rationale; labels like Delta 1 and Delta 2 sit
  behind ? icons.
- Interests: ad funded (several large ad slots and a 1226-vendor consent wall).
- Weigh: steal the density tricks, not the colour use or the type.

## Findings

- [ux/density] The page header packs the context strip: role icons with the share of the
  champion's games in each role under them (top 88.1%, jungle 9.7%), patch, queue and
  region, and the site average win rate for the rank. (seen in screenshot
  lolalytics-darius-fold.png) ^f1
  > Average Emerald+ Win Rate: 51.7%
- [ux/density] [ux/features] Summary stats block: win rate, WR delta, game average win
  rate, pick rate, tier, rank of 112, ban rate, games, as eight small figures in a 4 by 2
  grid next to a prose summary. ^f2
  > top has a 51.4% win rate in Emerald+ on Patch 16.20 coming in at rank 21 of 112 and graded A Tier
- [ux/density] The counters strip is a transposed table: one column per opponent
  (portrait on top), rows Win Rate, Delta 1, Delta 2, Pick Rate, Games, about 13
  opponents per row in 730 px. Very dense: five numbers per opponent in a 54 px column.
  (seen in screenshot lolalytics-darius.png) ^f3
- [ux/colour] Colour mostly encodes which metric a row is, not its size: row labels and
  values are green for Win Rate, yellow for Delta, purple for Pick Rate; only win rates
  turn red or green with the value. A reader has to learn a colour key that carries no
  magnitude. (seen in screenshot lolalytics-darius.png) ^f4
- [ux/layout] Delta 1 and Delta 2 are unexplained names with a help icon; two near
  identical metrics side by side. ^f5
  > Normalised Synergy Delta
- [ux/density] Objectives table: Secure and Yield column groups, green and red headers,
  each with share and win rate for first blood, tower, inhibitor, herald, baron, drake,
  souls; condensed font about 11 px, centred figures. (seen in screenshot) ^f6
  > | First Tower | 51.58 | 69.87 | 47.64 | 31.41 |
- [ux/density] Skill order as a 4 by 18 grid of small squares, the levelled ability
  filled with its level number: a whole sequence readable in one glance, 1 row per
  ability. A good compact form. (seen in screenshot lolalytics-darius-fold.png) ^f7
- [ux/layout] Readability failures seen: a stock sunset image (about 300 by 170 px) and
  a large ad slot beside the hero; numbers in a condensed display font at about 11 to
  12 px, centred rather than right aligned, so decimals do not line up; two-decimal win
  rates (49.81) everywhere; many full-width panels that are empty until scrolled to
  (lazy loading), so the page is long with blank boxes. (seen in screenshots) ^f8
- [ux/layout] Tier list: about 52 px rows with a 48 px portrait; at 1440 by 1000 the
  first row starts at about 710 px under an ad strip, hero image, prose and a second ad,
  so about five rows show above the fold. (seen in screenshot lolalytics-tierlist.png) ^f9
- [ux/density] Tier list filters are inline number inputs in the header (min lane %,
  min games 100, min pick %), with role icons as buttons. ^f10
  > Emerald+ Champions Analysed: 24,880,984
- [ux/features] Matchup page leads with prose giving win rate against the opponent,
  the difference from the average opponent and a normalised difference, then a two-number
  box (win rate, games); the rest is the build page filtered to the matchup. (seen in
  screenshot lolalytics-vs-fold.png) ^f11
- [ux/layout] (inferred) What makes it hard to read: colour spent on metric identity,
  equal visual weight for every number (no figure stands out as the answer), tiny
  condensed centred type, and unexplained metric names; density itself is not the
  problem. ^f12

### 22 Oct: section by section (for champion-matchup-gap)

Screenshots in the session scratchpad shots/lolalytics/ (darius-build-1920-fold.png, -full.png
and segments, darius-build-390-*.png). Raw snapshots: lolalytics-darius-build.2026-10-22.md
(page text), .dom-1920x1080.txt and .dom-390x844.txt (every rendered text node with its page
y, x and font size), .tooltips.txt (help icons, hovered). `browse` itself is fixed at
1440x1000; these were taken with its browser module and a set viewport.

- [ux/layout] Layout at 1920x1080: a fixed content column about 1040 px wide (x 474 to
  1512), about 880 px of the 1920 width is black margin; inside it a main column of about
  730 px and a right column of about 340 px that holds an ad (152 to 432) beside the hero.
  (seen in screenshot darius-build-1920-fold.png) ^f13
- [ux/layout] Sticky filter bar under the logo (y 47 to 103): champion portrait, six role
  buttons with the champion's share of games in each role under them, rank (EMERALD+),
  patch, queue, region, and on the right the site average win rate and games analysed with
  help icons. Each control is a 40 to 50 px icon tile; no dropdown labels. ^f14
  > y=89 x=488 9px: top
  > Average Emerald+ Win Rate: 51.31%
- [ux/density] Hero (y 140 to 505, about 365 px): portrait with a win-rate ring and tier
  letter, a stock sunset photo about 300 by 170 px, prose summary naming top three
  counters and countered-by, and the 8-figure stat grid (Win Rate, WR Delta, Game Avg WR,
  Pick Rate; Tier, Rank, Ban Rate, Games) at 16 px figures with 12 px labels. ^f15
  > y=394 x=811 16px: 52.47
  > y=479 x=994 12px: Ban Rate
- [ux/trust] WR Delta in the hero is not a matchup or patch delta: per its tooltip it is the
  gap between win rate by each player's own tier and by game-averaged tier, a method
  argument with other sites, given the same visual weight as win rate. ^f16
  > The win rate delta is the difference between the win rate using individual player tiers (LoLalytics chosen method) vs the win rate derived from using a game averaged tier
- [ux/features] [ux/density] Build block (y 585 to 915, about 330 px, all on the first
  screen): a Highest Win Build / Most Common Build toggle, then in one panel skill priority
  (3 icons, win rate, games), summoner spells (2 icons), skill order as a 4 by 18 grid,
  primary and secondary rune trees with the picked runes lit and others greyed, stat
  shards, starting items, core build (3 items with win rate and games each), and Item 4, 5,
  6 as 2 or 3 alternatives with win rate and games under each. ^f17
  > y=593 x=689 12px: Highest Win Build
  > y=593 x=1202 12px: Most Common Build
- [ux/uncertainty] Skill priority and skill order are measured at different levels, so
  they disagree, explained only in a tooltip; the highest-win build quotes 58.05% on 3,347
  games for its skill order. ^f18
  > Skill Priority is measured at level 10.
  > Skill Order is measured at level 15.
  > y=778 x=816 12px: 58.05
- [ux/charts] Trends: a legend row (rank brackets Overall to Iron as coloured words, then
  Max Days, 7 Days, 14 Days, Today, Smooth) over four small line charts side by side,
  about 255 by 290 px each: Win Rate, Pick Rate, Game Count, Ban Rate by day for about 30
  days, one line per rank bracket. Starts at y 1036, so only the legend shows on the first
  screen. Lines are not labelled; the bracket is read from the legend colours. ^f19
  > y=1036 x=498 14px: LEGEND:
  > y=1071 x=557 16px: Darius Win Rate
  > y=1036 x=1453 14px: Smooth
- [ux/features] [ux/density] Counters and synergy: one control with two rows of tabs
  (Counters: Common Matchup, Strong Against, Weak Against, Delta; Synergy: Common
  Teammates, Good Synergy, Bad Synergy, Synergy Delta, Normalised Synergy Delta), then
  five transposed strips, one per enemy role (top, jungle, mid, bot, support), each 12
  opponents by Win Rate, Delta 1, Delta 2, Pick Rate, Games, about 154 px tall (y 1440 to
  2210, 770 px). So the build page also shows how Darius fares against each enemy
  jungler, mid, ADC and support, not only the lane opponent. ^f20
  > Normalised Synergy Delta
  > y=1374 x=603 12px: Common Matchup
- [ux/trust] Delta 1 and Delta 2 do have formulas, but only in hover tooltips (no touch
  equivalent seen); game counts in the strips are 9 px. ^f21
  > Delta 1 = Counter Matchup Win Rate - (100 - Counter Champions Overall Average Win Rate)
  > Delta 2 = Counter Matchup Win Rate - Normalised Champions Win Rate in Matchup
  > y=1557 x=573 9px: 993
- [ux/features] Item tables in the main column, all as transposed strips (icons on top,
  rows Win Rate, Pick Rate, Games, and on item rows Time in minutes): summoner spell pairs
  (12), starting items / starting item sets toggle, early items at 10 minutes, item sets
  with a grid of 30-odd mode buttons (Exact Item Count 1 to 5, Actually Built Sets 2+ to 5,
  Extrapolated Sets -2 to -5, Combined Sets, each with and without boots), then Item 1,
  Boots, Item 2 to 5 slot strips, then Popular, Winning and All Items (y 2220 to 4380,
  about 2,160 px). ^f22
  > Click Items Below to Filter Builds by Item and Item Buy Position
  > y=3268 x=503 12px: Time
  > Actually Built Sets
- [ux/uncertainty] Extrapolated sets are sorted by win rate and built from what players
  could be building, not what they built; the mode grid is unlabelled beyond tooltips. ^f23
  > These items sets are sorted by win rate and are extrapolated
- [ux/features] Skill tables (y 4400 to 4700): Overview, Level 6+, 10+, 15+ tabs; six
  skill-priority orders with win rate, pick rate, games; and a per-level table for levels
  1 to 6 giving win and pick rate for each ability. Then a full rune table (y 4710 to
  5420) with every rune's win rate, pick rate, games, filterable by keystone and toggled
  Overview / Highest Win Rune Page / Most Picked Rune Page. ^f24
  > y=4401 x=723 12px: Level 6+
  > Highest Win Rune Page
- [ux/features] Right column below the fold: objectives Secure/Yield table (y 1990), a
  Normalised Champion Ranked Player Base quadrant (breadth vs depth: Niche, Popular,
  Unpopular, Broad), Win Rate vs Game Length (7 buckets 0-15 to 40+) and Game Length
  Distribution line charts (about 230 px each), then Best on Darius (top 549 players over
  7 days), a 12-row leaderboard, sister-site links and Darius Stats (13 end-of-game
  averages as bars with rank of 112). ^f25
  > y=2313 x=1238 14px: Normalised Champion Ranked Player Base
  > y=2547 x=1281 16px: Win Rate vs Game Length
  > y=2783 x=1281 16px: Game Length Distribution
  > Maximum 50 summoners are used per region with a minimum of Diamond IV and 50 games played on Darius to be eligible.
- [ux/density] First screen at 1920x1080: filter bar, hero with 8 stats, page tabs and the
  whole build block; about 70 numeric figures, mostly 10 to 14 px (30 at 12 px, 15 at 10
  px). Page height 5,682 px, about 5.3 screens; counters start at y 1374 (second screen).
  (counted from the .dom-1920x1080 dump: number-only text nodes above y 1080) ^f26
  > darius/build/ at viewport 1920x1080, 2026-10-22 ... height 5682
- [ux/layout] Phone 390x844: the page is 420 px wide, so it scrolls sideways; the queue and
  region tiles sit at x 402 to 483, off screen. The first screen holds the filter bar,
  portrait, prose and the 8-figure grid (about 21 figures); the build starts at y 760 with
  runes first. Every strip scrolls sideways showing about 5.5 of 12 opponents; the four
  trend charts stack (about 300 px each). Height 13,597 px, about 16 screens. (seen in
  darius-build-390 screenshots) ^f27
  > y=55 x=402 16px: Ranked
  > y=85 x=483 8.5px: GLOBAL
- [ux/layout] Checked, not there: no lane stats on the champion page (gold, XP or CS
  difference at 10 or 15 minutes, first blood in lane, kill share), no explanation text per
  section beyond hover tooltips, no sample-size shading: an item on 1 game shows 100.00
  like one on 5,000. ^f28

## Read

- raw/lolalytics-darius-build.md: header, summary, counters strip, objectives table
- Screenshots of the fold, the full page, the tier list and Darius vs Garen
- 22 Oct: raw/lolalytics-darius-build.2026-10-22.md, .dom-1920x1080.txt, .dom-390x844.txt,
  .tooltips.txt; screenshots at 1920x1080 and 390x844, whole page

## Not read

- Leaderboard page (lead logged); synergy tab contents: clicking a tab emptied the strips
  in the headless browser, so only the default Common Matchup view was seen
