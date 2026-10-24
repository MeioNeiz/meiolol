---
title: 'League of Graphs: match page (Wayback, May 2025)'
url: https://web.archive.org/web/20250502190210/https://www.leagueofgraphs.com/match/euw/7234931480
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (archived ranked solo game page: scoreboard, gold and damage charts, one player's Fighting tab with lane and average comparison curves, items, skills, runes)
relevance: high
grade: B/fair
description: League of Graphs match page: mirrored scoreboard, team gold advantage area chart, damage bars, then per-player tabs with gauges, coloured badges and paired cumulative curves against the same champion's rank average and against the lane opponent
---
# League of Graphs: match page (Wayback, May 2025)

Why: game detail (kind 1); League of Graphs is the one site seen that charts a player's game against both the lane opponent and the average player of that champion and rank.

## Assessment

- Evidence: B. Long-running site (copyright 2013-2026) of the M.O.B.A. Network, same creator as Porofessor ([[porofessor-faq#^f3]]).
- Reasoning: weak. No rationale on the page.
- Interests: vendor; pushes Porofessor.
- Weigh: the live site served a Cloudflare challenge to headless and headed Chrome on 24 Oct, so this is a Wayback capture of 2 May 2025 (game from Dec 2024); the layout may have changed since. Shots: data/team/2026-10-24-ui/refs/game-detail/ (leagueofgraphs-scoreboard.png, leagueofgraphs-gold-badges.png, leagueofgraphs-lane-curves.png).

## Findings

- [ux/postgame] The scoreboard header is one line: Defeat, team K/D/A, team objective counts, queue with duration, the other team's counts and K/D/A, Victory. ^f1
  > Ranked Solo/Duo (50:35)
- [ux/layout] The scoreboard is mirrored by lane like Mobalytics' ([[mobalytics-match-ui#^f3]]): each row a lane, the two players facing each other, K/D/A coloured green, red and orange per number, then CS and gold, then KP and vision on a second line. ^f2
  > 274 CS - 17.6k gold
- [ux/charts] Under it, a Team Gold Advantage area chart over minutes (blue fill above zero, red below, gold axis to -10000) next to a damage dealt bar chart of the ten players in team colours with champion icons as the x axis. ^f3
  > Team Gold Advantage
- [ux/layout] Per-player detail is a row of ten champion tabs plus a table icon; each player has sub-tabs. ^f4
  > Fighting Farming Objectives Vision Pings
- [ux/density] The Fighting tab opens with six ring gauges: teamfights win rate, duels win rate, kills under enemy turret, teamfights participation, solo deaths, deaths under enemy turret. ^f5
  > Teamfights winrate
- [ux/postgame] Every stat then gets two cumulative charts side by side: left the player against the average of the same champion at a rank, with rank emblems under the chart to switch the rank; right the player's champion against the lane opponent's. Stats charted: Kills + Assists, Deaths, Kill participation, Roaming Kills/Assists, Damage dealt. ^f6
  > Average Bronze Dr. Mundo
  > Roaming Kills/Assists
- [ux/charts] The gap between the two lines is filled in the colour of whoever is ahead, so who led and when reads without reading numbers. (seen in screenshot leagueofgraphs-lane-curves.png, 24 Oct) ^f7
- [ux/colour] Badges for the player's game are coloured chips: green for good (High Kill Participation, Good vision), yellow for neutral (Split pusher), red for bad (Stopped CSing, Bad CSer, No Control Wards). ^f8
  > High Kill Participation Good vision Split pusher Stopped CSing Bad CSer No Control Wards
- [ux/postgame] The right column has the player's K/D/A, then items as a purchase timeline (one row per buy time with the items bought), a skill order grid by level and the rune list. ^f9
- [ux/postgame] Checked, not there: no win probability and no list of fights or moments; the timeline is the gold chart and the purchase list. (seen in page text and screenshots) ^f10

## Read

- Scoreboard, charts, one player's Fighting tab, items, skills, runes.

## Not read

- Farming, Objectives, Vision, Pings tabs; table view; live site (Cloudflare).
