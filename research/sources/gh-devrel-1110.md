---
title: 'developer-relations #1110: getCurrentGameInfoByPuuid and streamer mode (2025-10-25)'
url: https://api.github.com/repos/RiotGames/developer-relations/issues/1110
kind: thread
commit:
for: [streamer-mode-names]
looked: 2026-10-20
depth: listed (issue, no comments)
relevance: low
grade: C/weak
description: Developer asks what "live games respect streamer mode" means for the spectator endpoint; open, no Riot answer a year on
---
# developer-relations #1110: getCurrentGameInfoByPuuid and streamer mode

Why: any Riot developer answer on what spectator returns for streamer-mode players.

## Assessment

- Evidence: C. One developer's question, open since 25 Oct 2025, no comments.
- Reasoning: weak. Guesses, not tested.
- Interests: none known.
- Weigh: shows Riot never documented the spectator behaviour in the developer
  channel; our own call answers the guess (our own Riot API call on 20 Oct, not snapshotted).

## Findings

- [policy] Quotes the League tweet ([[league-tweet-streamer-mode-spectate#^f3]]) and asks
  what "respect streamer mode" means for the spectator endpoint. ^f1
  > What does live game capability update respecting streamer mode here mean?
- [privacy] Developer's guess: streamer-mode players in a returned match are zeroed out,
  no name or identifier. ^f2
  > anyone in the match with streamer mode enabled will be zeroed out and not have any name or identifier
- [policy] Checked, not there: no Riot reply; the issue has no comments and is open. ^f3

## Read

- issue body (no comments exist)
