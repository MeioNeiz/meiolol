---
title: 'Zig issue 35901: optional externref pointers and null (Codeberg)'
url: https://codeberg.org/ziglang/zig/issues/35901
kind: thread
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: docs (whole thread)
relevance: medium
grade: B/fair
description: Open bug on 0.17-dev: a null optional externref compiles to 0 and LLVM fails; funcref likely too
---
# Zig issue 35901: optional externref pointers and null (Codeberg)

Why: is Zig 0.17's externref usable for DOM calls that take or return null?

## Assessment

- Evidence: B. A user's reproducible report on 0.17.0-dev, labelled by a maintainer;
  still open on 22 Oct.
- Reasoning: fair.
- Interests: none.
- Weigh: DOM APIs return null often (querySelector, getAttribute), so this bites.

## Findings

- [web/wasm] [toolchain] A null optional externref fails to compile: LLVM cannot select
  a constant 0 for an externref. ^f1
  > LLVM ERROR: Cannot select: externref = Constant<0>
  > Normal pointers use the value `0` to represent `null`, but when the `.externref` address space is used, the value `ref.null` defined in WASM must be used
- [web/wasm] [toolchain] Applies to variables, parameters and return values; funcref
  likely the same. ^f2
  > This case must be handled for variables, function parameters and the return value of functions that have an optional externref type.
- [web/wasm] [toolchain] Still open at 22 Oct 2026, labels arch/wasm and backend/llvm.
  ^f3

## Read

- Whole thread.
