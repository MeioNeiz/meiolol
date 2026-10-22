---
title: 'Debug C/C++ WebAssembly (Chrome DevTools docs)'
url: https://developer.chrome.com/docs/devtools/wasm
kind: docs
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: docs (whole page)
relevance: medium
grade: A/fair
description: Chrome's guide to source-level wasm debugging from DWARF via the C/C++ DevTools Support extension: breakpoints, stepping, scope, separate debug files
---
# Debug C/C++ WebAssembly (Chrome DevTools docs)

Why: what source-level debugging does Chrome offer wasm built from a non-JS language?

## Assessment

- Evidence: A. Official Chrome docs.
- Reasoning: fair.
- Interests: vendor docs; C/C++ and Emscripten only, nothing on Zig.
- Weigh: last updated 2023-06-07, so check the extension still installs.

## Findings

- [web/wasm] Needs DWARF in the wasm plus the C/C++ DevTools Support (DWARF) extension.
  ^f1
  > Compile your application with [DWARF](https://dwarfstd.org/) debug information included.
  > Install the [C/C++ DevTools Support (DWARF) Chrome extension]
- [web/wasm] Gives line breakpoints and stepping in the original source, hover values,
  source function names in the call stack, and variables in Scope. ^f2
  > Pause execution with line-of-code [breakpoints](https://developer.chrome.com/docs/devtools/javascript/breakpoints#loc) and step through your original C/C++ source code
  > Understand function names in **Call Stack** and variables in **Scope**.
- [web/wasm] Debug info can be split into a separate .wasm file to keep the shipped
  module small (Emscripten flag shown). ^f3
  > To speed up loading but still have a better debugging experience, you can split out the debug information into a separate `.wasm` file.
- [web/wasm] Page last updated in 2023. ^f4
  > Last updated 2023-06-07 UTC.

## Read

- Whole page.
