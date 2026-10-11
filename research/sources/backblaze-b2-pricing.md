---
title: Backblaze B2 Cloud Storage pricing (2026)
url: https://www.backblaze.com/cloud-storage/pricing
kind: docs
commit:
for: [free-hosting-storage]
looked: 2026-10-11
depth: docs (whole page)
relevance: high
grade: A/fair
description: Backblaze's official B2 price page: $6.95/TB-month, first 10 GB free, free egress to 3x storage, no minimum duration or file size fees
---
# Backblaze B2 Cloud Storage pricing (2026)

Why: price, free allowance, egress and minimum-retention for off-site backups and bulk data

## Assessment

- Evidence: A. Vendor's own price page, current on 2026-10-11.
- Reasoning: fair. Clear list; comparison calculator is marketing.
- Interests: vendor; competitor comparison numbers are theirs.
- Weigh: list prices trustworthy; the "vs AWS" savings figures are not evidence.

## Findings

- [ops] B2 starts at $6.95/TB/month, pay as you go monthly. ^f1
  > Starts at $6.95 / TB / mo
- [ops] [privacy] No minimum file size and no minimum storage duration fees, so deleting
  early (erasure) costs nothing extra. ^f2
  > No minimum file size or storage duration fees
- [ops] First 10 GB of storage always free. ^f3
  > First 10GB storage is always free.
- [ops] Egress free up to 3x average monthly storage, then $0.01/GB. ^f4
  > Up to 3x of average monthly data stored, then $0.01/GB for additional egress
- [ops] Class A, B, C calls free on pay as you go; Class D $0.004 per 10,000 after 2,500
  free a day. ^f5
  > Class A, B, and C API calls are free for pay-as-you-go customers. Class D transactions cost $0.004 per 10,000 calls plus the first 2,500 calls per day are free.
- [ops] (inferred) 0.6 TB after a year is about $4.20/month; 1.2 TB after two about
  $8.30. ^f6

## Read

- whole page

## Not read

- transaction-pricing page (what Class D covers), EU Central region availability
