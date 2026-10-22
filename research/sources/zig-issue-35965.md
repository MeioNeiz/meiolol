---
title: 'Zig issue 35965: struct with externref field fails in Debug (Codeberg)'
url: https://codeberg.org/ziglang/zig/issues/35965
kind: thread
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: docs (whole thread)
relevance: medium
grade: B/fair
description: Open bug on 0.17-dev: wrapping an externref in a struct breaks Debug builds; error unions of externref unsupported
---
# Zig issue 35965: struct with externref field fails in Debug (Codeberg)

Why: how usable is Zig 0.17's externref in ordinary code (structs, errors, Debug)?

## Assessment

- Evidence: B. Two users' reports with exact commands on 0.17.0-dev; open.
- Reasoning: fair.
- Interests: none.
- Weigh: shows the feature is thin: no wrappers in Debug, no error unions.

## Findings

- [web/wasm] [toolchain] A struct with an externref field hits an LLVM error in Debug;
  release modes compile. ^f1
  > Compiling a struct with a .externref field in debug mode causes an LLVM Error.
  > Compiling with release mode works
- [web/wasm] [toolchain] Error unions holding externref are not supported either. ^f2
  > errors encapsulating `.externref` pointers are not supported
- [web/wasm] [toolchain] Build line used: wasm32-freestanding with
  `-mcpu generic+reference_types`. ^f3
  > zig build-exe -target wasm32-freestanding -mcpu generic+reference_types -fstrip -fno-entry -rdynamic

## Read

- Whole thread.
