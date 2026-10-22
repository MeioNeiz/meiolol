---
title: 'Blitz: Darius top build with matchup Garen (patch 26.21)'
url: https://blitz.gg/lol/champions/Darius/build/top?matchup=Garen
kind: docs
commit: 
for: [champion-matchup-gap]
looked: 2026-10-22
depth: docs (rendered text, fold screenshots at 1920x1080 and 390x844; full-page shot did not render below the fold)
relevance: high
grade: B/fair
description: Blitz build page with the opponent filter set; only a Matchup Builds card changes, the rest (header stats, items, runes, guide text) stays champion-wide
---
# Blitz: Darius top build with matchup Garen (patch 26.21)

Why: what Blitz shows for one opponent. URL found by clicking "Select Matchup" on the
build page (?matchup=Garen).

## Assessment

- Evidence: B. Big site, live page.
- Reasoning: weak.
- Interests: vendor.
- Shots: scratchpad shots/others/blitz-darius-vs-garen-{1920,390}-fold.png.

## Findings

- [ux/density] Densest first screen of the sites read: at 1920x1080 the header strip
  (tier, win rate, change, pick, ban, matches), build variants with games and win rate,
  full rune tree, spells, starting, build order, completed and situational items and the
  ability max order grid all fit above the fold, in a 1050 px content column with ads to
  the right (seen in screenshot blitz-darius-vs-garen-1920-fold.png). ^f1
- [ux/features] The opponent filter adds one card, Matchup Builds (vs Garen): the build
  variants played into Garen, each with games and win rate. ^f2
  > Matchup Builds (vs Garen) VS Bruiser 621 GAMES
- [ux/trust] Failure: with the matchup set, the header still shows Darius's overall
  numbers (12,410 matches) and nowhere states Darius's win rate against Garen; items
  and runes stay champion-wide (Dead Man's Plate on 6,035 purchases, half the 12,410). ^f3
  > Dead Man's Plate +0.53 53.8% 54.3% 17.4% 6,035
- [learning] Written guide text under the stats is champion-wide, not per matchup: Key
  Insights, Strengths, Weaknesses, similar champions; one templated line names the
  hardest matchup. ^f4
  > Cho'Gath is one of the more difficult matchups.
  > Can be kited very easily by mobile champions or ones who outrange him.
- [ux/features] Item table has a WRI column (win rate increase) and a pre-buy win rate
  beside the win rate, separating "this item helps" from "winners buy it". ^f5
  > ITEM WRI PRE-BUY WR WIN RATE PICK RATE PURCHASES
- [ux/layout] At 390 wide the opponent, rank and region pickers fold into one filter icon,
  the six header numbers become a 3x2 grid, and the build variant list hides behind a
  menu button, so the matchup chosen is not visible on the first phone screen (seen in
  screenshot blitz-darius-vs-garen-390-fold.png). ^f6
- [ux/features] Checked, not there: no lane stats (gold, XP, CS at a minute), no level 2
  or first blood rate, no matchup difficulty, no power spike or tips for the pair. ^f7

## Read

- Whole page plain text; fold screenshots

## Not read

- Abilities tab; Synergies tab
