---
title: InfoQ: Oracle halves Always Free A1 allowance (Jul 2026)
url: https://infoq.com/news/2026/07/oracle-cloud-free-tier-limits/
kind: article
commit:
for: [oci-payg-upgrade]
looked: 2026-10-11
depth: docs (whole article)
relevance: high
grade: B/fair
description: InfoQ news: June 2026 cut of free A1 from 3000/18000 to 1500/9000 OCPU/GB-hours; unclear whether PAYG keeps the old allowance
---
# InfoQ: Oracle halves Always Free A1 allowance (Jul 2026)

Why: what is the free A1 allowance now, and does PAYG change it?

## Assessment

- Evidence: B. Tech press summarising docs diffs, Reddit and support emails.
- Reasoning: fair. Says what is unconfirmed.
- Interests: none.
- Weigh: the 1500/9000 figure matches Oracle's docs ([[oci-always-free]]); PAYG
  exemption is hearsay.

## Findings

- [ops] Free A1 halved to 1,500 OCPU-h and 9,000 GB-h a month (from 3,000/18,000). ^f1
  > The new allowance of 1,500 OCPU hours and 9,000 GB hours halves that capacity.
- [ops] (claim) Support reportedly told users PAYG keeps 4 OCPU / 24 GB free; Oracle has
  not said so publicly. ^f2
  > PAYG accounts may still use 4 OCPUs and 24 GB at no charge.
  > As of publication, Oracle has not issued a public clarification
- [ops] People upgraded to PAYG for easier A1 provisioning. ^f3
  > Pay-As-You-Go users who had upgraded their accounts to gain easier instance provisioning
- [ops] Advice: keep A1 within 2 OCPU / 12 GB total. ^f4
  > ensure total usage does not exceed 2 OCPUs and 12 GB of RAM across all instances in your tenancy

## Read

- whole article
