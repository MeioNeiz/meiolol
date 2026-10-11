---
title: Game Memory Access Removed for Third Party Apps (Riot Support, 2026-09-29)
url: https://support.riotgames.com/en-us/riot/performance/game-memory-access-removed-for-third-party-apps
kind: docs
commit:
for: [riot-production-key]
looked: 2026-10-11
depth: docs (whole page)
relevance: high
grade: A/fair
description: Riot announcement that from 2026-10-06 unknown third-party apps are blocked from game memory; official APIs the only allowed route
---
# Game Memory Access Removed for Third Party Apps (Riot Support, 2026-09-29)

Why: did Riot change third-party app rules in Oct 2026 (memory reading, approved apps)?

## Assessment

- Evidence: A. Riot's own support article, dated 29 Sep 2026, all titles.
- Reasoning: fair. Gives the why (AI-assisted reverse engineering, cheats, bot farms) and
  the cost; no technical detail on how "known" apps are identified.
- Interests: Riot (anti-cheat, platform control).
- Weigh: binding direction of travel. Does not mention the LCU (client) API explicitly;
  "official APIs" links to the developer portal.

## Findings

- [policy] From 6 Oct 2026, game memory access blocked by default for unknown third-party
  apps, all titles; known approved tools have grace until April 2027. ^f1
  > Starting October 6, 2026, Riot will begin proactively preventing game memory access by default for all unknown third-party applications, for all titles, including League, TFT, and VALORANT. For known and currently approved tools, we will have an extended grace period until April 2027, after which time, they will need to have switched to the official APIs.
- [policy] Official API is to be the only allowed mechanism for retrieving game data. ^f2
  > by preventing memory access universally and moving all remaining 3rd party applications onto the official API as the only allowed mechanism for retrieving game data.
- [policy] Rationale: AI-assisted reverse engineering has multiplied cheats and bot farms. ^f3
  > advances in AI-assisted reverse engineering have grown the ranks of would-be hackers at an unsustainable pace
- [policy] Grace-period path for existing developers: move to approved API mechanisms,
  request new API data, or sunset features. ^f4
  > transition affected features to approved API mechanisms, formally request new API data in support of them, or sunset those features where no good alternatives remain
- [policy] Not a ban trigger by itself; it blocks unauthorised tools. ^f5
  > This change does not result in bans by itself—it just blocks unauthorized tools from interacting with the game client.
- [policy] (inferred) An app that only reads the LCU and Riot API and never game memory
  (meiolol's design) is on the "official API" side of this line, but the article never
  names the LCU, so whether LCU counts as "official" is unconfirmed. ^f6
- [policy] Checked, not there: no published list of approved or known apps; no mention
  of champion select, the LCU, or the League Client API. ^f7

## Read

- whole article

## Not read

- linked developer portal docs (riot-docs-portal noted separately)
