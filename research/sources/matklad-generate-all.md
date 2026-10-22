---
title: Generate All the Things (matklad, 2021-11-07)
url: https://matklad.github.io/2021/11/07/generate-all-the-things.html
kind: article
commit: 
for: [zig-testing]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/strong
description: Exhaustive testing of all small inputs with an imperative Gen (exhaustigen): while (!g.done()) { g.gen(bound) }, inclusive bounds, smallest counterexample first
---
# Generate All the Things (matklad, 2021-11-07)

Why: the exhaustigen technique he later uses in Zig (TigerBeetle `exhaustigen.zig`, see
[[matklad-snapshot-testing]]). Rust examples; language neutral.

## Assessment

- Evidence: B. Expert technique, implementations in Rust and C++ (Graydon Hoare) followed.
- Reasoning: strong.
- Interests: none.
- Weigh: cheap and strong for small combinatorial inputs.

## Findings

- [zig/test] Uniform random inputs are ordinary (e.g. rarely equal elements); most bugs
  have small tricky examples, so check every input up to small n and m. ^f1
  > _Most_ of the bugs involve small, tricky examples.
- [zig/test] A fuzzer's byte stream can serve as the random number source for a
  structured generator. ^f2
  > Essentially, we say that the fuzzer _is_ a random number generator.
- [zig/test] Imperative `Gen` with `while !g.done()` enumerates any combinatorial
  structure without recursion; bounds inclusive so `gen(0)` doesn't panic. ^f3
  > Somewhat unusually, the bounds are treated inclusively.
- [zig/test] Examples come out ordered by complexity, so the first failure is the
  smallest counterexample. ^f4
  > That means that the first example which fails a property test is actually guaranteed to be the smallest counterexample!

## Read

- Whole post.
