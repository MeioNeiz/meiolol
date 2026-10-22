---
title: Zig's Io.Threaded is Neat (matklad, 2026-08-06)
url: https://matklad.github.io/2026/08/06/neat-io-threaded.html
kind: article
commit: 
for: [zig-api-design, zig-errors-safety]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: B/strong
description: How std.Io.Threaded cancels blocking syscalls (flag plus signal loop, EINTR), error.Canceled, and io.async vs io.concurrent
---
# Zig's Io.Threaded is Neat (matklad, 2026-08-06)

Why: what std.Io (0.16+) gives for concurrency and cancelation. Links Zig std at
commit 16b42da (0.17 dev), so current.

## Assessment

- Evidence: B. Expert reading of the std source, with links to the two halves of the
  protocol; not a user report of running it.
- Reasoning: strong. Explains mechanism, prior art (Java interrupts, pthread_cancel) and
  why Zig's is better.
- Interests: none (not a Zig core member).
- Weigh: trust the mechanism; the "handle error.Canceled with care" point is the
  actionable part.

## Findings

- [zig/api] std.Io.Threaded is a "just use threads" Io implementation using blocking
  syscalls that fully supports cancelation. ^f1
  > `Io.Threaded` uses blocking syscalls and fully supports cancelation.
- [zig/api] Litmus test: concurrency invariably involves cancelation; parallelism is
  deterministic partitioning. ^f2
  > _Second_, concurrency invariably involves cancelation.
- [zig/api] On POSIX: the canceler sets a shared flag and signals the thread in a loop
  until acknowledged; on EINTR the cancelee checks the flag and retries or unwinds
  (`signalCanceledSyscall`, `fileReadPositionalPosix`). ^f3
  > the canceling thread sets a flag in shared memory to request cancelation, and then signals the cancelee, in a loop, until the cancelation is acknowledged
- [zig/errors] Cancelation reaches user code as `error.Canceled`; Zig implements
  cancelation and branching of error management, not reporting. ^f4
  > On the user-side, cancelation request is materialized as `error.Canceled`.
  > Error management as a feature is a combination of cancelation, branching, and reporting, and Zig implements the first two.
- [zig/api] [zig/errors] Reader and Writer interfaces type erase errors and so support
  cancelation, which needs extra care, on top of remembering to flush. ^f5
  > In Zig, reader and writer interfaces completely type erase errors and therefore support cancelation, though this requires some extra care to handle correctly
- [zig/api] Unlike pthread_cancel, cancelation integrates with `try` and `defer`, so
  cleanup after cancelation is ordinary unwinding. ^f6
  > However, it doesn’t integrate with language-level cancelation (`try`, `defer`) which makes post-cancelation cleanup cumbersome and slow.
- [zig/api] Io separates "may run concurrently" (`io.async`, never fails) from "must run
  concurrently" (`io.concurrent`, always fallible, thread pool backed). ^f7
  > By naming what is happening (`io.async` vs `io.concurrent`), Zig makes it easier to understand what is actually going on, and also gets more precise signatures (`concurrent` is always fallible, `async` never is).

## Read

- Whole post.

## Not read

- kristoff.it "Asynchrony is not concurrency" (linked): other blog, lead for the std.Io
  reader if not noted.
- Zig std/Io/Threaded.zig source itself.
