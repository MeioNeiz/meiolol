---
title: OCI Budgets overview (Oracle docs)
url: https://docs.oracle.com/en-us/iaas/Content/Billing/Concepts/budgetsoverview.htm
kind: docs
commit:
for: [oci-payg-upgrade]
looked: 2026-10-11
depth: docs (overview)
relevance: medium
grade: A/fair
description: Oracle docs on budgets: soft limits with email alerts on actual or forecast spend, evaluated every 24 hours
---
# OCI Budgets overview (Oracle docs)

Why: can a budget stop surprise charges after a PAYG upgrade?

## Assessment

- Evidence: A. Oracle's docs.
- Reasoning: fair.
- Interests: vendor.
- Weigh: budgets warn, they don't stop spend; hard limits are quotas ([[oci-quotas]]).

## Findings

- [ops] Budgets are soft limits with alerts, not caps. ^f1
  > Use budgets to set soft limits on your Oracle Cloud Infrastructure spending.
- [ops] Alerts are evaluated every 24 hours, on actual or forecast spend, by email. ^f2
  > Alerts are evaluated periodically every 24 hours, and can be triggered when your actual or forecasted spending hits either a percentage of your budget or a specified set amount.

## Read

- overview

## Not read

- budget creation steps
