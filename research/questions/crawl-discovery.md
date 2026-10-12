---
status: answered
priority: now
area: data
tags: [data]
description: Which players to scan for match ids so the key's budget goes on newest-patch ranked games
decision: docs/plan.md#ops-and-data-was-meiolol-de-data-safety-af
---
# How do we find the most newest-patch ranked games per Riot API call?

Feeds: the crawler's scan order and ids window (src/riot/crawl.zig), docs/plan.md.

## Answer

The standard methods are a ladder seed and a participant snowball (C1); neither says
when to rescan a player. Our measurements answer that: most Plat+ ladder players play
nothing in a day (C3), so a rescan is usually an empty call, and the ladder's
wins+losses growth since the last scan predicts the new ids almost exactly (C2).
Ladder pages use the platform buckets, which matches don't, so the signal costs none of
the regional budget. Scan players whose count grew, most new games first, and only
fall back to never-scanned or stalest players when none have (C4). Measured gain: about
5x ids per call over ~20 h windows (C3). Combined with an ids window from the newest
patch's start, every call goes on newest-patch games.

## Claims

- C1: Crawlers discover ranked matches by paging the ladder for players or snowballing through match participants. for: [[hextech-crawling#^f1]], [[hextech-crawling#^f2]]
- C2: A player's ladder wins+losses growth since a snapshot equals their ranked match ids since then. for: [[ladder-delta-measured#^f2]], [[riotapi-schema#^f20]]
- C3: Most Plat+ ladder players play no ranked game in a given day or even five days, so blind rescans mostly return nothing. for: [[ladder-delta-measured#^f1]], [[ladder-delta-measured#^f3]]
- C4 (inferred): Ordering scans by ladder growth puts nearly every ids call on a player with new games. from: C2, C3

## Open

- Patch day itself and other platforms: unmeasured; watch the crawl report's ids/new.
- Ladder refresh rate vs writes: a faster refresh gives fresher signal but more writer
  load; measure on the A1.
- Participants (no ladder counts) and sampling (--player-sample 16 limits the pool).
- Checked, not there: no published account of how lolalytics/u.gg/op.gg schedule rescans.
