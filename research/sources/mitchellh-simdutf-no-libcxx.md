---
title: Simdutf Can Now Be Used Without libc++ or libc++abi (Mitchell Hashimoto)
url: https://mitchellh.com/writing/simdutf-no-libcxx
kind: article
for: [zig-build]
looked: 2026-10-22
depth: docs (full)
relevance: low
grade: B/strong
description: April 2026 post: removing libc++ and libc++abi from simdutf so libghostty-vt has no C++ runtime deps; symbol audit script in CI; validating both modes; PR etiquette
---
# Simdutf Can Now Be Used Without libc++ or libc++abi (Mitchell Hashimoto)

Why: how does a Zig project keep C/C++ dependencies from dragging in runtimes?

## Assessment

- Evidence: B. First-hand, with merged Ghostty PR; mostly about C++, not Zig.
- Reasoning: strong. Explains benefits, the hidden ABI deps, how they were audited and how
  both modes stay validated.
- Interests: none.
- Weigh: relevant to meiolol only for the principle (audit artifacts for deps in CI, test
  both build modes); we have no C++ deps.

## Findings

- [zig/build] Dropping libc++ makes a library more portable (embedded, wasm, freestanding), cross-compiles simpler, and shrinks binaries. ^f1
  > Not depending on libc++ makes a library more portable (embedded, WebAssembly, freestanding environments), simplifies cross-compilation
- [zig/build] libghostty-vt with SIMD off has zero dependencies, not even libc; SIMD brought in C++ via simdutf. ^f2
  > Note that with SIMD disabled, libghostty-vt has always had zero dependencies, not even libc.
- [zig/build] Hidden runtime deps show only in object symbols, so a script decompiles objects and CI checks for `__cxa_*` and similar. ^f3
  > To detect these, I had to write a script that decompiles the object files and looks for symbols such as `__cxa_guard_acquire`.
- [zig/test] Ghostty added its own tests that its artifacts have no libc++ deps, and ran UTF-8 tests and benchmarks to confirm no regression. ^f4
  > added our own suite of tests to verify our artifacts have no dependencies on libc++ or libc++abi.
- [zig/test] Test and benchmark suites run in both build modes so future changes keep both working. ^f5
  > I modified the pre-existing test and benchmark suites to run in both `NO_LIBCXX` and normal modes

## Read

- Full post

## Not read

- The simdutf PR 959 and Ghostty PR 12291
