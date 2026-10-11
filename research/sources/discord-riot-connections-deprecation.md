---
title: 'Discord API changelog: Riot Games connections removed from Get Current User Connections (2026-07-07)'
url: https://github.com/discord/discord-api-docs
kind: docs
commit: 37148620d2324292b76047541d5f8331f81ea77a
for: [identity-and-privacy]
looked: 2026-10-11
depth: docs (developers/change-log.mdx entry of 7 July 2026)
relevance: high
grade: A/fair
description: Discord's official API changelog: Riot and League connections no longer returned by /users/@me/connections from 10 July 2026, no replacement
---
# Discord API changelog: Riot Games connections deprecation

Why: could a Discord OAuth login (connections scope) prove Riot ID ownership without RSO?

## Assessment

- Evidence: A. Discord's own API docs repo, changelog entry dated 7 July 2026.
- Reasoning: fair. States cause (move to the Discord Social SDK) and that nothing
  replaces it.
- Interests: Discord.
- Weigh: closes the Discord-connections route for third parties. A Discord link can
  still identify a Discord user (e.g. for Squads invites), but not prove a Riot ID.

## Findings

- [privacy] [tools] Riot Games and League connections are no longer returned by
  GET /users/@me/connections, as part of the move to the Discord Social SDK.
  `developers/change-log.mdx` ^f1
  > Riot Games and League of Legends connections are no longer returned by the /users/@me/connections endpoint as part of their migration to the Discord Social SDK.
- [privacy] [tools] Legacy connections stopped being returned from 10 July 2026; no
  replacement. `developers/change-log.mdx` ^f2
  > Starting July 10, 2026, legacy Riot Games and League of Legends connections will also no longer be returned by this endpoint. There is no replacement for this functionality.
- [privacy] (inferred) Before July 2026 a Discord OAuth login with the connections scope
  was a de facto RSO substitute (Riot verified the link); that route is now gone, so
  without RSO the remaining ownership check is the profile-icon challenge
  ([[lolsite-icon-verify#^f4]], [[moon-poro-bot#^f3]]). ^f3

## Read

- change-log entry of 7 July 2026

## Not read

- Discord Social SDK docs (whether a third-party app can read a user's Riot identity
  through it)
