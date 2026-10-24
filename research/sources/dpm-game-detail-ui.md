---
title: 'DPM.LOL: game detail (expanded match row), Oct 2026'
url: https://dpm.lol/profile/match
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: docs (rendered text of General and Details tabs, screenshots 1280 wide)
relevance: high
grade: B/fair
description: dpm.lol game detail inside the match row: General scoreboard with place pills and objective counts per team, Details tab with a ten-champion picker and the picked player's lane numbers at 15 against the lane opponent, build, skill grid, spells cast and pings
---
# DPM.LOL: game detail (expanded match row), Oct 2026

Why: lol-site-ui, kind 1. Same game as [[opgg-game-detail-ui]]. Screenshots in
data/team/2026-10-24-ui/refs/game-detail/ (gitignored): dpm-general.png,
dpm-details-lane.png.

## Assessment

- Evidence: B. Popular newer site.
- Reasoning: fair. The only one of the four with a lane-opponent block in the game.
- Interests: Premium in the header; a Video tab (clips) suggests their app.
- Weigh: copy the Details layout; the scoreboard is close to the others.

## Findings

- [ux/postgame] [ux/layout] Detail opens inside the 62 px row (arrow, 1 click), about
  675 px, four tabs; Copy match link sits on the team header line. ^f1
  > Tabs: General Details Runes Video
- [ux/postgame] [ux/density] General scoreboard: rows about 50 px; place pill first (7th,
  ACE, MVP, 10th), champion with level, name over LP, spells and runes, eight items in
  two rows, K/D/A, kill share, CS per minute (vision per minute for supports), damage in
  k with per minute over a bar, and the 0-100 score coloured by value. ^f2
  > 10th 12 [player] 4257 LP 3/10/5 40 % KP 5.5 CS/min 12.6K (517 /m) 5
  > 8th 11 [player] 2377 LP 3/11/6 45 % KP 1.9 vision 23.4K (959 /m) 25
- [ux/postgame] Each team's header line carries its objective counts as icon and number
  (grubs, heralds, barons, dragons, towers), so the objective story is one line. ^f3
  > Defeat (Blue Side) 3 0 0 0 1 Copy match link
- [ux/postgame] Details tab opens on a strip of the ten champions, lined up five "VS"
  five by role, the viewed player selected; any one can be picked (screenshot 24 Oct,
  dpm-details-lane.png). ^f4
- [ux/postgame] [ux/density] For the picked player: three cards in a row, Laning phase at
  15 against the lane opponent (CS, gold and XP difference, first to level 2), Wards
  (placed, killed, control) and Global stats (CS, vision, damage and gold per minute),
  each a few big numbers with small labels; then build order by minute, a skill grid,
  spells cast per key and pings. No sentence anywhere. ^f5
  > LANING PHASE (AT 15) -48 cs diff -4500 gold diff -1709 xp diff No first lvl 2
  > WARDS 9 placed 3 killed 0 control GLOBAL STATS 5.5 CS/m 0.8 VS/m 517 DMG/m 343 Gold/m
- [ux/postgame] Spells cast per ability and summoner (Q 112 times, Flash 4 times) and pings
  by type per game: trivia, but light and specific. ^f6
  > SPELL CASTED Q 112 times W 22 times E 28 times R 4 times D 5 times F 4 times
- [ux/postgame] Checked, not there: no win chance or gold curve, no kill feed, map or
  moments; the lane numbers are a snapshot at 15, not a line. ^f7

## Read

- General and Details for one game.

## Not read

- Runes and Video tabs.
