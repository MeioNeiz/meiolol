---
title: 'League of Legends on X: streamer mode and third-party spectate, live games and featured games (2025-10-21)'
url: https://x.com/LeagueOfLegends/status/1980434309736771638
kind: thread
commit:
for: [streamer-mode-names]
looked: 2026-10-20
depth: docs (post and the one before it, logged-out X)
relevance: high
grade: A/weak
description: League's official account on streamer mode: client spectate hides streamer-mode players, third-party live spectate and featured games to be disabled, live game lookups respect streamer mode
---
# League of Legends on X: streamer mode and third-party spectate (2025-10-21)

Why: what Riot told players third-party live game pages would do with streamer mode.

## Assessment

- Evidence: A. Official @LeagueOfLegends, 21 Oct 2025, 104.1k views.
- Reasoning: weak. Announcement.
- Interests: Riot.
- Weigh: states intent; "featured games capabilities will also be disabled" but
  Porofessor still shows featured live games a year later
  ([[porofessor-featured-live-2026-10-20#^f1]]), so the Riot featured-games endpoint is
  meant, not sites' own lists. The "new endpoint" for replays not checked.

## Findings

- [policy] Spectate in the League client hides streamer-mode players' information. ^f1
  > Spectating in the League client will continue to function as it does today and will hide information for players that have streamer mode on.
- [policy] [tools] Third-party live spectate to be disabled and replaced by replay file
  access in the match API; featured games capability disabled too. ^f2
  > Live spectate options on 3rd party sites will be disabled and replaced with enhanced access to replays files via a new endpoint that will be made available in Riot API’s match endpoint. Featured games capabilities will also be disabled.
- [policy] [privacy] Third-party live game lookups keep working but results respect each
  player's streamer mode. ^f3
  > Live games capabilities on 3rd party sites will continue to function but returned results will respect players’ streamer mode settings.
- [policy] The day before, the whole Spectator API including getCurrentGameInfoByPuuid
  was re-enabled, with time for third-party sites to adjust. ^f4
  > We’ve just reenabled the entire Spectator API (including the getCurrentGameInfoByPuuid endpoint) so now everyone should be able to access live game data again.

## Read

- the post and the thread post above it

## Not read

- replies behind the X login
