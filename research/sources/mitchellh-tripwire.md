---
title: "Don't Trip[wire] Yourself: Testing Error Recovery in Zig (Mitchell Hashimoto)"
url: https://mitchellh.com/writing/tripwire
kind: article
for: [zig-testing, zig-errors-safety]
looked: 2026-10-22
depth: docs (full)
relevance: high
grade: B/strong
origin: ghostty-repo
description: Jan 2026 post on Tripwire, Ghostty's single-file fault injection library for testing errdefer paths, zero cost outside tests
---
# Don't Trip[wire] Yourself: Testing Error Recovery in Zig (Mitchell Hashimoto)

Why: how do you test errdefer paths in Zig?

## Assessment

- Evidence: B. First-hand report with a result: ~6 errdefer bugs found in the first PR. Code
  is in [[ghostty-repo]] (`src/tripwire.zig`, PageList init tests), so one origin.
- Reasoning: strong. States the problem, why existing tools fall short (failing_allocator
  is fragile), how it works, the zero-cost mechanism and its open limits.
- Interests: none; MIT, invites copying the file.
- Weigh: written against Zig 0.15.2 (`std.fs.cwd()`, `std.builtin.CallingConvention`); the
  repo copy at 0.17 uses `std.Io.Dir` and `std.lang.CallingConvention`.

## Findings

- [zig/test] [zig/errors] errdefer cleanup is called one of the most error-prone parts of Zig programs, because error paths rarely run in tests. ^f1
  > Ironically, error cleanup is one of the most error-prone parts of Zig programs and is a consistent source of resource leaks and memory corruption.
  > they usually are only cognitively reviewed once or twice during development, and never truly exercised until a user hits them in production.
- [zig/test] defer is tested by any test, errdefer only if the error can be triggered; failing_allocator works only for allocation and is fragile in complex code. ^f2
  > You always get `defer` testing for free if you unit test your code because defers run unconditionally on block exit.
  > getting it exactly configured right in complex code that does many allocations and whose allocations may be conditional is tricky and fragile.
- [zig/test] Tripwire: named fail points (an enum) checked before fallible calls; the module's error set comes from the function itself. ^f3
  > lets you put named points in your code where you can trigger errors during tests.
  > argument is the function itself to get its error set.
- [zig/test] testing.allocator turns an injected error into a leak check: a missing errdefer fails the test. ^f4
  > The key insight is that `std.testing.allocator` will fail the test if any memory is leaked.
- [zig/test] Loop over `std.meta.tags(FailPoint)` to cover every fail point. ^f5
  > Another common pattern I use is to iterate through all possible failure points to get complete coverage:
- [zig/test] `errorAfter` trips only after N hits (loop cleanup); `end` checks each point actually tripped. ^f6
  > you can use `errorAfter` to only trigger an error after a certain number of times that that failure point has been reached.
- [zig/comptime] [zig/perf] Zero cost outside tests via `builtin.is_test` and an inline calling convention; an empty non-inline function still emitted a call in real builds. ^f7
  > pub const enabled = builtin.is_test;
  > we've seen real compilations produce machine code with full function call overhead to a function with an empty body and only a `ret`.
- [zig/comptime] Unreferenced globals aren't emitted, so the tripwire state costs no binary space when disabled. ^f8
  > Since no code references this state when Tripwire is disabled, none of our global state gets emitted into the binary, either.
- [zig/errors] Result: ~6 errdefer bugs fixed in the first integration PR, none ever seen in the wild, each now held by a test. ^f9
  > In the initial PR I fixed ~6 `errdefer` bugs.
- [zig/test] He plans errdefer testing for all new Ghostty code. ^f10
  > to ensure that I'm considering `errdefer` testing for any newly written code by myself, maintainers, or contributors.

## Read

- Full post

## Not read

- PRs 8249 and 10401 (the bug examples)
