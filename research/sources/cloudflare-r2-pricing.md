---
title: Cloudflare R2 pricing (docs, updated 2026-10-01)
url: https://developers.cloudflare.com/r2/pricing/
kind: docs
commit:
for: [free-hosting-storage]
looked: 2026-10-11
depth: docs (whole page)
relevance: high
grade: A/fair
description: Cloudflare's official R2 object storage price list: free tier, Standard and Infrequent Access prices, no egress fees, minimum storage durations
---
# Cloudflare R2 pricing (docs, updated 2026-10-01)

Why: what does R2 cost for off-site backups and bulk data, and what do deletes cost?

## Assessment

- Evidence: A. Vendor's own price list, dated 1 Oct 2026.
- Reasoning: fair. Worked examples; no SLA or durability figures on this page.
- Interests: vendor.
- Weigh: binding prices. Free tier is per account, Standard class only.

## Findings

- [ops] Standard storage $0.015/GB-month, Infrequent Access $0.01/GB-month. ^f1
  > | Storage | $0.015 / GB-month | $0.01 / GB-month |
- [ops] No egress charges for any storage class. ^f2
  > There are no charges for egress bandwidth for any storage class.
- [ops] Free tier: 10 GB-month storage, 1M Class A and 10M Class B operations a month. ^f3
  > | Storage | 10 GB-month / month |
- [ops] Free tier applies to Standard only, not Infrequent Access. ^f4
  > The free tier only applies to Standard storage, and does not apply to Infrequent Access storage.
- [ops] [privacy] Minimum storage duration: none for Standard, 30 days for Infrequent
  Access; early deletes of IA objects are billed for the full 30 days. ^f5
  > | Standard storage | None |
  > For objects stored in Infrequent Access storage, you will be charged for the object for the minimum storage duration even if the object was deleted, moved, or replaced before the specified duration.
- [ops] DeleteObject is a free operation. ^f6
  > Free operations include `DeleteObject`, `DeleteBucket` and `AbortMultipartUpload`.
- [ops] Infrequent Access adds a $0.01/GB retrieval fee on every read or copy. ^f7
  > | Data Retrieval (processing) | None | $0.01 / GB |
- [ops] Class A writes $4.50 per million (Standard). ^f8
  > | Class A Operations | $4.50 / million requests | $9.00 / million requests |
- [ops] (inferred) 1 TB in Standard is about $15/month; 0.6 TB/year growth means about
  $9/month after year one, $18 after year two. Backups of a few GB stay inside the free
  10 GB. ^f9

## Read

- whole page

## Not read

- R2 limits page (object size, buckets), data location and jurisdiction (EU) options
