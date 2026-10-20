---
status: answered
priority: soon
area: policy
tags: [privacy, policy]
description: How do lookup sites and the Riot API treat streamer mode and other players' Riot IDs on public pages?
---
# How do lookup sites and the Riot API treat streamer mode and other players' Riot IDs on public pages?

Feeds: J18 (docs/plan/decisions.md): names on public pages; docs/legal/lia.md "Streamer
mode" and "Names of other players"; docs/privacy-rules.md

## Answer

Streamer mode hides a Riot ID only for the duration of a match: Riot says match history
and replays are not affected, and that the anonymous modes do not touch post-match APIs
such as match-v5 (S2). Measured: 5,000 recent EUW ranked match-v5 documents have no blank
Riot ID or PUUID and no field marking streamer mode (S3). So a site built on finished
games cannot tell who had it on and is not asked to. Riot's line is live data:
spectator-v5 returns a null PUUID for a hidden player (S3), and lookup sites follow it
live, Porofessor showing "Streamer Mode" in the seat, OP.GG dropping the row (S4). Lookup
sites name every visible player by Riot ID (S1).

For meiolol: finished games (Your games) may name all ten players; no live game or champ
select names (S5). Not settled: whether OP.GG's match history shows a finished game's
streamer-mode players by name (one try, logged out, rendered no match list).

## Claims

- S1: Large lookup sites show other players by Riot ID beside their rank and stats. for: [[porofessor-featured-live-2026-10-20#^f1]], [[opgg-ingame-streamer-mode#^f1]]
- S2: Streamer mode hides a Riot ID only during the match; match history, replays and post-match APIs such as match-v5 are not affected. for: [[riot-support-anonymizing-riot-id#^f2]], [[riotdevrel-tweet-spectator-anonymity#^f2]]
- S3: match-v5 neither blanks nor marks streamer-mode players; only spectator-v5 (live) hides them, with a null PUUID. for: [[match-v5-streamer-check#^f1]], [[match-v5-streamer-check#^f2]], [[riotapi-schema#^f22]], [[riotapi-schema#^f21]]
- S4: Live game pages respect streamer mode: Porofessor replaces the name and rank with "Streamer Mode", OP.GG leaves the player out. for: [[porofessor-featured-live-2026-10-20#^f1]], [[porofessor-featured-live-2026-10-20#^f2]], [[opgg-ingame-streamer-mode#^f2]], [[league-tweet-streamer-mode-spectate#^f3]]
- S5 (inferred): Naming all players of a finished game breaks no streamer mode rule; showing live games or champ select names would. from: S2, S3, S4

## Disagreements

- gh-devrel-1110 guesses hidden players are "zeroed out" in returned matches; it means
  the spectator endpoint (live), consistent with S3, and has no Riot reply.

## Open

- OP.GG or U.GG match history for a game where players had streamer mode on: are the
  names shown post-game? A logged-in or "Update"-clicked snapshot would settle it
- Whether Riot ever extends streamer mode to match history (lia.md revisits if so)
