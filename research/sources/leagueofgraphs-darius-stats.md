---
title: 'League of Graphs: Darius stats (Wayback, Mar 2026)'
url: https://www.leagueofgraphs.com/champions/stats/darius
kind: docs
commit: 
for: [league-tools-landscape]
looked: 2026-10-11
depth: docs (whole page, Wayback copy 2026-03-08, patch 16.4; live site 403)
relevance: high
grade: B/fair
description: League of Graphs champion stats page: aggregate curves by game duration (gold, CS, kills, deaths, win rate), snowballing win rate by kill lead at 10 and 20 minutes, kill and death position maps
---
# League of Graphs: Darius stats (Wayback, Mar 2026)

Why: League of Graphs is the stats site most known for graphs; does it already show
time-based (timeline-derived) champion curves?

## Assessment

- Evidence: B. Long-running (since about 2014), global rank ~7,600
  ([[similarweb-opgg-competitors#^f3]]); same creator as Porofessor ([[porofessor-faq#^f3]]).
- Reasoning: fair. Charts labelled, method not explained.
- Interests: vendor (M.O.B.A. Network, ads; promotes Porofessor).
- Weigh: text snapshot shows chart titles and axes only, not values.

## Findings

- [tools] [data] Shows per-champion curves against game duration: gold, minions, kills plus assists, deaths, and win rate. ^f1
  > ### Gold / Game duration
  > ### Minions / Game duration
  > ### Winrate / Game Duration
- [tools] [data] "Snowballing" stats: win rate by kills minus deaths at 10 and at 20 minutes, which need timeline frames. ^f2
  > ### Winrate / (Kills - deaths) @10 min
  > ### Winrate / (Kills - deaths) @20 min
- [data] Kill and death position maps per champion, which need timeline event coordinates. ^f3
  > ### Positions ### Kills ### Deaths
- [tools] Win rate by number of ranked games played on the champion (a learning curve). ^f4
  > ### Winrate / Ranked Games Played
- [data] Large rolling sample: 4.3M matches in the last 2 days, 99k for Darius; Platinum+ default, normals and ranked. ^f5
  > 4,310,514 matches (Last 2 days)
  > 99,067 matches ( Last 2 days )
- [tools] Other sections: tier list, pro builds, matchups, runes, skill orders, items, spells, jungle paths, rankings, infographics, replays; popularity, win and ban rate history since 2016. ^f6
  > ### Popularity History
- [tools] (inferred) Its curves are champion-wide (vs everyone) and end-of-game-duration based, not matchup-specific and not minute-by-minute lead within a lane. ^f7
- [tools] [ux/features] Checked, not there: no per-matchup gold or XP curve, no lane-phase diff, no explanation of power spikes. ^f8

## Read

- Whole stats page (text)

## Not read

- leagueofgraphs.com/champions/counters/darius (matchup columns)
- /champions/snowballing-stats and /infographics
