---
title: How to Test (matklad, 2021-05-31)
url: https://matklad.github.io/2021/05/31/how-to-test.html
kind: article
commit: 
for: [zig-testing]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: B/strong
description: matklad's testing approach (from rust-analyzer, pre-Zig): check functions, test features not code, sans-IO for fast tests, data-driven and expect tests, tests for everything
---
# How to Test (matklad, 2021-05-31)

Why: the testing philosophy he carries into Zig (snapshot tests, tidy-as-test,
simulation). Written in his Rust era; language neutral.

## Assessment

- Evidence: A. Canonical, widely cited essay by a recognised expert, grounded in
  rust-analyzer (large, fast, data-driven suite) and Cargo.
- Reasoning: strong. Key points with reasons; notes the opposite view (Tim Bray).
- Interests: none.
- Weigh: the frame for meiolol's pipeline_test and snapshot tests.

## Findings

- [zig/test] Use a single `check` function that wraps the API under test, so API changes
  touch one place instead of every test. ^f1
  > Use the `check` idiom to make tests resilient to changes.
- [zig/test] Make adding a test trivial; if writing a test costs more than the fix,
  testing gets skipped. ^f2
  > work hard on making adding new tests trivial.
- [zig/test] Test features, not code; the neural network test: could the suite be reused
  if the software were an opaque model? ^f3
  > Can you re-use the test suite if your entire software is replaced with an opaque neural network?
- [zig/test] Tests are slow because of IO, not code volume; keep as much as possible sans
  IO: caller does IO, callee computes. ^f4
  > architecture the software to keep as much as possible sans io. Let the caller do input and output, and let the callee do compute.
- [zig/test] Slow tests are skipped by default via an env var check, not conditional
  compilation; print each test's time. ^f5
  > Definitely do _not_ use conditional compilation to hide slow tests
- [zig/test] Expect tests: gold output inline, updated in place by a special mode. ^f6
  > Instead of failing the test, a mismatch between expected and actual causes the gold value to be updated in-place.
- [zig/test] He prefers plain asserts, adding a crafted message on first real failure, over
  fluent assertion libraries. ^f7
  > Usually, I start with plain asserts without messages.
- [zig/test] Make hidden behaviour observable (cache hit logging, coverage marks) instead
  of testing internals. ^f8
  > The solution to this problem is to make this extra data a part of the system’s output by adding extra observability points.
- [zig/test] Fire-and-forget background work is untestable; don't do it (structured
  concurrency). ^f9
  > This API is fundamentally untestable.
- [zig/test] Write integrated tests per layer, so a change to a low layer doesn't rebuild
  the whole stack before its tests run. ^f10
  > The right setup here is to write integrated tests for each layer:
- [zig/test] Move automation into tests: formatting, history checks, docs, licences,
  linear-time checks via regression on input sizes. ^f11
  > Use this to your advantage, simplify the automation by moving as much as possible into tests.
- [zig/test] Over-represented, not useful: fluent assertions, mocks, BDD. ^f12
  > There are not so useful techniques which are over-represented in the discourse: fluent assertions, mocks, BDD.

## Read

- Whole post.
