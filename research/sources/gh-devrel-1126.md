---
title: "developer-relations #1126: Honorus pending 45+ days; prod key limits and increases"
url: https://api.github.com/repos/RiotGames/developer-relations/issues/1126
kind: thread
commit:
for: [riot-production-key]
looked: 2026-10-11
depth: listed (issue and all 5 comments)
relevance: high
grade: C/fair
description: Community regulars state 6-9 month waits, that prod keys start at dev-key limits, increases come after approval, and docs' 500/10s figure is stale
---
# developer-relations #1126: production key limits and increases

Why: the most explicit 2026 statements on what rate limits a newly approved key gets.

## Assessment

- Evidence: C. Community regulars (DarkIntaqt, Cypherous, Token07), not Riot staff; consistent with #1188 and #697.
- Reasoning: fair. They contrast the docs and explain why they think the docs are stale.
- Interests: none obvious; regulars of the Riot API Discord.
- Weigh: plausible and repeated, but verify on approval by reading the app's limits in the portal.

## Findings

- [policy] Opened 2026-01-08; app pending 45+ days; applicant cites dev key limit 100 req/2min. ^f1
  > The Development Key rate limits (100 req/2min) are causing issues:
- [policy] Community (2026-01-08): average wait 6-9 months and rising. ^f2
  > the average waiting time is 6-9 months (by now) and steadily increasing.
- [data] [policy] Community: a production key has the same limits as a dev key; ask for an increase during or after approval. ^f3
  > a production key still has the same limits as a dev key. You need to ask for a rate limit increase on the prod key while or after it has been approved.
- [data] [policy] Community: dev keys cannot get increases; the ticket system for increases has a months-long backlog. ^f4
  > Dev keys are not subject to API limit increases, and even if they were, the support ticket system used for those requests also has a several month backlog aswell
- [policy] (claim) Queue is first-in first-out, and editing the app reportedly resets your place. ^f5
  > The queue is processed in the order applications are received and also editing the app also apparently resets your place in the queue so don't do that either
- [data] Docs still say production keys start at 500 per 10 s and 30,000 per 10 min (quoted 2026-05-07). ^f6
  > 500 requests every 10 seconds
  > 30,000 requests every 10 minutes
- [data] [policy] Community: dev portal docs on limits and timeframes are years old and should be treated as out of date. ^f7
  > Anything regarding specific limits or timeframes should be considered out-of-date at this point.

## Read

- Whole thread (2026-01-08 to 2026-05-07)
