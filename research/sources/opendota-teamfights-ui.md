---
title: 'OpenDota: match timeline strip, teamfights, advantage graph and benchmarks (Dota 2)'
url: https://www.opendota.com/matches/9039847755/teamfights
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (Teamfights, Graphs, Benchmarks tabs, desktop and phone screenshots)
relevance: high
grade: B/fair
description: OpenDota match page: event strip above every tab with teamfights coloured by winner, Roshan and first blood; clickable fight breakdown with map and per-player table; gold and XP advantage graph; per-player percentile benchmarks
---
# OpenDota: match timeline strip, teamfights, advantage graph and benchmarks (Dota 2)

Why: how a Dota site marks fights and objectives on a game timeline and breaks a fight down, for the meio.lol game detail rebuild.

## Assessment

- Evidence: B. Open-source Dota stats site, years of use, smaller audience than Dotabuff.
- Reasoning: fair.
- Interests: none known (open source, donations).
- Weigh: screenshots data/team/2026-10-24-ui/refs/game-detail/opendota-timeline-advantage.png, opendota-teamfight.png, opendota-benchmarks.png.

## Findings

- [ux/charts] A thin event strip (one 4 px bar, -1:30 to 42:57, end times printed) sits above the content of every tab: crossed swords for each teamfight, green or red by the team that won it; a blood drop for first blood and a Roshan icon for each Roshan kill, each with its time printed and placed above or below the bar by team. About 9 marks over 43 minutes, none overlapping at 1280 px. (seen in screenshot opendota-timeline-advantage.png, 24 Oct) ^f1
- [ux/controls] On the Teamfights tab each swords mark is a button: the selected fight is highlighted, its time range shown under a map, and the tables below switch to that fight (11:23 - 12:00 for the first). (seen in screenshot opendota-teamfight.png) ^f2
- [ux/postgame] The fight breakdown is one table per team: player, a skull if they died, then damage, healing, gold and XP in the fight, each number with a thin bar under it, then the abilities and items used with use counts; the map at left shows where each player died or stood. ^f3
  > PARIVISION - Teamfights
- [ux/charts] The Graphs tab's advantage chart draws gold (yellow) and XP (white) as two lines on one chart, the background split into halves labelled with the team names, y axis every 7,500; no event marks on the chart itself, only the strip above. ^f4
  > Radiant Advantage
- [ux/uncertainty] The Benchmarks tab gives each player's per-minute stats as a percentile among games on the same hero next to the raw value (62.10% 648 GPM), the percentile coloured in five bands from red to green; ten column headers are abbreviations without a key. ^f5
  > PARIVISION - Benchmarks
- [ux/layout] About 20 tabs (Overview, Benchmarks, Performances, Laning, Combat, Farm, Items, Graphs, Casts, Objectives, Vision, Actions, Teamfights, Fantasy, Chat, Story, Log, Cosmetics) scroll sideways on desktop. (seen in screenshot 24 Oct) ^f6
- [ux/layout] On a 390 px phone the advantage chart stays full width and grows taller than wide; the event strip keeps all marks but the swords crowd together. (seen in phone screenshot 24 Oct) ^f7

## Read

- Teamfights (first fight), Graphs (advantage chart), Benchmarks; phone Graphs.

## Not read

- Story tab (text summary of the game), Laning tab map, Objectives.
