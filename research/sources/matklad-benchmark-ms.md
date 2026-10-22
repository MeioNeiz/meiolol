---
title: Benchmark In Milliseconds (matklad, 2026-10-05)
url: https://matklad.github.io/2026/10/05/benchmark-milliseconds.html
kind: article
commit: 
for: [zig-perf]
looked: 2026-10-22
depth: docs (whole post)
relevance: low
grade: B/fair
description: Size micro benchmark inputs so a run takes about 300ms: integer ms, fixed costs vanish, human-perceptible, still fast to iterate
---
# Benchmark In Milliseconds (matklad, 2026-10-05)

Why: benchmark sizing. Language neutral.

## Assessment

- Evidence: B. Expert rule of thumb.
- Reasoning: fair. Four reasons; states the assumption (benchmarks for intuition, not
  precise measurement).
- Interests: none.
- Weigh: a rule of thumb.

## Findings

- [zig/perf] Tune benchmark input until it takes about 300ms. ^f1
  > My rule of thumb is to tweak the input size until the benchmark takes about 300ms
- [zig/perf] Below ~10ms fixed costs skew results; above a second, iterating is slow. ^f2
  > Anything faster than, say, `10ms` risks being skewed by fixed costs
  > But anything longer than a second makes _iterating_ on the benchmark slower than it needs to be.
- [zig/perf] Purpose: intuition to make a correct decision, not precise measurement. ^f3
  > the purpose of benchmarking isn’t so much a precise measurement of performance, but rather providing the author with enough intuition to make a correct decision.

## Read

- Whole post.
