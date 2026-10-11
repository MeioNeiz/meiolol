---
title: OCI Archive Storage overview (Oracle docs)
url: https://docs.oracle.com/en-us/iaas/Content/Archive/Concepts/archivestorageoverview.htm
kind: docs
commit:
for: [free-hosting-storage]
looked: 2026-10-11
depth: docs (overview, restore)
relevance: medium
grade: A/fair
description: Oracle docs on the Archive tier: 90-day minimum retention charged pro rata on early delete, restore up to an hour, retention rules
---
# OCI Archive Storage overview (Oracle docs)

Why: what early deletion (GDPR erasure) and restores cost on OCI Archive

## Assessment

- Evidence: A. Oracle docs.
- Reasoning: fair.
- Interests: vendor.
- Weigh: binding.

## Findings

- [ops] [privacy] Minimum retention 90 days; deleting or overwriting earlier is billed
  for the full 90 days. ^f1
  > The minimum storage retention period for the Archive tier is 90 days. If you delete or overwrite objects from the Archive tier before the minimum retention requirements are met, you are charged the prorated cost of storing the data for the full 90 days.
- [ops] Objects must be restored before download; restore takes at most an hour. ^f2
  > Restoration takes at most an hour from the time an Archive Storage restore request is made
- [ops] [privacy] Bucket retention rules (WORM) would block deletes entirely; must not
  be used for data under erasure. ^f3
  > You cannot update, overwrite, or delete objects

## Read

- overview, restore, retention rules paragraphs

## Not read

- lifecycle policy docs
