---
title: Zig's New Async I/O (Text Version) - Andrew Kelley (2025-10-29)
url: https://andrewkelley.me/post/zig-new-async-io-text-version.html
kind: article
commit:
origin: zig-talk-async-io-zigtoberfest
for: [zig-api-design, zig-errors-safety, zig-memory]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: A/strong
description: Text and code of Kelley's Zigtoberfest std.Io demo, posted the day the std.Io patchset landed: DebugAllocator plus Io.Threaded setup, async/await/cancel, defer-cancel pattern freeing results, Queue, async vs concurrent
---
# Zig's New Async I/O (Text Version)

Why: the exact code behind [[zig-talk-async-io-zigtoberfest]], so its patterns can be
quoted verbatim.

## Assessment

- Evidence: A. Kelley's own write-up of the API he landed (PR #25592, Oct 2025).
- Reasoning: strong. Each example shows a bug, its output, and the fix.
- Interests: none.
- Weigh: 0.16-dev API. `std.Io.Threaded.init(gpa)` took one argument then; by Feb 2026 it
  takes an options struct ([[zig-devlog-2026#^f12]]), and 0.17 main receives `io` via
  `std.process.Init` ([[zig-repo-docs#^f14]]). Check names against 0.17 std.

## Findings

- [zig/api] Rule stated outright: set up Io once in main like an allocator; reusable code
  takes an Allocator if it allocates and an Io if it does I/O. ^f1
  > Reusable code should accept an Allocator parameter if it needs to allocate, and it should accept an Io parameter if it needs to perform I/O operations.
- [zig/memory] [zig/test] Setup pattern: DebugAllocator with `defer assert(deinit() ==
  .ok)` so leaks (including leaked tasks) fail the run. ^f2
  > defer assert(debug_allocator.deinit() == .ok);
- [zig/errors] [zig/memory] Leak footgun: `try a.await(io); try b.await(io);` leaks `b`
  when `a` fails. ^f3
  > The problem is that when the first `try` activates, it skips the second `await` which is then caught by the leak checker.
- [zig/errors] The fix pattern: `defer x.cancel(io) catch {};` right after each
  `io.async`, then `try x.await(io)` normally. ^f4
  > defer a.cancel(io) catch {};
- [zig/api] cancel has await's semantics plus a cancellation request; honouring it is up
  to the Io implementation; both are idempotent with each other. ^f5
  > `cancel` is trivial to understand: it has identical semantics as `await`, except that it _also requests cancellation_.
- [zig/memory] When the task returns an owned resource, the deferred cancel frees it on
  success and ignores errors: `defer if (a.cancel(io)) |s| gpa.free(s) else |_| {};` ^f6
  > defer if (a.cancel(io)) |s| gpa.free(s) else |_| {};
- [zig/errors] Benefit: code below the defers stays ordinary Zig with try and return. ^f7
  > by doing resource management like this, we are able to write standard, idiomatic Zig code below, using `try` and `return` like normal without worrying about special resource management cases
- [zig/api] Producer/consumer over `Io.Queue` needs `io.concurrent` (can fail with
  `error.ConcurrencyUnavailable`); `io.async` there deadlocks with one thread. ^f8
  > The problem is that _we needed concurrency, but we asked for asynchrony_.
- [zig/api] Example helper naming: free functions take `(gpa, io, ...)` in that order. ^f9
  > fn doWork(gpa: Allocator, io: Io, flavor_text: []const u8) !void {
- [zig/api] He says the APIs are not set in stone and asks for real-world feedback. ^f10
  > These APIs are not set in stone. It will probably take a few iterations to get it right.
- [zig/api] [toolchain] In Oct 2025 `std.Io.Threaded.init` took just the allocator (later
  an options struct too). ^f11
  > var threaded: std.Io.Threaded = .init(gpa);

## Read

- Whole post.
