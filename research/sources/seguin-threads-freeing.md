---
title: Zig: Freeing resources referenced in multiple threads (Karl Seguin, 2024)
url: https://www.openmymind.net/Zig-Freeing-Resources-Referenced-In-Multiple-Threads/
kind: article
commit:
for: [zig-memory]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/fair
description: A mutex doesn't stop one thread freeing a value another holds; atomic reference counting on heap entries, as in cache.zig
---
# Zig: Freeing resources referenced in multiple threads (Karl Seguin, 2024)

Why: ownership across threads (meiolol uses par.zig threads).

## Assessment

- Evidence: B. The pattern ships in his cache.zig; May 2024, Zig 0.13.
- Reasoning: strong; shows a too-narrow lock as a subtle bug.
- Interests: his own library.
- Weigh: stale names (`std.Thread.RwLock` is `std.Io.RwLock` from 0.16). His decrement
  uses `.monotonic`; standard refcounting uses release on decrement and acquire before
  freeing (inferred, see ^f6).

## Findings

- [zig/memory] A lock around the map doesn't stop one thread freeing a value another thread is still reading. ^f1
  > A mutex would serialize access to `lookup`, but that wouldn't stop thread 2 from freeing the value now referenced by thread 1.
- [zig/memory] Values stored inline in a hash map move when it grows; references to them become invalid. ^f2
  > as the hashmap grows any references to its values will become invalid
- [zig/memory] With threads, the rule becomes: free when the last reference goes; heap entries with an atomic refcount, the map holding one reference. ^f3
  > _the memory must be freed when the last reference is no longer needed_.
- [zig/memory] Acquire must happen under the lock, or another thread can drop the count to zero in between. ^f4
  > This opens the small window where another thread could `release` its own reference to this entry, possibly causing the entry to clean itself up.
- [zig/memory] Many workloads keep clear single ownership across threads and don't need this. ^f5
  > Some workloads maintain clear ownership and lifetimes across threads.
- [zig/memory] (inferred) His `release` uses `@atomicRmw(.Sub, ..., .monotonic)`; the usual safe ordering is `.release` on the decrement plus an acquire fence or `.acq_rel` before freeing. ^f6
  > if (@atomicRmw(usize, &self.rc, .Sub, 1, .monotonic) == 1) {
- [zig/errors] (inferred) His `put` registers `errdefer allocator.destroy(entry)` and then `errdefer entry.release()`; a failure after both would run release (which destroys the entry at rc 1) and then destroy again, a double free. Once ownership moves into a release-style cleanup, end the earlier errdefer's scope. ^f7
  > errdefer entry.release();

## Read

- Whole post.
