---
title: 'HextechDocs: Crawling matches using the Riot Games API (2021)'
url: https://hextechdocs.dev/crawling-matches-using-the-riot-games-api/
kind: article
commit: 
for: [crawl-discovery]
looked: 2026-10-12
depth: listed
relevance: medium
grade: B/fair
description: Riot API community docs guide to the two standard ways of crawling ranked matches (ladder seed, participant snowball)
---
# HextechDocs: Crawling matches using the Riot Games API (2021)

Why: how do others discover matches to crawl, and what do they do about wasted calls?

## Assessment

- Evidence: B. Community docs site run from Riot's third-party developer Discord;
  describes what the community uses, no measurements.
- Reasoning: fair. Pros and cons per method, no numbers on calls per match.
- Interests: none known.
- Weigh: confirms the two standard methods; silent on recrawl scheduling or skipping
  inactive players, which is where our cost is.

## Findings

- [data] Method 1: page the ladder (league entries per division) for every ranked player, then their match lists; dedupe matches in a store. ^f1
  > League-v4 has a really powerful endpoint called getLeagueEntries that allows you to fetch every single ranked player in a given division.
  > You can optimize this by storing all the matches in a database or a cache layer to avoid fetching matches twice
- [data] Method 2: snowball from one player through the other 9 participants of each fetched match; no rank filter. ^f2
  > using the other 9 participants from that match, you start building up your list of players
  > Since you're not making any calls to league-v4, you won't be able to filter the data based on ranked tiers
- [data] Checked, not there: no advice on when to rescan a player, skipping inactive players, or using the ladder's wins/losses to tell who has played. ^f3

## Read

- Whole article (short).

## Not read

- Linked Discord: where crawler authors discuss scheduling; not searchable from here.
