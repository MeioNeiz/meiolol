---
title: Vanguard FAQ for Third Party Applications (Riot DevRel, 2024-04-01)
url: https://www.riotgames.com/en/DevRel/vanguard-faq
kind: docs
commit:
for: [riot-production-key]
looked: 2026-10-11
depth: docs (whole page)
relevance: medium
grade: A/fair
description: Riot DevRel FAQ on Vanguard's effect on third-party League apps; LCU still works, no allow list
---
# Vanguard FAQ for Third Party Applications (Riot DevRel, 2024-04-01)

Why: whether LCU-based apps survive Vanguard, and whether an approved-apps list exists.

## Assessment

- Evidence: A. Riot DevRel, dated 1 Apr 2024.
- Reasoning: fair. Plain answers, few reasons.
- Interests: Riot.
- Weigh: 2024; the Sept 2026 memory article (riot-memory-access-removed) talks of "known
  and currently approved tools", which sits awkwardly with "no allow list" here.

## Findings

- [policy] LCU and in-game API apps expected to keep working under Vanguard, but LCU is
  unsupported by DevRel. ^f1
  > Apps developed using the LCU and in-game APIs are still expected to work. Please note the LCU and in-game APIs are not owned by Developer Relations and we cannot offer support or guarantee updates when using these methods.
- [policy] External memory-reading tools stop working. ^f2
  > Overlays and internal tools using the API, game client, and in-game APIs should continue to function. External tools reading memory will no longer work, and you’ll need to change methods.
- [policy] No Vanguard allow list, no exceptions. ^f3
  > No - There is absolutely no allow list for Vanguard.
- [policy] DevRel cannot advise individual apps. ^f4
  > we just don’t have the bandwidth to address Vanguard questions at the individual level.

## Read

- whole page

## Not read

- https://www.leagueoflegends.com/en-us/news/dev/dev-vanguard-x-lol/: player-facing dev blog
