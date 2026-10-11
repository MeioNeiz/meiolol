---
title: Riot static queues.json (game constants)
url: https://static.developer.riotgames.com/docs/lol/queues.json
kind: dataset
commit:
for: [match-v5-queues]
looked: 2026-10-11
depth: docs (whole file, 121 entries)
relevance: high
grade: A/weak
description: Riot's official list of LoL queue ids (id, map, description, notes) that the developer docs' Game Constants page points to
---
# Riot static queues.json (game constants)

Why: the authoritative id-to-mode mapping the docs name for `queueId` in match-v5.

## Assessment

- Evidence: A for the ids it lists: Riot's own file, linked from the Game Constants section
  of developer.riotgames.com/docs/lol. But it lags: entries are added by hand after
  developers file issues (Swiftplay and Mayhem added 2025-12-26, see
  match-v5-queues-measured and gh-devrel-1109), and Arena 3v3 (1750) is still missing.
- Reasoning: weak. Bare list; no field says whether match-v5 serves a queue.
- Interests: none.
- Weigh: trust listed ids; check missing ones against the client's own list
  (cdragon-queues-json) and riotapi-schema-enums.

## Findings

- [queues] Core Summoner's Rift queues: 400 draft, 420 ranked solo, 430 blind, 440 ranked
  flex. `raw/riot-queues-json.md` ^f1
  > "queueId": 400, "map": "Summoner's Rift", "description": "5v5 Draft Pick games"
  > "queueId": 420, "map": "Summoner's Rift", "description": "5v5 Ranked Solo games"
  > "queueId": 440, "map": "Summoner's Rift", "description": "5v5 Ranked Flex games"
- [queues] Swiftplay is 480 and Quickplay 490. ^f2
  > "queueId": 480, "map": "Summoner's Rift", "description": "Swiftplay Games"
  > "queueId": 490, "map": "Summoner's Rift", "description": "Normal (Quickplay)"
- [queues] ARAM is 450 on Howling Abyss; ARAM: Mayhem is 2400 on the same map. ^f3
  > "queueId": 450, "map": "Howling Abyss", "description": "5v5 ARAM games"
  > "queueId": 2400, "map": "Howling Abyss", "description": "ARAM: Mayhem"
- [queues] Arena (Rings of Wrath) is listed twice, 1700 and 1710 (16 player lobby). ^f4
  > "queueId": 1700, "map": "Rings of Wrath", "description": "Arena"
  > "notes": "16 player lobby"
- [queues] Rotating modes keep fixed ids: 900 ARURF, 1900 Pick URF, 1020 One for All, 1300
  Nexus Blitz, 1400 Ultimate Spellbook, 2300 Brawl, 1810-1840 Swarm. ^f5
  > "queueId": 900, "map": "Summoner's Rift", "description": "ARURF games"
  > "queueId": 1020, "map": "Summoner's Rift", "description": "One for All games"
  > "queueId": 1300, "map": "Nexus Blitz", "description": "Nexus Blitz games"
  > "queueId": 2300, "map": "The Bandlewood", "description": "Brawl"
- [queues] Custom games are queue 0; Clash 700 (Summoner's Rift) and 720 (ARAM). ^f6
  > "queueId": 0, "map": "Custom games"
  > "queueId": 720, "map": "Howling Abyss", "description": "ARAM Clash games"
- [queues] Checked, not there: no 1750 (Arena 3v3, served by match-v5 per our probe), no
  Doom Bots 4200-4262, no Mayhem variants 2401-2450, no custom-lobby ids 3100-3280 (all in
  the client's own list). No field marks a queue as private or not served by match-v5. ^f7

## Read

- Whole file

## Not read

- seasons.json, maps.json, gameTypes.json: not needed for the queue question
