---
title: OCI Always Free Resources (Oracle docs, 2026)
url: https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm
kind: docs
commit:
for: [free-hosting-storage, oci-payg-upgrade]
looked: 2026-10-11
depth: docs (Compute, Block Volume, Object and Archive Storage, Outbound Data Transfer)
relevance: medium
grade: A/fair
description: Oracle's list of Always Free resources: 20 GB Object Storage total, 200 GB block volume, 10 TB/month egress
---
# OCI Always Free Resources (Oracle docs, 2026)

Why: what storage does the existing Always Free Oracle account give for free?

## Assessment

- Evidence: A. Oracle's own docs.
- Reasoning: fair.
- Interests: vendor.
- Weigh: binding for Always Free accounts; compute covered by another session.

## Findings

- [ops] Object Storage: 20 GB total per tenancy, Always Free. ^f1
  > All tenancies get a total of 20 GB of Always Free
- [ops] Block Volume: 200 GB total incl. boot volumes, plus five volume backups; home
  region only. ^f2
  > All tenancies receive a total of 200 GB of
  > To create an Always Free block volume, the volume must be created in the
- [ops] Outbound data: 10 TB per month free. ^f3
  > As part of your Always Free resources, you get 10 TB per month of outbound data.
- [ops] (inferred) 20 GB object storage fits a few weeks of rotated state snapshots
  (~150 MB each) but not bulk data; anything beyond needs Pay As You Go, which the
  account is not on. ^f4
- [ops] Out of host capacity: Oracle itself suggests upgrading to Pay As You Go, which
  gives access to more compute types; Always Free stays free after upgrading. ^f5
  > You can also choose to upgrade your account to Pay as You Go or another Paid account type, which gives you access to more types of Compute resources.
  > Remember that Oracle doesn't charge for Always Free resources after you upgrade
- [ops] A1 free allowance: 1,500 OCPU-h and 9,000 GB-h a month, 2 OCPU / 12 GB for
  Always Free tenancies. ^f6
  > All tenancies get the first 1,500 OCPU hours and 9,000 GB hours per month for free
- [ops] Idle Always Free instances (7 days under 20% CPU p95, network and A1 memory)
  may be reclaimed. ^f7
  > Idle Always Free compute instances may be reclaimed by Oracle.

## Read

- Block Volume, Object and Archive Storage, Outbound Data Transfer sections

## Not read

