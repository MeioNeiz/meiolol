---
status: answered
priority: soon
area: data
tags: [data, policy]
description: What may we take from Leaguepedia's Cargo API for a daily pro draft, under what licence and rate limits, and which tables and fields give one game's draft, result and scoreboard?
---
# What may we take from Leaguepedia's Cargo API for a daily pro draft, under what licence and rate limits, and which tables and fields give one game's draft, result and scoreboard?

Feeds: Daily Draft page fetch (one finished pro game a day from Leaguepedia Cargo)

## Answer

Licence is workable: wiki text is CC BY-SA 3.0, commercial use allowed with a link back (C1, C2). Automated use: Leaguepedia publishes the API and bot passwords for it and robots.txt allows api.php, but Fandom's Terms ban robots without written permission (C3, see Disagreements). The real blocker is rate: anonymous api.php cargoquery is ratelimited from the first call, so the box must log in with a bot password (Cargo grant, confirmed email) (C4, C5). Numbers are not published; one query a day, retrying with backoff on `ratelimited`, is the practice (C6). Special:CargoExport answered anonymously but robots.txt disallows /wiki/Special:, so not for the server (C7).

One query gets everything for the last N games (C8): ScoreboardGames (Team1 = blue = Side 1, WinTeam, Winner, Gamelength, Gamelength_Number, Patch, DateTime_UTC, GameId, Tournament) joined on GameId to PicksAndBansS7 (TeamXBan1-5, TeamXPick1-5, TeamXRole1-5, SwitchedSides) and ScoreboardPlayers (Side, Team, Role, Link, Champion, Kills, Deaths, Assists, CS, Gold, DamageToChampions), and on OverviewPage to Tournaments (League). PB Team1/Team2 are the series' teams: blue is PB Team1 unless SwitchedSides=1 (C9), and PB Winner follows that too, so take the winner from ScoreboardGames (C10). Draft order is the fixed 20-step sequence (C11). Major leagues by Tournaments.League (C12). Patch must be read as text (C13). Sample query (log in first, 10 rows per game, so limit 10N up to 500):

`https://lol.fandom.com/api.php?action=cargoquery&format=json&tables=ScoreboardGames%3DSG%2CPicksAndBansS7%3DPB%2CTournaments%3DT%2CScoreboardPlayers%3DSP&join_on=SG.GameId%3DPB.GameId%2CSG.OverviewPage%3DT.OverviewPage%2CSG.GameId%3DSP.GameId&fields=SG.GameId%2CSG.DateTime_UTC%3DDateTime%2CSG.Tournament%2CT.League%2CSG.Team1%2CSG.Team2%2CSG.WinTeam%2CSG.Winner%2CSG.Gamelength%2CSG.Gamelength_Number%3DMinutes%2CSG.Patch%2CPB.Team1%3DPBTeam1%2CPB.Team2%3DPBTeam2%2CPB.SwitchedSides%2CPB.Team1Ban1%2CPB.Team1Ban2%2CPB.Team1Ban3%2CPB.Team1Ban4%2CPB.Team1Ban5%2CPB.Team1Pick1%2CPB.Team1Pick2%2CPB.Team1Pick3%2CPB.Team1Pick4%2CPB.Team1Pick5%2CPB.Team1Role1%2CPB.Team1Role2%2CPB.Team1Role3%2CPB.Team1Role4%2CPB.Team1Role5%2CPB.Team2Ban1%2CPB.Team2Ban2%2CPB.Team2Ban3%2CPB.Team2Ban4%2CPB.Team2Ban5%2CPB.Team2Pick1%2CPB.Team2Pick2%2CPB.Team2Pick3%2CPB.Team2Pick4%2CPB.Team2Pick5%2CPB.Team2Role1%2CPB.Team2Role2%2CPB.Team2Role3%2CPB.Team2Role4%2CPB.Team2Role5%2CSP.Side%2CSP.Team%2CSP.Role%2CSP.Link%2CSP.Champion%2CSP.Kills%2CSP.Deaths%2CSP.Assists%2CSP.CS%2CSP.Gold%2CSP.DamageToChampions&where=T.League+IN+%28%27LoL+Champions+Korea%27%2C%27Tencent+LoL+Pro+League%27%2C%27LoL+EMEA+Championship%27%2C%27League+of+Legends+Championship+Series%27%2C%27World+Championship%27%2C%27Mid-Season+Invitational%27%2C%27First+Stand%27%29+AND+SG.DateTime_UTC+%3E%3D+%272026-10-01%27&order_by=SG.DateTime_UTC+DESC%2CSP.Side%2CSP.Role_Number&limit=100`

The same query ran through Special:CargoExport on 26 Oct 2026 and returned the expected rows.

## Claims

- C1: Leaguepedia text is CC BY-SA 3.0; reuse, commercial included, is allowed with attribution and share-alike. for: [[fandom-licensing#^f1]], [[fandom-licensing#^f2]], [[leaguepedia-api-help#^f11]]
- C2: A hyperlink to the source article (credit line like Fandom's example) satisfies attribution. for: [[fandom-licensing#^f3]], [[fandom-licensing#^f4]]
- C3: Bots may use api.php: Leaguepedia documents it for developers and robots.txt allows it for all agents. for: [[leaguepedia-api-help#^f1]], [[leaguepedia-api-help#^f2]], [[fandom-lol-robots#^f1]] against: [[fandom-terms#^f1]]
- C4: Anonymous cargoquery is ratelimited to near uselessness; it failed on the first call from two IPs. for: [[leaguepedia-api-help#^f3]], [[leaguepedia-cargo-ratelimits#^f1]], [[leaguepedia-cargo-tests#^f1]]
- C5: Fix: bot password with the Cargo grant, confirmed email, log in before querying. for: [[leaguepedia-cargo-ratelimits#^f2]], [[leaguepedia-api-help#^f3]]
- C6: No published request rate; max 500 rows per query; clients retry `ratelimited` with backoff (0, 10, 30 s). for: [[leaguepedia-api-help#^f4]], [[leaguepedia-api-help#^f12]], [[mwcleric-arbolito#^f1]]
- C7: Special:CargoExport works anonymously but robots.txt disallows /wiki/Special:. for: [[fandom-lol-robots#^f2]], [[leaguepedia-cargo-tests#^f2]]
- C8: One Cargo query can join ScoreboardGames, PicksAndBansS7, ScoreboardPlayers (GameId) and Tournaments (OverviewPage), 10 rows per game. for: [[leaguepedia-api-help#^f6]], [[leaguepedia-api-help#^f7]], [[leaguepedia-cargo-tests#^f2]]
- C9: ScoreboardGames.Team1 is blue (ScoreboardPlayers Side 1); PicksAndBansS7 Team1/Team2 are series teams, blue is PB Team1 unless SwitchedSides=1. for: [[leaguepedia-cargo-tests#^f3]], [[leaguepedia-cargo-tests#^f4]], [[leaguepedia-pb-template#^f3]], [[leaguepedia-parser#^f2]]
- C10: PicksAndBansS7.Winner is relative to PB Team1/Team2; take the winner from ScoreboardGames.WinTeam. for: [[leaguepedia-cargo-tests#^f5]] against: [[leaguepedia-pb-template#^f2]]
- C11: Draft order of the 20 cells, by side: B1 R1 B2 R2 B3 R3 bans, B1 R1 R2 B2 B3 R3 picks, R4 B4 R5 B5 bans, R4 B4 B5 R5 picks; roles are per pick slot, entered before swaps. for: [[leaguepedia-parser#^f1]], [[leaguepedia-pb-template#^f1]]
- C12: Major leagues filter on Tournaments.League: LoL Champions Korea, Tencent LoL Pro League, LoL EMEA Championship, League of Legends Championship Series, World Championship, Mid-Season Invitational, First Stand (TournamentLevel 'Primary' is the broader filter). for: [[leaguepedia-cargo-tests#^f7]], [[leaguepedia-tournaments#^f1]]
- C13: Patch is a string ("26.20") that JSON output turned into 26.2; read it as text. for: [[leaguepedia-cargo-tests#^f6]], [[leaguepedia-scoreboardgames#^f2]]

## Disagreements

- Automated use (C3): Fandom's Terms ban robots and automated access without express written permission ([[fandom-terms#^f1]], A), while Leaguepedia, hosted by Fandom, documents api.php for developers, issues bot passwords with a Cargo grant and allows api.php in robots.txt (A). Read together: API use is the permitted channel, scraping pages is not. Settle by asking in the Leaguepedia Discord `api-help` channel and keeping the answer.
- Winner (C10): the template docs say winner 1 = blue, but stored PB rows have Winner 2 when PB Team2 (on blue after a switch) won. The template converts on save; ScoreboardGames is unambiguous.

## Open

- Logged-in cargoquery rate: untested (no bot password yet). First real run would tell.
- Discord confirmation that a daily server fetch is welcome.
- Fearless draft or loss-of-ban games: check rows with "Loss of Ban" or "Missing Data" ([[leaguepedia-pb-template#^f4]]) are skipped.
