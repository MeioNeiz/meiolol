---
title: League client queues.json via CommunityDragon
url: https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/queues.json
kind: dataset
commit:
for: [match-v5-queues]
looked: 2026-10-11
depth: docs (whole file, 420 entries; names, categories, pick modes)
relevance: high
grade: B/weak
description: The live client's own queue table (rcp-be-lol-game-data), mirrored by CommunityDragon; fuller and faster than Riot's static queues.json
---
# League client queues.json via CommunityDragon

Why: Riot's static queues.json lags new modes; a developer-relations commenter pointed to
this file as "the json the client relies on" (#1114, skipped in the ledger).

## Assessment

- Evidence: B. Extracted from the live client by CommunityDragon (community project, not
  Riot), `latest` path, so it tracks the current patch. Lists every queue the client knows,
  including internal, PBE and test ones, with no statement of what match-v5 serves.
- Reasoning: weak. Data only.
- Interests: none.
- Weigh: use to name ids that appear in match-v5 but not in Riot's list (1750). Not
  evidence that any queue is served by the API.

## Findings

- [queues] Arena has more ids than Riot's list: 1700 Arena, 1710 Arena, 1750 Arena 3x6
  (the 18-player 3v3 Arena that match-v5 returns, see match-v5-queues-measured). `raw/cdragon-queues-json.md` ^f1
  > "id":1750,"name":"Arena 3x6"
- [queues] ARAM: Mayhem has several ids: 2400 (main), 2401, 2403, 2405, 2410 (Tournament)
  and 2450 Classic-ish, a limited-time queue. ^f2
  > "id":2400,"name":"ARAM: Mayhem","shortName":"ARAM: Mayhem","description":"ARAM: Mayhem"
  > "id":2450,"name":"ARAM: Mayhem Classic-ish"
- [queues] Custom lobbies now have their own queue ids (3100-3280: Summoner's Rift blind,
  draft and tournament draft customs, Howling Abyss customs, ARAM: Mayhem customs), so a
  custom match may not carry queueId 0. ^f3
  > "id":3110,"name":"SR Draft Pick Custom"
  > "id":3270,"name":"ARAM: Mayhem","shortName":"ARAM: Mayhem","description":"ARAM: Mayhem","detailedDescription":"ARAM: Mayhem","gameSelectModeGroup":"kAlternativeLeagueGameModes","gameSelectCategory":"kCustom"
- [queues] Doom Bots have ids 4200-4262 (absent from Riot's queues.json). ^f4
  > "id":4210,"name":"Doom Bots"
- [queues] Client names: 480 Swiftplay, 490 Quickplay. ^f5
  > "id":490,"name":"Quickplay"
  > "id":480,"name":"Swiftplay"
- [queues] (inferred) The file has no gameMode field, so the match-v5 gameMode string per
  queue (CHERRY for Arena, etc.) must come from responses or riotapi-schema-enums. ^f6

## Read

- id, name, gameSelectCategory, pickMode, isLimitedTimeQueue for all entries

## Not read

- viableChampionRoster and other client-only fields
