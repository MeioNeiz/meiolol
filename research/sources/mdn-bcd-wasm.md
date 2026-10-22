---
title: 'MDN browser-compat-data: wasm reference types, GC, JS string builtins, JSPI, import.source'
url: https://github.com/mdn/browser-compat-data
kind: dataset
commit: 6ced300dbd4cb9dbca68b2c2dffb8627d2aac82f
for: [zig-only-frontend]
looked: 2026-10-22
depth: code (5 JSON files)
relevance: high
grade: A/fair
description: The browser support data behind MDN and caniuse, read at main on 22 Oct 2026 for the wasm features a JS-light frontend would lean on
---
# MDN browser-compat-data: wasm reference types, GC, JS string builtins, JSPI, import.source

Why: which wasm-to-JS features can a site rely on in Chrome, Firefox and Safari in
October 2026?

## Assessment

- Evidence: A. The canonical compat dataset (MDN, caniuse import it), community and
  vendor maintained.
- Reasoning: fair. Data, no explanation.
- Interests: none.
- Weigh: Safari iOS mirrors desktop Safari in every file read.

## Findings

- [web/wasm] Reference types (externref): Chrome 96, Firefox 79, Safari 15.1, so
  universal. `webassembly/reference-types.json` ^f1
  > "version_added": "15.1"
- [web/wasm] JS String Builtins: Chrome 130, Firefox 134, Safari 26.2.
  `webassembly/jsStringBuiltins.json` ^f2
  > "version_added": "26.2"
- [web/wasm] Wasm GC: Chrome 119, Firefox 120, Safari 18.2.
  `webassembly/garbage-collection.json` ^f3
  > "version_added": "18.2"
- [web/wasm] JSPI (wasm awaiting promises): Chrome 137, Firefox 153, Safari 27.
  `webassembly/jspi.json` ^f4
  > "version_added": "137"
- [web/wasm] `import.source()` (source phase import of a .wasm module): Firefox 153
  only; Chrome and Safari false, marked experimental. `javascript/operators/import.json` ^f5
  > "description": "`import.source()`",
- [web/wasm] Checked, not there: no BCD entry for Wasm ESM integration (importing a
  .wasm as a module with its imports linked) in the webassembly folder; a page still
  needs a JS module or script to instantiate the wasm. (inferred) ^f6

## Read

- The five files above (support blocks).

## Not read

- `javascript/statements/import.json` (404 at this path); `webassembly/api/`.
