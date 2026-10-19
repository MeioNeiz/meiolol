---
title: LoLalytics Darius top build page (layout read, 20 Oct 2026)
url: https://lolalytics.com/lol/darius/build/
kind: docs
commit: 
for: [dense-stat-layout]
looked: 2026-10-20
depth: skimmed (page text, screenshots of fold, full page, tier list, Darius vs Garen)
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

## Read

- raw/lolalytics-darius-build.md: header, summary, counters strip, objectives table
- Screenshots of the fold, the full page, the tier list and Darius vs Garen

## Not read

- Counters page and leaderboard; mobile layout
