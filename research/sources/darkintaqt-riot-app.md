---
title: Applying for an App in the Riot Games Developer Portal (DarkIntaqt blog)
url: https://darkintaqt.com/blog/riot-app-application
kind: article
commit:
for: [riot-production-key]
looked: 2026-10-11
depth: docs (whole post)
relevance: high
grade: B/fair
description: Third-party developer's practical notes on Riot app registration, dated 19 Aug 2026
---
# Applying for an App in the Riot Games Developer Portal (DarkIntaqt)

Why: practical, recent view of key types, limits and wait times.

## Assessment

- Evidence: B. First-hand report of an active Riot API developer (runs darkintaqt.com since 2020);
  dated August 19, 2026. Not Riot.
- Reasoning: fair. Gives reasons (limits same, long wait) but no data on sample size.
- Interests: none known; self-declared "not a lawyer".
- Weigh: contradicts official docs on default production limits; trust as recent practice,
  confirm with GitHub issues.

## Findings

- [policy] Post dated 19 August 2026. ^f1
  > August 19, 2026
- [policy] Personal keys usually auto-approved, same limits as development key, no 24h refresh. ^f2
  > Personal keys are nowadays usually auto approved (which could be useful) and give you the same rate limits as a development key.
- [policy] Production keys usually not accepted for personal research. ^f3
  > Production keys usually don't get accepted when they are for "personal research".
- [policy] [data] Default production limits do not differ from development; must ask with justification. ^f4
  > the default rate limits **DO NOT** differ from a development key. You have to ask for a higher rate limit and attach. justification
- [policy] Production keys need a valid domain to verify the app URL. ^f5
  > Production keys require a valid domain, which is needed in order to verify the apps URL.
- [policy] LoL production review about 5 to 8 months; put limit requests in the app description or a ticket right after creating. ^f6
  > Production keys take, depending on the game (League of Legends, Valorant, ...), around 5 to 8 months.
  > it is highly advised to put any further requests (e.g. limit increases) directly into the apps description or create a ticket directly after the app was created.
- [data] Dev-level limits (100 per 2 min) still allow 72,000 requests/day per region. ^f7
  > With normal limits (100:120), you can still to up to 72.000 requests a day per server.
- [data] [policy] Each key has its own PUUID encryption; upgrading means a new production app; ask to link encryption to the personal app id. ^f8
  > Each key comes with a new encryption, which means that the PUUIDs change.
  > When "upgrading" a personal key to a production key, by creating a new production app, ask in the description to link the encryption to the perosnal apps app id.
- [policy] GitHub barely monitored by Rioters. ^f9
  > The GitHub is barely monitored by Rioters and is not going to help you getting your app approved faster.

## Read

- whole post

## Not read

- other posts on darkintaqt.com/blog
