---
title: 'Measured: Riot IDs in 5,000 match-v5 summaries (EUW, 16.20, 2026-10-20)'
url: https://developer.riotgames.com/apis#match-v5/GET_getMatch
kind: dataset
commit:
for: [streamer-mode-names]
looked: 2026-10-20
depth: ran (5,000 newest riot_match docs in the box's raw.db, read-only)
relevance: high
grade: B/fair
description: Our check whether match-v5 summaries blank or flag streamer-mode players: none of 50,000 participants blank, no such field
---
# Measured: Riot IDs in 5,000 match-v5 summaries (EUW, 16.20, 2026-10-20)

Why: J18 wants streamer-mode players hidden on public pages; can match-v5 data tell us
who had streamer mode on in a game?

## Assessment

- Evidence: B. First-hand, 5,000 ranked solo games (queue 420, patch 16.20, EUW,
  Platinum IV+ crawl), 50,000 participants. Script appended to the raw file.
- Reasoning: fair. Absence of a flag in a large sample, plus the spec
  ([[riotapi-schema#^f21]]); cannot prove none of the players had streamer mode on.
- Interests: ours.
- Weigh: Platinum+ EUW in Oct 2026, where streamers play, so some of 50,000 players
  almost surely had streamer mode on; still no blank. Agrees with Riot support
  ([[riot-support-anonymizing-riot-id#^f2]]).

## Findings

- [privacy] [data] No participant in 5,000 recent ranked solo summaries has a blank Riot
  ID, PUUID or summoner name. ^f1
  > matches 5000 participants 50000
  > empty (name, puuid, summonerName): {}
- [privacy] [data] No participant field name contains anon, stream, hidden, privacy or
  hide (156 keys seen). ^f2
  > suspicious keys {}
  > participant keys 156
- [privacy] (inferred) match-v5 neither hides nor marks streamer-mode players, so a site
  built on post-game data cannot tell who had it on; only spectator-v5 (live games)
  does ([[riotapi-schema#^f21]]). ^f3

## Read

- 5,000 newest `riot_match` docs, all participants
