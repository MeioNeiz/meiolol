---
title: zig.guide - Allocators (Sobeston, Zig 0.15.2 version)
url: https://zig.guide/standard-library/allocators
kind: docs
commit:
for: [zig-memory]
looked: 2026-10-22
depth: docs (whole page)
relevance: low
grade: B/fair
description: Basics page: page_allocator cost, FixedBuffer, Arena, create/destroy, DebugAllocator, SmpAllocator, c_allocator
---
# zig.guide - Allocators (Sobeston, Zig 0.15.2 version)

Why: the beginner baseline, to compare with practitioners.

## Assessment

- Evidence: B. Long-running community guide (repo since 2020, 930 stars, 30
  contributors), versioned per Zig release; this page is the 0.15.2 version, last
  repo push Jan 2026 (no 0.16 version yet).
- Reasoning: fair; brief.
- Interests: none.
- Weigh: basics consistent with Seguin; doesn't cover juicy main (0.16).

## Findings

- [zig/perf] `page_allocator` makes a syscall per allocation and reserves whole pages: slow and wasteful for small allocations. ^f1
  > As asking the OS for memory requires a system call, this is also extremely inefficient for speed.
- [zig/memory] Arena: allocate many times, free once with `deinit`; `free` on it is a no-op. ^f2
  > Using `allocator.free` in this example would be a no-op (i.e. does nothing).
- [zig/memory] DebugAllocator trades speed for safety: prevents double free and use-after-free, detects leaks. ^f3
  > Zig's DebugAllocator is designed for safety over performance, but may still be many times faster than page\_allocator.
- [zig/perf] `SmpAllocator` is the high-performance general allocator, with few safety features. ^f4
  > For high performance (but very few safety features!), the Zig standard library offers [`std.heap.SmpAllocator`]
- [toolchain] Checked, not there: no 0.16 version of the guide (newest is 0.15.2). ^f5
  > Version: Zig 0.15.2

## Read

- Whole page.
