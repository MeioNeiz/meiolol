---
title: GitHub Docs: Repository limits
url: https://docs.github.com/en/repositories/creating-and-managing-repositories/repository-limits
kind: docs
commit:
for: [free-hosting-storage]
looked: 2026-10-11
depth: docs (Repository size, Activity)
relevance: high
grade: A/fair
description: GitHub's recommended and enforced repository limits: 10 GB on-disk recommendation, 2 GB push limit, 100 MB file limit, generated files belong in object storage
---
# GitHub Docs: Repository limits

Why: can meiolol use GitHub to store backups or data, and what are the limits?

## Assessment

- Evidence: A. GitHub's own docs, current on 2026-10-11.
- Reasoning: fair.
- Interests: vendor (platform terms).
- Weigh: binding limits and policy wording.

## Findings

- [ops] Recommended maximum on-disk repository size 10 GB. ^f1
  > **On-disk size**: 10 GB
- [ops] GitHub itself says to keep generated files out of Git, in object storage. ^f2
  > Store programmatically generated files outside of Git, such as in object storage.
- [ops] Push size enforced at 2 GB. ^f3
  > **Push size**: This limit is enforced at 2GB.
- [ops] File size: recommended 1 MB, enforced at 100 MB. ^f4
  > The recommended maximum limit is 1MB. This is enforced at 100 MB.

## Read

- Repository size, Activity sections

## Not read

- PR, diff and text limits (irrelevant)
