---
title: '/dev: State of Ranked (Riot SapMagic, 2019-03)'
url: https://web.archive.org/web/2019/https://nexus.leagueoflegends.com/en-us/2019/03/dev-state-of-ranked/
kind: docs
commit:
for: [pregame-player-skill]
looked: 2026-10-13
depth: docs (whole post, archived copy)
relevance: medium
grade: B/fair
description: Riot ends visible position ranks (satisfaction down 20-30%) but keeps positional matchmaking, which raised off-position win rates; partial Diamond+ reset after rank bugs
---
# /dev: State of Ranked (Riot SapMagic, 2019-03)

Why: what happened to per-position ratings in LoL after the 2019 trial.

## Assessment

- Evidence: B. First-hand from Riot's Ranked lead, with one survey number; the win-rate
  claim has no figure.
- Reasoning: fair. Separates the visible ranks (dropped) from the matchmaking use of
  position (kept).
- Interests: Riot explaining a rollback.
- Weigh: trust that Riot found position-aware matchmaking worth keeping; no effect size.

## Findings

- [method] Positional matchmaking (position-aware MMR, not visible position ranks)
  stayed: queue times improved and off-position win rates rose. ^f1
  > On the matchmaking side, we're happy with how positional matchmaking—not to be confused with position **ranks**—is working.
  > Queue times have improved for many players and off-position win rates have gone up.
- [method] Visible position ranks were withdrawn after satisfaction fell 20 to 30%. ^f2
  > Since position ranks launched, we've seen a dramatic negative shift—by 20 to 30%—in satisfaction with the feature in both North America and Korea.
- [method] Riot considered keeping positional matchmaking to make off-position games
  fairer without position ranks. ^f3
  > We're also looking into keeping positional matchmaking, which would make off-position games more fair even **_without_** position ranks.
- [data] Rank bugs: up to 155 players on one server reached Grandmaster with under 40%
  win rate; visible rank can mislead about skill for a while after such events. ^f4
  > up to 155 on one server—to get to Grandmaster despite having a win rate below 40%.
- [method] (inferred) "Off-position win rates have gone up" once matchmaking used
  position skill means off-role players lost more than 50% before: an off-role
  penalty exists and is large enough for Riot to act on. If matchmaking now absorbs
  part of it, the residual our model can find is smaller, but autofilled and off-role
  slots should still be a feature (role share in the player's history). ^f5

## Read

- Whole post (archived 2019-10 copy)

## Not read

- The boards "Ranked 2019 dev update 3" recap it links
