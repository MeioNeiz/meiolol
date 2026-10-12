---
title: 'Ladder wins+losses growth vs new match ids, EUW Plat+ (our measurement, 2026-10-12)'
url: https://meiolol.jomify.lol/
kind: dataset
commit: 
for: [crawl-discovery]
looked: 2026-10-12
depth: ran
relevance: high
grade: B/strong
description: Our live-key samples of how many 16.20 games random EUW Plat+ ladder players have, and whether ladder wins+losses growth predicts match ids
---
# Ladder wins+losses growth vs new match ids, EUW Plat+ (our measurement, 2026-10-12)

Why: most match id calls seemed to come back empty; can the ladder tell us who played?

## Assessment

- Evidence: B. Our own calls on the live API, 90 + 160 players, one platform, one
  day, five days into a patch. Counts only, PUUIDs not kept.
- Reasoning: strong. Direct measurement of the thing we optimise (ids per call).
- Interests: none.
- Weigh: EUW only and mid-patch; other platforms and patch day itself unmeasured.
  Sampling by PUUID prefix from the scan pool (1 in 16 of the ladder), not uniform.

## Findings

- [data] Five days into 16.20, about half of random EUW Plat+ ladder players had no 16.20 ranked game; those who played averaged about 6. ^f1
  > 90 players: 49 with 0 games on 16.20; mean 2.91 games per player; mean 6.39 among the 41 who played.
- [data] Ladder wins+losses growth since a snapshot equals the ranked match ids since then, almost exactly. ^f2
  > delta equals ids for 156 of 160, the rest within 1.
- [data] Over about 20 hours most players play nothing, so rescanning without the ladder signal mostly returns nothing; scanning only players whose count grew returns about 5x as many ids per call. ^f3
  > 131 players had delta 0 and returned 0 ids in total. Players with delta > 0 returned 3.17 ids per call; all players 0.57 per call.

## Read

- All of it (our data).

## Not read

- Other platforms, patch day itself, players found as participants (no ladder counts).
