---
title: GitHub Docs: Removing sensitive data from a repository
url: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository
kind: docs
commit:
for: [free-hosting-storage]
looked: 2026-10-11
depth: docs (side effects, fully removing data)
relevance: high
grade: A/fair
description: GitHub's procedure for purging data from history: rewritten commits survive in clones, forks, cached SHA views and PRs; full removal needs GitHub Support and a server gc
---
# GitHub Docs: Removing sensitive data from a repository

Why: can meiolol use GitHub to store backups or data, and what are the limits?

## Assessment

- Evidence: A. GitHub's own docs, current on 2026-10-11.
- Reasoning: fair.
- Interests: vendor (platform terms).
- Weigh: binding limits and policy wording.

## Findings

- [privacy] [ops] After a history rewrite, old commits stay reachable in clones, forks,
  cached SHA views and pull requests. ^f1
  > If you only rewrite your history and force push it, the commits with sensitive data may still be accessible elsewhere:
  > Directly via their SHA-1 hashes in cached views on GitHub
- [privacy] Full removal needs GitHub Support to dereference PRs and run a server gc. ^f2
  > Run a garbage collection on the server to expunge the sensitive data from storage.
- [privacy] GitHub Support won't remove non-sensitive data and only helps when risk can't
  be mitigated by rotating credentials. ^f3
  > GitHub Support won't remove non-sensitive data, and will only assist in the removal of sensitive data in cases where we determine that the risk can't be mitigated by rotating affected credentials.
- [privacy] (inferred) A GDPR erasure from a git-hosted backup means rewriting history
  and asking Support each time, with no guarantee: git history is the wrong store for
  personal data. Releases (deletable assets) avoid history but not the AUP risk. ^f4

## Read

- side effects, fully removing data from GitHub

## Not read

- git-filter-repo steps
