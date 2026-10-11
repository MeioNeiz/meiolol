---
title: Riot static gameModes.json (game constants)
url: https://static.developer.riotgames.com/docs/lol/gameModes.json
kind: dataset
commit:
for: [match-v5-queues]
looked: 2026-10-11
depth: docs (whole file, 22 entries)
relevance: medium
grade: A/weak
description: Riot's official list of the gameMode strings found in match-v5 info.gameMode
---
# Riot static gameModes.json (game constants)

Why: match-v5 carries both `queueId` and `gameMode`; which strings to expect per mode.

## Assessment

- Evidence: A for what it lists (Riot's own constants file), but incomplete.
- Reasoning: weak. Bare list.
- Interests: none.
- Weigh: use queueId as the key; treat gameMode as a coarse family. Missing strings come
  from riotapi-schema-enums and real responses.

## Findings

- [queues] Summoner's Rift normals and ranked share gameMode CLASSIC; ARAM is ARAM; URF and
  One for All have their own. `raw/riot-gamemodes-json.md` ^f1
  > "gameMode": "CLASSIC", "description": "Classic Summoner's Rift and Twisted Treeline games"
  > "gameMode": "ARAM", "description": "ARAM games"
- [queues] Swiftplay has its own gameMode SWIFTPLAY; Brawl is BRAWL. ^f2
  > "gameMode": "SWIFTPLAY", "description": "Swiftplay Games"
- [queues] Checked, not there: CHERRY (Arena, returned by match-v5 for queues 1700 and 1750
  in our probe), STRAWBERRY (Swarm) and anything for ARAM: Mayhem. ^f3

## Read

- Whole file
