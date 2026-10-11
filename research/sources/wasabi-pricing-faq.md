---
title: Wasabi Pay as You Go pricing FAQ (2026)
url: https://wasabi.com/pricing/faq
kind: docs
commit:
for: [free-hosting-storage]
looked: 2026-10-11
depth: docs (pricing table, minimums, free egress policy)
relevance: medium
grade: A/fair
description: Wasabi's pricing FAQ: $7.99/TB-month, 1 TB monthly minimum charge, 90-day minimum storage duration, free egress up to stored volume
---
# Wasabi Pay as You Go pricing FAQ (2026)

Why: Wasabi minimums and early-delete charges

## Assessment

- Evidence: A. Vendor FAQ.
- Reasoning: fair.
- Interests: vendor; comparisons with AWS are marketing.
- Weigh: the minimums are what matter for a small, growing store.

## Findings

- [ops] $7.99 per TB-month in North America, EMEA and APAC; egress and API calls free. ^f1
  > Wasabi Object Storage $7.99/mo ($.0078 GB/mo) Ingress Data Transfer = Free* Egress Data Transfer = Free* API Requests = Free*
- [ops] Minimum monthly charge equals 1 TB of active storage. ^f2
  > If you store less than 1 TB of active storage in your account, you will still be charged for 1 TB of storage
- [ops] [privacy] 90-day minimum storage duration: objects deleted earlier are billed for
  the remaining days. ^f3
  > if stored objects are deleted before they have been stored with Wasabi for a certain number of days (90 days when using the Wasabi Pay as You Go pricing model), a Timed Deleted Storage charge equal to the storage charge for the remaining days will apply.
- [ops] Free egress only while monthly egress stays at or below stored volume. ^f4
  > If your monthly egress data transfer is less than or equal to your active storage volume, then your storage use case is a good fit for Wasabi’s free egress policy
- [ops] (inferred) At meiolol's size Wasabi costs $7.99/month from day one and every
  overwritten daily snapshot is billed for 90 days; worse than B2 or R2 until well past
  1 TB. ^f5

## Read

- pricing table, minimum charge and duration, free egress policy

## Not read

- reserved capacity pricing
