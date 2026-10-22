---
title: Data Oriented Parallel Value Interner (matklad, 2023-04-23)
url: https://matklad.github.io/2023/04/23/data-oriented-parallel-value-interner.html
kind: article
commit: 
for: [zig-perf, zig-memory]
looked: 2026-10-22
depth: docs (whole post)
relevance: low
grade: C/fair
description: Untested design in Zig for a parallel interner: segmented lists that never move, struct-of-arrays values as u32 indexes, sharded maps and bulk index allocation per thread
---
# Data Oriented Parallel Value Interner (matklad, 2023-04-23)

Why: data-oriented layout ideas in Zig. Zig 0.10/0.11 era (`.Acquire` capitalised
atomic orders, now lowercase); a design sketch he never implemented.

## Assessment

- Evidence: C. "there will be no benchmarks as I haven’t implemented the thing".
- Reasoning: fair. Clear mechanisms, untested.
- Interests: none.
- Weigh: ideas only; the SoA value table mirrors Zig compiler's InternPool which did
  ship (verify there).

## Findings

- [zig/perf] Theoretical, no benchmarks, never implemented. ^f1
  > It should be fast, but there will be no benchmarks as I haven’t implemented the thing.
- [zig/memory] SegmentList: like ArrayList but growing never moves old items, so readers
  can hold references; 31 lazily allocated power-of-two segments cover u32 indexes. ^f2
  > Segmented list is like `ArrayList` with an extra super power that pushing new items does not move/invalidate old ones.
- [zig/perf] Struct-of-arrays value table: a value is a u32 index into `tag` and `data`
  arrays; large payloads live in per-kind side arrays. ^f3
  > Of course we will struct-of-array it now
- [zig/safety] Invariant: possessing an index proves the item is allocated, initialised
  and published; manufacturing indexes out of thin air is unchecked. ^f4
  > we will rely on an invariant that we always use indexes provided to use by someone else
- [zig/perf] Reduce contention by sharding (16 mutexes and maps by hash bits) and by
  threads reserving index blocks with one atomic add, which also improves locality. ^f5
  > we can amortize atomic increments by allowing each thread to bulk-allocate indexes.

## Read

- Whole post (pseudo-code skimmed).
