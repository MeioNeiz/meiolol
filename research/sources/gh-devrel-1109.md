---
title: 'developer-relations #1109: ARAM Mayhem matches return 403'
url: https://api.github.com/repos/RiotGames/developer-relations/issues/1109
kind: thread
commit:
for: [match-v5-queues]
looked: 2026-10-11
depth: listed (issue and all 8 comments)
relevance: high
grade: B/fair
description: Bug report that match-v5 returns 403 for ARAM Mayhem matches; closed by a Riot engineer as expected behaviour, Mayhem matches are private
---
# developer-relations #1109: ARAM Mayhem matches return 403

Why: whether match-v5 serves ARAM Mayhem (Squads recaps want it).

## Assessment

- Evidence: B. Riot's official developer issue tracker; closing comment by
  lucasMesquitaBorges, whose GitHub profile says "Senior Backend Software Engineer at Riot
  Games" (the same person answers other match-v5 issues). Opened 2025-10-22 by metasrc (a
  stats site), closed 2025-12-18; still "private" per a 2026-03-31 comment.
- Reasoning: fair. States the policy, gives no reason.
- Interests: reporter is a stats site wanting the data.
- Weigh: trust the policy; the "new rotating modes will stay private" line is one
  developer's report of a private conversation.

## Findings

- [queues] [policy] match-v5 returns 403 Forbidden for ARAM Mayhem match ids, in every
  region. `raw/gh-devrel-1109.txt` ^f1
  > When I query the match API with ARAM: Mayhem game ids, I receive an error response with status 403 Forbidden
- [queues] [policy] A Riot engineer closed it as intended: Mayhem matches are private. ^f2
  > Expected behavior. Mayhem matches are private.
- [queues] [policy] Brawl was blocked from the API the same way, with a public DevRel
  announcement at the time. ^f3
  > as they were when Brawl was intentionally blocked from the API.
- [queues] [policy] (claim) A developer says Riot told him privately that new rotating modes
  (Doom Bots, Mayhem) are no longer meant to be public. ^f4
  > they seem to no longer intend to make the data for new rotating game modes publicly available
- [queues] [policy] As of 2026-03-31 nobody knew of plans to make Mayhem public. ^f5
  > No, its private, there are no plans for that to change that anyone is aware of

## Read

- Issue body and all comments
