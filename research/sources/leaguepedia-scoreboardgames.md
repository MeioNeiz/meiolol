---
title: Leaguepedia Cargo table ScoreboardGames
url: https://lol.fandom.com/wiki/Special:CargoTables/ScoreboardGames
kind: dataset
commit: 
for: [leaguepedia-daily-fetch]
looked: 2026-10-26
depth: skimmed (field list)
relevance: high
grade: B/fair
description: Leaguepedia Cargo table with one row per pro game: teams by side, winner, length, patch, date, GameId; 138,430 rows
---
# Leaguepedia Cargo table ScoreboardGames

Why: which fields give a pro game's result, length, patch, date and sides?

## Assessment

- Evidence: B. The wiki of record's game table, hand- and bot-filled.
- Reasoning: fair (schema only).
- Interests: none.
- Weigh: field meanings partly inferred from names; side meaning checked in [[leaguepedia-cargo-tests]].

## Findings

- [data] Per game: Team1, Team2, WinTeam, LossTeam, Winner (integer 1 or 2), DateTime_UTC. ^f1
  > **WinTeam** - String
  > **Winner** - Integer
  > **DateTime\_UTC** - Datetime
- [data] Length as "mm:ss" string and as a float in minutes; patch as a string. ^f2
  > **Gamelength** - String
  > **Gamelength\_Number** - Float
  > **LegacyPatch** - String
- [data] Keys: OverviewPage (tournament page, joins Tournaments), Tournament (display name), GameId, MatchId, plus RiotPlatformGameId. ^f3
  > **GameId** - String
  > **RiotPlatformGameId** - String
- [data] Also bans and picks as unordered lists per team, team totals (kills, gold, towers, dragons, barons). ^f4
  > **Team1Bans** - List of String, delimiter: ,
- [data] 138,430 rows on 26 Oct 2026, more than PicksAndBansS7's 104,747: not every scoreboard game has a draft row. ^f5
  > This table has **138,430** rows altogether
- [data] Checked, not there: no side field; Team1 is blue by convention (see [[leaguepedia-cargo-tests]], [[leaguepedia-parser]]). ^f6

## Read

- `raw/leaguepedia-scoreboardgames.md`: field list.

## Not read

- Declaring module (field docs).
