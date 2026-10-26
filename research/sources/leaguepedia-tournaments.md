---
title: Leaguepedia Cargo table Tournaments
url: https://lol.fandom.com/wiki/Special:CargoTables/Tournaments
kind: dataset
commit: 
for: [leaguepedia-daily-fetch]
looked: 2026-10-26
depth: skimmed (field list)
relevance: high
grade: B/fair
description: Leaguepedia Cargo table, one row per tournament: League, Region, TournamentLevel, IsOfficial, dates; 10,534 rows
---
# Leaguepedia Cargo table Tournaments

Why: how to filter games to major leagues?

## Assessment

- Evidence: B.
- Reasoning: fair.
- Interests: none.
- Weigh: League names checked live in [[leaguepedia-cargo-tests]].

## Findings

- [data] Filter fields: League, Region, TournamentLevel, IsOfficial, IsQualifier, IsPlayoffs, DateStart, Year; join key OverviewPage. ^f1
  > **League** - String
  > **TournamentLevel** - String
  > **IsOfficial** - Boolean
  > **OverviewPage** - String

## Read

- `raw/leaguepedia-tournaments.md`: field list.

## Not read

- Metadata:Leagues (full league list).
