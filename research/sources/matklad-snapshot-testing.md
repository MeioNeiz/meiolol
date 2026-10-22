---
title: Underusing Snapshot Testing (matklad, 2025-04-15)
url: https://matklad.github.io/2025/04/15/underusing-snapshot-testing.html
kind: article
commit: 
for: [zig-testing]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: B/strong
description: Inline snapshot tests in Zig (TigerBeetle snaptest: snap(@src(), \\expected).diff_fmt, .update()) even for stable code, plus smoke examples and an exhaustive generator test
---
# Underusing Snapshot Testing (matklad, 2025-04-15)

Why: test style. Zig 0.14 era; uses TigerBeetle's own `snaptest.zig`, `exhaustigen.zig`
and `BoundedArray` (std.BoundedArray removed in 0.15, TigerBeetle has its own).

## Assessment

- Evidence: B. First-hand workflow with real code from a debugging session.
- Reasoning: strong. Shows the failure of the assert version and why the snapshot
  version is faster to debug.
- Interests: promotes a TigerBeetle library (MIT, copyable).
- Weigh: the tool is ~200 lines in TigerBeetle; meiolol would need its own.

## Findings

- [zig/test] His order: property/fuzz/randomised test first; if you can't fuzz, a snapshot
  test. ^f1
  > If I need to test something, I write a property/fuzz/randomized test. If I can’t fuzz, I write a snapshot test.
- [zig/test] Snapshot test: render the outcome as text, compare with an inline string
  literal by diff, and a tool updates the literal automatically. ^f2
  > Finally, there’s a tool that will _automatically_ update the literal in the source code to match the value actually observed.
- [zig/test] API: `try snap(@src(), \\expected).diff_fmt("2 + 2 = {}", .{result});`,
  `.update()` or `Snap.update_all = true` rewrites the gold value. ^f3
  > ).update().diff_fmt("2 + 2 = {}", .{result});
- [zig/test] Main benefit: software is easy to change; on new requirements only the
  stringification changes and tests re-run once in update mode. ^f4
  > The main benefit of this style of testing is that it makes software easy to change.
- [zig/test] Even for stable code: asserts stop at the first failure; snapshots show all
  failures inline next to the code, a repeatable REPL. ^f5
  > Notice how we have _all_ failures, how they are right there in the code you are looking at
  > Snapshot tests give you a repeatable REPL!
- [zig/test] `std.testing.expectEqualSlices` prints a useful diff, better than
  `std.debug.print`. ^f6
  > Zig has `std.testing.expectEqualSlices` whose job is precisely to print useful diff.
- [zig/test] Keep a few example tests as smoke checks even with fuzzing: a fuzz test may
  miss reversed order, `0 1 2 3 4 -> 119` would not. ^f7
  > a couple of example based tests are still useful for magic smoke checks!
- [zig/test] For small N, an exhaustive test over all inputs with a generator
  (`exhaustigen.zig`, `while (!g.done())`, `g.index(...)`) instead of random. ^f8
  > given that my N is small, an _exhaustive_ test for all permutations I care about
- [zig/test] [zig/safety] Tests use `assert` heavily, and assert container counts before
  and after loops. ^f9
  > assert(permutation.count() == n);

## Read

- Whole post.

## Not read

- tigerbeetle.com "Snapshot Testing For The Masses": reader "tigerbeetle".
- "Generate All The Things" (2021, Rust): exhaustigen technique; lead.
