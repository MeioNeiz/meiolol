---
title: Zig Overview (ziglang.org/learn)
url: https://ziglang.org/learn/overview/
kind: docs
commit:
for: [zig-good-practice, zig-errors-safety, zig-memory, zig-perf, zig-build]
looked: 2026-10-22
depth: docs (whole page)
relevance: medium
grade: A/fair
description: Official feature tour: no hidden control flow, build modes and safety, errors, allocators, comptime, C interop, cross-compiling; examples partly run on 0.17 CI, partly years stale
---
# Zig Overview (ziglang.org/learn)

Why: the core team's own statement of what Zig code should rely on (safety modes, error
handling, allocators) and why.

## Assessment

- Evidence: A. Official page; shell outputs come from the site CI on 0.17.0.
- Reasoning: fair. States motives (readability, reuse, optimisation) but is a feature
  tour, not a practice guide.
- Interests: promotion of the language ("Zig is faster than C" is a claim).
- Weigh: trust the motives and the examples with CI output. Several examples are stale:
  `std.fs.cwd()` fails on 0.17 (its own output shows the error), the errdefer example
  uses `*Allocator` and allocPrint without a tuple, `@cImport` is removed in 0.17, and
  both build.zig examples use the 0.10-era `std.build.Builder` API.

## Findings

- [zig/style] No hidden control flow: control flow only through keywords and function
  calls, for readability. ^f1
  > Zig promotes code maintenance and readability by making all control flow managed exclusively with language keywords and function calls.
- [zig/safety] Four build modes; safety checks are on in Debug and ReleaseSafe and can be
  toggled per scope with `@setRuntimeSafety`. ^f2
  > Zig has four [build modes](https://ziglang.org/documentation/master/#Build-Mode), and they can all be mixed and matched all the way down to [scope granularity]
- [zig/safety] [zig/perf] Recommended stance: run a safety-enabled build and disable safety
  only at measured bottlenecks. ^f3
  > With Zig one can rely on a safety-enabled build mode, and selectively disable safety at the performance bottlenecks.
- [zig/safety] [zig/perf] Illegal behaviour serves both bug prevention and optimisation;
  unsigned overflow is illegal too, unlike C, which enables optimisations. ^f4
  > Zig uses [Illegal Behavior](https://ziglang.org/documentation/master/#Illegal-Behavior) as a razor sharp tool for both bug prevention and performance enhancement.
  > in Zig both signed and unsigned integers have illegal behavior on overflow, contrasted to only signed integers in C
- [zig/perf] (claim) Zig is faster than C: one compilation unit, chosen illegal behaviour,
  SIMD vectors, std data structures instead of linked lists. ^f5
  > The standard library provides essential data structures such as hash maps and array lists, whereas in C it is tempting to use linked lists for simplicity.
- [zig/memory] Programmers must manage memory and handle allocation failure; every
  allocating std function takes an allocator, so std works freestanding. ^f6
  > In order to accomplish this, Zig programmers must manage their own memory, and must handle memory allocation failure.
- [zig/memory] [zig/errors] defer and errdefer cover all resource management, not only
  memory: each acquisition is followed by its errdefer release. ^f7
  > Zig provides [defer](https://ziglang.org/documentation/master/#defer) and [errdefer](https://ziglang.org/documentation/master/#errdefer) to make all resource management - not only memory - simple and easily verifiable.
- [zig/errors] Errors are values and may not be ignored; `try` is shorthand for
  `catch |err| return err`; error return traces cost no stack unwinding. ^f8
  > The keyword [try](https://ziglang.org/documentation/master/#try) is a shortcut for `catch |err| return err`
  > The code did not pay the price of unwinding the stack to come up with that trace.
- [zig/errors] An exhaustive `switch` on an error forces every possible error to be
  handled; the compiler lists the missing ones. ^f9
  > keyword used on an error ensures that all possible errors are handled
- [zig/errors] [zig/safety] `catch unreachable` asserts no error; it is undefined
  behaviour in unsafe modes, so only where success is guaranteed. ^f10
  > This invokes [undefined behavior](https://ziglang.org/learn/overview/#performance-and-safety-choose-two) in the unsafe build modes, so be sure to use it only when success is guaranteed.
- [zig/comptime] A generic data structure is a function returning a `type`; `@typeInfo`
  reflection implements std formatted printing with no compiler special case. ^f11
  > A generic data structure is simply a function that returns a `type`:
- [zig/comptime] [toolchain] The reflection example uses the 0.17 struct-of-arrays type
  info (`field_types`, `field_names`). ^f12
  > inline for (info.field_types, info.field_names) |FieldType, field_name| {
- [zig/api] [toolchain] The 0.17 examples take `main(init: std.process.Init)` and get
  `io` from it; Io.Dir.cwd().openFile takes `io` first. ^f13
  > pub fn main(init: std.process.Init) !void {
- [zig/errors] [toolchain] Stale on the page: the errors-as-values example calls
  `std.fs.cwd()`, which does not compile on 0.17 (output shows the error). ^f14
  > error: root source file struct 'fs' has no member named 'cwd'
- [zig/build] [toolchain] Stale: the C interop and build system examples use `@cImport`
  (removed in 0.17), `callconv(.C)` and `std.build.Builder` with `addSharedLibrary`. ^f15
  > const Builder = @import("std").build.Builder;
- [zig/build] Cross-compiling needs no separate toolchain; Zig ships libc sources for many
  targets so `-lc` needs no system files; musl allows static linking. ^f16
  > This means `-lc` for these targets _does not depend on any system files_!
- [zig/build] Non-debug build modes are reproducible. ^f17
  > Non-debug [build modes](https://ziglang.org/documentation/master/#Build-Mode) are reproducible/deterministic.
- [zig/build] System integration is explicit: `--system` disables fetching and enables
  `-fsys` options so packagers and upstream cooperate. ^f18
  > The build system acknowledges system integration as an explicit intent.
- [zig/style] Top-level declarations are order independent and lazily analysed. ^f19
  > Top level declarations such as global variables are order-independent and lazily analyzed.

## Read

- Whole page.

## Not read

- Linked godbolt overflow example; andrewkelley.me stack traces post.
