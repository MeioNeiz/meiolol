---
title: GitHub Docs: About releases
url: https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases
kind: docs
commit:
for: [free-hosting-storage]
looked: 2026-10-11
depth: docs (Storage and bandwidth quotas)
relevance: high
grade: A/fair
description: GitHub releases quotas: up to 1000 assets per release, each under 2 GiB, no total size or bandwidth limit
---
# GitHub Docs: About releases

Why: can meiolol use GitHub to store backups or data, and what are the limits?

## Assessment

- Evidence: A. GitHub's own docs, current on 2026-10-11.
- Reasoning: fair.
- Interests: vendor (platform terms).
- Weigh: binding limits and policy wording.

## Findings

- [ops] Up to 1000 assets per release, each under 2 GiB, no total size or bandwidth
  limit. ^f1
  > Up to 1000 release assets may be associated with a single release. Each file included in a release must be under 2 GiB. There is no limit on the total size of a release, nor bandwidth usage.
- [ops] (inferred) Technically a release could hold encrypted backup segments without
  a size cap, but [[gh-aup#^f1]] lets GitHub throttle or delete repos under undue strain,
  and releases are meant for distributing software ([[gh-large-files#^f5]]). ^f2

## Read

- Storage and bandwidth quotas

## Not read

- release management pages
