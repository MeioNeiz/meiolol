---
title: 'developer-relations #1020: Quickplay games with bots 404 on match-v5'
url: https://api.github.com/repos/RiotGames/developer-relations/issues/1020
kind: thread
commit:
for: [match-v5-queues]
looked: 2026-10-11
depth: listed (issue body; no comments)
relevance: medium
grade: C/fair
description: Open bug (2024-12) that Quickplay matches with bots appear in the id list but 404 on fetch
---
# developer-relations #1020: Quickplay games with bots 404 on match-v5

Why: whether every id the list returns can be fetched.

## Assessment

- Evidence: C. One developer's report (yearin.lol), open since 2024-12-21, no Riot reply.
  Our probe reproduces the 404 on its example id.
- Reasoning: fair. Clear repro and scale estimate.
- Interests: reporter runs a stats site.
- Weigh: plan for listed ids that 404; the crawler must skip them, not retry forever.

## Findings

- [queues] [data] Quickplay (490) games played with or against bots appear in a player's
  id list but 404 when fetched; mainly new accounts. `raw/gh-devrel-1020.txt` ^f1
  > When querying a players matchhistory the gameid for quickplay games that were played with/against bots show up in the history but when trying to actually get the data for that match the match 404s
- [queues] [data] Scale: a couple of hundred thousand games in 2024. ^f2
  > A couple hundred thousand games affected globally for 2024.

## Read

- Issue body
