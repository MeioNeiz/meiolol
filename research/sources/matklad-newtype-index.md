---
title: Newtype Index Pattern In Zig (matklad, 2025-12-23)
url: https://matklad.github.io/2025/12/23/zig-newtype-index-pattern.html
kind: article
commit: 
for: [zig-perf, zig-style, zig-api-design]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: B/strong
description: Why indexes beat pointers, and typed indexes as non-exhaustive enum(u32) in Zig, with an n-ary tree example and layout conventions
---
# Newtype Index Pattern In Zig (matklad, 2025-12-23)

Why: data layout and typed indexes. Zig 0.15.2 era (links the 0.15.2 langref);
`enum(u32) { _ }`, `@intFromEnum`, `@enumFromInt` unchanged in 0.17.

## Assessment

- Evidence: B. Expert first-hand; credits the pattern to Andrew Kelley (used in the Zig
  compiler). He admits the memory win is unmeasured ("gut feeling").
- Reasoning: strong. Three benefits with mechanisms, the main risk and its fix, and
  open preferences stated as such.
- Interests: none known.
- Weigh: the pattern is the Zig compiler's own idiom; the "default to indexes before
  profiling" stance is his judgement.

## Findings

- [zig/perf] In efficiency-minded code indexes are idiomatic over pointers; a 32-bit index
  saves four bytes per pointer on 64-bit. ^f1
  > In efficiency-minded code, it is idiomatic to use indexes rather than pointers.
  > Typically a 32-bit index is enough, a saving of four bytes per pointer on 64-bit architectures.
- [zig/perf] (claim) Memory savings spread evenly and don't show in a profiler, so he
  defaults to indexes where speed matters before any profiling. ^f2
  > I would default to indexes for code where speed matters, even when I don’t have the code written yet to profile it!
- [zig/perf] A list can often be a range into shared storage instead of a list of
  indexes. ^f3
  > you can often avoid materializing the list of indexes by storing a range “pointing” into the shared storage
- [zig/perf] Pointers encourage recursion over long chains, which overflows the stack in
  production; indexes model cycles and recursion more naturally. ^f4
  > The combination works fine at small scale, but then it fails with stack overflow in production every single time
- [zig/perf] Indexes are relocatable, so arrays can be bulk serialized with memcpy;
  caveats: padding can leak data, checksum the result. ^f5
  > you can directly `memcpy` arrays around (but be careful to not leak data via padding, and be sure to checksum the result)
- [zig/api] [zig/style] Typed index: `const ItemIndex = enum(u32) { _ };`, a distinct u32
  (popularised by Andrew Kelley); no strong encapsulation, anyone can `@enumFromInt`. ^f6
  > is a way to spell “`u32`, but a distinct type”. Note that there’s no _strong_ encapsulation boundary here, anyone can `@enumFromInt`.
- [zig/style] Define the collective noun first (`Tree`, not `Node`); don't suffix index
  types with `Index`. ^f7
  > As usual with indexes, you start with defining the collective noun first, a `Tree` rather than a `Node`.
  > you usually don’t want `Index` suffix in your index types
- [zig/style] Nested types are good (`Node.Data`); order within a struct: fields, then
  nested types, then functions. ^f8
  > For readability, the order is fields, then nested types, then functions.
- [zig/safety] [zig/perf] Sentinel `invalid = std.math.maxInt(u32)` for "no parent"
  instead of `?Node` (which wastes space), as offensive programming so bad indexes blow
  up. ^f9
  > `.invalid` for whenever we want to apply offensive programing and make bad indexes blow up.
- [zig/perf] [zig/safety] `comptime { assert(@sizeOf(Data) == 12); }` inside the struct,
  as a comment telling the reader the size, not to prevent changes. ^f10
  > its a good idea to `comptime assert` sizes of structures, not to prevent changes, but as a comment that explains to the reader just how the large the struct is.
- [zig/api] Ranges as `index/count` (names align in length); API shape `tree.method(node)`
  by default since it works with several node arguments. ^f11
  > I default to the former because it works even if there are several node arguments.

## Read

- Whole post.

## Not read

- 2018 Rust version of the post (linked): Rust, adds nothing for Zig.
