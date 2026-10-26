---
title: "Leaguepedia: Template:PicksAndBansS7 (entry rules)"
url: https://lol.fandom.com/wiki/Template:PicksAndBansS7
kind: docs
commit: 
for: [leaguepedia-daily-fetch]
looked: 2026-10-26
depth: docs (documentation section)
relevance: high
grade: A/fair
description: Editor docs for PicksAndBansS7: entered as blue/red in draft order, winner 1 = blue, switched_sides flag, special values
---
# Leaguepedia: Template:PicksAndBansS7 (entry rules)

Why: what do PicksAndBansS7's Team1/Team2, Winner and SwitchedSides mean?

## Assessment

- Evidence: A. The template that fills the table; editors follow it.
- Reasoning: fair.
- Interests: none.
- Weigh: input is blue/red; the stored Team1/Team2 columns follow the series team (see [[leaguepedia-cargo-tests]]).

## Findings

- [data] [draft] Editors enter bans and picks per side (blueban1, red_ban1, bluepick1, bluerole1...) in champion select order, before swaps. ^f1
  > In champion select order (i.e. before any swaps are made).
  > |blueban1=      |red\_ban1=
- [data] Template winner is 1 for blue, 2 for red. ^f2
  > If blue team wins, 1; if red team wins, 2.
- [data] Side switches within a series are flagged by switched_sides. ^f3
  > If teams switched sides, write `|switched_sides=yes`
- [data] Special values: Loss of Ban, Missing Data; noroles=yes when roles unknown (roles not guessed). ^f4
  > If a team loses a ban, write e.g. `|blue1ban=Loss of Ban`
  > If there is missing data, e.g. from the stream not showing the pick and ban phase, write `|bluepick1=Missing Data`
  > Just write `|noroles=yes`

## Read

- `raw/leaguepedia-pb-template.md`: documentation section.

## Not read

- Module:CargoDeclare/PicksAndBansS7 (how blue/red map to Team1/Team2 in storage).
