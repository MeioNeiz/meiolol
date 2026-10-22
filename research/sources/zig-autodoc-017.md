---
title: 'Zig 0.17 autodoc: lib/docs main.js and wasm/main.zig'
url: https://codeberg.org/ziglang/zig/src/branch/0.17.x/lib/docs
kind: project
commit: 0.17.0
for: [zig-only-frontend]
looked: 2026-10-22
depth: code (docs/main.js, docs/wasm/main.zig from the 0.17.0 release lib dir)
relevance: high
grade: A/fair
description: The Zig team's own browser app (std docs): Zig wasm does the work and returns HTML strings; a 1,022-line hand-written main.js owns the DOM
---
# Zig 0.17 autodoc: lib/docs main.js and wasm/main.zig

Why: how does the Zig core team itself split a browser UI between Zig wasm and JS?

## Assessment

- Evidence: A. Ships with every Zig release (`zig std`), written by the core team.
- Reasoning: fair. Code, no design doc read.
- Interests: none.
- Weigh: a docs browser, close in shape to meiolol (read-mostly pages, search, lists).

## Findings

- [web/wasm] Zig wasm imports a single JS function (log); everything else crosses as
  exported functions returning numbers or packed (ptr, len) strings. `docs/wasm/main.zig`
  ^f1
  > extern "js" fn log(level: LogLevel, ptr: [*]const u8, len: usize) void;
- [web/wasm] JS loads the module with `WebAssembly.instantiateStreaming` and copies the
  sources tarball into wasm memory through an exported alloc. `docs/main.js` ^f2
  > const ptr = wasm_exports.alloc(js_array.length);
- [web/wasm] Zig builds HTML strings; JS decodes them (ptr in the low 32 bits, len in
  the high) and assigns innerHTML. `docs/main.js` ^f3
  > domTldDocs.innerHTML = tld_docs_html;
  > const len = Number(bigint >> 32n);
- [web/wasm] The DOM side is 1,022 lines of hand-written JS (`wc -l`), with every
  element looked up by id up front. `docs/main.js` ^f4
  > const domSearch = document.getElementById("search");
- [web/wasm] [toolchain] The wasm panic handler logs the message through the JS import
  and traps; no stack trace reaches the browser. `docs/wasm/main.zig` ^f5
  > log.err("panic: {s}", .{msg});
- [web/wasm] (inferred) The Zig team's choice for its own web UI is wasm for logic plus
  a JS DOM layer with coarse calls (one HTML string per section), not Zig driving
  individual DOM nodes. ^f6

## Read

- `docs/main.js`: top 130 lines and grep for wasm calls; `docs/wasm/main.zig`: top 40.

## Not read

- `html_render.zig`, `Walk.zig`, `markdown.zig`; index.html.
