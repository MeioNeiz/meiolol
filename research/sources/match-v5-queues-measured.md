---
title: Measured match-v5 per-queue lists, summaries and timelines (EUW, 2026-10-11)
url: https://europe.api.riotgames.com/lol/match/v5/matches/by-puuid/
kind: dataset
commit:
for: [match-v5-queues]
looked: 2026-10-11
depth: ran (188 GETs, personal key, europe routing; lists per queue, one summary and timeline per found queue)
relevance: high
grade: B/strong
description: Our own probe of which queue ids match-v5 lists and serves with timelines, and how Arena and ARAM summaries differ
---
# Measured match-v5 per-queue lists, summaries and timelines (EUW, 2026-10-11)

Why: the docs and enums say which queue ids exist, not which ones match-v5 actually serves
today, nor whether each has a timeline. Probed directly.

Method: puuids from the euw1 challenger league plus participants of one ARAM and one Arena
match (15 players in all). `by-puuid/{puuid}/ids?queue=Q&count=3` per queue until a hit,
then the first match's summary and timeline. Script in session scratch; raw table in
`raw/match-v5-queues-measured.txt` (puuids truncated, no key).

## Assessment

- Evidence: B. First-hand, real responses, but a small and skewed player sample (challenger
  players and their ARAM/Arena team-mates, EUW only). A hit proves a queue is served; an
  empty list proves little on its own (the players may not play that mode).
- Reasoning: strong. Every status code recorded; positives and empties kept apart.
- Interests: ours.
- Weigh: trust the 200s and the field differences. Treat the empty queues (430, 480, 490,
  1710, 1900, 2300, 2400, 0) as "not seen", not "not served", unless another source says so.

## Findings

- [queues] [data] Ranked solo 420, flex 440 and normal draft 400 are listed and served with
  timelines, gameMode CLASSIC on map 11, one frame per minute. `raw/match-v5-queues-measured.txt` ^f1
  > 420 | 200 | EUW1_8005330559 | 200 | 420 | CLASSIC | 11 | 16.19.823.722 | 10 | 1 | 200 | 20 | 60000
  > 400 | 200,200,200 | EUW1_7715593124 | 200 | 400 | CLASSIC | 11 | 16.2.741.3171 | 10 | 1 | 200 | 34 | 60000
- [queues] [data] ARAM 450 is listed and served with a timeline (gameMode ARAM, map 12), and
  an ARAM player's last 8 games (all queue 450, patch 16.20) all returned 200. ^f2
  > 450 | 200 | EUW1_7845926532 | 200 | 450 | ARAM | 12 | 16.9.772.8292 | 10 | 1 | 200 | 10 | 60000
  > EUW1_8009957362 200 queue 450 16.20.824.8524
- [queues] [data] Arena is served with timelines under gameMode CHERRY on map 30, in two
  shapes: queue 1700 with 16 players in 8 subteams (2v2 x8) and queue 1750 with 18 players
  in 6 subteams (3v3 x6). ^f3
  > 1700 | 200 | EUW1_7842540522 | 200 | 1700 | CHERRY | 30 | 16.9.772.1032 | 16 | 8 | 200 | 27 | 60000
  > 1750 | 200 | EUW1_7862069785 | 200 | 1750 | CHERRY | 30 | 16.10.776.5552 | 18 | 6 | 200 | 26 | 60000
- [queues] [data] Arena summaries fill placement, playerSubteamId, subteamPlacement and
  playerAugment1-6 per participant, and teamPosition is empty; on Summoner's Rift and ARAM
  those are all 0 and win is the outcome. ^f4
  > 1750 EUW1_7862069785: placement 2, subteamId/subteamPlacement [6, 2], augments [89, 234, 195, 340, 364, 82], teamPosition '', win True
  > 420 EUW1_8005330559: placement 0, subteamId/subteamPlacement [0, 0], augments [0, 0, 0, 0, 0, 0], teamPosition 'TOP', win False
- [queues] [data] ARAM summaries have empty teamPosition and an empty gameModeMutators
  list (absent on Summoner's Rift games). ^f5
  > 450 EUW1_7845926532: placement 0, subteamId/subteamPlacement [0, 0], augments [0, 0, 0, 0, 0, 0], teamPosition '', win False, gameModeMutators []
- [queues] [data] Arena and ARAM timelines have no building, dragon, plate or bounty events:
  only kills, items, levels, skills, wards. Summoner's Rift adds BUILDING_KILL,
  ELITE_MONSTER_KILL, TURRET_PLATE_DESTROYED, DRAGON_SOUL_GIVEN and OBJECTIVE_BOUNTY_*. ^f6
  > timeline event types: CHAMPION_KILL CHAMPION_SPECIAL_KILL GAME_END ITEM_DESTROYED ITEM_PURCHASED ITEM_SOLD ITEM_UNDO LEVEL_UP PAUSE_END SKILL_LEVEL_UP WARD_KILL WARD_PLACED
- [queues] [data] Rotating and event queues are served with timelines when found: ARURF
  900 (gameMode URF), Clash 700 (CLASSIC) and ARAM Clash 720 (ARAM). ^f7
  > 900 | 200,200,200 | EUW1_7759739899 | 200 | 900 | URF | 11 | 16.4.748.682 | 10 | 1 | 200 | 13 | 60000
  > 720 | 200 | EUW1_7615166380 | 200 | 720 | ARAM | 12 | 15.23.728.3286 | 10 | 1 | 200 | 25 | 60000
- [queues] [data] ARAM Mayhem 2400 returned an empty id list for all 15 players, including
  8 from an ARAM game, while the same calls found 450 games. ^f8
  > queue 2400: lists 200/0 200/0 200/0 200/0 200/0 200/0 200/0 200/0; hit None
- [queues] [data] Swiftplay 480, Quickplay 490 and Blind 430 also returned empty lists for
  all 15 players; so did 1710, 1900, 1020, 1300, 1400, 1810, 2300 and custom 0. ^f9
  > queue 490: lists 200/0 200/0 200/0 200/0 200/0 200/0 200/0 200/0; hit None
  > 0 | 200,200,200,200,200,200,200 all empty
- [queues] [data] A January 2025 Swiftplay match (from developer-relations #1025) is still
  served with a timeline (queueId 480, gameMode SWIFTPLAY); the April 2025 Swiftplay match
  from #1068 and the Quickplay-with-bots match from #1020 return 404. ^f10
  > EUW1_7261321891 (Swiftplay 480, #1025): summary 200 queueId 480 gameMode SWIFTPLAY version 15.1.647.8644 timeline 200 frames 24
  > EUW1_7383662079 (Swiftplay, #1068): summary 404
- [queues] [data] Every list call returned 200 (an unserved queue gives an empty list, not
  an error), so a queue filter cannot distinguish "private" from "not played". ^f11
  > 200/0 means HTTP 200 with an empty list.
- [queues] (inferred) The empty 2400 lists fit developer-relations #1109 (Mayhem private),
  but with 15 players we cannot tell hidden from unplayed. ^f12

## Read

- All 188 responses' status codes; queueId, gameMode, mapId, version, participant and
  subteam counts, first participant's Arena fields, timeline frame count and event types

## Not read

- Custom-lobby queue ids 3100-3280, Doom Bots 4200-4262, Mayhem variants 2401-2450 (from
  the client's queues.json, cdragon-queues-json): not probed
- Other regions (americas, asia, sea): not probed
- A known current Mayhem match id: none found, so the 403 itself is not reproduced
