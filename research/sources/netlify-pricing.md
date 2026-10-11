---
title: Netlify pricing (credit-based plans, 2026)
url: https://www.netlify.com/pricing/
kind: docs
commit:
for: [free-hosting-storage]
looked: 2026-10-11
depth: docs (plans, usage credits)
relevance: medium
grade: A/fair
description: Netlify's credit pricing: Free plan 300 credits a month; production deploys 15 credits each, bandwidth 20 credits per GB
---
# Netlify pricing (credit-based plans, 2026)

Why: does Netlify's free plan fit a site redeployed daily?

## Assessment

- Evidence: A. Vendor's own page, current on 2026-10-11.
- Reasoning: fair.
- Interests: vendor.
- Weigh: binding limits; free tiers change often, recheck before relying on one.

## Findings

- [ops] Free plan: $0 with a 300 credit limit a month. ^f1
  > 300 credit limit / month
- [ops] Each production deploy costs 15 credits. ^f2
  > Production deploys
  > 15 credits each
- [ops] Bandwidth costs 20 credits per GB. ^f3
  > 20 credits per GB
- [ops] (inferred) Daily deploys alone (~30 x 15 = 450 credits) exceed the free 300;
  with no deploys the cap is 15 GB bandwidth. Netlify Free does not fit a daily-updated
  site. ^f4

## Read

- plans, usage credit table

## Not read

- legacy plan terms, credit FAQ details
