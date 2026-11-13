---
title: 'Box data disk: growth per store and compression tests (our measurement, 2026-11-13)'
url: https://meio.lol/?measured=box-disk-measure-1113
kind: dataset
commit:
for: [box-disk-headroom]
looked: 2026-11-13
depth: ran
relevance: high
grade: A/fair
description: C01's data disk growth by store over 3-10 Nov, free space, and zstd/xz/brotli/dictionary tests on real day file frames and a backup segment
---
# Box data disk: growth per store and compression tests (our measurement, 2026-11-13)

Why: measure before choosing between retention, compression and more storage for C01's
data disk.

## Assessment

- Evidence: A. Our own box's numbers: eight days of admin-history.tsv (one row per 15
  min) and sealed day file sizes; recompression on 120 real frames of three kinds and a
  1.4 GB backup segment.
- Reasoning: fair. Plain sizes and ratios; samples are one day's frames (the head of the
  timeline and mastery files), not a whole week.
- Interests: none.
- Weigh: growth is at the personal key's rate; any key change rescales it. The chunk
  test models btrfs/ZFS sizes, not their speed under SQLite. The segment is a proxy
  for the live databases (no indexes beyond primary keys, no digests).
  Data/team notes: data/team/2026-11-13-max/rdisk.md.

## Findings

- [ops] At ~145k matches a day (3-10 Nov) kept data grows ~5.2 GB a day: day files 2.84,
  timeline.db 1.43, meiolol.db 0.85, partials 0.07. ^f1
  > | day files (complete/) | 25.9 GB | 2.84 GB | 2.25-3.48 (sealed 2-9 Nov) |
  > | timeline.db | 46.1 GB | 1.43 GB | 1.12-1.83 |
  > | meiolol.db | 35.7 GB | 0.85 GB | 0.68-1.05 |
  > Kept data grows about 5.2 GB a day.
- [ops] Day files split: timeline 1.84 GB, summary 0.47, mastery 0.45 a day. ^f2
  > Sealed day file split, 2-9 Nov means: timeline 1.84 GB, summary 0.47 GB, mastery 0.45 GB.
- [ops] 351 GB free on 13 Nov: ~66 days from a crawl at that rate, health's 80% line
  after ~52. ^f3
  > From a crawl at 5.2 GB a day, 351 GB less the 10 GB valve lasts about 66 days.
  > Health's 80% line (422 GB used of 528 GB) comes after about 52 days.
- [ops] meiolol.db holds 13.3 GB of free pages after the mastery table's prune on 11 Nov;
  Megatron has 2.8 TB free. ^f4
  > 3255052 free pages: 13.3 GB free inside the file.
  > Megatron share (/srv/megatron): 4.6T size, 1.9T used, 2.8T avail.
- [ops] Recompressing frames with zstd at -19, or in groups of 8-32 frames with long
  windows, saves 0-5.5% (summaries most, timelines and mastery under 1%); -12 costs
  2-6%. ^f5
  > | groups of 32 frames, -19 wlog30 long | 0.945 | 0.995 | 1.000 |
  > | -12 per frame | 1.020 | 1.042 | 1.060 |
- [ops] Trained dictionaries (110 KB, 1 MB) make frames 0-5% bigger. ^f6
  > | dictionary 110 KB, trained on first half, tested on second | 1.000 | 1.035 | 1.050 |
- [ops] xz -9e and brotli -q11 on groups of 8 frames save 7-10%; brotli took ~9x zstd
  -19's time on summaries. ^f7
  > | xz -9e, groups of 8 | 0.909 | 0.910 | 0.934 |
  > CPU per test: summary -19 19 s, xz 41 s, brotli 167 s for the same 144 MB.
- [ops] In 128 KB chunks at zstd -3 a backup segment shrinks to 0.78; participants to
  0.57, compact timelines only to 0.95 (already compressed). ^f8
  > | 128K zstd -3 | 0.784 | 0.950 | 0.568 |
- [ops] The crawler has stored nothing since 10 Nov 18:01Z (TLS errors on every call). ^f9
  > Crawler: no match stored since 2026-11-10 18:01Z (TlsInitializationFailed on every call).

## Read

- Everything in the raw file (we made it)

## Not read

- timeline.db's split between compact timelines and digests (a live dbstat stalls
  commits)
