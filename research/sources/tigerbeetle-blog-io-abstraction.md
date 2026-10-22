---
title: A Programmer-Friendly I/O Abstraction Over io_uring and kqueue (TigerBeetle blog, 2022)
url: https://tigerbeetle.com/blog/2022-11-23-a-friendly-abstraction-over-iouring-and-kqueue
kind: article
commit:
for: [zig-api-design]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/fair
description: central IO dispatch with per-op functions, caller-owned completions with callbacks, overflow queue, run_for_ns loop; single thread
---
# A Programmer-Friendly I/O Abstraction Over io_uring and kqueue (TigerBeetle blog, 2022)

Why: the design of TigerBeetle's IO layer; compare with Zig 0.16/0.17 `std.Io`.

## Assessment

- Evidence: B. By King Protty (Zig core team) and Phil Eaton; the design persists at
  0450c32 ([[tigerbeetle-code#^f31]]); Bun adopted the code.
- Reasoning: fair; walkthrough rather than trade-off analysis.
- Interests: none.
- Weigh: all code is Zig 0.9/0.10 (`@intToPtr`, `@ptrToInt`, two-argument
  `@intCast`, `os.socket`); stale. Predates `std.Io`, which now offers an
  interface-based alternative.

## Findings

- [zig/api] Don't weave io_uring handling into business logic; schedule IO through a
  central dispatcher with a callback and context. ^f1
  > this code ties io\_uring behavior directly to business logic
  > you might want to be able to schedule I/O and pass a callback (and sometimes with some application context) to be called when the event is complete.
- [zig/api] The caller drives the event loop by calling `run_for_ns`, a flush with a
  time limit. ^f2
  > Finally we’ll put the user in charge of setting up a loop to call this `run_for_ns` function, independent of normal program execution.
- [zig/api] [zig/memory] Requests that don't fit the ring go to an overflow queue made
  of intrusive completion structs rather than allocations. ^f3
  > accept a struct that can be used in an [intrusive linked list] to contain all request context, including the callback.
- [zig/api] Single-threaded userspace IO is simplest, best for non-parallel workloads
  and needed for deterministic simulation; parallel workloads may prefer per-thread or
  shared queues. ^f4
  > Keeping I/O code single-threaded in userspace is beneficial
  > But there are other valid architectures for other workloads.

## Read

- Whole post.
