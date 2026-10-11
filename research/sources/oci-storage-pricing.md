---
title: Oracle Cloud price list, storage rows (2026)
url: https://www.oracle.com/cloud/storage/pricing/
kind: docs
commit:
for: [free-hosting-storage, oci-payg-upgrade]
looked: 2026-10-11
depth: docs (Storage table, Archive Storage row)
relevance: medium
grade: A/fair
description: Oracle's public price list (the storage pricing URL redirects to it): Object Storage Standard $0.0255/GB, Infrequent Access $0.01, Archive $0.0026 per GB-month
---
# Oracle Cloud price list, storage rows (2026)

Why: OCI Object and Archive Storage prices if the account moved to Pay As You Go

## Assessment

- Evidence: A. Oracle's price list; URL resolves to the global price list page.
- Reasoning: n/a (price list).
- Interests: vendor.
- Weigh: USD list prices; egress allowance in [[oci-always-free#^f3]].

## Findings

- [ops] Object Storage Standard $0.0255 per GB-month. ^f1
  > Object Storage - Standard — $0.0255 Gigabyte storage capacity per month
- [ops] Infrequent Access $0.01 per GB-month plus $0.01 per GB retrieved. ^f2
  > Object Storage - Infrequent Access - Retrieval
- [ops] Archive Storage $0.0026 per GB-month (about $2.66 per TB-month). ^f3
  > Oracle Cloud Infrastructure - Archive Storage — $0.0026 Gigabyte storage capacity per month
- [ops] Requests $0.0034 per 10,000. ^f4
  > Object Storage - Requests — $0.0034 10,000 requests per month
- [ops] Ampere A1 $0.01 per OCPU-hour and $0.0015 per GB-hour beyond the free
  allowance. ^f5
  > Compute – Ampere A1 – OCPU
- [ops] E5 $0.03 per OCPU-hour, $0.002 per GB-hour; E4 $0.025 and $0.0015. ^f6
  > Compute - Standard - E5 - OCPU
- [ops] Block Volume $0.0255 per GB-month plus $0.0017 per VPU-GB-month (10 VPUs for
  balanced). ^f7
  > Block Volume Performance Units

## Read

- Storage section, Archive Storage row

## Not read

- everything else on the 23k-word list
