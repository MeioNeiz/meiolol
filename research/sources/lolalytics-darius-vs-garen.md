---
title: 'LoLalytics: Darius vs Garen build (matchup page)'
url: https://lolalytics.com/lol/darius/vs/garen/build/
kind: docs
commit: 
for: [league-tools-landscape]
looked: 2026-10-11
depth: docs (whole rendered page, text only)
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
- [tools] Checked, not there: no gold or XP difference at 10 or 15 minutes, no per-minute lead curve, no explanation of how the lane plays out or when each champion spikes. ^f7
- [market] Cross-links sister sites (pros.lol, XDX.gg) and Mobalytics as "friends". ^f8
  > Quality alternative Darius build stats and more from our friends at Mobalytics.

## Read

- Whole rendered page text

## Not read

- Charts if any (win rate by game length) not captured in text
- lolalytics.com/lol/darius/counters/ (counter list)
