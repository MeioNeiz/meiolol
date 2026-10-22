---
title: Mechanical Habits (matklad, 2025-12-06)
url: https://matklad.github.io/2025/12/06/mechanical-habits.html
kind: article
commit: 
for: [zig-testing, zig-build, zig-perf]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: B/strong
description: Weekly releases, not-rocket-science merges, a tidy.zig lint-as-test, a DevHub page, and micro benchmarks as tests with two-mode Bench.parameter (TigerBeetle)
---
# Mechanical Habits (matklad, 2025-12-06)

Why: process and test infrastructure around Zig code. TigerBeetle 0.16.66 (Zig 0.14/0.15
era); ideas version neutral.

## Assessment

- Evidence: B. Practised across IntelliJ Rust, rust-analyzer and TigerBeetle; benchmark
  habit is new (PR 3405), he says check back in years.
- Reasoning: strong. Each habit with first and second order effects; warns automation
  must reduce toil.
- Interests: none.
- Weigh: tidy-as-test and benchmark-as-test fit meiolol directly.

## Findings

- [zig/test] A tidy file collects project lint checks as tests; its value is mere
  existence, adding a check is easier than building infrastructure. ^f1
  > The biggest value of such `tidy.zig` is its mere existence.
- [zig/test] TigerBeetle tidy checks: no large blobs in git history (actual git objects),
  line and function length, banned std APIs, no `// FIXME`, no dead code. ^f2
  > No dead code (Zig specific, as the compiler is not well-positioned to tackle that, due to lazy compilation model).
- [zig/test] `// FIXME` used positively: marks code to change before merge, tidy blocks
  it. ^f3
  > I add `// FIXME` comments to code I want to change before the merge
- [zig/test] Tidy checks find files with `git ls-files -z`. ^f4
  > shell out to `git ls-files -z` to figure out what needs tidying.
- [zig/test] Not rocket science rule: advance main only to a commit whose tests already
  passed, by a robot; forces CI to stay tidy. ^f5
  > Only advance the tip of the master branch to a commit hash, for which you _already know_ the tests results.
- [zig/perf] [zig/test] Micro benchmarks bitrot; make each one a test (`test "benchmark:
  binary search"`), chaining onto an existing entry point. ^f6
  > So each micro benchmark is going to be just a test:
- [zig/perf] [zig/test] Two modes by CLI shape: full suite runs benchmarks small and
  silent; `zig build test -- "benchmark: search"` runs big and prints. ^f7
  > So we use the shape of CLI invocation to select benchmarking mode.
- [zig/perf] `bench.parameter("element_count", 1_000, 10_000_000)`: small for test, big
  for benchmark, named so it prints and can be overridden by env var. ^f8
  > bench.parameter("element_count", 1_000, 10_000_000);
  > we get to override values of parameters via environmental variables for free!
- [zig/build] Avoid multiplying entry points (O(1) build file). ^f9
  > Avoid multiplying entry points

## Read

- Whole post.

## Not read

- HYTRADBOI 2025 talk on simulation testing visualisation (linked): lead.
- O(1) Build File post (2023): lead for zig-build.
