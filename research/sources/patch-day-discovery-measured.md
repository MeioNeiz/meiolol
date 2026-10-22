---
title: 'Match id yield per call on patch 16.21 day one, by scan source (our measurement, 2026-10-21)'
url: https://github.com/MeioNeiz/meiolol/commit/044f5fa
kind: dataset
commit: 044f5fa
for: [crawl-discovery]
looked: 2026-10-21
depth: ran
relevance: high
grade: B/strong
description: Crawl log counts and database checks of how many new 16.21 match ids each kind of match id call found on the patch's first day, all four regions
---
# Match id yield per call on patch 16.21 day one, by scan source (our measurement, 2026-10-21)

Why: on 16.21's release the crawl fell from ~169k to ~116k matches/day; match id calls
were returning ~0.3 new ids each in americas (pre-patch ~20).

## Assessment

- Evidence: B. Our own crawler on the live key, all four regions, one patch day; per
  source counts from the minute crawl report (3648361 on), stored games per scanned
  player from the database. Counts only.
- Reasoning: strong. Direct measurement of ids per call, before and after each change.
- Interests: none.
- Weigh: one patch, first ~24 h; hours differ by region (patch went live 00:00 to 11:11
  UTC). Stored-game counts per player are complete only for players scanned after the
  patch began. Each hour compares different times of day.

## Findings

- [data] On a patch's first day most players have not played it: of players scanned 3+ h after the patch began, 75 to 89% had no game on it; those with one had 1.6 to 3.5 more. ^f1
  > scanned since patch start: americas 17,133 (89% none, +1.57), asia 25,243 (75%, +2.98), europe 17,589 (83%, +2.94), sea 28,709 (82%, +3.52)
- [data] Ladder growth counted from a scan or sighting before the patch mostly finds older-patch games: americas active-list scans found no 16.21 game for 75% of players, and never scanned players' growth (from their first sighting) gave 0.41 new ids per call. ^f2
  > 265 americas active scans in 10 min, 199 with no 16.21 game; hour after 3648361: americas active 1870 calls, 770 new
- [data] Players who appear in a newly stored match and played since their last scan (snowball) give 3.1 to 3.5 new ids per call on day one. ^f3
  > sea snowball 344 calls 1077 new (22:06 to 23:07); 480 calls 1694 new (23:12 to 00:13); asia 45 calls 151 new
- [data] With pre-patch baselines reset and never scanned players moved to the stale tier, americas active scans rose to 1.9 new ids per call and the crawl from ~116k to ~143k matches/day (pre-patch ~165k). ^f4
  > 23:12 to 00:13: americas active 810 calls 1522 new; all regions ~3000 req/h, no idle, no spare-budget timelines; 142,890 matches/day
- [data] The ladder refresh (every 12 h, 500 pages per hour per platform) leaves gaps of hours with no new sightings: americas rows were last sighted 12:59 to 19:34 UTC, then nothing until the next pass. ^f5
  > pending americas rows: rank_seen_at min 1792587598, max 1792611293 at 23:00 UTC

## Read

- All of it (our data).

## Not read
