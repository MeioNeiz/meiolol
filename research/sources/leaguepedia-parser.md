---
title: mrtolkien/leaguepedia_parser
url: https://github.com/mrtolkien/leaguepedia_parser
kind: project
commit: c23d6c8974239dd11e39df26bc015ad5c4b89a95
for: [leaguepedia-daily-fetch]
looked: 2026-10-26
depth: code (transmuters/, site/)
relevance: medium
grade: B/fair
description: Python wrapper for Leaguepedia's Cargo API (MIT, 75 stars, last push Nov 2023) linked from the API help page; draft-order field list, paging
---
# mrtolkien/leaguepedia_parser

Why: how do existing clients turn Cargo rows into a draft, and do they pace or page?

## Assessment

- Evidence: B. Linked from Leaguepedia's own API page; MIT, created Mar 2020, 75 stars, 23 forks, v2.0.2 (Jun 2023), last push Nov 2023.
- Reasoning: fair.
- Interests: none.
- Weigh: the draft order is a useful map; its blue/red assumption ignores SwitchedSides.

## Findings

- [data] [draft] Draft order of the 20 PicksAndBansS7 cells (pro play since June 2020): B1 R1 B2 R2 B3 R3 bans, B1 R1 R2 B2 B3 R3 picks, R4 B4 R5 B5 bans, R4 B4 B5 R5 picks. `leaguepedia_parser/transmuters/field_names.py` ^f1
  > # Ordered in the draft order for pro play as of June 2020
- [data] It maps Team1 to BLUE and SG Winner 1 to blue. `transmuters/picks_bans.py`, `transmuters/game.py` ^f2
  > team="BLUE" if "Team1" in field else "RED",
  > winner="BLUE" if source_dict["Winner"] == "1" else "RED",
- [data] (inferred) Right for ScoreboardGames, wrong for PicksAndBansS7 games with SwitchedSides=1 ([[leaguepedia-cargo-tests#^f4]]): swap Team1/Team2 cells before applying the order. ^f3
- [data] Pages with limit=500 and offset until a short page; no delay of its own. `leaguepedia_parser/site/leaguepedia.py` ^f4
  > def __init__(self, limit=500):

## Read

- `raw/leaguepedia-parser/`: field_names.py, picks_bans.py, game.py, leaguepedia.py.

## Not read

- Tests, team parser.
