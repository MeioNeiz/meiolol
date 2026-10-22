---
title: A Tale Of Four Fuzzers (TigerBeetle blog, matklad, 2025)
url: https://tigerbeetle.com/blog/2025-11-28-tale-of-four-fuzzers
kind: article
commit:
for: [zig-testing, zig-api-design]
looked: 2026-10-22
depth: docs (interfaces, fuzzers 1-2, non-deterministic aside, recap; routing details skimmed)
relevance: high
grade: A/strong
description: subsystem fuzzers beside the whole-system simulator; exhaustive, negative-space and statistical tests; seeds from std.testing.random_seed; interface design for fuzzing
---
# A Tale Of Four Fuzzers (TigerBeetle blog, matklad, 2025)

Why: the most detailed TigerBeetle account of how they write fuzzers and randomised
tests in Zig, applicable to a stats pipeline.

## Assessment

- Evidence: A. Real subsystem (adaptive replication routing, ~1000 lines with
  fuzzers, `src/vsr/routing.zig` at 0.16.66).
- Reasoning: strong. Each fuzzer motivated; admits Zig's `std.testing.fuzz` did not
  work for the author.
- Interests: none.
- Weigh: written on Zig 0.14.x; principles independent of version.

## Findings

- [zig/test] Besides the whole-system simulator, every subsystem gets its own targeted
  fuzzer: the big one is slow to reach deep layers and can't judge quality. ^f1
  > in addition to the main whole-system fuzzer, each subsystem should also have a targeted fuzzer
- [zig/test] [zig/api] Fuzzable design starts with minimal interfaces sketched before
  code; mechanical extraction ossifies accidental dependencies. ^f2
  > the starting point is sketching minimal interfaces that yield themselves to efficient fuzzing.
  > Sometimes a little copying is better than a little dependency!
- [zig/test] Small spaces: drive the same random test with an exhaustive generator to
  cover every case. ^f3
  > If the search space is small, you can use the _same_ PRNG interface to walk it thoroughly and exhaustively.
- [zig/test] Test negative space too: decode random bytes then re-encode
  (`serialize . deserialize`), and crash on invalid internal data (offensive
  programming: `.?` at the call site). ^f4
  > `deserialize . serialize` is positive space, `serialize . deserialize` can be negative space.
  > This is offensive programming, we want to force bugs to jump into the spotlight
- [zig/test] Count valid and invalid cases and assert both occur, so the test keeps
  testing what it claims. ^f5
  > You want to _assert_ that both positive and negative cases actually happen with non-negligible probability.
- [zig/test] Random seeds in tests, generated outside the process: Zig's
  `std.testing.random_seed` is passed on the CLI, so a crashing test still prints a
  replayable command. ^f6
  > Zig I think has the best design in this space. It provides you with the `std.testing.random_seed` value
  > the seed is generated outside of the test process itself and is passed to it on the CLI.
- [zig/test] Statistical asserts: run once with a fixed seed (92) to check counts, and
  again with the random seed for coverage. ^f7
  > Run fuzzer once with a fixed seed (I use `92`), to sanity check the count of good and bad cases.
- [zig/test] [toolchain] At the time Zig's built-in fuzzing (`std.testing.fuzz`) did
  not work for the author. ^f8
  > It already has `std.testing.fuzz`, but I wasn’t able to get that working on my machine.
- [zig/test] Keep each CI run fast; total fuzzing time accumulates over runs. ^f9
  > Mind the time! You want to make each individual CI run as quick as possible, while racking up the total fuzzing time over multiple runs.
- [zig/test] Quick coverage check: put `unreachable` in a branch and see if the
  fuzzer crashes. ^f10
  > Another quick and dirty way to check fuzzer coverage is adding `unreachable` to various branches and check seeing if it crashes.
- [zig/test] Purpose: find bugs in your understanding, not only in code. ^f11
  > Don’t write fuzzers to find bugs in the code, write fuzzers to find bugs in your understanding of the problem.

## Read

- Sections listed in depth.

## Not read

- Fuzzers 3-5 in detail (routing optimality, performance fuzzing).
