---
title: 'Riot Games DevRel on X: Spectator-v5 off, Match-v5 unaffected by anonymous modes (2025-10-17)'
url: https://x.com/RiotGamesDevRel/status/1979263978787246391
kind: thread
commit:
for: [streamer-mode-names]
looked: 2026-10-20
depth: docs (post and Riot's follow-up reply, logged-out X)
relevance: high
grade: A/weak
description: Riot DevRel's announcement to API developers: Spectator-v5 switched off over streamer mode, Match-v5 and leaderboards not affected; getCurrentGameInfoByPuuid back on 20 Oct
---
# Riot Games DevRel on X: Spectator-v5 off, Match-v5 unaffected (2025-10-17)

Why: whether streamer mode reaches post-game match-v5 (and so lookup sites' match
history) or only live data.

## Assessment

- Evidence: A. Riot's official developer relations account, the channel it uses for API
  changes; 17 Oct 2025, 339.4k views. Read logged out through real Chrome.
- Reasoning: weak. Announcement, gives the reason (de-anonymising) but no detail.
- Interests: Riot.
- Weigh: the clearest primary statement that match-v5 is out of scope; a year old, so
  check against a live match-v5 response (our own Riot API call on 20 Oct, not snapshotted).

## Findings

- [policy] [privacy] Riot switched off Spectator-v5 for LoL, with the anonymity
  additions, to stop third-party apps de-anonymising players. ^f1
  > We will be deactivating the Spectator-V5 API for League of Legends to prevent third party applications from deanonymizing players.
- [policy] [privacy] The anonymous modes do not affect post-match APIs such as Match-v5
  or leaderboards. ^f2
  > However, the new anonymous modes will not have any impact on post-match APIs such as Match-V5 or leaderboards.
- [policy] Three days later (20 Oct 2025) getCurrentGameInfoByPuuid came back, "working as
  intended" with streamer mode. ^f3
  > We are reactivating the getCurrentGameInfoByPuuid endpoint from the Spectator API. This endpoint is now working as intended with the release of the streamer mode feature.
- [privacy] (inferred) So a post-game page that shows all ten Riot IDs from match-v5
  is not something Riot's anonymity change targets; Riot's line is drawn at live data. ^f4

## Read

- the post and the replies shown logged out

## Not read

- replies behind the X login
