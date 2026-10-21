---
title: 'meiolol: is pick order recoverable from match-v5? (own check, 2026-10-21)'
url: https://europe.api.riotgames.com/lol/match/v5/matches/{matchId}
kind: dataset
commit: 3664821
for: [frontier-causal]
looked: 2026-10-21
depth: ran (two queries on data/snap, 87,766 ranked solo matches; schema and app parser excerpts)
relevance: high
grade: A/strong
description: Our own check that match-v5 carries no pick order (participants sorted by role, ban pickTurn is slot order) and that the LCU champ select session does
---
# meiolol: is pick order recoverable from match-v5? (own check, 2026-10-21)

Why: the brief says "no pick order in match-v5 (verify)"; counter-pick selection can
only be modelled if we know who picked after whom.

## Assessment

- Evidence: A. Direct queries over 175,532 team-sides of our local snapshot; schema from
  the community OpenAPI spec; LCU structure from the app's parser and mock scenarios.
- Reasoning: strong for match-v5 (exhaustive over fields we store); the LCU side is
  what the app reads today, not a new probe.
- Interests: none.
- Weigh: participant order could in principle carry cell order on some other queue;
  checked only for queue 420.

## Findings

- [data] [method/causal] Participant order in match-v5 is role order, not pick order:
  175,281 of 175,532 team-sides (99.86%) list TOP, JUNGLE, MIDDLE, BOTTOM, UTILITY in
  that order; the rest are the same order with a missing or odd position. ^f1
  > TOP,JUNGLE,MIDDLE,BOTTOM,UTILITY|175281
  > team-sides total: 175532
- [data] [method/causal] Ban pickTurn is a slot index, 1-5 for blue and 6-10 for red,
  not the time order of bans (bans are simultaneous anyway), and the schema gives it
  no meaning. ^f2
  > team 100: pickTurn min 1 max 5, bans 414943
  > team 200: pickTurn min 6 max 10, bans 415122
- [data] [method/causal] So no field in a stored ranked match reveals who picked first,
  whether a laner picked before or after their opponent, or any hovers, trades or
  dodges (a dodged lobby produces no match). ^f3
- [data] [method/causal] The LCU champ select session the app polls holds the actions
  as a list of turns, each with actor cell, champion, type and completion, for both
  teams: the real pick order is visible to the app for the user's own games. ^f4
  > actions: []const []const Action = &.{},
  > actorCellId: i64 = -1,
- [method/causal] (inferred) Pick order data can only come from app users who consent,
  a small, self-selected sample; enough to estimate a last-pick or counter-pick offset
  per role (a few parameters), not a pick-order-specific matchup table. ^f5

## Read

- Queries and excerpts in raw/meiolol-pick-order-check.txt.
