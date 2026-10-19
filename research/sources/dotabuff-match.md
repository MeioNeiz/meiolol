---
title: 'Dotabuff: match overview page'
url: https://www.dotabuff.com/matches/9053174983
kind: dataset
commit:
for: [dense-stat-layout]
looked: 2026-10-20
depth: skimmed (overview fold screenshot)
relevance: medium
grade: A/fair
description: Dotabuff match overview for a pro match: per-player scoreboard with leader underlines, item timings, lane outcome, draft strip
---
# Dotabuff: match overview page

Why: how a big game-stats site lays out one game's ten players, for the Your games
review.

## Assessment

- Evidence: A. Largest Dota stats site.
- Reasoning: fair.
- Interests: the deeper analysis tabs sell Plus.
- Weigh: screenshot dotabuff-match.png (`data/team/2026-10-19-night/design-shots/`).

## Findings

- [ux/density] Scoreboard row per player: K, D, A, net worth, last hits/denies, GPM/XPM,
  damage, healing, building damage, wards, then items. About 15 numbers per row. ^f1
  > | Hero | R | L | Player |  | K | D | A | NET | LH |  | DN | GPM |  | XPM | DMG | HEAL | BLD | Wards | Items |
- [ux/density] The team leader in each column is underlined (most kills, most assists,
  top GPM), so the standout numbers are found without colour.
  (seen in screenshot dotabuff-match.png) ^f2
- [ux/charts] Each item icon carries the minute it was bought (1m, 3m, 11m): a timeline
  folded into a row of icons. (seen in screenshot dotabuff-match.png) ^f3
- [ux/layout] Each lane gets a one-word verdict per player (Won, Lost, Drew) under the
  role, and the team summary row says it outright. ^f4
  > Lane Outcome: won
- [ux/colour] Team sections are tinted: winners' rows a faint green, losers' a faint
  red, team names in the same colours. (seen in screenshot dotabuff-match.png) ^f5
- [ux/layout] Draft strip under each team: pick and ban portraits in order with a
  number and a PICK or BAN label, so the draft reads as a sequence.
  (seen in screenshot dotabuff-match.png) ^f6

## Read

- Overview fold.

## Not read

- Lanes, Combat, Farm tabs (graphs over time, Plus).
