---
title: 'Dotabuff: match page graph, lanes and kills (Dota 2)'
url: https://www.dotabuff.com/matches/9059185615
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (overview, Combat and Kills tabs, desktop and phone screenshots)
relevance: high
grade: A/fair
description: Dotabuff match page for a pro game: net worth advantage graph with deaths as hero portraits, kill grid, kill matrix and death log, phone scoreboard folded into column-group tabs
---
# Dotabuff: match page graph, lanes and kills (Dota 2)

Why: how a big Dota stats site draws a game timeline and marks kills on it, for the meio.lol game detail rebuild (Jacob dislikes our +/- markers on the win chance graph). Builds on [[dotabuff-match]] (scoreboard).

## Assessment

- Evidence: A. Largest Dota stats site, many years of use.
- Reasoning: fair. No design rationale on the page.
- Interests: sells Plus; heavy ads (a 250 px install ad above the match header, a video ad over the scoreboard's item column at 1280 px).
- Weigh: screenshots in data/team/2026-10-24-ui/refs/game-detail/ (dotabuff-advantage-graph.png, dotabuff-kill-matrix-log.png, dotabuff-phone.png).

## Findings

- [ux/charts] The overview's graph is a team advantage per minute with three tabs (Net Worth, Experience, Gold Earned), only on matches whose replay was parsed. ^f1
  > This match page has been enhanced with extra information from the replay file analysed by our TrueSight engine.
- [ux/charts] Every death is drawn as the dead hero's small portrait (about 14 px) at its minute, one team's along the top edge of the plot and the other's along the bottom, stacked upwards when several die in the same minute; nothing is drawn on the line itself. Counts match the score (about 11 icons top, 29 bottom for 10-29). (seen in screenshot dotabuff-advantage-graph.png, 24 Oct) ^f2
- [ux/charts] The advantage is one line with a filled area to zero in the leading team's colour (olive green for Radiant); the short stretch where Dire led turns red. No legend, no labels on points, minute ticks every 5:00, gold axis every 10k. (seen in screenshot dotabuff-advantage-graph.png) ^f3
- [ux/charts] Hovering the line or the portraits showed no tooltip in a headless run: the graph reads at a glance but gives no per-minute numbers. (seen 24 Oct, hover test) ^f4
- [ux/postgame] Under the graph a kill grid per killer row lists each victim portrait with a count and the gold earned from them (x4 / 1,333g). ^f5
  > Radiant KillsWith TrueSight
- [ux/postgame] The Kills tab has a 5x5 hero matchup grid: each cell two K/A pairs (what this hero did to that one, and the reverse), outlined boxes for the non-zero side; and a death log, one line per death: time, victim, killer, ability, assisters' portraits, gold lost, gold and XP fed, time dead. (seen in screenshot dotabuff-kill-matrix-log.png) ^f6
- [ux/postgame] The Combat tab is a plain table of damage, healing and crowd control dealt to and received from heroes per player for the whole game, not per fight. Checked, not there: no teamfight list or fight breakdown on Dotabuff's free tabs. (seen in page text 24 Oct) ^f7
- [ux/layout] On a 390 px phone the scoreboard keeps hero, role and lane icons, name with lane verdict, and only K, D, A, NET; the other columns move behind tabs per column group (Overview, Farm, Damage, Items) above each team table. (seen in screenshot dotabuff-phone.png) ^f8
- [ux/layout] Checked, not there: no win probability graph and no first-screen summary; at 1280x900 the first screen shows ads, the series box and the header row of the scoreboard. (seen in screenshot 24 Oct) ^f9

## Read

- Overview (graph, kill grid), Combat and Kills tabs, phone overview.

## Not read

- Farm, Objectives, Vision, Log tabs; Plus-only analysis.
