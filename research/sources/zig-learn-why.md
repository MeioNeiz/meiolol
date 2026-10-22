---
title: Why Zig When There is Already C++, D, and Rust? (ziglang.org/learn)
url: https://ziglang.org/learn/why_zig_rust_d_cpp/
kind: docs
commit:
for: [zig-good-practice, zig-memory, zig-api-design]
looked: 2026-10-22
depth: docs (whole page)
relevance: medium
grade: A/fair
description: Official design-motives page: no hidden control flow or allocations, optional std, libraries portable via C ABI, build system and package manager, simplicity
---
# Why Zig When There is Already C++, D, and Rust?

Why: the core team's reasons behind allocator passing and explicitness, which justify
API rules (take an Allocator, don't allocate implicitly).

## Assessment

- Evidence: A. Official page, unchanged in substance for years; no code to go stale.
- Reasoning: fair. Each rule comes with its why (readability, reuse), against named
  alternatives; costs are not discussed.
- Interests: a comparison written by one side.
- Weigh: trust as the official rationale; the competitor critiques are one-sided.

## Findings

- [zig/style] No hidden control flow, for readability: no properties, operator
  overloading or exceptions. ^f1
  > The purpose of this design decision is to improve readability.
- [zig/memory] [zig/api] No hidden allocations, because hidden allocation limits where
  code can be reused. ^f2
  > The main problem with hidden allocations is that it prevents the _reusability_ of a piece of code, unnecessarily limiting the number of environments that code would be appropriate to be deployed to.
- [zig/memory] [zig/api] Convention: every std feature that heap allocates takes an
  `Allocator` parameter. ^f3
  > Every standard library feature that needs to allocate heap memory accepts an `Allocator` parameter in order to do it.
- [zig/memory] Allocator roles named: the debug allocator catches use-after-free, double
  free and leaks; the arena frees many allocations at once. ^f4
  > There is an arena allocator so that you can bundle any number of allocations into one and free them all at once rather than manage each allocation independently.
- [zig/errors] The language aims to make correct error handling the lazy path. ^f5
  > Zig is designed such that the laziest thing a programmer can do is handle errors correctly
- [zig/build] The build system and package manager are meant to replace cmake/make and
  system package managers for developers, even for pure C/C++ projects. ^f6
  > This build system is appropriate even if the entirety of a project’s codebase is in C or C++.
- [zig/comptime] No macros: things like formatted printing live in std, not the compiler. ^f7
  > Zig has no macros yet is still powerful enough to express complex programs in a clear, non-repetitive way.

## Read

- Whole page.

## Not read

- rust-lang/rust#29802, andrewrk/ffmpeg port.
