---
title: League Akari README (LCU toolkit)
url: https://github.com/LeagueAkari/LeagueAkari
kind: project
commit: 5109b2f7fcce6e02312e534cd1729ed0f2142b51
for: [riot-production-key]
looked: 2026-10-11
depth: docs (README, CHANGELOG grep, issue search)
relevance: medium
grade: B/fair
description: Popular open-source LCU toolkit (auto pick/ban, match analysis); unregistered, warns of ban and ToS risk
---
# League Akari README (LCU toolkit)

Why: the most popular open-source champ select tool on GitHub; does it claim Riot approval, and what does it say about risk?

## Assessment

- Evidence: B. 4,438 stars, 377 forks, created 2023-12, release v1.5.1 2026-07, last push 2026-10-01; widely used.
- Reasoning: fair. Candid disclaimer.
- Interests: none (free, open source).
- Weigh: the counter-example: an unregistered LCU tool that tells users it may break ToS; meiolol should look nothing like this in an application.

## Findings

- [tools] LCU-based client toolkit, Windows and macOS, Riot regions only (Tencent not supported). `README.md` ^f1
  > A League of Legends client toolkit based on the LCU API.
  > Most Riot-operated regions are supported. Tencent-operated servers are not supported.
- [policy] Disclaims Riot support or endorsement and warns use may violate ToS and risk bans. `README.md` ^f2
  > The developer is not responsible for any consequences, such as account bans or data loss, resulting from the use of this software.
  > **this application is not officially supported or endorsed by Riot Games**. All rights are reserved by Riot Games. Use it at your own risk, as it may violate the game's terms of service.
- [policy] (inferred) No sign of Riot registration or production key; it is the unapproved end of the spectrum and still distributed via GitHub. ^f3
- [policy] Issue #523 (2026-10-05, unverified user report, D quality): permanent NA ban while using auto matchmaking, auto accept and auto pick; maintainer only restates the risk warning. `issue-523.txt` ^f5
  > 开了自动匹配, 自动接受, 自动选英雄
  > 使用本软件需谨慎，我已告知可能的风险。
- [policy] Checked, not there: no README or CHANGELOG mention of a feature removed at Riot's request; removals in the changelog are technical. ^f4

## Read

- `README.md`; CHANGELOG grep for Riot, Tencent, removals; issue search for ban and Riot

## Not read

- Similar ban reports #149, #370, #403 (titles only)
- Source for auto pick/ban and opponent analysis modules
