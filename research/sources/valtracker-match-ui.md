---
title: 'Valorant Tracker (tracker.gg): match page round strip, economy graph, rounds, performance'
url: https://tracker.gg/valorant/match/176736f6-9a97-471a-9d1a-370b201111f2
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (Scoreboard, Performance, Economy, Rounds, Duels tabs; desktop and phone screenshots)
relevance: high
grade: B/fair
description: Valorant Tracker match page: two-row round strip with outcome icons, economy advantage graph with round outcome icons under the axis, round tiles that open a round detail, per-player round strip of kills and deaths
---
# Valorant Tracker (tracker.gg): match page round strip, economy graph, rounds, performance

Why: how a non-MOBA stats site marks moments on a game timeline and folds a match on a phone, for the meio.lol game detail rebuild.

## Assessment

- Evidence: B. Tracker Network, a large multi-game stats network; Valorant Tracker is widely used.
- Reasoning: fair.
- Interests: ads (a video ad pinned bottom right over the table at 1280 px), Premium, mobile app promotion.
- Weigh: screenshots data/team/2026-10-24-ui/refs/game-detail/valtracker-*.png. Raw snapshot has player names redacted.

## Findings

- [ux/charts] Under the header a two-row round strip (Team A row, Team B row, round numbers 1-30 below) puts the winner's icon in the winner's row for each round and a small dot in the loser's; the icon says how the round was won (elimination, spike defused, spike detonated). The whole game's flow reads in one 90 px band. (seen in screenshot valtracker-scoreboard-rounds.png, 24 Oct) ^f1
  > TEAM B ELIMINATION WIN
- [ux/charts] The Economy tab's graph is one advantage line with a dot per round, area filled teal where Team A leads and red where Team B leads; the round outcome icons sit in their own row under the x axis, one per round, coloured by winner, instead of on the line. A three-way toggle switches Bank, Loadout and Total. ^f2
  > Avg. Loadout: 20,163 / 19,170
- [ux/controls] The Rounds tab is a row of round tiles (about 60x120 px), each with two bars for the teams' loadout and the outcome icon; clicking one opens that round: both teams' score, K, D, A and economy, an event log (time, killer, weapon, distance, victim) and a map of player positions. ^f3
  > Select a round above to view detailed stats for that round.
- [ux/postgame] The Performance tab picks one player (portrait row of all ten) and shows a column per round: their kills as stacked white skulls above a short line coloured by round won or lost, their death as a red skull below; then splits by attack and defence and by opponent (kills, deaths, damage dealt and received). (seen in screenshot valtracker-player-rounds.png) ^f4
- [ux/density] Scoreboard: 16 numeric columns (TRS, ACS, K, D, A, +/-, K/D, DDΔ, ADR, HS%, KAST, FK, FD, MK); the sorted column (ACS) has a lighter cell background; signed columns (+/-, DDΔ) and K/D are green above zero or 1, red below; rows about 57 px with agent portrait and rank. (seen in screenshot valtracker-scoreboard-rounds.png) ^f5
- [ux/postgame] Duels tab: a 5x5 grid of kills each way between every pair of opposing players, tiles coloured by who won the pair, with three callout cards above (Top Rivalry, Mismatch A, Mismatch B). (seen in screenshot 24 Oct) ^f6
- [ux/layout] On a 390 px phone the header wraps to two lines, the round strip scrolls sideways (7 of 30 rounds visible) and the scoreboard shows only player, Match Rank and TRS with the rest off screen to the right; a video ad covers the lower right. (seen in screenshot valtracker-phone.png) ^f7
- [ux/layout] Header is one band: mode and map, score per team in team colours, date, duration, average rank; five tabs (Scoreboard, Performance, Economy, Rounds, Duels). About 15 words above the strip. (seen in screenshot 24 Oct) ^f8

## Read

- All five tabs on desktop (first round and first player only), scoreboard on phone.

## Not read

- Other rounds and players; phone layout of Economy and Rounds tabs.
