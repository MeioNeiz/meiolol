---
title: Hetzner Storage Box product page (2026)
url: https://www.hetzner.com/storage/storage-box/
kind: docs
commit:
for: [free-hosting-storage]
looked: 2026-10-11
depth: docs (whole page, comparison table)
relevance: high
grade: A/fair
description: Hetzner's Storage Box overview: 1/5/10/20 TB backup boxes, unlimited traffic, SFTP/rsync/Borg/restic/rclone, snapshots, Germany or Finland, no minimum term
---
# Hetzner Storage Box product page (2026)

Why: is a Storage Box a cheap EU off-site target for SQLite backups and bulk data?

## Assessment

- Evidence: A. Vendor's own product page, 2026. Prices load by script and are missing
  from the snapshot; see [[hetzner-storage-box-prices]].
- Reasoning: fair. Feature table only.
- Interests: vendor.
- Weigh: features and terms binding; durability (RAID, single site) not stated here.

## Findings

- [ops] Four sizes: 1 TB, 5 TB, 10 TB and 20 TB (BX11, BX21, BX31, BX41). ^f1
  > Available storage 1 TB 5 TB 10 TB 20 TB
- [ops] Traffic is unlimited on every box. ^f2
  > Traffic Unlimited
- [ops] Access by SFTP, SCP, rsync over SSH, BorgBackup, restic, rclone, WebDAV, Samba. ^f3
  > You can use various access protocols such as FTP, SFTP, SCP, and RSYNC so that you can easily and securely access your Storage Box.
- [ops] [privacy] No minimum contract period; cancellation immediate. ^f4
  > Minimum Contract Period none
  > Cancellation period immediately
- [ops] Storage location Germany or Finland; a data processing agreement is available. ^f5
  > Storage location optional Germany or Finland
- [ops] Snapshots: 10 on BX11 up to 40 on BX41; boxes can be resized without migrating. ^f6
  > You can scale it up or down to fit your current needs, and without losing data or having to migrate it manually.
- [ops] (inferred) rsync over SSH matches the existing Mac mirror (`rsync --delete`), so
  erasure scrubs propagate the same way; encryption at rest would need restic, Borg or
  rclone crypt on our side. ^f7

## Read

- whole page

## Not read

- docs.hetzner.com Storage Box FAQ (redundancy, RAID), snapshot retention rules
