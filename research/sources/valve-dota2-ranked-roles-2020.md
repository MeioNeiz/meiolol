---
title: Ranked Roles Update (Valve, Dota 2 blog, 2020-03)
url: https://web.archive.org/web/2020/http://blog.dota2.com/2020/03/ranked-roles-update/
kind: docs
commit:
for: [pregame-player-skill]
looked: 2026-10-13
depth: docs (whole post, archived copy)
relevance: medium
grade: B/fair
description: Valve replaces separate Core and Support MMRs with one MMR plus a handicap per role (five roles), seeded from the old MMRs and the last 100 games; every game updates the single MMR
---
# Ranked Roles Update (Valve, Dota 2 blog, 2020-03)

Why: how a shipped MOBA handles per-role skill: separate ratings or one plus offsets.

## Assessment

- Evidence: B. Official Valve announcement for a system in use since March 2020, after
  trying split Core/Support MMRs from 2019. Short; no numbers or method details.
- Reasoning: fair. States the structure, not why separate ratings failed.
- Interests: Valve's own product.
- Weigh: trust the design choice (two separate ratings replaced by one plus offsets);
  how the handicaps are estimated is not said.

## Findings

- [method] Dota 2 moved from separate Core and Support MMRs to one rank with a
  handicap per role (five roles) for relative strength in each position. ^f1
  > Today's update features a change to the rank system that replaces the Core/Support separation with a single rank that uses handicaps for each of the five ranked roles, representing your relative strength playing each position.
- [method] Queueing a weaker role places the player at a lower effective MMR; every
  game, in any role, updates the single MMR. ^f2
  > Queuing for your weaker role(s), however, will result in the matchmaker placing you into a match at a lower MMR.
  > Regardless of which role you queue for and play, the results of the match will affect your actual MMR value.
- [method] Role handicaps were seeded from the old Core/Support MMRs plus analysis of
  the last 100 games. ^f3
  > Your initial levels for each role are calculated based on your previous Core/Support MMR values and analysis of your past 100 games.
- [method] (inferred) Valve and Riot ([[riot-dev-ranked-2019-positions#^f1]]) both
  ended at one skill plus a per-role adjustment, the TrueSkill2 base-plus-offset form
  ([[trueskill2-2018#^f11]]). Valve tried separate ratings and moved away; Riot
  linked its per-position MMRs from the start. For us: one player term plus role and
  champion offsets, not independent per-champion ratings. ^f4

## Read

- Whole post (archived 2021-01 copy)

## Not read

- The 2019 Core/Support experimental update post
