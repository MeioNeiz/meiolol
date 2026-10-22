---
title: Is Zig's New Writer Unsafe? (Karl Seguin, 2025)
url: https://www.openmymind.net/Is-Zigs-New-Io-Unsafe/
kind: article
commit:
for: [zig-api-design, zig-errors-safety]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: C/fair
description: Readers and writers can require minimum buffer sizes of each other; a too-small buffer asserts in Debug and loops in release
---
# Is Zig's New Writer Unsafe? (Karl Seguin, 2025)

Why: a buffer-size hazard of the 0.15 Io interfaces.

## Assessment

- Evidence: C. One practitioner's repro on 0.15 (Sep 2025) with zstd; no upstream
  response quoted.
- Reasoning: fair; concrete repro, argues it isn't only a docs issue.
- Interests: none known.
- Weigh: verify for the specific streams meiolol uses (zstd? flate?); read the stream's
  doc comment for buffer minimums.

## Findings

- [zig/safety] A stream may require a minimum buffer on the other side; zstd decompression streamed into a writer with a 64-byte buffer fails an assertion in Debug and loops forever in release. ^f1
  > with a small buffer of 64, fails an assertion in debug mode, and falls into an endless loop in release mode
- [zig/api] The requirement is documented per stream (e.g. zstd.Decompress) but a generic consumer can't know it. ^f2
  > It's true that the documentation for `zstd.Decompress` mentions what a `Writer`'s buffer must be. **But this is not a documentation problem**.
- [zig/test] The failure depends on input, so small tests can pass. ^f3
  > Worse is that the failure can be conditional on the input.
- [zig/api] Writers must be flushed: his example ends with `flush()`. ^f4
  > try writer.interface.flush();

## Read

- Whole post.
