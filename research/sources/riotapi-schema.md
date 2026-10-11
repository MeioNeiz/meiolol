---
title: 'riotapi-schema: OpenAPI spec of the Riot Games API'
url: https://github.com/MingweiSamuel/riotapi-schema
kind: spec
commit: b5a159ab1d65e8e400eaaa1184d4179d877ee29f
for: [riot-api-data-depth, identity-and-privacy]
looked: 2026-10-11
depth: code (gh-pages openapi-3.0.0.yml, match-v5, mastery, challenges, spectator, clash, league-exp)
relevance: high
grade: B/fair
description: OpenAPI 3 spec generated daily from Riot's API reference; field-level view of every LoL endpoint
---
# riotapi-schema: OpenAPI spec of the Riot Games API

Why: field-level inventory of what the API returns beyond match summaries (timeline, mastery,
challenges, spectator, clash, league-exp), without scraping Riot's JS reference pages.

## Assessment

- Evidence: B. Scraped daily from developer.riotgames.com reference by the Riven maintainer;
  repo since 2017-10, 57 stars, 9 contributors, gh-pages build 2026-10-06. Used to generate
  Riven and other clients. Field names are Riot's; types and "required" are partly hand
  patched (README lists hacks for Riot's missing or wrong DTOs).
- Reasoning: fair. A spec, no reasoning; descriptions are Riot's terse ones.
- Interests: none known.
- Weigh: trust field and endpoint existence; verify which fields are actually populated
  with a real response (see riot-timeline-measured).

## Findings

- [data] Timeline is its own endpoint per match, `/lol/match/v5/matches/{matchId}/timeline`
  (so one extra call per match on top of the summary). `openapi-3.0.0.yml` ^f1
  > summary: 'Get a match timeline by match id'
- [data] Timeline info has a `frameInterval` and a list of frames; each frame holds
  `events`, `participantFrames` keyed by participant id, and a `timestamp`. ^f2
  > match-v5.FramesTimeLineDto:
  > participantFrames:
- [data] Each participant frame carries gold (current, total, per second), xp, level, lane
  and jungle CS, map position, time spent CC'ing enemies, plus full championStats and
  damageStats snapshots. ^f3
  > match-v5.ParticipantFrameDto:
  > timeEnemySpentControlled:
  > jungleMinionsKilled:
- [data] championStats per frame includes armour, MR, AD, AP, ability haste, health and
  max health, move speed, penetration and vamp stats; damageStats splits physical, magic
  and true damage done, done to champions, and taken. ^f4
  > match-v5.ChampionStatsDto:
  > physicalDamageDoneToChampions:
- [data] Events are one generic DTO with a `type` string and optional fields for items
  (itemId, afterId/beforeId), skills (skillSlot, levelUpType), wards (wardType, creatorId),
  kills (killerId, victimId, assistingParticipantIds, bounty, shutdownBounty, position,
  victimDamageDealt/Received), buildings (buildingType, towerType, laneType) and monsters
  (monsterType, monsterSubType). The type enum itself is not in the spec. ^f5
  > match-v5.EventsTimeLineDto:
  > victimDamageReceived:
- [data] Newer event fields exist for Feats of Warfare and teamfight damage. ^f6
  > victimTeamfightDamageDealt:
- [data] The match summary already carries Riot-computed lane-phase comparisons in each
  participant's `challenges` block: early laning gold/xp advantage, max CS advantage on
  lane opponent, max level lead, lane minions in first 10 minutes, jungle CS before 10,
  vision score advantage, plus the role picked in champ select. ^f7
  > earlyLaningPhaseGoldExpAdvantage:
  > maxCsAdvantageOnLaneOpponent:
  > laneMinionsFirst10Minutes:
  > playedChampSelectPosition:
- [data] A `/replays` endpoint by puuid returns a count and a list of match file URLs. ^f8
  > summary: 'Get player replays'
  > description: 'Total of replay files'
- [data] RSO match endpoints (needs player login, so production key) list a player's
  matches including custom games, and serve their timelines. ^f9
  > summary: 'Get a list of match ids by player access token - Includes custom matches'
  > '/lol/rso-match/v1/matches/{matchId}/timeline':
- [data] [fun] champion-mastery-v4 returns every champion's mastery for a player, sorted
  by points, with level, points and last play time; a total score endpoint sums levels. ^f10
  > summary: 'Get all champion mastery entries sorted by number of champion points descending.'
  > description: 'Last time this champion was played by this player - in Unix milliseconds time format.'
- [data] [fun] lol-challenges-v1 serves challenge config, per-level percentiles of players,
  top-player leaderboards (Master+ levels only) and per-player progress. ^f11
  > keys: ChallengeId -> Season -> Level -> percentile of players who achieved it
  > Return top players for each level. Level must be MASTER, GRANDMASTER or CHALLENGER.
  > summary: 'Returns player information with list of all progressed challenges (REST)'
- [data] spectator-v5 gives the live game for a puuid (champions, bans, runes, spells,
  game length); anonymous players come back with a null puuid. ^f12
  > summary: 'Get current game information for the given puuid.'
  > description: 'The encrypted puuid of this participant. null when the player is anonym.'
- [data] Checked, not there: no featured-games endpoint in spectator-v5 in this spec. ^f13
- [data] clash-v1 player entries give team, position (TOP..UTILITY, FILL) and role. ^f14
  > description: '(Legal values:  UNSELECTED,  FILL,  TOP,  JUNGLE,  MIDDLE,  BOTTOM,  UTILITY)'
- [data] league-exp-v4 entries take tier and division like league-v4 but its tier enum
  also includes Master to Challenger, so one paged endpoint covers the whole ladder. `/lol/league-exp/v4/entries/{queue}/{tier}/{division}` ^f15
  > summary: 'Get all the league entries.'
- [data] Checked, not there: no rate limits in the spec; method limits come only from
  response headers (see riot-timeline-measured). ^f16

- [privacy] [data] Checked, not there: no third-party-code path (summoner ownership
  check) in this spec; summoner-v4 and account-v1 only offer lookups plus RSO `/me`. ^f17
- [privacy] [data] summoner-v4 returns profileIconId, and revisionDate changes on an
  icon change, so an app can see when a player sets a given icon. ^f18
  > description: 'ID of the summoner icon associated with the summoner.'
  > The following events will update this timestamp: profile icon change, playing the tutorial or advanced tutorial, finishing a game, summoner name change.
- [privacy] [data] account-v1 resolves any Riot ID (game name plus tag line) to an
  account, with no player consent step. `/riot/account/v1/accounts/by-riot-id/{gameName}/{tagLine}` ^f19
  > summary: 'Get account by riot id'

## Read

- `openapi-3.0.0.yml`: paths for match-v5, rso-match, mastery, challenges, spectator,
  clash, league-exp; schemas for TimelineDto, frames, events, ChallengesDto field list

## Not read

- `ParticipantPlayerBehaviorDto` (PlayerBehavior_IsHeroInCombat etc.): looks new, unclear
  where it appears; may be worth a look
- Event `type` values: not enumerated in the spec; taken from a real response instead
