---
title: 'riotapi-schema enums: queues and game modes'
url: https://raw.githubusercontent.com/MingweiSamuel/riotapi-schema/gh-pages/enums/queues.json
kind: spec
commit: b5a159ab1d65e8e400eaaa1184d4179d877ee29f
origin: riotapi-schema
for: [match-v5-queues]
looked: 2026-10-11
depth: code (gh-pages enums/queues.json, enums/gameModes.json, missing.json; openapi-3.0.0.yml match-v5 and lol-rso-match-v1 paths)
relevance: high
grade: B/fair
description: Community-maintained queue and gameMode enums behind the Riven client, plus the match-v5 ids filter and RSO match endpoints from the same OpenAPI spec
---
# riotapi-schema enums: queues and game modes

Why: community libraries patch Riot's constants faster than Riot does; this is the source
for Riven's `Queue` and `GameMode` enums (Riven's generated `consts/queue.rs` matches it,
see ledger skip), and the spec gives the by-puuid filters.

## Assessment

- Evidence: B. Same maintainer and build as riotapi-schema (repo since 2017-10, 57 stars;
  gh-pages built 2026-10-06). The maintainer files the developer-relations issues that get
  Riot's files fixed (#1025). Enum entries merge Riot's file with hand additions.
- Reasoning: fair. Spec, no prose.
- Interests: none.
- Weigh: newer than Riot's list for gameMode strings (CHERRY, STRAWBERRY); still lacks
  Arena 3v3 1750.

## Findings

- [queues] Arena queue 1700 is the 2v2v2v2 `CHERRY` game; gameMode CHERRY is Arena and
  STRAWBERRY is Swarm, strings missing from Riot's gameModes.json. `enums/queues.json`, `enums/gameModes.json` ^f1
  > "description": "2v2v2v2 `CHERRY` games",
  > "gameMode": "CHERRY",
  > "description": "2v2v2v2 Arena",
  > "gameMode": "STRAWBERRY",
- [queues] ARAM: Mayhem is 2400 and Brawl 2300 here too. `enums/queues.json` ^f2
  > "x-name": "HOWLING_ABYSS_ARAM_MAYHEM"
- [queues] Checked, not there: no 1750 (Arena 3x6) and no Doom Bots or custom-lobby 3xxx
  ids. ^f3
- [queues] [data] The match-v5 by-puuid ids endpoint takes optional `queue` (one queue id)
  and `type` (ranked, normal, tourney, tutorial) filters that must both match. `openapi-3.0.0.yml` ^f4
  > Filter the list of match ids by a specific queue id. This filter is mutually inclusive of the type filter meaning any match ids returned must match both the queue and type filters.
- [queues] [data] Match info carries queueId, gameMode, gameType, mapId and a
  gameModeMutators string list. `openapi-3.0.0.yml` ^f5
  > gameModeMutators:
- [queues] [data] A separate RSO endpoint family, lol-rso-match-v1, lists a signed-in
  player's match ids including customs, with its own match and timeline endpoints. `openapi-3.0.0.yml` ^f6
  > summary: 'Get a list of match ids by player access token - Includes custom matches'
  > '/lol/rso-match/v1/matches/{matchId}/timeline':
- [queues] [data] Its DTOs are undocumented by Riot (listed as missing schemas). `missing.json` ^f7
  > "lol-rso-match-v1.MatchDto",
  > "lol-rso-match-v1.TimelineDto",

## Read

- enums/queues.json and enums/gameModes.json in full; missing.json; openapi match-v5 ids
  parameters and lol-rso-match-v1 paths

## Not read

- Riven's hand-written docs for the Queue enum; Cassiopeia and kayn (skipped)
