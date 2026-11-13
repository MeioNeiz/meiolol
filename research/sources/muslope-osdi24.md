---
title: 'muSlope: High Compression and Fast Search on Semi-Structured Logs (OSDI 2024)'
url: https://www.usenix.org/system/files/osdi24-wang-rui.pdf
kind: paper
commit:
for: [box-disk-headroom]
looked: 2026-11-13
depth: skimmed (sections 1, 2, 8.2)
relevance: high
grade: A/strong
description: YScope/Uber/Toronto archive for JSON logs: merged schema tree, columnar per path, dictionaries, then zstd; 2.34x zstd's ratio on 21 datasets
---
# muSlope: High Compression and Fast Search on Semi-Structured Logs (OSDI 2024)

Why: the state of the art for archiving many JSON documents; how far past generic zstd a
structural codec gets, so we know whether jsonpack has room left

## Assessment

- Evidence: A. Peer-reviewed (OSDI), 21 datasets, deployed at Uber (CLP).
- Reasoning: strong. Compares many systems, breaks down where bytes go.
- Interests: authors' own system (YScope sells CLP).
- Weigh: ratios are on logs (more repetitive than match JSON); the relative gain over
  zstd and LZMA is the transferable part.

## Findings

- [ops] Structure: records' schema trees merged, values stored per leaf path in columns,
  strings in dictionaries, then compressed. ^f1
  > Each ERT is stored and compressed in a columnar order.
- [ops] On its JSON datasets it beats zstd's ratio 2.34x and LZMA's 1.70x (default
  levels). ^f2
  > dard’s, LZMA’s, and CLP’s compression ratios by factors of
  > 2.34x, 1.70x, and 1.50x respectively
- [ops] Columnar database setups did much worse: ClickHouse under 4:1 at Uber. ^f3
  > Its overall compression ratio on our setup is less than 4:1
- [ops] Dictionaries took 26.3% of the compressed bytes on one dataset, columns the rest. ^f4
  > for 26.3% of the storage space, with the remaining 73.7%
- [ops] (inferred) jsonpack is this design (shape dictionary, one stream per path, per
  path string dictionaries, zstd) and got a similar gain: timelines 21.7 KB against the
  archive's 44 KB zstd stream (ops.md "Complete form" S2), about 2x. The structural
  lever is taken. ^f5

## Read

- Sections 1-2 and 8.2 (compression results)

## Not read

- Search design (sections 4-7): we do not search the day files in place
