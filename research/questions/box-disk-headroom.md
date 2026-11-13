---
status: answered
priority: now
area: ops
tags: [ops]
description: How should the box's data disk keep up with ~5.5 GB a day (complete form day files plus databases): retention, compression or more storage, and what does each cost?
---
# How should the box's data disk keep up with ~5.5 GB a day (complete form day files plus databases): retention, compression or more storage, and what does each cost?

Feeds: docs/plan/ops.md "Storage and hosts" (D1-D5; Jacob's call on D2). Measurements:
[[box-disk-measure-1113]] (13 Nov), first pass data/team/2026-11-02-polish/notes/
meiolol-research-disk.md (2 Nov).

## Answer

At the personal key's ~145k matches a day, kept data grows ~5.2 GB a day: day files
2.84, timeline.db 1.43, meiolol.db 0.85, partials 0.07 (C5). The 351 GB free (less the
10 GB valve) lasts ~66 days from a crawl at that rate, health's 80% line ~52 (C6); the
crawler has stored nothing since 10 Nov 18:01Z, so the clock is paused, not gone. A
production key's limits are 60x the personal key's (C13): at even 5x the crawl the disk
lasts two weeks, so the plan has to be built for that.

Compression is spent. The day files already use the design the literature puts at ~2x
zstd (schema tree, a stream per path, dictionaries, then zstd; C7), and recompressing
their frames gains next to nothing with zstd: levels, long windows and groups of frames
save under 1% on timelines (5.5% on summaries), trained dictionaries make it worse (C8), as RocksDB's
16 KB bound predicts for 1.5-22 MB frames (C9). xz -9e and brotli -q11 save 7-10% at
2-9x the CPU (C10). Filesystem compression would take ~22% off the databases
(participants 0.57, compact timelines 0.95; C11), ~0.5 GB a day, but only with btrfs or
ZFS in place of ext4 under SQLite (C12). Lichess, facing the same full disk, did the
codec and bought servers (C14); our codec half is done.

So the levers are storage and retention (C15). Recommended (C16): grow the disk image on
Megatron to ~1 TB before the 80% alert (free, Ethan's yes, ~100 more days; Megatron has
2.8 TB free); then a rolling window: day files past 90 days leave C01 (~260 GB held
flat) and live on the Megatron mirror plus an off-site Hetzner 5 TB Storage Box at
EUR 10.90 a month net (C1), which holds 730 days at today's rate (~2.1 TB) and is the
first off-site copy. That ends Jacob's 30 Oct rule that C01 keeps every document, so it
is his call; the rule-keeping alternative is a 4 TB disk in Ethan's host (~GBP 100-135
once, not snapshotted), which a production key would outgrow within months.

## Claims

- C1: A 5 TB Hetzner Storage Box costs EUR 10.90 a month. for: [[hetzner-storage-box-prices#^f2]]
- C2: Backblaze B2 costs $6.95 per TB-month, no minimum duration. for: [[backblaze-b2-pricing#^f1]]
- C3: Cloudflare R2 standard storage costs $0.015 per GB-month. for: [[cloudflare-r2-pricing#^f1]]
- C4: S3 Glacier Deep Archive is ~$1 per TB-month. for: [[aws-s3-pricing#^f1]]
- C5: At ~145k matches a day (3-10 Nov) C01's kept data grows ~5.2 GB a day: day files
  2.84, timeline.db 1.43, meiolol.db 0.85, partials 0.07. for: [[box-disk-measure-1113#^f1]], [[box-disk-measure-1113#^f2]]
- C6: From a crawl at that rate the data disk's free space lasts ~66 days, health's 80%
  line ~52; meiolol.db's 13 GB of free pages absorb its first ~15 days. for: [[box-disk-measure-1113#^f3]], [[box-disk-measure-1113#^f4]]
- C7: Structural JSON archivers (merged schema, a column per path, dictionaries, then a
  general codec) reach ~2x zstd's ratio; jsonpack is one and got ~2x on timelines.
  for: [[muslope-osdi24#^f1]], [[muslope-osdi24#^f2]], [[muslope-osdi24#^f5]]
- C8: Recompressing day file frames with zstd gains next to nothing: -19 matches the
  stored bytes, -12 costs 2-6%, long windows and groups of 8-32 frames save under 1% on
  timelines and mastery (5.5% on summaries, a sixth of the bytes), trained dictionaries
  add 0-5%. for: [[box-disk-measure-1113#^f5]], [[box-disk-measure-1113#^f6]]
- C9: Preset dictionaries pay on blocks up to ~16 KB; our frames are 1.5-22 MB.
  for: [[rocksdb-dictionary-compression#^f2]], [[box-disk-measure-1113#^f6]]
- C10: xz -9e and brotli -q11 on groups of 8 frames save 7-10%, at 2-9x zstd -19's
  CPU. for: [[box-disk-measure-1113#^f7]]
- C11: Compressing the databases in 128 KB chunks (as btrfs does) saves ~22% of a backup
  segment: participants to 0.57, compact timelines only to 0.95. for: [[box-disk-measure-1113#^f8]], [[btrfs-compression-docs#^f1]]
  against: [[trunc-sqlite-zfs#^f1]] (text logs: 0.24-0.32)
- C12: Btrfs compression is off under nodatacow, fallocate and direct IO writes, so it
  means a new copy-on-write filesystem under SQLite. for: [[btrfs-compression-docs#^f3]], [[btrfs-compression-docs#^f4]], [[btrfs-compression-docs#^f5]]
- C13: A production key starts at 30,000 requests per 10 minutes per region, 60x the
  personal key's 100 per 2 minutes. for: [[riot-docs-portal#^f9]], [[riot-docs-portal#^f7]]
- C14: A large game archive facing a full disk did both: bigger servers and a denser
  domain codec. for: [[lichess-game-compression#^f1]], [[lichess-game-compression#^f4]]
- C15 (inferred): Storage and retention are the levers; compression adds at most ~10%.
  from: C7, C8, C10, C11
- C16 (inferred): Grow the image now (free), then a 90-day day file window on C01 with
  Megatron and a Hetzner box holding 730 days. from: C1, C5, C6, C13, C15

## Options

| Option | Growth on C01 | Headroom | Cost | Claims for | Claims against | Would change if |
|---|---|---|---|---|---|---|
| A. Grow disk.img on Megatron to ~1 TB | 5.2 GB/day | +~100 days | free; Ethan's yes; ~1 h | C6 | Megatron then holds image + mirror (~10 GB/day of its 2.8 TB) | Ethan says no |
| B. Day files past 90 days off C01 (Megatron mirror + off-site) | ~2.4 GB/day (databases) once 90 days pass | needs A first (90 days of day files ~256 GB); with A ~8 months, then the databases are the limit; a 30-day window on today's disk ~4 months | C's price | C5, C15 | Jacob's 30 Oct rule | a reader needs old days on C01 |
| C. Off-site store for B: Hetzner BX21 5 TB | | 730 days at today's rate | EUR 10.90/month net (~13 with VAT) | C1 | erasure must reach it | price; privacy.md |
| C'. Backblaze B2 instead | | any | ~$15/month at 2.1 TB | C2 | | |
| D. 4 TB disk in Ethan's host | 5.2 GB/day | ~2 years at today's rate | ~GBP 100-135 once | | single disk; production key outgrows it | Ethan's host has no bay |
| E. Thin timeline.db (digests, old compact timelines rebuilt from day files) | -0.5 to -1.4 GB/day | weeks | free | C5 | readers of old games | databases, not day files, fill first |
| F. Compression (xz/brotli frames, btrfs/ZFS for SQLite) | -0.3 to -0.5 GB/day | +~5-7 days | CPU, a filesystem migration | | C8, C10, C12 | a production key's growth makes 10% matter |

## Open

- A 4 TB NAS HDD's UK price (~GBP 95-135 from search snippets, not snapshotted)
- Whether Megatron's 2.8 TB free is ours to fill (Ethan)
- Growth at a production key's crawl rate: bounded by Platinum+ games played per day,
  not measured; measure it the first day (D4)
- timeline.db's split between compact timelines and digests (a dbstat on the box stalls
  commits; measure from a restored copy, not live)
