---
title: ArenaAllocators don't play nicely with ArrayLists (Karl Seguin, 2026)
url: https://www.openmymind.net/Arena-Allocators-and-ArrayLists/
kind: article
commit:
for: [zig-memory, zig-perf]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: B/fair
description: Why ArrayList or Writer.Allocating growth in an arena wastes the old buffers, and the two mitigations
---
# ArenaAllocators don't play nicely with ArrayLists (Karl Seguin, 2026)

Why: arena plus growing container, a pattern meiolol uses.

## Assessment

- Evidence: B. Practitioner (http.zig, pg.zig maintainer), Aug 2026, Zig 0.16; quotes
  the std `array_list.zig` growth path. Checked against the 0.17 std arena: `free`
  still only reclaims the most recent allocation (`ArenaAllocator.zig` `fn free`).
- Reasoning: strong. Mechanism from the std code, bounded worst case, two mitigations.
- Interests: none known.
- Weigh: trust; the "~3x" worst case is his estimate.

## Findings

- [zig/memory] An arena `free` only returns memory if it was the last allocation and on the arena's current node. ^f1
  > The freed memory must have been the last allocated memory, and
- [zig/memory] ArrayList growth tries remap first; on failure it allocates new, copies, and frees old, so the old buffer is never the last allocation and an arena never reclaims it. ^f2
  > the allocate + copy + free guarantees that `old_memory` isn't the last allocation (the last allocation is `new_memory`).
- [zig/memory] The same applies to `std.Io.Writer.Allocating`. ^f3
  > there's a common situation where the first simpler rule isn't met: `ArrayList` (or `Writer.Allocating`) growth.
- [zig/perf] Mitigations: size the list up front (`initCapacity`, `ensureTotalCapacityPrecise`) and avoid interleaving other allocations with appends, so remap succeeds; in an arena the worst case is about 3x the memory. ^f4
  > First, size your `ArrayList` (e.g. with `initCapacity` or `ensureTotalCapacityPrecise`). Second, avoid interleaving other allocations with your appends/writes.
  > but with an `ArenaAllocator` the worst case is ~3x the memory.

## Read

- Whole post.
