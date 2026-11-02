---
title: Basketball-Reference 2024-25 Celtics lineups (2-man combinations)
url: https://www.basketball-reference.com/teams/BOS/2025/lineups/
kind: project
commit: 
for: [stat-presentation-patterns]
looked: 2026-11-02
depth: skimmed (2-Man Combinations table, page navigation)
relevance: medium
grade: A/fair
description: Basketball-Reference's team lineup page: 2, 3, 4 and 5-man combinations per team, the regular-season 2-man table of the Celtics read for pair-row design
---
# Basketball-Reference 2024-25 Celtics lineups (2-man combinations)

Why: the outside-League model of a pair table (two named players, minutes together, net rating relative to the team).

## Assessment

- Evidence: A. Basketball-Reference is the canonical public basketball stats reference, years of use.
- Reasoning: fair. A static table with no explanation text beside it.
- Interests: ads; none on the numbers.
- Weigh: the cell design transfers, the stats do not: basketball pairs share a court for minutes, LoL duos share a game.

## Findings

- [ux/features] A pair row is two linked player names, minutes together, then stats shown as a difference from the team: the header over the stat columns reads "Net (Per 100 Poss)" and values are signed (+9.8, -1.3). The pair's gain is the whole table, with no raw-level columns. ^f1
  > | 1 | J. Tatum | D. White | 1776:40 | +9.8 | +1.1 | -1.3 |
- [ux/features] Order is by minutes together, descending (1776:40, 1648:52, 1423:28, ...), not by net rating; the best net rating (+15.2, Kornet and Tatum, rank 16, 885:12) sits mid-table. Sample size is the sort, so the top rows are always the well-measured ones. ^f2
  > | 16 | L. Kornet | J. Tatum | 885:12 | +15.2 |
- [ux/uncertainty] Thin pairs are cut by showing only the top 20 by minutes; the table ends at 816:38 minutes, with no flag on rows and no interval. ^f3
  > | 20 | K. Porziņģis | J. Tatum | 816:38 | +1.6 |
- [ux/density] A last row, Team Average, gives the baseline the signed numbers are measured against, with the team's total minutes (3968:24), so a reader can see what 0 means. ^f4
  > Team Average | 3968:24
- [ux/layout] The page gives 5, 4, 3 and 2-man combinations as separate tables for regular season and playoffs, with an in-page contents list ("Regular Season: 2-Man Combinations"). Pair size is a section, not a filter. ^f5
  > Regular Season: 2-Man Combinations
- [ux/controls] Each player name links to that player's page, so switching partner is by going to the player and reading their own list; the team page has no partner picker. ^f6
- [ux/features] Checked, not there: no per-player solo numbers in the pair row, no page for a single pair, no thin-pair marker, no confidence interval. ^f7

## Read

- `raw/bbref-celtics-lineups.md`: 2-Man Combinations (regular season) table in full, contents list.

## Not read

- The 3, 4 and 5-man tables, playoffs, the On/Off page.
- NBA.com and pbpstats pair pages: JS apps; pbpstats lists "WOWY" and "wowy-combos" ("Gets efficiency for all on/off combinations for selected players") but needs a query form.
