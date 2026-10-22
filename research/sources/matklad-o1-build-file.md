---
title: O(1) Build File (matklad, 2023-12-31)
url: https://matklad.github.io/2023/12/31/O(1)-build-file.html
kind: article
commit: 
for: [zig-build, zig-testing]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/fair
description: Build and CI config size should not grow with the project: few entry points (run, test, fuzz, deploy), filters instead of new steps, few artifacts
---
# O(1) Build File (matklad, 2023-12-31)

Why: build.zig structure. Mentions build.zig; version neutral.

## Assessment

- Evidence: B. Expert rule of thumb from TigerBeetle and rust-analyzer.
- Reasoning: fair. Costs named (entry points, quadratic link time); he frames it as a
  rule that focuses attention, not a law.
- Interests: none.
- Weigh: meiolol has one `zig build ci` and test filters, already close.

## Findings

- [zig/build] Build or CI config size should be mostly independent of project size: a
  new test shouldn't need a new build line or CI line. ^f1
  > the size of build or CI configuration should be mostly independent of the project size.
- [zig/build] Enumerate O(1) entry points: run, test, fuzz, deploy; consider folding lint
  and fmt into test. ^f2
  > Enumerate `O(1)` of project entry points explicitly.
  > consider if you can avoid separate `lint` and `fmt` entry points, as those are a form of automated tests.
- [zig/build] Use filters (`--test-filter=tidy`) rather than opt-in steps. ^f3
  > It’s much easier to discover how to filter out things you don’t need, than to realize that there’s something you need to opt into.
- [zig/build] Few artifacts: a production and a test build; subcommands or multicall
  binaries instead of related binaries, which also ships debug tools to production. ^f4
  > Avoid building a set of related binaries, use subcommands or BusyBox-style multicall binaries instead.
- [zig/build] The rule's value: pause whenever you add to build.zig. ^f5
  > The main value of today’s rule is to make me pause whenever I add to `build.zig` and think for a second.

## Read

- Whole post.
