---
title: Zig Code Smells (Ziggit thread, 2024)
url: https://ziggit.dev/t/zig-code-smells/2928
kind: thread
commit:
for: [zig-good-practice, zig-errors-safety, zig-comptime, zig-memory]
looked: 2026-10-22
depth: docs (whole thread)
relevance: medium
grade: C/fair
description: Community list of Zig code smells: try to main without handling, anytype readers, undefined field defaults, unreachable as panic, allocators in many structs
---
# Zig Code Smells (Ziggit thread, 2024)

Why: community-identified anti-patterns.

## Assessment

- Evidence: C. Long Jan 2024 thread (6.7k words), moderators and regulars, no core
  team. Zig 0.11/0.12 era: the `anytype` reader complaint was addressed by 0.15's
  concrete `std.Io.Reader`/`Writer`.
- Reasoning: mixed; some posts reasoned, some assertions.
- Interests: none.
- Weigh: use as a checklist of things to look for, not as rules. Read first ~12 posts.

## Findings

- [zig/errors] Smell: `try` everywhere up to `main` in an application, never handling anything; decide what is recoverable. ^f1
  > Zig provides errors as values, but if you never do anything with those values and just let them bleed through main, you might as well have used a `@panic`.
  > Try to think about whether something is actually recoverable or not - it can greatly simplify your code.
- [zig/comptime] Smell: `reader: anytype` where an interface type would document the contract; tools can't help. ^f2
  > Tools cannot help you and you have to understand what methods the reader must have from reading the source.
- [zig/perf] Counterpoint: vtable interfaces cost an indirection; `anytype` generates direct calls. ^f3
  > Taking by `anytype` is strictly superior than taking by interface in terms of generated code, because it avoids the cost of indirection
- [zig/safety] Smells: `undefined` as a default for non-array fields; allocators stored in many small structs; treating `unreachable` as a panic. ^f4
  > Using `undefined` as a default value for non-array struct fields. It's rarely necessary and would usually be better without a default value.
  > Conflating `unreachable` with a panic.
- [zig/memory] Allocators in many instances suggest pooling (data-oriented) or unmanaged containers sharing the parent's allocator. ^f5
  > Another way I interpret this is a lack of awareness about unmanaged variants of data structures (such as `ArrayListUnmanaged`) which cuts down on unnecessary copies of allocators
- [zig/memory] Smell: consecutive `try allocator.alloc` lines without `errdefer`, leaking on partial failure. ^f6
  > One thing that has troubled me is how often you see code with consecutive lines of `try allocator.alloc(...)`.

## Read

- Posts 1-10 in full; rest skimmed.
