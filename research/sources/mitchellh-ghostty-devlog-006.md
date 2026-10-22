---
title: 'Ghostty Devlog 006: IO throughput (Mitchell Hashimoto)'
url: https://mitchellh.com/writing/ghostty-devlog-006
kind: article
for: [zig-perf]
looked: 2026-10-22
depth: docs (full)
relevance: medium
grade: B/strong
description: Feb 2024 devlog on IO throughput: SIMD scan and UTF-8 decode (7.3x, 16.6x), precomputed 3-stage codepoint width table, grapheme-break pair table under 1KB, CSI fast path; profile first, benchmarks vs memcpy and noop baselines
---
# Ghostty Devlog 006: IO throughput (Mitchell Hashimoto)

Why: how did Ghostty find and fix hot spots, and how did it measure them?

## Assessment

- Evidence: B. Benchmarks with spread (hyperfine-style output), wall-clock checks, honest
  caveat that the comparison table is contrived.
- Reasoning: strong. Each optimisation starts from a profile or a bottleneck, is measured
  against a do-nothing baseline, and the wall-clock gain is reported separately (Amdahl).
- Interests: comparison with other terminals is promotional; he disclaims blanket claims.
- Weigh: the method (profile, baseline, precomputed tables exploiting domain preconditions)
  transfers; the numbers are terminal-specific.

## Findings

- [zig/perf] Compilers rarely auto-vectorise beyond trivial loops, so SIMD is one place hand-written code still wins. ^f1
  > compilers are notoriously bad at [autovectorization](https://en.wikipedia.org/wiki/Automatic_vectorization) and with the exception of relatively trivial loops, compilers rarely autovectorize effectively.
- [zig/perf] Shipping binaries means one SIMD variant per instruction set and picking at runtime by CPU feature detection. ^f2
  > you must write a variation for each SIMD instruction set, compile each form, and choose the correct version at runtime using CPU feature detection
- [zig/perf] Benchmarks include a memcpy (just read) baseline, so "as fast as reading" is visible. ^f3
  > This means that in both cases above, our SIMD pipeline is reading _and parsing_ (in the case of UTF-8) text at roughly the same speed as simply reading the data into memory.
- [zig/perf] Microbenchmark gains shrink end to end because other bottlenecks remain (7.3x became 2x on `cat`). ^f4
  > The speedups are dramatically slower than the benchmarks above due to [other bottlenecks]
- [zig/perf] Profiling found 30% of per-character time in codepoint width, which set the next target. ^f5
  > we determined that _30% of the time taken for every printed character_ was spent calculating codepoint width.
- [zig/perf] Precompute the answer for every codepoint in a 3-stage table: compact and cache friendly. ^f6
  > I precalculated the codepoint width for _every single Unicode codepoint value_ and used a trie-like [3-stage lookup table]
- [zig/perf] Domain preconditions (no control chars, max width 2) remove branches from the table lookup. ^f7
  > we know terminals can handle at most double-width characters so we can clamp triple-width characters
- [zig/perf] With enough preconditions, grapheme-break state for every codepoint pair fits in under 1KB. ^f8
  > computing a lookup table of _every possible codepoint pair plus state_ takes up less than 1KB of memory.
- [zig/perf] The CSI fast path skips the state machine and assumes valid syntax, measured on a replayed real pty capture (1.4x to 2x). ^f9
  > We captured the pty stream from doing some work in Neovim and replayed it as fast as we could
- [zig/perf] Measurement hygiene: 10 runs averaged, range within 2%. ^f10
  > I `cat` the file 10 times and took the average.

## Read

- Full post

## Not read

- PRs 1472, 1485, 1486, 1494; the linked 3-stage table article
