---
title: "developer-relations #697: production key limits differ from docs (2022)"
url: https://api.github.com/repos/RiotGames/developer-relations/issues/697
kind: thread
commit:
for: [riot-production-key]
looked: 2026-10-11
depth: listed (issue and all 7 comments)
relevance: low
grade: C/fair
description: 2022 production key holder saw 250/10s method limit and a lower app limit in headers; community says prod keys haven't started at 500/10s for a long time
---
# developer-relations #697: prod key limits vs docs (2022)

Why: an older data point that documented production limits were already stale in 2022.

## Assessment

- Evidence: C. One key holder's headers plus community comments.
- Reasoning: fair.
- Interests: none.
- Weigh: old; the app limit in headers may have been a mismatch for that key.

## Findings

- [data] Opened 2022-10-27: portal showed 250 requests per 10 s for an issued product key. ^f1
  > according that page got allotted 250 requests every 10 seconds as rate limit.
- [data] Headers showed app limit 20:1,100:120 (dev-key-like) alongside 250:10 method limit. ^f2
  > "x-app-rate-limit":"20:1,100:120"
- [data] Community: production keys haven't started at 500 per 10 s in a long time; docs out of date. ^f3
  > Production keys have not started at 500:10 in a really long time, that specific documentation is out of date
- [data] Community: implement caching; match details don't change and can be stored. ^f4
  > Match details can be cached or stored indefinitely as they are not going to change
- [data] Community: match data is removed from the API after 2 years, timelines after 1. ^f5
  > just deleted after 2 years, 1 year for timelines

## Read

- Whole thread
