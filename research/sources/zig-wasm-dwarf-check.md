---
title: 'Zig 0.17 wasm32-freestanding debug info check (our measurement, 2026-10-22)'
url: https://meio.lol/?measured=zig-wasm-dwarf-check
kind: dataset
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: ran
relevance: medium
grade: A/fair
description: Built a 12-line Zig module for wasm32-freestanding in Debug (LLVM and self-hosted) and ReleaseSmall and listed the wasm sections: LLVM Debug carries full DWARF, the self-hosted backend none
---
# Zig 0.17 wasm32-freestanding debug info check (our measurement, 2026-10-22)

Why: can Chrome's DWARF debugging work on Zig wasm, i.e. does Zig 0.17 emit DWARF?

## Assessment

- Evidence: A for what the binaries contain (we built and parsed them); says nothing
  yet about how Chrome's extension renders Zig types.
- Reasoning: fair.
- Interests: none.
- Weigh: not opened in Chrome; that step is still open.

## Findings

- [web/wasm] [toolchain] Zig 0.17 Debug wasm (default, LLVM) has DWARF sections:
  .debug_info, .debug_line, .debug_loc and others. ^f1
  > custom section .debug_info 224828
  > custom section .debug_line 147183
- [web/wasm] [toolchain] `-fno-llvm` (self-hosted backend) Debug wasm has a name
  section but no DWARF, matching the release notes. ^f2
  > custom section name 6667
- [web/wasm] [toolchain] Sizes for the same 12-line module: Debug 659,162 bytes (almost
  all DWARF), self-hosted Debug 110,289, ReleaseSmall 130. ^f3
  > dbg.wasm size 659162
  > small.wasm size 130
- [web/wasm] (inferred) So the debug build is usable with a DWARF reader, but ships far
  too big for production; the release build has no names or DWARF at all. A separate
  debug file (as Emscripten's -gseparate-dwarf) is not something Zig offers that we
  know of. ^f4

## Read

- Our own build output (raw).

## Not read

- Behaviour in Chrome with the C/C++ DevTools Support (DWARF) extension.
