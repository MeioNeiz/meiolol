---
title: Leaguepedia Cargo table ScoreboardPlayers
url: https://lol.fandom.com/wiki/Special:CargoTables/ScoreboardPlayers
kind: dataset
commit: 
for: [leaguepedia-daily-fetch]
looked: 2026-10-26
depth: skimmed (field list)
relevance: high
grade: B/fair
description: Leaguepedia Cargo table, one row per player per pro game: champion, role, side, K/D/A, CS, gold, damage to champions; 1,384,300 rows
---
# Leaguepedia Cargo table ScoreboardPlayers

Why: which fields give each player's line in a pro game?

## Assessment

- Evidence: B. The wiki of record.
- Reasoning: fair (schema only).
- Interests: none.
- Weigh: Side meaning (1 blue, 2 red) checked against ScoreboardGames.Team1 in [[leaguepedia-cargo-tests]].

## Findings

- [data] Per player: Name, Link (player page), Team, Champion, Role, Role_Number, IngameRole, Side (integer), PlayerWin. ^f1
  > **Champion** - String
  > 34.  **Side** - Integer
  > **Role\_Number** - Integer
- [data] Stats: Kills, Deaths, Assists, Gold, CS, DamageToChampions, VisionScore, Items, runes, summoner spells. ^f2
  > **Kills** - Integer
  > **DamageToChampions** - Integer
- [data] Joins to ScoreboardGames on GameId. ^f3
  > **GameId** - String
- [data] 1,384,300 rows (10 per game). ^f4
  > This table has **1,384,300** rows altogether

## Read

- `raw/leaguepedia-scoreboardplayers.md`: field list.

## Not read

- Declaring module.
