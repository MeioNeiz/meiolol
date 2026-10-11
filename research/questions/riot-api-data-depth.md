---
status: decided
decision: docs/concept.md
priority: soon
tags: [data, learning, fun]
description: What can the Riot API provide beyond match summaries to power a data-hungry learning or fun tool?
---
# What can the Riot API provide beyond match summaries to power a data-hungry learning or fun tool?

Feeds: docs/concept.md data needs; rate limit calculation for the production application

## Answer

The match-v5 timeline is the deep source: one frame per minute with each player's gold, xp,
level, CS, position and 25 champion stats, plus about 1,000 typed events per game (kills,
objectives and buildings with positions; item purchases; skill-ups; wards without
positions) (C1). It costs one extra call per match and is about 9x the summary (C2); the
summary alone gives only lane-phase flags, not gold or xp at a minute (C4). Other endpoints
add mastery for every champion, challenges, live game, clash and the full ladder (C5).
Per-minute win probability from timelines is feasible (C6).

Volume is the binding constraint. The EUW crawl already fills the personal key (C3), and
matchup stats are noisy below a few hundred games (C7). Per-patch per-bracket curves for
anything beyond the most-picked pairs need far more than one region on a personal key (C8);
limits are per routing value, so all four match regions give about 4x (C9). Rare pairs need
pooling across patches or brackets whatever the key (C8).

## Claims

- C1: Timeline gives per-minute per-player economy, xp, CS, position and stats, plus ~1,000 typed events per game; kills, objectives and buildings positioned, wards not. for: [[riotapi-schema#^f2]], [[riotapi-schema#^f3]], [[riotapi-schema#^f5]], [[riot-timeline-measured#^f1]], [[riot-timeline-measured#^f3]], [[riot-timeline-measured#^f4]], [[riot-timeline-measured#^f5]]
- C2: A timeline is one extra app-limit call per match and ~9x the summary (727 KB vs 78 KB JSON; 63 KB vs 11 KB gzipped). for: [[riotapi-schema#^f1]], [[riot-timeline-measured#^f2]], [[riot-timeline-measured#^f8]]
- C3: The personal key is already saturated by the EUW summary crawl, so timelines displace summaries. for: [[riot-timeline-measured#^f9]]
- C4: The summary's challenges block gives lane-phase flags and max CS/level leads, not gold or xp amounts at a minute. for: [[riotapi-schema#^f7]], [[riot-timeline-measured#^f7]], [[riot-timeline-measured#^f10]]
- C5: Other endpoints: mastery (all champions, points, last played), challenges, spectator (anonymous puuids null), clash, full ladder, replays by puuid, RSO match history incl. customs (production key). for: [[riotapi-schema#^f8]], [[riotapi-schema#^f9]], [[riotapi-schema#^f10]], [[riotapi-schema#^f11]], [[riotapi-schema#^f12]], [[riotapi-schema#^f13]], [[riotapi-schema#^f14]], [[riotapi-schema#^f15]]
- C6: Per-minute win probability from timelines works (ROC AUC 0.82 at 15 min, Challenger only). for: [[sbgames-2026-minute-win-prob#^f1]], [[sbgames-2026-minute-win-prob#^f2]], [[sbgames-2026-minute-win-prob#^f4]], [[zilean-docs#^f1]]
- C7: Matchup stats are noisy at the common 100-game floor; high elo and early patch worse. for: [[lolalytics-counters-threshold#^f1]], [[lolalytics-counters-threshold#^f3]], [[riot-august-ugg-sample-size#^f1]], [[riot-august-ugg-sample-size#^f2]], [[riot-august-ugg-sample-size#^f3]], [[lolalytics-darius-counters#^f3]]
- C8 (inferred): A personal key cannot support per-patch per-bracket matchup curves beyond the most-picked pairs; even all of EUW is thin for 1% x 1% pairs. from: C2, C3, C7 against: [[darkintaqt-riot-app#^f4]]
- C9: Rate limits apply per routing value, so crawling all four match regions multiplies volume ~4x on the same key. for: [[riot-docs-portal#^f7]], [[riot-docs-portal#^f9]], [[darkintaqt-riot-app#^f7]]

## Volume estimate (ours, 2026-10-11)

Assumes in-role pick rates and n = 400 games per pair per bracket (~±5 points win rate), 3
brackets. Timelines: ~2.2 calls/match, ~33k matches/day per region on a personal key.

| Pair pick rates | Matches per patch | Calls/day | vs one personal-key region |
| --- | --- | --- | --- |
| 5% x 5% | 240k | 38k | fits |
| 2% x 2% | 1.5M | 236k | 3.3x |
| 1% x 1% | 6M | 943k | 13x |

All of EUW with timelines is ~352k calls/day (4.9x). Storage: ~2 GB/day gz raw per region,
so keep extracted per-minute features.

## Disagreements

Production starting limits: docs say 500/10s per region ([[riot-docs-portal#^f9]]) vs
community reports of personal-level starts ([[darkintaqt-riot-app#^f4]]).

## Open

- Sizes and event counts are from one match; gold-diff spread per role unsourced (n = 400 is a
  binomial assumption).
- How much do regions differ per matchup (pooling bias)? Measure once crawling all regions.
