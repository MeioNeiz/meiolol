---
title: Zig's New Async I/O (Loris Cro, 2025)
url: https://kristoff.it/blog/zig-new-async-io/
kind: article
commit:
for: [zig-api-design, zig-perf, zig-errors-safety]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: A/strong
description: Zig team post on the std.Io interface: Io passed like Allocator, io.async/await/cancel, why buffering lives in Reader/Writer, sendFile and splat
---
# Zig's New Async I/O (Loris Cro, 2025)

Why: the design reasons behind `std.Io`, which meiolol uses everywhere.

## Assessment

- Evidence: A. Zig Software Foundation (VP Community), Jul 2025, describing Andrew
  Kelley's design ahead of 0.15/0.16.
- Reasoning: strong; goals, costs (virtual calls), roadmap.
- Interests: ZSF; ends with a donation request.
- Weigh: design reasons hold. Stale names: `io.asyncConcurrent` became `io.concurrent`
  (0.17 `std/Io.zig` has `pub fn concurrent(`), and `Future.cancel` returns the
  `Result` (no `catch {}` needed) in 0.17.

## Findings

- [zig/api] `Io` is provided by the caller, like `Allocator`, so the program author picks the I/O implementation for all dependencies. ^f1
  > Most importantly, the `Io` interface is now expected to be provided by the caller, just like we already do with `Allocator`.
  > The main implication of this change is that now the author of a program is able to decide the concrete I/O implementation and inject it also into code coming from dependencies.
- [zig/api] `io.async` expresses that order doesn't matter; under blocking I/O it runs the function immediately and `await` is a no-op, so the code stays correct. ^f2
  > it will still be correct when used with blocking I/O because `io.async` will immediately call `saveFile`, and `Future.await` will become a no-op.
- [zig/errors] Don't `try` the first of several awaits: an early return skips awaiting the others, and every future must be awaited or cancelled. ^f3
  > The reason why we can’t immediately use `try` is because if `try a_future.await(io)` were to trip, we would fail to await `b_future`. Futures are resources that need to be released so failing to await one is a programming error.
- [zig/errors] Pattern: `defer future.cancel(io)` right after `io.async`, then `try future.await(io)`; cancel and await are idempotent. ^f4
  > The API of `Future.cancel()` is identical to `Future.await()` aside from additionally requesting cancellation from the `Io` implementation. Both functions are idempotent.
- [zig/perf] `Io` is a non-generic vtable: less code bloat, virtual-call cost; with a single implementation in the program calls are to be guaranteed de-virtualised. ^f5
  > The new `Io` interface is non-generic and uses a vtable for dispatching function calls to a concrete implementation. This has the upside of reducing code bloat, but virtual calls do have a performance penalty at runtime.
- [zig/perf] Buffering in the Reader/Writer interface means a virtual call only on flush, even without de-virtualisation. ^f6
  > Buffering at the interface level means that even when no de-virtualization can happen, you will have to go through a virtual call only to flush the buffer, ensuring optimal behavior even in such case.
- [zig/api] `Writer` gains `sendFile` (kernel-side copy) and vectored `drain` with `splat`. ^f7
  > Being able to express this operation at the `Writer` interface level will allow you to create chains of writers where, for example, sending a file over HTTP will still allow you to leverage `sendfile`.
- [zig/api] Library authors need not use async everywhere: sequential code still fits the user's I/O strategy. ^f8
  > No, if you write normal sequential code, it will still be able to play nice with the overall I/O strategy chosen by your users.
- [zig/errors] Code that needs two tasks to overlap (server accept plus client connect) must request concurrency explicitly; `async` alone is a bug there. ^f9
  > `io.async` expresses _asynchrony_ (the possibility for operations to happen out of order and still be correct) and it does not request _concurrency_, which in this case is necessary for the code to work correctly.

## Read

- Whole post including FAQ.
