---
title: Riot Developer Portal VALORANT docs (policy, opt-in, RSO)
url: https://developer.riotgames.com/docs/valorant
kind: docs
commit:
for: [identity-and-privacy]
looked: 2026-10-11
depth: docs (policy, approved use cases, RSO sections)
relevance: medium
grade: A/fair
description: VALORANT developer policy: every app must use RSO opt-in before showing any player's stats; contrast with League's looser rules
---
# Riot Developer Portal VALORANT docs (policy, opt-in, RSO)

Why: how strict Riot is when it does require player opt-in, as a contrast to League and a
sign of where League policy could go.

## Assessment

- Evidence: A. Canonical Riot docs, snapshot 2026-10-11.
- Reasoning: fair. Lists, no rationale for opt-in beyond the rule.
- Interests: Riot.
- Weigh: VALORANT only. League docs carry no such opt-in rule except for custom games
  ([[riot-docs-lol#^f15]], [[riot-docs-lol#^f17]]). Shows the shape Riot uses for opt-in:
  RSO account linking plus a disclaimer that linking makes data public.

## Findings

- [privacy] [policy] VALORANT: every app must require player opt-in through RSO, plus a
  disclaimer that account linking makes player data public. ^f1
  > All apps must include functionality requiring a player to opt-in to sharing their data. This is done through RSO integration, as well as a disclaimer within your app that account linking makes player data public.
- [privacy] [policy] Players who have not opted in must not be shown to others on sites,
  apps or overlays. ^f2
  > If players have not opted into data sharing in their ecosystem, their information should not be made available to other players through their website, applications, or game overlays.
- [privacy] [policy] Opt-in needed even for training tools showing a player their own
  history, and for Discord bots with server-member stats. ^f3
  > Training tools that allow players to view their own match histories and aggregate stats.
  > Discord Bots showing community leaderboards, stats for server members.
- [privacy] [policy] No opt-in needed for aggregate stats without specific players or
  official ladder leaderboards. ^f4
  > Aggregate player stats without any specific players.
- [policy] VALORANT personal keys not supported; scouting opponents before a match not
  approved. ^f5
  > **Note:** Personal Key Applications are currently not supported.
  > Scouting, which is seeing an opponents stats before a match starts.
- [privacy] (inferred) Riot's opt-in model is RSO-based; a non-RSO opt-in (icon check) has
  no stated standing in any Riot doc read. For League the closest analogue is Squads: a
  group page of named players is the "stats for server members" case. ^f6

## Read

- policy, approved and unapproved use cases, RSO integration

## Not read

- API endpoint tables (VAL content, match, ranked)
