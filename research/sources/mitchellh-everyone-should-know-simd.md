---
title: Everyone Should Know SIMD (Mitchell Hashimoto)
url: https://mitchellh.com/writing/everyone-should-know-simd
kind: article
for: [zig-perf]
looked: 2026-10-22
depth: docs (full)
relevance: high
grade: B/strong
description: July 2026 post: the five-step shape of everyday SIMD in Zig with @Vector, @splat, @reduce, @bitCast mask and @ctz, scalar tail as fallback; why not rely on auto-vectorisation
---
# Everyone Should Know SIMD (Mitchell Hashimoto)

Why: how should everyday Zig hot loops use SIMD, and when is it worth it?

## Assessment

- Evidence: B. Real Ghostty loop with a measured end-to-end 5x on AVX2; the current code is in
  [[ghostty-repo]] (`src/terminal/stream.zig:876-894`, `src/simd/main.zig`).
- Reasoning: strong. Gives the general recipe, when it doesn't pay (small inputs), and why
  explicit beats auto-vectorisation (predictability), and says to check the compiler first.
- Interests: none (states it was hand-written).
- Weigh: written July 2026 but uses `std.meta.Int(.unsigned, lanes)`; Ghostty at 0.17 uses
  `@Int(.unsigned, lanes)` in the same idiom. Prefer `@Int`.

## Findings

- [zig/perf] Everyday SIMD follows one shape: broadcast constants, loop one vector at a time, operate on all lanes, reduce, scalar tail. ^f1
  > Broadcast any constants you need and initialize vector accumulators, if any.
  > Handle the remaining elements with a scalar tail.
- [zig/perf] It pays only on large data: hundreds of values or more, not dozens. ^f2
  > If you're doing these for loops across data that is only ever a handful or dozens of bytes, it's not worth it.
- [zig/perf] The scalar loop stays as both the tail and the fallback when the target has no usable vector width (`simd.lanes` returns null). ^f3
  > The original implementation remains both the fallback and the tail.
- [zig/perf] Generic `@Vector` code has no CPU intrinsics; Zig lowers it to the target's instruction set. ^f4
  > Generic vectors remove the CPU-specific syntax, not CPU-specific code generation.
- [zig/perf] First-mismatch idiom: `@reduce(.And, cmp)` for the all-pass fast path, else `@bitCast` the bool vector to an int mask and `@ctz(~mask)`. ^f5
  > if (@reduce(.And, greater_than_threshold)) continue;
  > end += @ctz(~mask);
- [zig/perf] Measured: up to 4x NEON, 8x AVX2, 16x AVX-512 in the loop; about 5x end to end on an AVX2 desktop. ^f6
  > this was more like a 5x speedup.
- [zig/perf] Compile the scalar version with optimisations and look before hand-writing SIMD; compilers sometimes vectorise. ^f7
  > You should always compile the scalar version with optimizations and see what your compiler produces before manually writing SIMD.
- [zig/perf] When the loop matters he wants vectorisation explicit so a code change or compiler update can't silently undo it. ^f8
  > I don't want an unrelated code change or compiler update to quietly turn it back into a scalar loop.
- [zig/perf] If the SIMD version isn't simple, that is a sign to skip it for now. ^f9
  > And when it's not, it's usually a good sign to skip it for now.
- [toolchain] Uses `std.meta.Int` for the mask type; the 0.17 code uses the `@Int` builtin. ^f10
  > const mask: std.meta.Int(.unsigned, lanes) = @bitCast(greater_than_threshold);

## Read

- Full post

## Not read

- The Lobsters thread it came from
