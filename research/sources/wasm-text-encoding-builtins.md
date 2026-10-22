---
title: 'JS Text Encoding Builtins proposal overview (Wasm CG, phase 1)'
url: https://github.com/WebAssembly/js-text-encoding-builtins
kind: spec
commit: 37de8460da76ac2d47d450b7c60b27344c1f37f4
for: [zig-only-frontend]
looked: 2026-10-22
depth: docs (Overview.md, goals and first two functions)
relevance: medium
grade: B/fair
description: Phase 1 proposal for wasm:text-encoding builtins that decode and encode UTF-8 in linear memory to and from JS strings, aimed at UTF-8 toolchains like Zig
---
# JS Text Encoding Builtins proposal overview (Wasm CG, phase 1)

Why: the string copy is the named cost of wasm UIs; JS String Builtins suit GC
languages; is there a fix for UTF-8 linear-memory languages like Zig?

## Assessment

- Evidence: B. A CG proposal at phase 1 (repo created 2026-04-23, last push 2026-05-26);
  no browser ships it.
- Reasoning: fair. States goals and non-goals.
- Interests: none.
- Weigh: years from usable; phase 1 means idea accepted for exploration only.

## Findings

- [web/wasm] Adds builtins to decode and encode UTF-8 strings in linear memory to and
  from JS strings, on top of JS String Builtins. ^f1
  > this proposal adds builtins for encoding and decoding UTF-8 strings in linear memory to and from JavaScript strings.
- [web/wasm] Aimed at toolchains that keep strings in UTF-8, avoiding user-side copies.
  ^f2
  > This proposal intends to serve Wasm toolchains that store strings in UTF-8.
- [web/wasm] Functions are imported from "wasm:text-encoding", e.g.
  decodeStringFromUTF8Memory, specified as a TextDecoder over the memory range. ^f3
  > ### "wasm:text-encoding" "decodeStringFromUTF8Memory"
- [web/wasm] Encoding still needs the caller to pre-allocate memory; sizing is a
  non-goal. ^f4
  > When encoding JS strings to linear memory, memory has to be pre-allocated on the users side.

## Read

- Overview.md: overview, goals, first two API entries.
