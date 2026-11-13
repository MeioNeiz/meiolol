---
title: 'Trunc: Compressing SQLite databases with ZFS'
url: https://trunc.org/learning/compressing-sqlite-with-zfs
kind: article
commit:
for: [box-disk-headroom]
looked: 2026-11-13
depth: listed
relevance: medium
grade: C/fair
description: A log vendor copies two SQLite FTS databases onto ZFS lz4 and zstd-fast datasets and compares size and query times
---
# Trunc: Compressing SQLite databases with ZFS

Why: what ratio filesystem compression gets on real SQLite databases

## Assessment

- Evidence: C. One team's test on two of its own log databases (6.5 GB and 112 GB), a
  handful of queries, no write load measured.
- Reasoning: fair. Shows commands and numbers; no write or fragmentation test.
- Interests: vendor blog (log search product), not selling ZFS.
- Weigh: text log tables compress far better than our integer-heavy rows and already
  compressed blobs; our own chunk test is the number to use.

## Findings

- [ops] A 112 GB SQLite database took 36 GB on ZFS lz4 and 27 GB on zstd-fast. ^f1
  > 112G /uncompressed/ext4/DB2.db   36G /compressed/zfs/lz4/DB2.db   27G /compressed/zfs/zstd/DB2.db
- [ops] A smaller one went from 6.5 GB to 586 MB with lz4 (text logs). ^f2
  > It went down from **6.5G to 586M**, that's about 1/10 of size reduction.
- [ops] (claim) Full scans were faster compressed (less IO), point queries the same. ^f3
  > The LZ4 compressed database was faster in 3 out of the 5 tests. But all very closed to the uncompressed performance.
- [ops] (inferred) Their logs are text; our segments compress to 0.77 at 128 KB chunks,
  participants alone to 0.57, compact timelines barely (0.93)
  ([[box-disk-measure-1113#^f8]]). ^f4

## Read

- Whole article

## Not read

- Nothing left
