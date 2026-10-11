---
title: OCI Compartment Quotas overview (Oracle docs)
url: https://docs.oracle.com/en-us/iaas/Content/Quotas/Concepts/resourcequotas.htm
kind: docs
commit:
for: [oci-payg-upgrade]
looked: 2026-10-11
depth: docs (overview)
relevance: medium
grade: A/fair
description: Oracle docs on compartment quotas: admin-set caps (set, unset, zero) on resource counts, alongside budgets
---
# OCI Compartment Quotas overview (Oracle docs)

Why: can we hard-cap the account to Always Free sizes after a PAYG upgrade?

## Assessment

- Evidence: A. Oracle's docs.
- Reasoning: fair.
- Interests: vendor.
- Weigh: exact quota names per service not read; check them when writing the policy.

## Findings

- [ops] Quotas cap how much of a resource can be used; `zero` removes access. ^f1
  > `set`: Sets the maximum number of a cloud resource that can be used for a compartment.
  > `zero`: Removes access to a cloud resource for a compartment.
- [ops] Oracle pitches quotas with budgets as the way to manage spend. ^f2
  > Along with compartment budgets, compartment quotas create a powerful toolset to manage your spending

## Read

- overview, quick start heading

## Not read

- Available Quotas by Service (exact quota names), sample quotas
