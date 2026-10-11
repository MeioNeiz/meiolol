---
title: 'Riot DevRel: GDPR Right to be Forgotten Compliance (2018, updated 2019-03-04)'
url: https://www.riotgames.com/en/DevRel/gdpr-right-to-be-forgotten-compliance
kind: docs
commit:
for: [identity-and-privacy]
looked: 2026-10-11
depth: docs (whole post)
relevance: high
grade: A/weak
description: Riot's guidance to API developers on GDPR erasure: forgotten accounts are renamed rtbf(summonerID); remove associations and refresh accounts at least every 30 days
---
# Riot DevRel: GDPR Right to be Forgotten Compliance

Why: what Riot actually asks of developers when a player is erased, and whether there is
a refresh or retention expectation.

## Assessment

- Evidence: A. Riot DevRel post (28 Sep 2018, update 4 Mar 2019), still live and the
  article DevRel points to ([[riot-dev-terms#^f6]] describes the newer Riot Channels list
  method). Old: written for summoner names, which Riot ID has replaced, so the rename
  marker may now show as the del#number seen on OP.GG ([[opgg-help-privacy#^f2]]).
- Reasoning: weak. Recommendations, no rationale.
- Interests: Riot.
- Weigh: the only explicit refresh cadence Riot has published (30 days). Treat as the
  floor for a deletion sweep; also handle the Riot Channels identifier list.

## Findings

- [privacy] [policy] Erased accounts are renamed rtbf(summonerID) and set to level 1. ^f1
  > We are now renaming summoners to **rtbf(SummonerID)** and changing the level to 1 when a **RTBF** request is complete.
- [privacy] [policy] Riot tells developers API data may be GDPR personal data. ^f2
  > As a developer using the Riot Games API, you may have access to personal data subject to the GDPR.
- [privacy] [policy] On detecting the marker, remove associations with the account;
  refresh players' accounts at least every 30 days. ^f3
  > When you detect a summoner name following this format, we recommend removing any associations with the account that you may have. Additionally we recommend updating the accounts of players at least once every 30 days.
- [privacy] Dated 28 Sep 2018 (page header), updated 4 Mar 2019 after v4 ID encryption. ^f4
  > **UPDATE 03/4/19:** As a result of the v4 encryption of IDs, we have made some changes to the **GDPR** right to be forgotten process.
- [privacy] (inferred) For meiolol's crawler (stores PUUIDs and match data for months),
  a monthly sweep re-resolving stored PUUIDs, dropping erased ones, plus processing the
  Riot Channels list, meets the stated expectation. Match rows can keep the game but
  must drop the link to the erased PUUID. ^f5

## Read

- whole post

## Not read

- current Riot Channels mechanism (developer portal, needs login)
