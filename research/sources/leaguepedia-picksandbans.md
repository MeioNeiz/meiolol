---
title: Leaguepedia Cargo table PicksAndBansS7 (pro games' picks and bans in order)
url: https://lol.fandom.com/wiki/Special:CargoTables/PicksAndBansS7
kind: dataset
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed
relevance: medium
grade: B/fair
description: Leaguepedia Cargo table with pro games picks and bans in draft order and the role of each pick, 104,747 rows
---
# Leaguepedia Cargo table PicksAndBansS7 (pro games' picks and bans in order)

Why: Is there any game population where pick order is public?

## Assessment

- Evidence: B. The pro-play wiki of record, hand-entered per game by editors since 2017; queryable through the Cargo API.
- Reasoning: fair (a schema, no prose).
- Interests: none.
- Weigh: pro games only, a different population from ranked; rows hold champion names, not Riot match ids.

## Findings

- [data] [draft] Pro games' picks and bans are recorded per game in draft order (Team1Pick1 to Team1Pick5, Team1Ban1 to Team1Ban5) with the role of each pick (Team1Role1 to Team1Role5). ^f1
  > Team1Role1 | Team1Role2 | Team1Role3 | Team1Role4 | Team1Role5
  > Team1Pick1 | Team1Pick2 | Team1Pick3 | Team1Pick4 | Team1Pick5
- [data] The table had 104,747 rows on 24 Oct 2026 (one per pro game since 2017). ^f2
  > This table has **104,747** rows altogether.

## Read

- `raw/leaguepedia-picksandbans.md`: field list and first rows.

## Not read

- Nothing more needed for the pick-order question.
