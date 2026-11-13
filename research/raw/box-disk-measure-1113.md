# Box data disk: growth per store and compression tests (our measurement, 2026-11-13)

Read-only on C01 (df, ls, du, admin-history.tsv, sqlite pragma page_count and
freelist_count); compression tests on the Mac: day file samples copied with nice and
ionice -c3 (2026-11-09: whole summary file, first 400 MB of timelines, first 150 MB of
mastery), backup segment 000033.db from the Mac mirror (~/Backups/meiolol/segments).
Scripts in the session scratchpad (cfd.py, chunks.py), Python 3.15 compression.zstd,
xz 5, brotli 1.

## Growth per store, 3-10 Nov (crawl at ~145k matches a day)

| store | size 13 Nov | per day mean | range |
|---|---|---|---|
| day files (complete/) | 25.9 GB | 2.84 GB | 2.25-3.48 (sealed 2-9 Nov) |
| timeline.db | 46.1 GB | 1.43 GB | 1.12-1.83 |
| meiolol.db | 35.7 GB | 0.85 GB | 0.68-1.05 |
| partials/ | 2.9 GB | 0.07 GB | 2.1 GB on 2 Nov |
| raw.db (buffer, goes at S6) | 24.7 GB | swings | |

Kept data grows about 5.2 GB a day.
Sealed day file split, 2-9 Nov means: timeline 1.84 GB, summary 0.47 GB, mastery 0.45 GB.
Matches stored per day 3-10 Nov: 121k-165k.

## Free space

df 13 Nov: /srv/meiolol 492G size, 140G used, 327G avail (GiB): 351 GB free.
meiolol.db: 8718893 pages of 4096, 3255052 free pages: 13.3 GB free inside the file.
raw.db: 6036110 pages, 5242880 free pages. timeline.db: 0 free pages.
The mastery table went from 8.9M rows to 1.4M rows on 11 Nov.
From a crawl at 5.2 GB a day, 351 GB less the 10 GB valve lasts about 66 days.
Health's 80% line (422 GB used of 528 GB) comes after about 52 days.
Megatron share (/srv/megatron): 4.6T size, 1.9T used, 2.8T avail.
Crawler: no match stored since 2026-11-10 18:01Z (TlsInitializationFailed on every call).

## Day file frames recompressed (ratio to the stored bytes)

Frames are 256 documents each, jsonpack then zstd -19 with window log 23.

| kind | frames | stored MB | plain MB per frame |
|---|---|---|---|
| summary | 48 | 40.5 | 3.01 |
| timeline | 24 | 132.2 | 21.80 |
| mastery | 48 | 18.7 | 1.46 |

| setting | summary | timeline | mastery |
|---|---|---|---|
| -19 wlog23 per frame (as stored) | 0.997 | 0.999 | 0.998 |
| -12 per frame | 1.020 | 1.042 | 1.060 |
| dictionary 110 KB, trained on first half, tested on second | 1.000 | 1.035 | 1.050 |
| dictionary 1 MB, trained on first half, tested on second | 1.002 | 1.019 | 1.048 |
| groups of 8 frames, -19 wlog27 long | 0.969 | 0.996 | 1.000 |
| groups of 8 frames, -19 wlog30 long | 0.969 | 0.996 | 1.000 |
| groups of 32 frames, -19 wlog27 long | 0.945 | 0.995 | 1.000 |
| groups of 32 frames, -19 wlog30 long | 0.945 | 0.995 | 1.000 |
| xz -9e, groups of 8 | 0.909 | 0.910 | 0.934 |
| brotli -q11 -w24, groups of 8 | 0.903 | 0.921 | 0.900 |

CPU per test: summary -19 19 s, xz 41 s, brotli 167 s for the same 144 MB; timeline -19 69 s, xz 126 s, brotli 483 s for 523 MB.

## Databases compressed in chunks (what btrfs or ZFS would store)

Segment 000033.db: 1410 MB, 147,438 matches, 84,656 compact timelines (9,965 bytes each).
By table: timelines 907 MB, participants 357 MB, bans 41 MB, the rest under 30 MB each.
Ratio of compressed to plain, compressed sizes rounded up to 4 KB sectors:

| chunk, level | whole segment | timelines table | participants table |
|---|---|---|---|
| 4K zstd -3 | 1.000 | 1.000 | 1.000 |
| 16K zstd -3 | 0.890 | 1.000 | 0.750 |
| 64K zstd -3 | 0.805 | 0.966 | 0.594 |
| 128K zstd -1 | 0.793 | 0.952 | 0.591 |
| 128K zstd -3 | 0.784 | 0.950 | 0.568 |
| 128K zstd -9 | 0.775 | 0.949 | 0.541 |
| 1M zstd -3 | 0.758 | 0.937 | 0.517 |

The compact timeline blobs are already compressed; participants (integer columns and
PUUIDs) compress to just over half at 128 KB chunks.
