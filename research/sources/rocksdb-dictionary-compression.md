---
title: 'RocksDB blog: Preset Dictionary Compression (2021)'
url: https://rocksdb.org/blog/2021/05/31/dictionary-compression.html
kind: article
commit:
for: [box-disk-headroom]
looked: 2026-11-13
depth: listed
relevance: high
grade: A/strong
description: RocksDB team on where zstd preset dictionaries pay: blocks of 8 KB or less in production, measurable gain up to 16 KB
---
# RocksDB blog: Preset Dictionary Compression (2021)

Why: would a trained zstd dictionary shrink our day file blocks

## Assessment

- Evidence: A. RocksDB (Meta) team, production deployments across many use cases.
- Reasoning: strong. Explains the mechanism (empty starting window on small inputs), the
  scope choices and their costs, and how they measure savings.
- Interests: none.
- Weigh: the block size bound is the transferable fact; our blocks are 1.5-30 MB plain.

## Findings

- [ops] Dictionaries help because small inputs start from an empty window and never fill
  it. ^f1
  > Compression algorithms relying on an adaptive dictionary, such as LZ4, zstd, and zlib, struggle to achieve good compression ratios on small inputs when using the basic compress API.
- [ops] Deployed for data blocks of 8 KB or less; meaningful gain measured only up to 16 KB
  blocks. ^f2
  > In production, we have deployed dictionary presetting to save space in multiple RocksDB use cases with data block size 8KB or smaller. We have measured meaningful benefit to compression ratio in use cases with data block size up to 16KB.
- [ops] A dictionary trained on adjacent data did substantially worse than one trained
  on the same file, so they moved to one dictionary per file. ^f3
  > the approach of training a dictionary on an adjacent file yielded substantially worse ratios than training the dictionary on the same file it would be used to compress
- [ops] Their typical dictionary size is 16 KB. ^f4
  > A typical value we use is 16KB.
- [ops] (inferred) Day file frames (256 documents, 1.5-30 MB before zstd) are two to three
  orders of magnitude past the size where a dictionary pays; our test agrees
  ([[box-disk-measure-1113#^f6]]). ^f5

## Read

- Whole post

## Not read

- API section details (ZSTD_CDict reuse): only matters for small blocks
