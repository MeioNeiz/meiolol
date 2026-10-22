---
title: 'State of WebAssembly 2026 (The Dev Newsletter, Feb 2026)'
url: https://devnewsletter.com/p/state-of-webassembly-2026/
kind: article
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: skimmed (browser, ESM and DOM sections)
relevance: low
grade: C/fair
description: Newsletter round-up of Wasm in 2025 with a 2026 outlook: Safari 26.2 string builtins, source phase imports in V8, no DOM proposal
---
# State of WebAssembly 2026 (The Dev Newsletter, Feb 2026)

Why: a dated snapshot of browser support for the pieces a JS-free loader would need.

## Assessment

- Evidence: C. Aggregator with links to primary sources; no own measurement.
- Reasoning: fair.
- Interests: newsletter.
- Weigh: use only as pointers; Feb 2026, so eight months old.

## Findings

- [web/wasm] Safari 26.2 added JS String Builtins (late 2025), closing the gap with
  Chrome and Firefox. ^f1
  > [Safari 26.2](https://webkit.org/blog/17640/webkit-features-for-safari-26-2/) added JS String Builtins to reduce glue code overhead.
- [web/wasm] No official proposal for direct DOM access as of early 2026; advice is
  hybrid (wasm compute, JS UI). ^f2
  > There's no official proposal yet, but there is interest in Web IDL bindings for Wasm to call web APIs directly.
  > Consider hybrid architectures (Wasm compute + JS UI) for current projects.
- [web/wasm] Source phase imports (`import source m from "./x.wasm"`) are TC39 stage 3
  and in V8 since M131; they return a module that JS still instantiates. ^f3
  > returns a `WebAssembly.Module` for manual instantiation
  > [V8 implemented this in M131]
- [web/wasm] JSPI (wasm awaiting JS promises) in Chrome 137+ and Firefox 139+, Safari
  open. ^f4
  > is Phase 4 and available in [Chrome 137+](https://developer.chrome.com/blog/new-in-chrome-137?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) and Firefox 139+; Safari support remains the open question.

## Read

- Browser, DOM, ESM source phase and JSPI sections.

## Not read

- Server-side, WASI and security sections (out of scope).
