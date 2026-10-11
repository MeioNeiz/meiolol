---
title: 'developer-relations #1068: Swiftplay matches no longer returned'
url: https://api.github.com/repos/RiotGames/developer-relations/issues/1068
kind: thread
commit:
for: [match-v5-queues]
looked: 2026-10-11
depth: listed (issue and all 9 comments)
relevance: high
grade: B/fair
description: April-May 2025 thread where Swiftplay games vanished from match-v5; Riot said they had been made private (RSO only), then that it was unintentional and being fixed
---
# developer-relations #1068: Swiftplay matches no longer returned

Why: whether Swiftplay (480) is served, and what "private" queues mean for the API.

## Assessment

- Evidence: B. Riot staff replies: lucasMesquitaBorges (Riot engineer per profile) and
  ChaseWater (DevRel, speaks for "the appropriate teams"). Closed 2025-05-12, before the
  fix was confirmed; no later follow-up in the thread.
- Reasoning: fair. Explains the mechanism (private queue, RSO endpoints) but not why.
- Interests: reporters run stats sites.
- Weigh: the mechanism is reliable; whether Swiftplay is public today is not settled here
  (our probe: a January 2025 Swiftplay match is served, this thread's April 2025 one 404s).

## Findings

- [queues] [data] Around April 2025 Swiftplay games stopped appearing in both the
  by-puuid id list and the match endpoint. `raw/gh-devrel-1068.txt` ^f1
  > `/lol/match/v5/matches/by-puuid/{puuid}/ids` nor `/lol/match/v5/matches/{matchId}` work as expected.
- [queues] [policy] A Riot engineer said Swiftplay had been made private, meaning player
  authorisation via the lol-rso-match-v1 endpoints is needed. ^f2
  > We were informed that Swiftplay games are now private. This means it requires authorization from player to get data
- [queues] [policy] DevRel then said making Swiftplay private was unintentional and being
  fixed, with RSO match as the stopgap. ^f3
  > we have learned that the Swiftplay matches being made private was unintentional and we are working to fix this.
- [queues] [policy] Riot promised clearer information on all game modes and how data works
  for each one. ^f4
  > We’ll follow up soon with clearer info on all the game modes and how data works for each one.
- [queues] [data] Scale: about 250k Swiftplay games a day were inaccessible (one site's
  estimate). ^f5
  > we are loosing somewhere in the neighbourhood of 250k games per day that are inaccessible.
- [queues] [data] match-v5 id lists stop at 1000 games per player, so private queues
  cannot be backfilled later. ^f6
  > basically rendered useless due to the 1000 games limit in match-v5

## Read

- Issue body and all comments

## Not read

- Whether Riot ever published the promised per-mode data statement (not found in a
  developer-relations search for Swiftplay or Mayhem)
