---
status: answered
priority: soon
area: data
tags: [data, queues]
description: Which queues and modes does match-v5 serve, with timelines, and what are their queue ids?
---
# Which queues and modes does match-v5 serve, with timelines, and what are their queue ids?

Feeds: docs/concept.md Open (ARAM Mayhem for Squads; any queue in squad recaps);
crawler queue filter

## Answer

Ranked solo (420) and flex (440), normal draft (400), ARAM (450), Arena 2v2 (1700) and 3v3
(1750), ARURF (900) and Clash (700, 720) are all served by match-v5 with one-minute
timelines; tested live on 2026-10-11 (C1). ARAM Mayhem (2400 and variants) is private:
match ids give 403 in every region, Riot closed the bug as intended and had no plans to
open it as of 2026 (C2). Brawl (2300) is blocked the same way. The only routes to Mayhem
are the local client (LCU match history, as OP.GG's desktop app does) or a special
agreement with Riot's Game Modes team (C3). Swiftplay (480) was made private by accident
in April 2025 and promised to be fixed; its current state is unknown (C8).

Summaries differ by mode: Arena fills placement, subteam and augments for 16 or 18 players
with no teamPosition; ARAM has no teamPosition either; ARAM and Arena timelines lack
building, dragon, plate and bounty events (C4). Riot's queues.json lags (no 1750, Doom
Bots, Mayhem variants or the new custom-lobby ids 3100-3280); key on queueId and fill
gaps from the client's list via CommunityDragon and riotapi-schema (C5). Customs are only
listed through the RSO match endpoints (production key) (C6). An unserved queue returns an
empty list, not an error, and some listed games 404, so the crawler must treat both as
normal and cannot tell private from unplayed (C7). Id lists stop at 1000 games per player,
so private-period games cannot be backfilled (C9).

For the concept: Squads can recap ranked, normals, ARAM, Arena and rotating modes from
match-v5, but not Mayhem or Brawl; Mayhem would need the desktop app to read the
player's own client history (opt-in), which is a separate policy question.

| Mode | Queue id | match-v5 | Timeline |
| --- | --- | --- | --- |
| Ranked solo / flex | 420 / 440 | yes (tested) | yes |
| Normal draft / blind | 400 / 430 | 400 tested; 430 not seen | yes / ? |
| Swiftplay / Quickplay | 480 / 490 | unknown; bot games 404 | ? |
| ARAM | 450 | yes (tested) | yes |
| ARAM Mayhem | 2400 (+2401, 2403, 2405, 2410, 2450) | no, private (403) | no |
| Arena 2v2 / 3v3 | 1700 (1710 also listed) / 1750 | yes (tested) | yes |
| ARURF / Pick URF | 900 / 1900 | 900 yes (tested) | yes |
| One for All / Nexus Blitz / Spellbook / Swarm | 1020 / 1300 / 1400 / 1810-1840 | not seen | ? |
| Brawl | 2300 | no, blocked | no |
| Clash / ARAM Clash | 700 / 720 | yes (tested) | yes |
| Custom | 0, 3100-3280 | RSO only | RSO endpoint |

## Claims

- C1: Ranked solo and flex, draft, ARAM, Arena 1700 and 1750, ARURF and Clash are served with one-minute timelines (live test, EUW players, patch 16.20). for: [[match-v5-queues-measured#^f1]], [[match-v5-queues-measured#^f2]], [[match-v5-queues-measured#^f3]], [[match-v5-queues-measured#^f7]]
- C2: ARAM Mayhem is private on match-v5 (403 in every region), intended by Riot, with no plans to open it; Brawl was blocked the same way. for: [[gh-devrel-1109#^f1]], [[gh-devrel-1109#^f2]], [[gh-devrel-1109#^f3]], [[gh-devrel-1109#^f5]], [[match-v5-queues-measured#^f8]]
- C3: Mayhem history is reachable only from the local client or under a special Riot agreement. for: [[gh-devrel-1154#^f2]], [[gh-devrel-1154#^f3]], [[gh-devrel-1154#^f4]]
- C4: Arena summaries carry placement, subteam and augments with no teamPosition; ARAM has no teamPosition; ARAM and Arena timelines lack building, dragon, plate and bounty events. for: [[match-v5-queues-measured#^f3]], [[match-v5-queues-measured#^f4]], [[match-v5-queues-measured#^f5]], [[match-v5-queues-measured#^f6]]
- C5: Riot's queues.json and gameModes.json are incomplete (no 1750, CHERRY, Doom Bots, Mayhem variants, custom-lobby ids); the client list and riotapi-schema fill the gaps. for: [[riot-queues-json#^f7]], [[riot-gamemodes-json#^f3]], [[cdragon-queues-json#^f1]], [[cdragon-queues-json#^f2]], [[cdragon-queues-json#^f4]], [[riotapi-schema-enums#^f1]]
- C6: Customs are listed only through the RSO match endpoints, and custom lobbies may carry ids 3100-3280 rather than 0. for: [[riotapi-schema-enums#^f6]], [[cdragon-queues-json#^f3]], [[riot-queues-json#^f6]]
- C7: An unserved queue returns 200 with an empty list, and some listed games (Quickplay with bots) 404, so the crawler must treat both as normal. for: [[match-v5-queues-measured#^f11]], [[match-v5-queues-measured#^f10]], [[gh-devrel-1020#^f1]]
- C8: Swiftplay was made private by accident around April 2025 and promised to be fixed; not confirmed since. for: [[gh-devrel-1068#^f1]], [[gh-devrel-1068#^f2]], [[gh-devrel-1068#^f3]], [[match-v5-queues-measured#^f10]]
- C9: Id lists stop at 1000 games per player, so games from a private period cannot be backfilled later. for: [[gh-devrel-1068#^f6]]

## Disagreements

Why Mayhem is private: an engineer says only "private" ([[gh-devrel-1109#^f2]]); a
developer claims it stops aggregators solving the meta ([[gh-devrel-1154#^f1]]) and that
new rotating modes are not meant to be public ([[gh-devrel-1109#^f4]]). Unconfirmed by
Riot; does not change what we can do.

## Open

- Is Swiftplay (480) public now? No current 480/490 games in a sample of 15 mostly high
  elo players; test with lower-elo players
- 1710 vs 1700; One for All, Nexus Blitz, Spellbook, Swarm, Doom Bots not in rotation
  during the test; other regions untested
- Do real custom matches carry 3xxx or 0?
- Policy: may an app upload a player's own Mayhem history from the client (opt-in) and
  show it to their squad?
- Riot's promised per-mode data statement (#1068) not found
