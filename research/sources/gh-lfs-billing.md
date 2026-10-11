---
title: GitHub Docs: Git LFS billing
url: https://docs.github.com/en/billing/concepts/product-billing/git-lfs
kind: docs
commit:
for: [free-hosting-storage]
looked: 2026-10-11
depth: docs (whole page)
relevance: high
grade: A/fair
description: How GitHub bills Git LFS: 10 GiB storage and 10 GiB bandwidth free on Free/Pro, blocked or metered beyond, storage not recalculated on mid-month delete
---
# GitHub Docs: Git LFS billing

Why: can meiolol use GitHub to store backups or data, and what are the limits?

## Assessment

- Evidence: A. GitHub's own docs, current on 2026-10-11.
- Reasoning: fair.
- Interests: vendor (platform terms).
- Weigh: binding limits and policy wording.

## Findings

- [ops] GitHub Free and Pro include 10 GiB LFS storage and 10 GiB bandwidth. ^f1
  > GitHub Free 10 GiB 10 GiB
- [ops] With a $0 budget, LFS is blocked for the rest of the month instead of billed. ^f2
  > Budget set to $0 : You are not charged for overages, but Git LFS usage is blocked for the rest of the calendar month.
- [ops] Every push of a changed LFS file stores a full new copy. ^f3
  > When you commit and push a change to a Git LFS file, a new version of the entire file is pushed and the total file size is included in the repository owner's storage use .
- [ops] [privacy] Deleting LFS objects mid-month does not reduce that month's storage. ^f4
  > If you delete Git LFS objects partway through a calendar month, the storage usage for that month is not recalculated.
- [ops] Checked, not there: the per-GiB overage price is not in the page text (it points
  to the pricing calculator). ^f5

## Read

- whole page

## Not read

- GitHub pricing calculator (overage price per GiB)
