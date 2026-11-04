---
status: active
priority: now
area: ops
tags: [ops]
description: How should the box's data disk keep up with ~5.5 GB a day (complete form day files plus databases): retention, compression or more storage, and what does each cost?
---
# How should the box's data disk keep up with ~5.5 GB a day (complete form day files plus databases): retention, compression or more storage, and what does each cost?

Feeds: docs/plan/ops.md "Storage and hosts" (Jacob's call; options table in
data/team/2026-11-02-polish/notes/meiolol-research-disk.md)

## Answer

Our own measurements (2 Nov, in the notes file above) carry this: the disk fills in ~9
weeks at ~5.5 GB a day, and compression gains at most ~5% (zstd levels, long mode and
grouping add nothing over the codec), so the levers are more storage or retention.
Bought storage for 730 days of day files (~2.2 TB): a Hetzner 5 TB Storage Box at
EUR 10.90/month (C1), B2 at $6.95/TB-month (C2, ~$15/month at 2.2 TB), R2 twice that
(C3); Glacier Deep Archive is cheapest but its 180-day minimum fights the erasure
rewrites (C4). Free first: growing the disk image on Megatron (Ethan's).

## Claims

- C1: A 5 TB Hetzner Storage Box costs EUR 10.90 a month. for: [[hetzner-storage-box-prices#^f2]]
- C2: Backblaze B2 costs $6.95 per TB-month, no minimum duration. for: [[backblaze-b2-pricing#^f1]]
- C3: Cloudflare R2 standard storage costs $0.015 per GB-month. for: [[cloudflare-r2-pricing#^f1]]
- C4: S3 Glacier Deep Archive is ~$1 per TB-month. for: [[aws-s3-pricing#^f1]]

## Open

- A 4 TB NAS HDD's UK price (~GBP 95-135 from search snippets, not snapshotted)
- Whether Megatron's 3.0 TB free is ours to fill (Ethan)
- Growth at a production key's crawl rate
