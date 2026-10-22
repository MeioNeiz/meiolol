---
title: Choosing an Allocator (Ziggit thread, 2025)
url: https://ziggit.dev/t/choosing-an-allocator/10743
kind: thread
commit:
for: [zig-memory]
looked: 2026-10-22
depth: docs (whole thread)
relevance: high
grade: B/fair
description: Which allocator when: DebugAllocator vs smp_allocator vs c_allocator, arena for CLI, the 0.14 conditional main pattern, cleanExit
---
# Choosing an Allocator (Ziggit thread, 2025)

Why: allocator choice in main and libraries.

## Assessment

- Evidence: B. Quotes squeek502 (std contributor); answers by IntegratedQuantum (Cubyz)
  and vulpesx citing the 0.14 release notes. Jun-Jul 2025, 0.14. 0.16's juicy main now
  supplies `init.gpa`, which supersedes the hand-written selection.
- Reasoning: fair to strong; explains why DebugAllocator is slow, thread safety.
- Interests: none.
- Weigh: trust; `ThreadSafeAllocator` advice from the old langref is gone (removed 0.16).

## Findings

- [zig/memory] squeek502: with the pass-an-allocator convention you rarely choose an allocator outside `main`, bar the odd arena; libraries don't choose at all. ^f1
  > in my experience it’s basically never necessary to choose an allocator beyond `main` (except for the odd `ArenaAllocator` wrapping a passed in allocator here and there). And when writing a library, you basically don’t have to worry about choosing an allocator at all–that’s for the user of your library to decide.
- [zig/perf] GeneralPurposeAllocator was renamed DebugAllocator because it is slow; `smp_allocator` is the fast general allocator, reportedly faster than libc's. ^f2
  > Recently the GPA was renamed to DebugAllocator and a new faster general purpose allocator `std.heap.smp_allocator` was introduced which, according to https://github.com/ziglang/zig/issues/12484, seems to be faster than the libc allocator, so that advice is likely obsolete.
- [zig/memory] The 0.14 notes' pattern: DebugAllocator in Debug/ReleaseSafe, `smp_allocator` in ReleaseFast/Small, leak check only when debugging. ^f3
  > .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
- [zig/memory] DebugAllocator is thread-safe by default (configurable off). ^f4
  > Also note that the DebugAllocator is thread-safe by default, so you don't even have to think about this most of the time.
- [zig/memory] Share one allocator across threads whenever memory is freed on a different thread from where it was allocated. ^f5
  > Every time you want to free data in another thread than it is allocated.
- [zig/memory] `std.process.cleanExit` verifies cleanup in debug builds and just exits in release. ^f6
  > But in release modes it just exits.  Since the OS is going to reap the entire process memory, releasing anything which was still held onto before exiting just wastes clock time.
- [zig/test] `FailingAllocator` tests OOM-handling paths; `testing.allocator` for normal tests. ^f7
  > So the failing allocator is like a dummy allocator that always fails?

## Read

- Whole thread.
