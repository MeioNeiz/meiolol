---
title: Hetzner Object Storage overview (docs)
url: https://docs.hetzner.com/storage/object-storage/overview
kind: docs
commit:
for: [free-hosting-storage]
looked: 2026-10-11
depth: docs (Pricing section)
relevance: low
grade: A/fair
description: Hetzner docs on S3-compatible Object Storage billing: hourly base price with ~1 TB storage and ~1 TB egress quota, 64 kB minimum object size, free S3 operations
---
# Hetzner Object Storage overview (docs)

Why: an S3 alternative to the Storage Box in the EU

## Assessment

- Evidence: A. Vendor docs. Euro amounts are on the product page and loaded by script,
  not captured.
- Reasoning: fair.
- Interests: vendor.
- Weigh: structure only; get the base price before choosing it.

## Findings

- [ops] Base price per account, charged hourly with a monthly cap, even for an empty
  bucket. ^f1
  > You are charged for every hour you have at least one active Bucket, even if it's empty.
- [ops] Base price includes up to 720 TB-hours (1 TB for a 30-day month) and 1.08 TB
  egress. ^f2
  > | Month with 30 days | max. 720 TB-hour | max. 1.0800 TB |
- [ops] Ingress and S3 operations (PUT, GET, DELETE) are free. ^f3
  > S3 operations such as PUT, GET, or DELETE
- [ops] Minimum billable object size 64 kB; no minimum storage duration mentioned. ^f4
  > The minimum billable object size is the size that you will be charged for, even if the data actually stored is smaller.
- [ops] Checked, not there: no euro price on this page. ^f5

## Read

- Pricing section

## Not read

- product page price (script-rendered), locations beyond the endpoint list
