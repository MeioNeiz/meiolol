---
title: 'Btrfs documentation: Compression'
url: https://btrfs.readthedocs.io/en/latest/Compression.html
kind: docs
commit:
for: [box-disk-headroom]
looked: 2026-11-13
depth: listed
relevance: high
grade: A/fair
description: Btrfs transparent compression: 128 KiB chunks, zstd levels, and the cases where it is off (fallocate, nodatacow, direct IO)
---
# Btrfs documentation: Compression

Why: would filesystem compression shrink the box's SQLite databases, and does it fit
how C01's disk is set up (ext4 on a loop image with direct IO)

## Assessment

- Evidence: A. The filesystem's own documentation.
- Reasoning: fair. States behaviour and limits, few numbers.
- Interests: none.
- Weigh: the exceptions decide whether it would work for SQLite at all.

## Findings

- [ops] Data is compressed in 128 KiB chunks so random rewrites stay cheap; more extents
  means more metadata. ^f1
  > Data are split into smaller chunks (128KiB) before compression to make random rewrites possible without a high performance hit.
- [ops] zstd levels -15..15; 1-3 near real time, default 3. ^f2
  > levels 1..3 are near real-time with good compression
- [ops] Any file touched by fallocate is never compressed (SQLite can preallocate). ^f3
  > Any file that has been touched by the _fallocate_ system call will always be excepted from compression even if _force-compress_ mount option is used.
- [ops] Compression needs data checksums and copy on write, so nodatacow (the usual
  advice for database files on btrfs) turns it off. ^f4
  > Compression requires both data checksums and COW, so either _nodatasum_ or _nodatasum_ mount option/inode flag will result in no compression.
- [ops] Direct IO reads of compressed data fall back to buffered reads; from kernel 7.3
  direct IO writes are never compressed. ^f5
  > Direct IO reads of compressed data will always falls back to buffered reads.
  > Starting with kernel v7.3, no compression is performed, no matter if the inode has data checksums or not.
- [ops] (inferred) For us it means a new filesystem (btrfs or ZFS) in place of ext4 on the
  data disk, copy on write under SQLite's in-place page writes, for ~22% of the
  database bytes ([[box-disk-measure-1113#^f8]]). ^f6

## Read

- Whole page

## Not read

- Defragmentation page (CoW fragmentation of database files)
