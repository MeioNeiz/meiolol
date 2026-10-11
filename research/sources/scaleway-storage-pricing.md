---
title: Scaleway storage pricing (Object Storage and Glacier, Paris, 2026)
url: https://www.scaleway.com/en/pricing/storage/
kind: docs
commit:
for: [free-hosting-storage]
looked: 2026-10-11
depth: docs (Object Storage table)
relevance: medium
grade: A/fair
description: Scaleway's price list: Glacier EUR 0.00254/GB-month, One Zone EUR 0.00803, Multi-AZ EUR 0.01606, 75 GB egress free a month, restore EUR 0.009/GB
---
# Scaleway storage pricing (Paris, 2026)

Why: EU cold storage price (successor of C14) for bulk data

## Assessment

- Evidence: A. Vendor price list, Paris region.
- Reasoning: n/a.
- Interests: vendor.
- Weigh: minimum storage duration for Glacier not on this page; verify before use.

## Findings

- [ops] Glacier EUR 0.00254/GB-month (about EUR 2.60 per TB-month). ^f1
  > €0.00254/GB /MONTH
- [ops] Standard One Zone EUR 0.00803/GB-month; Multi-AZ EUR 0.01606. ^f2
  > €0.00803/GB /MONTH
  > €0.01606/GB /MONTH
- [ops] Requests and ingress included; 75 GB egress free a month then EUR 0.01/GB. ^f3
  > 75GB free every month then €0.01/GB /MONTH
- [ops] Restore from Glacier EUR 0.009/GB. ^f4
  > Restore from Glacier €0.009/GB
- [ops] Glacier storage is in an underground shelter in Paris. ^f5
  > Secure your precious data in our fallout shelter 25 meters underground.
- [ops] Checked, not there: no minimum storage duration stated on the price page. ^f6

## Read

- Object Storage table

## Not read

- Glacier docs (minimum duration, restore time)
