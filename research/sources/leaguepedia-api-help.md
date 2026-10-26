---
title: "Leaguepedia: Help:Leaguepedia API"
url: https://lol.fandom.com/wiki/Help:Leaguepedia_API
kind: docs
commit: 
for: [leaguepedia-daily-fetch]
looked: 2026-10-26
depth: docs (whole page)
relevance: high
grade: A/fair
description: Leaguepedia's own API page: api.php endpoint, Cargo query fields, 500-row limit, logged-out ratelimits, join examples
---
# Leaguepedia: Help:Leaguepedia API

Why: may we query Leaguepedia from a server, how, and with what limits?

## Assessment

- Evidence: A. The wiki's own developer page, maintained by its staff; the reference every Leaguepedia client points to.
- Reasoning: fair. States rules and examples, little on why (no published rate numbers).
- Interests: none (a courtesy API, no paid tier).
- Weigh: trust the endpoint, limits and join keys; the ratelimit warning is vague on numbers.

## Findings

- [data] [policy] The API is offered as a courtesy, unofficial (not Riot), without guarantee of stability or accuracy; support only through their Discord. ^f1
  > the API is made available without guarantee of stability or accuracy
  > Our API is made available as a courtesy.
- [data] Endpoint is lol.fandom.com/api.php; reading needs no token, only editing does. ^f2
  > Just to make queries you do NOT need a token.
- [data] [policy] But anonymous cargo queries are ratelimited to near uselessness: log in with a bot password and a confirmed email first. ^f3
  > it is really important **to log in with a Bot Password and have your email address confirmed first**, as Fandom added ratelimits that make it practically impossible to execute queries while logged out
- [data] Max 500 rows per query (5,000 for admins); default limit 50. ^f4
  > 500 result per query otherwise
  > Can be 'max' or integer (default: 50)
- [data] Cargo takes tables, fields (no wildcards), where, join_on, order_by, group_by, having, limit, offset. ^f5
  > Cargo does not support `*` or wildcards
- [data] Official example joins ScoreboardGames, ScoreboardPlayers and Tournaments in one query (SG.GameId=SP.GameId, SG.OverviewPage=T.OverviewPage). ^f6
  > join\_on\="SG.GameId=SP.GameId, SG.OverviewPage=T.OverviewPage"
- [data] PicksAndBansS7 joins on GameId (via MatchScheduleGame, same GameId as ScoreboardGames). ^f7
  > `PicksAndBansS7.GameId = MatchScheduleGame.GameId`, `MatchScheduleGame.GameId = ScoreboardGames.GameId`
- [data] Row ids change on every data rebuild and no field is promised as a permanent key; use OverviewPage, not _pageName. ^f8
  > you shouldn't rely on any field we have as a permanent primary key
- [data] Recommended clients: mwrogue (Python, EsportsClient) and the unofficial leaguepedia_parser wrapper. ^f9
  > An unofficial wrapper for this API is available
- [data] List fields need `__full` appended to come back whole. ^f10
  > you should append `__full` to the name of the field
- [policy] Page footer: content under CC BY-SA 3.0 unless otherwise noted. ^f11
  > Content is available under [CC BY-SA 3.0](https://www.fandom.com/licensing) unless otherwise noted.
- [data] Checked, not there: no published request rate (per minute or hour) for anonymous or logged-in cargoquery. ^f12

## Read

- `raw/leaguepedia-api-help.md`: whole page.

## Not read

- Linked Discord `api-help` channel (may hold the actual numbers).
