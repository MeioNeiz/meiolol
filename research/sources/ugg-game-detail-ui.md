---
title: 'U.GG: game detail (expanded match card), Oct 2026'
url: https://u.gg/lol/profile/euw1/overview
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: docs (rendered text of all five tabs, screenshots 1280 wide)
relevance: high
grade: A/fair
description: U.GG's game detail inside the profile's match card: Post Game scoreboard with Carry score, a sortable all-ten Performance table, Item Build, a Timeline kill feed beside a map of every kill, Metrics lines
---
# U.GG: game detail (expanded match card), Oct 2026

Why: lol-site-ui, kind 1. Same game as [[opgg-game-detail-ui]] (a Challenger EUW
player's latest loss), so the two read side by side. Screenshots in
data/team/2026-10-24-ui/refs/game-detail/ (gitignored): ugg-postgame.png,
ugg-performance-sorted.png, ugg-timeline-map.png.

## Assessment

- Evidence: A. One of the two biggest LoL stats sites.
- Reasoning: fair. Tighter than OP.GG, one real sortable table.
- Interests: ad funded, desktop app and PLUS upsells in the header.
- Weigh: the Performance table is the one to copy; Post Game is OP.GG's scoreboard, denser.

## Findings

- [ux/postgame] [ux/layout] Detail opens inside the match card (arrow at its bottom
  right, 1 click), about 730 px, five tabs. ^f1
  > Post Game Performance Item Build Timeline Metrics
- [ux/postgame] [ux/density] Post Game scoreboard: rows about 48 px; champion with level,
  spells, runes; name over a rank letter (GM, C, M); a Carry score; K/D/A over KDA (KDA
  coloured gold or blue when high); damage number over a team-coloured bar; gold in k;
  CS; wards; items as two rows of four, so the table stays 640 px wide. ^f2
  > Defeat (Blue Team) Carry KDA Damage Gold CS Wards Items
  > 12 [player] C 68 3 / 10 / 5 0.80 KDA 12,595 8.4k 133 9
- [ux/postgame] [ux/density] [ux/controls] Performance tab: all ten players in one table,
  sorted by the clicked column (Damage here, its header underlined and the column shaded),
  team shown by the row tint and a bar under each name; columns kills, KDA, damage, gold,
  wards, CS. Answers "who did most" across both teams in one look. ^f3
  > Player Kills KDA Damage Gold Wards CS [player] 13 12.00 26,037 16,365 7 191
- [ux/postgame] [ux/charts] Timeline tab: Kills, Objectives and Vision check boxes; a kill
  feed by minute (team-tinted rows, objectives such as drakes, grubs and turrets
  included) beside a map with a dot at every kill position, both teams at once. ^f4
  > Kills Objectives Vision 2 min [player] killed [player] 7 min [player] killed Mountain Drake
- [ux/charts] Metrics tab: Gold, Damage, Exp and CS lines for one player at a time, chosen
  from ten portraits; the viewed player is the default. ^f5
  > Gold Damage Exp CS 0 min 1 min 3 min 5 min
- [ux/postgame] Item Build tab: runes, skill order grid and timed item groups, as OP.GG. ^f6
  > Runes Precision Sorcery Skill Order Q 1 4 5 7 9 W 2 8 10 12 E 3 R 6 11 Items 0 min 3 min
- [ux/postgame] Checked, not there: no win chance or gold lead curve, no lane opponent
  comparison, no turning point; the collapsed card above the tabs repeats the row. ^f7

## Read

- All five tabs for one game.

## Not read

- Vision overlay on the Timeline map.
