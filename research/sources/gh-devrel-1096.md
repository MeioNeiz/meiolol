---
title: "developer-relations #1096: riot.txt domain verification silently fails"
url: https://api.github.com/repos/RiotGames/developer-relations/issues/1096
kind: thread
commit:
for: [riot-production-key]
looked: 2026-10-11
depth: listed (issue and all 2 comments)
relevance: medium
grade: B/fair
description: riot.txt verification failed because the host blocked Riot's old python-requests user agent; Riot engineer closed noting certificate issues fixed
---
# developer-relations #1096: riot.txt verification failure

Why: the only riot.txt-specific thread; practical gotchas for verification.

## Assessment

- Evidence: B. Reporter's diagnosis plus closing comment from a Riot engineer (lucasMesquitaBorges, profile: Senior Backend Software Engineer at Riot Games).
- Reasoning: fair.
- Interests: none.
- Weigh: user agent may have changed since; check host logs if verification fails.

## Findings

- [policy] Opened 2025-08-26: riot.txt in web root, verify click returns to "unverified" with no error. ^f1
  > the verification page just very quickly goes back to the app page with the status unverified without any kind of error message
- [policy] Unverified domain blocks progress of the production application. ^f2
  > This means i cannot verify my domain and progress with my applications for a prod key
- [policy] Cause (2025-08-31): web host returned 403 to Riot's verifier on user agent. ^f3
  > riot was getting blocked at a user agent level by my webhost, each time they requested the file they were getting a 403 responses even though the file exists
- [policy] Verifier's user agent was python-requests/2.11.1. ^f4
  > Your user agent currently presents as "python-requests/2.11.1"
- [policy] Riot engineer (2025-12-18) closed it, noting certificate validation issues by issuer were also fixed. ^f5
  > We also had some certificates validation issues depending on the issuer, which is now resolved.

## Read

- Whole thread
