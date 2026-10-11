---
title: League of Legends Patch 26.20 Notes (Riot, 2026-10-06)
url: https://www.leagueoflegends.com/en-us/news/game-updates/league-of-legends-patch-26-20-notes/
kind: docs
commit:
for: [riot-production-key]
looked: 2026-10-11
depth: skimmed (Private Replays section; grepped for champ select and third party)
relevance: medium
grade: A/fair
description: Official patch notes; Private Replays section ties replay lockout to the game memory restrictions
---
# League of Legends Patch 26.20 Notes (Riot, 2026-10-06)

Why: official confirmation and framing of the Oct 2026 third-party changes.

## Assessment

- Evidence: A. Riot's own patch notes, dated 10/6/2026.
- Reasoning: fair. Short rationale (security vulnerabilities exploited by cheat devs).
- Interests: Riot.
- Weigh: replay part later delayed to 26.21 (dotesports-replay-delay-2621); memory part
  not reported as delayed.

## Findings

- [policy] Patch 26.20 published 6 Oct 2026 (page date 10/6/2026). ^f1
  > Bee woo woop - the Worlds patch is here!
- [policy] Replays limited to own matches; third-party apps and sites lose replay
  downloads entirely. ^f2
  > Starting with this patch, you will only be able to access replays from matches you played in. Other players will no longer be able to download your replays, and third-party apps & sites will lose access to replay downloads entirely.
- [policy] Done alongside game-memory restrictions to close security holes used to build
  unauthorised tools around League game data. ^f3
  > We are making this change, alongside some restrictions on third party access to game memory, to close some security vulnerabilities that have recently been exploited by cheat developers and other bad actors to build unauthorized tools around League game data.
- [policy] Checked, not there: nothing on champion select tools, the LCU, Riot API keys or
  pick recommendation (only champ select mention is a chroma bug fix). ^f4

## Read

- Private Replays section; grep of whole page

## Not read

- balance and champion changes (irrelevant to policy)
