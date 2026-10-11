---
title: 'zilean: Python library for match-v5 timeline analysis (docs)'
url: https://zilean.readthedocs.io/en/main/
kind: project
commit:
for: [riot-api-data-depth]
looked: 2026-10-11
depth: docs (index page)
relevance: low
grade: C/weak
description: Small 2022 hobby library that crawls timelines and turns minute snapshots into ML features
---
# zilean: Python library for match-v5 timeline analysis (docs)

Why: example of what community tooling derives from timelines (minute snapshots, gold@15).

## Assessment

- Evidence: C. Single-author 2022 hobby library, version 0.0.1.
- Reasoning: weak. Demo only.
- Interests: none.
- Weigh: confirms the common pattern (snapshot frames 10 and 15, compare gold by win),
  nothing more.

## Findings

- [data] [method] Timeline seen by the community as a per-minute record suited to ML, e.g.
  predicting results from stats before minute 16. ^f1
  > contains information of a specific [League of Legends](https://leagueoflegends.com/) match at **every minute mark**
  > For example, predicting match results using game statistics before the 16 minute mark.
- [data] Typical workflow: crawl a few thousand timelines of one tier, take snapshots at
  minutes 10 and 15, compare total gold by role against win. ^f2
  > Crawl 2000 Diamond RANKED\_SOLO\_5x5 timelines from the Korean server.
  > We will look at the player statistics at 10 and 15 minute mark.
- [data] Crawling even 2000 timelines on a personal key is flagged as slow. ^f3
  > This will take a long time!
