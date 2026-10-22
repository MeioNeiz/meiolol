---
title: Hard Mode Rust (matklad, 2022-10-06)
url: https://matklad.github.io/2022/10/06/hard-mode-rust.html
kind: article
commit: 
for: [zig-memory]
looked: 2026-10-22
depth: docs (intro, scratch space, conclusions)
relevance: medium
grade: B/strong
description: Rust ray tracer with no allocation in the library: all memory injected as one byte slice; the RAII critique that led him to TigerBeetle and Zig
---
# Hard Mode Rust (matklad, 2022-10-06)

Why: the origin of his static-allocation style (contrast, Rust). Pre-Zig.

## Assessment

- Evidence: B. Working toy (matklad/crt); he admits the scratch space trick fails miri.
- Reasoning: strong. States the RAII critique fairly, then tests it.
- Interests: none.
- Weigh: the RAII critique and the scratch-then-copy build are the transferable parts.

## Findings

- [zig/memory] Critique of RAII: easy allocation encourages a sloppy attitude to
  resources, allocated and destroyed all over the place. ^f1
  > because allocating resources becomes easy, RAII encourages a sloppy attitude to resources, where they are allocated and destroyed all over the place.
- [zig/memory] Costs: untested exhaustion paths, unpredictable resource use, poor
  performance vs batch allocation, spaghetti architecture. ^f2
  > Usually, it is significantly more efficient to allocate and free resources in batches.
  > If all resource management is centralized to a single place, it becomes significantly easier to understand lifecycle of resources.
- [zig/memory] Hard mode: only the small main binary asks the OS for resources; the
  library gets a fixed byte slice for all storage. ^f3
  > Only the small binary is allowed to directly ask OS for resources. For the library, all resources must be injected.
- [zig/memory] Scratch space: split memory into permanent and temporary halves; build a
  pointer tree in scratch, count, then allocate exact arrays in permanent and copy once. ^f4
  > Allocate arrays of the right size in the permanent space, and copy data over once.
- [zig/memory] He liked being able to tell precisely how much memory the program uses. ^f5
  > Aesthetically, I quite like that I can tell precisely how much memory the program would use!

## Read

- Intro, Scratch Space, Conclusions.

## Not read

- Pixel buffer, rayon, allocator, parsing, BVH sections in detail: Rust lifetime
  mechanics, not transferable.
