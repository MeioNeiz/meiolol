---
title: Our Leaguepedia Cargo test calls (26 Oct 2026)
url: https://lol.fandom.com/api.php
kind: dataset
commit: 
for: [leaguepedia-daily-fetch]
looked: 2026-10-26
depth: ran (about 10 calls, limit 5 to 20)
relevance: high
grade: B/strong
description: Our own calls: anonymous api.php cargoquery ratelimited on the first call from two IPs; CargoExport joins work; side, winner and patch semantics checked on Worlds 2026 games
---
# Our Leaguepedia Cargo test calls (26 Oct 2026)

Why: confirm field names, joins, response shape and rate limits before building the fetch.

## Assessment

- Evidence: B. First-hand, a handful of calls on one day.
- Reasoning: strong (direct observation).
- Interests: none.
- Weigh: CargoExport answered anonymously but robots.txt disallows /wiki/Special: ([[fandom-lol-robots#^f2]]), so it was only a probe; the logged-in api.php path is untested (no account yet).

## Findings

- [data] Anonymous api.php cargoquery returned `ratelimited` on the very first call, from the Mac and from the box (fresh IP), even for limit=1 on one table; other api.php actions (siteinfo) worked. ^f1
  > You've exceeded your rate limit. Please wait some time and try again.
  > from the box (meiolol-cloud, first call ever from that IP): same ratelimited error
- [data] One Cargo query joining ScoreboardGames, PicksAndBansS7, Tournaments and ScoreboardPlayers on GameId and OverviewPage returns 10 rows per game (one per player) with the whole draft repeated on each. ^f2
  > 20 rows (10 per game)
- [data] ScoreboardGames.Team1 is ScoreboardPlayers Side 1 (blue): in game 3_4_1 LYON is SG Team1 and its players have Side 1. ^f3
  > "Team1": "LYON (2024 American Team)", "Winner": 1, "WinTeam": "LYON (2024 American Team)"
  > 1 LYON (2024 American Team) Top Olaf Yes
- [data] [draft] PicksAndBansS7 Team1/Team2 are the series' teams, not sides: with SwitchedSides=1, PB Team1 (Gen.G) played red, and Team1Pick1 is Gen.G's pick (Qiyana, played by Gen.G's red-side jungler). ^f4
  > "PBTeam1": "Gen.G", "PBTeam2": "LYON (2024 American Team)", "Team1Ban1": "Nocturne", "Team2Ban1": "Cassiopeia", "Team1Pick1": "Qiyana"
  > 2 Gen.G Jungle Qiyana No
- [data] Stored PicksAndBansS7.Winner is relative to PB Team1/Team2 (2 when PB Team2 won), unlike the template's blue=1 input; use ScoreboardGames.WinTeam or Winner instead. ^f5
  > "PBTeam1": "Gen.G", "PBWinner": 2, "SwitchedSides": 1
- [data] Gotcha: Patch is a string ("26.20") but JSON output turned it into the number 26.2; read it as text (CSV, or check the API's JSON). ^f6
  > "Patch": 26.2, "PatchSort": null, "LegacyPatch": 16.2
  > Patch of game 3_4_1 with format=csv:
- [data] Primary official 2026 leagues: LCK, LPL (Tencent LoL Pro League), LEC (LoL EMEA Championship), LCS (League of Legends Championship Series), LCP, CBLOL, plus World Championship, MSI and First Stand. ^f7
  > 6 LoL Champions Korea | Korea
  > 6 Tencent LoL Pro League | China
  > 6 LoL EMEA Championship | EMEA
  > 6 League of Legends Championship Series | North America
  > 1 Mid-Season Invitational | International
  > 1 First Stand | International

## Read

- `raw/leaguepedia-cargo-tests.txt`: our log.

## Not read

- Logged-in (bot password) api.php rate: untested.
