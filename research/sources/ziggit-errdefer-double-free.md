---
title: Defer/errdefer ways to prevent double free (Ziggit thread, 2024)
url: https://ziggit.dev/t/defer-errdefer-ways-to-prevent-double-free/6983
kind: thread
commit:
for: [zig-memory, zig-testing, zig-errors-safety]
looked: 2026-10-22
depth: docs (whole thread)
relevance: high
grade: B/strong
description: errdefer scope across nested init calls; block-scoping an errdefer after ownership transfer; checkAllAllocationFailures
---
# Defer/errdefer ways to prevent double free (Ziggit thread, 2024)

Why: errdefer correctness in nested init and ownership hand-off.

## Assessment

- Evidence: B. Answers by Sze (regular, moderator) and squeek502 (Ryan Liptak, std
  contributor who wrote `checkAllAllocationFailures`); Nov 2024, 0.13.
- Reasoning: strong; explains scoping precisely, gives a test tool.
- Interests: squeek502 links his own posts.
- Weigh: trust.

## Findings

- [zig/errors] A callee's `errdefer` and the caller's `errdefer` for the same resource don't both run: the caller's is only registered after the callee returned successfully. ^f1
  > The errdefer for `Foo.deinit` (that is within `Bar.init`) only gets called after `Foo.init` returns without failure
- [zig/memory] After ownership moves to another object, end the `errdefer` with a block, or a later failure frees memory the new owner also frees. ^f2
  > We can fix the bug by limiting the scope of the `errdefer` by sticking it in a block:
  > // The errdefer is no longer active since it's block-scoped.
- [zig/test] `std.testing.checkAllAllocationFailures` reruns a test failing each allocation in turn; with `testing.allocator` it also catches double frees. ^f3
  > But another good way to prevent double free is to use [std.testing.checkAllAllocationFailures](https://ziglang.org/documentation/master/std/#std.testing.checkAllAllocationFailures) to test your code for errors in its allocation logic.
- [zig/test] It requires a deterministic allocation count and reports swallowed OOM as `error.SwallowedOutOfMemoryError`. ^f4
  > If an allocation was made to fail during a run of `test_fn`, but `test_fn` didn't return `error.OutOfMemory`, then `error.SwallowedOutOfMemoryError` is returned from `checkAllAllocationFailures`.
- [zig/test] Limit: it only injects `OutOfMemory`, not other errors. ^f5
  > I'd also like a way for tests to automatically trigger every possible error, and not just `error.OutOfMemory`

## Read

- Whole thread.

## Not read

- squeek502's blog posts on checkAllAllocationFailures and fuzzing with allocators (leads).
