---
title: "Leaguepedia user page: Avoiding cargo ratelimits (Arbolitoloco)"
url: https://lol.fandom.com/wiki/User:Arbolitoloco/Avoiding_cargo_ratelimits
kind: docs
commit: 
for: [leaguepedia-daily-fetch]
looked: 2026-10-26
depth: docs (whole page)
relevance: high
grade: B/fair
description: Leaguepedia admin's how-to for cargo ratelimits: bot password with the Cargo grant, confirmed email, retrying mwcleric fork
---
# Leaguepedia user page: Avoiding cargo ratelimits (Arbolitoloco)

Why: how do API users get past Fandom's cargo ratelimits?

## Assessment

- Evidence: B. A user page (flagged as not maintained by staff) by a Leaguepedia admin, linked from the official API help page.
- Reasoning: fair. Steps, no numbers.
- Interests: none.
- Weigh: the recipe; numbers still unknown.

## Findings

- [data] [policy] Logged-out cargo queries are really difficult since Fandom's new ratelimits. ^f1
  > Fandom added new ratelimits for cargo queries which make it really difficult to query while logged out.
- [data] Recipe: Special:BotPasswords, tick the Cargo grant, log in with it (mw:API:Login), confirm the account's email. ^f2
  > check the ⁨⁨⁨⁨⁨Create, query and delete data through the Cargo extension⁩⁩⁩⁩⁩ box
  > Make sure you have confirmed your email address
- [data] Recommends a mwcleric fork that retries failed (ratelimited) queries. ^f3
  > install a modified version of mwcleric (dependency of mwrogue) to retry failed queries

## Read

- `raw/leaguepedia-cargo-ratelimits.md`: whole page.

## Not read

- Nothing more on the page.
