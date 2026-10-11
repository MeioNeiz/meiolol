---
title: Amazon S3 pricing (2026)
url: https://aws.amazon.com/s3/pricing/
kind: docs
commit:
for: [free-hosting-storage]
looked: 2026-10-11
depth: docs (storage table, request footnotes, Free Tier section)
relevance: medium
grade: A/fair
description: AWS's S3 price page: Glacier Deep Archive $0.00099/GB-month with a 180-day minimum and 12-hour restores; Free Tier is now up to $200 credits for new accounts
---
# Amazon S3 pricing (2026)

Why: cheapest archive tier and its early-delete rules; AWS free tier state

## Assessment

- Evidence: A. Vendor price page; region selector default (US East assumed; EU
  regions cost a little more).
- Reasoning: n/a.
- Interests: vendor.
- Weigh: storage prices binding; egress table not captured (script-rendered).

## Findings

- [ops] S3 Glacier Deep Archive $0.00099 per GB-month (about $1 per TB-month). ^f1
  > | All Storage / Month | $0.00099 per GB |
- [ops] Deep Archive is for data accessed once or twice a year, restored within 12 hours. ^f2
  > For long-term data archiving that is accessed once or twice in a year and can be restored within 12 hours
- [ops] [privacy] Deep Archive minimum storage duration 180 days (Glacier Flexible and
  Instant 90); early deletes pay the remaining days. ^f3
  > S3 Glacier Deep Archive has a minimum storage duration of  180 days. Objects deleted prior to the minimum storage duration incur a pro-rated charge equal to the storage charge for the remaining days.
- [ops] Each archived object carries 40 KB of billed metadata. ^f4
  > AWS charges for 40 KB of additional metadata for each archived object
- [ops] S3 Standard $0.023 per GB-month for the first 50 TB. ^f5
  > | First 50 TB / Month | $0.023 per GB |
- [ops] Free Tier since 15 July 2025: up to $200 credits; free plan lasts 6 months,
  credits expire after 12 months. ^f6
  > As of July 15, 2025, new AWS customers will receive up to $200 in AWS Free Tier credits
  > The free plan will be available for 6 months after account creation.
- [ops] (inferred) 1 TB in Deep Archive is about $1/month, the cheapest found, but
  restores are slow and egress is not free; erasure within 180 days pays out the rest of
  the 180 days. ^f7

## Read

- storage table, request table footnotes, Free Tier section

## Not read

- data transfer (egress) table, retrieval per-GB prices
