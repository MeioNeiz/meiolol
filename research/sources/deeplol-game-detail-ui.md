---
title: 'DeepLoL: game detail (expanded match row), Oct 2026'
url: https://www.deeplol.gg/summoner/euw/matches
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: docs (rendered text of the three tabs, screenshots 1280 wide)
relevance: high
grade: B/fair
description: DeepLoL game detail inside the match row: AI Analysis scoreboard with a 0-100 score and place per player, AI Graph of the score by minute with a team average and objective icons per team under the axis, Build with a skill grid
---
# DeepLoL: game detail (expanded match row), Oct 2026

Why: lol-site-ui, kind 1. Same game as [[opgg-game-detail-ui]]. Screenshots in
data/team/2026-10-24-ui/refs/game-detail/ (gitignored): deeplol-ai-analysis.png,
deeplol-ai-graph.png, deeplol-build-skills.png. A floating video ad covers the lower
right of the page; the shots are cropped above it.

## Assessment

- Evidence: B. Korean site, smaller in EUW; method of the AI-Score not on the page
  ([[deeplol-profile#^f1]]).
- Reasoning: weak on the score, fair on layout.
- Interests: ad funded (video ad, coaching ad in the sidebar).
- Weigh: the graph's objective strip is worth copying; the score itself is a black box.

## Findings

- [ux/postgame] [ux/layout] Detail opens inside the row (a Detail arrow, 1 click); a
  permalink per game opens the profile with that game expanded. Three tabs. ^f1
  > Tabs: AI Analysis AI Graph Build
- [ux/postgame] [ux/density] AI Analysis scoreboard: rows about 42 px; champion, spells,
  runes; rank letter chip (GM, C, M) and name; the AI-Score in a coloured box (green from
  about 50, red below) with the place beside it (1st with a crown, 10th); K/D/A over KDA;
  damage over a bar; CS with per minute; eight items. ^f2
  > Lose (Blue Team) AI-Score KDA Damage CS Items (Click)
  > 12 C [player] 37 10th 3 / 10 / 5 0.80 12,595 133 (5.5/m)
- [ux/charts] [ux/postgame] AI Graph: a strip of ten portraits on a red and a blue team
  bar with each score under it (the viewed player framed); below, the player's score by
  minute as a red line with dots, a dashed team average, a 50 baseline and Good / Fair
  labels on the right axis instead of numbers. ^f3
  > Lose 44 40 50 36 37 | Win 53 60 72 75 69 | Team Avg AI-Score | 70 50 30 | Good | Fair
- [ux/charts] [ux/postgame] Under the graph's time axis, one row per team carries an icon
  at the minute of each objective it took (grubs, dragons, herald): moments placed on the
  same time axis as the curve without crowding it. (screenshot 24 Oct, deeplol-ai-graph.png) ^f4
  > 0m 5m 10m 15m 20m | Lose (Blue Team) | Win (Red Team)
- [ux/postgame] Build tab: item groups by minute, skill order as a coloured grid (Q, W, E,
  R rows by level 1 to 18, each cell numbered with the level) plus the max order as three
  icons, runes as the full tree. The grid reads faster than OP.GG's letter strip. ^f5
  > Skill Order Q W E Q W E R + 1 4 5 7 9 2 8 10 12 3 6 11
- [ux/postgame] Checked, not there: no lane opponent comparison, no gold or win chance
  curve, no kill feed or map. ^f6

## Read

- AI Analysis, AI Graph, Build for one game.

## Not read

- The "What's AI-Score" explainer.
