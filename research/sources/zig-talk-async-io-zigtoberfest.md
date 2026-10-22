---
title: Zig's New Async I/O - Andrew Kelley and core team (Zigtoberfest 2025)
url: https://www.youtube.com/watch?v=mdOxIc0HM04
kind: talk
commit:
for: [zig-api-design, zig-errors-safety, zig-memory]
looked: 2026-10-22
depth: docs (whole transcript)
relevance: high
grade: A/strong
description: Kelley walks 11 std.Io examples for 0.16: io.async/await, defer cancel, cancellation as error.Canceled, async vs concurrent, Group, Queue, select; Q&A with Matthew Lugg on context structs holding gpa and io
---
# Zig's New Async I/O (Zigtoberfest 2025)

Why: the core team's own usage rules for std.Io async primitives, which 0.17 code follows.

## Assessment

- Evidence: A. Kelley and core members (Lugg, Techatrix) demoing the API they designed,
  Oct 2025, before 0.16.0.
- Reasoning: strong. Each pattern is motivated by a bug shown live (leaked task, deadlock)
  and the fix; open questions admitted (oversubscription, timeouts).
- Interests: none beyond the project.
- Weigh: they warn details were not final; check names against 0.17 std (`io.async`,
  `io.concurrent`, `Future.cancel`, `Io.Group`, `Io.Queue`, `Io.select`). Captions
  mangle "async await" ("async8") and "idempotent" ("item potent").

## Findings

- [zig/api] Setting up an Io implementation is like setting up an allocator, done once in
  main; example code is then the same for every implementation. @2:23 ^f1
  > We set up an allocator. Okay, now this is kind of like setting up an allocator. You set up an IO implementation.
- [zig/api] In Zig, async means decoupling the call of a function from its return;
  await is idempotent. @3:24 ^f2
  > So what what async8 means to to zigg is you decouple the calling of a function from the returning of a function.
- [zig/errors] [zig/memory] Footgun: `try a.await(io)` before awaiting `b` leaks `b` when
  `a` fails (the leak checker catches it). @11:26 ^f3
  > our our leak check detects that we actually leaked this task
- [zig/errors] [zig/memory] Rule: if you async, defer a cancel, as you defer a free after
  allocating; then `try ... await` is safe and failure cancels the rest at once. @13:26 ^f4
  > If you async, you defer a cancel. And this is a really, really nice pattern because now we can use try a wait like normal.
- [zig/api] cancel is the same as await plus a cancellation request; both idempotent, so
  a `defer cancel` after an await is a no-op. Cancellation is a request, not a guarantee.
  @14:14 ^f5
  > Cancel and await are the same except cancel also requests cancellation and they're item potent just like a wait.
  > What's important to understand is that the cancel is a request.
- [zig/memory] Treat a task like a resource (an open file, an allocation): defer cancel
  is structured concurrency; returning the future is the advanced case. @18:01 ^f6
  > You should think of it like a resource as if you had opened a file or as if you had allocated memory.
- [zig/errors] Many Io functions now include `error.Canceled`; ordinary errdefer and
  defer cleanup then runs on cancellation and propagates it, so cancellation comes "for
  free"; explicit checks only in long CPU-bound loops. @21:30 ^f7
  > because cancellation is an error error.ancelled, you end up going through all of your resource de allocation code as you cancel
- [zig/memory] When the async function returns an allocated result, the deferred cancel
  must free it on success too: `defer if (fut.cancel(io)) |s| gpa.free(s) else |_| {}`
  shape. (inferred from the demo description) @26:41 ^f8
  > So if the call succeeds we have to free the resource and in fact even if even in the happy path we go down here and we print everything we still go up and have to free the resources.
- [zig/api] Asynchrony is not concurrency: a producer/consumer pair under `io.async`
  deadlocks with one thread; use `io.concurrent`, which can fail with
  ConcurrencyUnavailable instead of deadlocking. Prefer async when you can. @33:14 ^f9
  > The problem is that we asked for asynchrony but we needed concurrency. So in order to fix this we use io.concurrent instead of io.async.
  > And you really you really should use async if you can
- [zig/api] `io.async` cannot fail: if the task cannot be allocated it runs the function
  immediately, which async permits. @36:44 ^f10
  > if this memory allocation cannot happen in order to allocate the producer, it will just run this function right here immediately before proceeding to the next line
- [zig/api] `Io.Group` is the arena of tasks: async into it, wait or cancel as a whole;
  finished task resources are freed as they finish, so a server can spawn one per client
  without leaking. @46:01 ^f11
  > group is the um is a really handy primitive. So it's kind of the yeah it's the arena of um of tasks.
  > It's fine to just put them in one group and you're not going to leak resources over time because they will be cleaned up when the individual tasks finish.
- [zig/test] Planned: a testing Io with deterministic, seed-driven scheduling for fuzzing
  concurrency. @41:45 ^f12
  > maybe even support fuzzing so make it make its scheduling decisions uh um deterministic based on on a seed
- [zig/api] Io is a fat pointer (pointer plus vtable), the same interface shape as
  Allocator. @50:06 ^f13
  > uh allocator is also an interface. And there's your fat pointer right there.
- [zig/api] [zig/memory] Pattern from the compiler: a context struct holds gpa and io as
  fields and functions take the context first; free functions take io and allocator
  directly. @50:51 ^f14
  > it's very common that you you take your um you take your context as your first argument, and that's where you're going to have your allocator, that's where you're going to have your IO implementation.
- [zig/style] No anonymous function syntax: Kelley decided against it; Io implementations
  are written as normal declarations in a file. @48:27 ^f15
  > Andrew doesn't like anonymous functions, and so he made this decision a while ago
- [zig/api] Timeouts belong in the operation (e.g. receive with timeout) so the code still
  works single-threaded without concurrency. @53:28 ^f16
  > So the general idea is you bake the timeout into the operation.
- [zig/api] Contribution stance: bring use cases from real code, not speculation. @57:06 ^f17
  > but bring use cases not sheds.

## Read

- Whole transcript (examples described verbally; code on screen not captured).

## Not read

- The example source files shown on screen.
