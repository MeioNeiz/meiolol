---
title: Google Cloud Free Tier and Free Trial (docs, 2026)
url: https://cloud.google.com/free/docs/free-cloud-features
kind: docs
commit:
for: [free-hosting-storage]
looked: 2026-10-11
depth: docs (Free Trial, Compute Engine, Cloud Storage, Cloud Run rows)
relevance: medium
grade: A/fair
description: Google Cloud free programme: $300 90-day trial plus Free Tier with one e2-micro VM in three US regions, 30 GB disk, 1 GB egress, 5 GB US-only storage
---
# Google Cloud Free Tier and Free Trial (docs, 2026)

Why: is the GCP e2-micro still free, and where?

## Assessment

- Evidence: A. Vendor's own page, current on 2026-10-11.
- Reasoning: fair.
- Interests: vendor.
- Weigh: binding limits; free tiers change often, recheck before relying on one.

## Findings

- [ops] One non-preemptible e2-micro VM a month, only in us-west1, us-central1 or
  us-east1. ^f1
  > 1 non-preemptible `e2-micro` VM instance per month in one of the following US regions:
- [ops] 30 GB-months standard persistent disk; 1 GB egress from North America a month. ^f2
  > 30 GB-months standard persistent disk.
  > 1 GB of outbound data transfer from North America to all region destinations (excluding China and Australia) per month.
- [ops] Cloud Storage free: 5 GB-months, US regions only. ^f3
  > 5 GB-months of regional storage (US regions only) per month
- [ops] Free Trial: $300 credit valid 90 days. ^f4
  > Signing up for the Free Trial creates a Free Trial billing account that is preloaded with $300 in free Welcome credit which is valid for 90 days.
- [ops] (inferred) 1 GB egress a month and US-only regions make the e2-micro worse than
  the Oracle micro (10 TB egress, London) for a public EUW site. ^f5

## Read

- Free Trial, Compute Engine, Cloud Storage, Cloud Run rows

## Not read

- other products' free rows
