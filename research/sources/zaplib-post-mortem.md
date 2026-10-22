---
title: 'Zaplib post-mortem (2022)'
url: https://zaplib.com/docs/blog_post_mortem.html
kind: article
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/strong
description: Founders of a Rust/Wasm web app framework startup explain why they shut it: real apps sped up 5% to 2x, not 10x, and the wins came from WebGL, not wasm
---
# Zaplib post-mortem (2022)

Why: a critic's view from people who bet a company on moving web app code to Rust/Wasm.

## Assessment

- Evidence: B. First-hand report from the framework's founders (Steve Krouse, JP Posma)
  with four pilot users; 2022, so before wasm GC and string builtins.
- Reasoning: strong. Admits own mistakes and misleading benchmarks.
- Interests: none left (company wound down).
- Weigh: about speed and adoption cost, not DOM access; the conclusions about
  ergonomics and team cost still hold, the engine numbers are dated.

## Findings

- [web/wasm] Their bet that porting JS to Rust/Wasm speeds apps up did not hold with
  real users. ^f1
  > We always knew that it would always be _possible_ to speed up slow JS within JS.
  > This did not hold up in real-world implementations.
- [web/wasm] A simulator ported to Rust was 5% faster. ^f2
  > It was 5% faster.
- [web/wasm] Rust beats JS rarely, and by about 2x, not 10x; big wins only with millions
  of tiny structs (layout, no GC). ^f3
  > Rust is faster than JS in some cases, but those cases are rarer than we expected, and the performance gain is on the order of 2x some of the time, not 10x most of the time.
- [web/wasm] Without a 10x gain, a second toolchain the team must learn and maintain is
  not worth it, in their own judgement. ^f4
  > Without a 10x improvement we can't imagine engineers making the investment to add a whole new experimental tool chain to their stack that their team has to learn and maintain.
- [web/wasm] Their 10x prototype numbers came from rewriting from scratch with a better
  architecture, not from the language. ^f5
  > we maybe could’ve gotten similar speedups in a JS rewrite

## Read

- Whole post.
