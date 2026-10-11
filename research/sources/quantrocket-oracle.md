---
title: QuantRocket: Installation Tutorial for Oracle Cloud
url: https://www.quantrocket.com/installation/oracle/
kind: docs
commit:
for: [oci-payg-upgrade]
looked: 2026-10-11
depth: docs (Upgrade to Pay As You Go section)
relevance: medium
grade: C/weak
description: A trading-software vendor's Oracle setup guide: upgrade to PAYG to get past A1 Out of Capacity; upgrade takes a day or two
---
# QuantRocket: Installation Tutorial for Oracle Cloud

Why: does PAYG actually get A1 capacity?

## Assessment

- Evidence: C. One vendor's install guide, undated; works for its users presumably.
- Reasoning: weak. Asserted, no numbers.
- Interests: none on Oracle's side.
- Weigh: matches widespread community reports, but not Oracle's word.

## Findings

- [ops] (claim) PAYG gives access to a larger pool of Always Free resources, fixing
  Out of Capacity. ^f1
  > upgrade your account to Pay As You Go billing, which provides access to a larger pool of Always Free resources
- [ops] Upgrade not instant: a day or two, email on completion; retry next day if it
  errors. ^f2
  > You may have to wait a day or two for the upgrade to complete.
- [ops] Path: Billing and Cost Management > Upgrade and Manage Payment, Individual
  account. ^f3
  > Open the navigation menu (hamburger icon) and click Billing and Cost Management > Upgrade and Manage Payment.

## Read

- signup and upgrade sections
