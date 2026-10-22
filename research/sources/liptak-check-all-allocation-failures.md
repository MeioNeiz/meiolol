---
title: An Intro to Zig's checkAllAllocationFailures (Ryan Liptak, 2022)
url: https://www.ryanliptak.com/blog/zig-intro-to-check-all-allocation-failures/
kind: article
commit:
for: [zig-testing, zig-memory, zig-errors-safety]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: A/strong
description: The std function's author on testing every OutOfMemory path: how it works, adapting a test, the errdefer leaks it finds, swallowed OOM, fuzzing
---
# An Intro to Zig's checkAllAllocationFailures (Ryan Liptak, 2022)

Why: testing errdefer paths systematically.

## Assessment

- Evidence: A. Ryan Liptak (squeek502) is a long-time std contributor and wrote
  `std.testing.checkAllAllocationFailures` (PR 10586); the strategy came from the Zig
  parser tests (since 2017). Jun 2022, Zig 0.10-dev. The function still exists in 0.17
  `std/testing.zig`.
- Reasoning: strong; walks real leaks, the determinism caveat and false positives.
- Interests: his own function and library.
- Weigh: API examples (`std.io.StreamSource`, old build API) are stale; the method holds.

## Findings

- [zig/test] OOM paths are rarely hit organically, so `try` handling of them goes untested in normal runs. ^f1
  > because actually running into `OutOfMemory` organically is rare, it's not easy to be sure that you're handling the error correctly in all cases.
- [zig/test] Strategy: count allocations in one run, then rerun failing allocation 0, 1, ... N; needs a deterministic allocation count. ^f2
  > Then, iterate and run the code X more times, incrementing the failing index each iteration (where X is the total number of allocations determined previously).
- [zig/test] Wrap the test body in a function taking the allocator first and returning `!void`; pass other inputs as a tuple. ^f3
  > The provided `test_fn` must have a `std.mem.Allocator` as its first argument,
- [zig/test] State shared between runs must be reset inside the test function. ^f4
  > Any relevant state shared between runs of `test_fn` *must* be reset within `test_fn`.
- [zig/test] With `std.testing.allocator` as backing it also catches double and invalid frees on the failure paths. ^f5
  > Using `std.testing.allocator` as the backing allocator will also allow `checkAllAllocationFailures` to detect double frees, invalid frees, etc. that happen as a result of allocation failure.
- [zig/memory] Typical find: two allocations in a row, the second fails, the first leaks until an `errdefer free` follows each one before ownership passes on. ^f6
  > That is, we're leaking the allocation for `key` when the allocation for `value` fails.
  > The simplest fix here would be to put in an [`errdefer`](https://ziglang.org/documentation/master/#errdefer) that will free `key`
- [zig/test] Code that recovers from OOM internally trips `NondeterministicMemoryUsage`/`SwallowedOutOfMemoryError`; treat it as a bug unless you know the recovery is intended. ^f7
  > Unless you know that part of the code you're testing has `OutOfMemory` recovery in place somewhere (like `std.BufMap.putMove`), then it's generally a good idea to ensure that the code under test doesn't erroneously/unexpectedly 'swallow' `OutOfMemory` errors.
- [zig/test] Make it switchable with a build option, since it runs the body N+1 times. ^f8
  > We might not always want to run our test code N+1 times (where N is the number of allocations that occur within the test).
- [zig/test] Projects found real bugs with it (arocc; zss found a dangling pointer). ^f9
  > It already helped to find a dangling pointer error!

## Read

- Whole post.
