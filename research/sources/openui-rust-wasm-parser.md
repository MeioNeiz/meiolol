---
title: 'Rewriting our Rust WASM Parser in TypeScript (OpenUI/Thesys, Mar 2026)'
url: https://www.openui.com/blog/rust-wasm-parser
kind: article
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/strong
description: A team moved a Rust wasm parser producing JS objects back to TypeScript and got 2.2-4.6x faster calls; the cost was the boundary, not the parsing
---
# Rewriting our Rust WASM Parser in TypeScript (OpenUI/Thesys, Mar 2026)

Why: experience report of moving UI-adjacent code from wasm back to JS, with numbers.

## Assessment

- Evidence: B. A product team's own measurements (medians of 1000 runs, three real
  fixtures), method stated; widely discussed in March 2026.
- Reasoning: strong. Tried the obvious fix first (direct JsValue), measured it, explains
  why each lost, and says when wasm does help.
- Interests: a vendor blog, but the result is against their earlier choice.
- Weigh: the workload is many small calls that build JS objects, close to what a
  Zig-driven DOM would do per update; not a DOM benchmark itself.

## Findings

- [web/wasm] The Rust parse was never the slow part; the cost was copying the string in,
  serialising to JSON, copying out and parsing in JS. ^f1
  > The Rust parsing itself was never the slow part. The overhead was entirely in the boundary
- [web/wasm] Building JS objects directly from wasm (serde-wasm-bindgen) was 9-29%
  slower than one JSON string, because of many small crossings. ^f2
  > It was **30% slower**.
  > Fewer, larger, and more optimised operations win over many small ones.
- [web/wasm] TypeScript port: 9.3 vs 20.5, 13.4 vs 61.4, 19.4 vs 57.9 µs per parse
  (2.2x to 4.6x faster). ^f3
  > | contact-form | 13.4 | 61.4 | **4.6x** |
- [web/wasm] Their rule: wasm helps for compute-bound work with rare crossings; not for
  small, frequent calls or for building JS objects. ^f4
  > **Compute-bound with minimal interop**: image/video processing, cryptography, physics simulations, audio codecs.
  > **Frequently-called functions on small inputs**: if the function is called 50 times per stream and the computation takes 5µs, you cannot amortise the boundary cost.
- [web/wasm] Wasm and JS do not share a heap, so conversion always costs something. ^f5
  > **WASM and JS do not share a heap.**
- [web/wasm] The algorithmic fix (O(N²) to O(N) streaming) mattered more than the
  language switch. ^f6
  > Algorithmic complexity improvements dominate language-level optimisations.

## Read

- Whole post.
