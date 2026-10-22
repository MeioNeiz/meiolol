---
title: Enum of Arrays (TigerBeetle blog, matklad, 2024)
url: https://tigerbeetle.com/blog/2024-12-19-enum-of-arrays
kind: article
commit:
for: [zig-perf]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/fair
description: struct-of-arrays recap and its enum dual: one tag per homogeneous batch instead of one per item
---
# Enum of Arrays (TigerBeetle blog, matklad, 2024)

Why: data-oriented layout advice from TigerBeetle, relevant to meiolol's per-game and
per-champion tables.

## Assessment

- Evidence: B. Pattern explained with toy types; tied to TigerBeetle's homogeneous
  8k-operation batches but no benchmark.
- Reasoning: fair.
- Interests: none.
- Weigh: general data-oriented design; measure before adopting.

## Findings

- [zig/perf] Struct of arrays: amortised padding and less memory traffic when a loop
  needs only some fields; use SIMD across items, not within one. ^f1
  > Reduced memory usage due to amortized padding.
  > A bad way to use SIMD is to try to vectorize the processing of an individual item. A good way to use SIMD is to process several items at once.
- [zig/perf] Enum of arrays: one tag for a whole batch of one variant, saving tag bytes,
  variant padding and per-item branches. ^f2
  > The _key_ idea is that there’s only a single `tag` per an entire batch of things.
- [zig/perf] TigerBeetle batches are homogeneous (all transfers or all accounts); the
  tag is control plane, the arrays data plane. ^f3
  > Instead, TigerBeetle uses homogeneous batches.
  > The `tag` is control plane, a small, infrequent piece of information which informs decisions.

## Read

- Whole post.
