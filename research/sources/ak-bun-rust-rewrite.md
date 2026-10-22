---
title: My Thoughts on the Bun Rust Rewrite - Andrew Kelley (2026-07-09)
url: https://andrewkelley.me/post/my-thoughts-bun-rust-rewrite.html
kind: article
commit:
for: [zig-good-practice, zig-comptime, zig-errors-safety, zig-testing]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/fair
description: Kelley's response to Bun leaving Zig for Rust; mostly about the relationship, with a few statements of what the Zig team sees as bad Zig practice (assertion abuse, comptime abuse, no fuzzing, ignored LTO) and compile-speed numbers
---
# My Thoughts on the Bun Rust Rewrite

Why: rare first-hand statement from the Zig lead of what "How Not To Write Zig Code"
looks like in a large codebase.

## Assessment

- Evidence: B. First-hand from Kelley, but about one project he is in conflict with;
  no code cited.
- Reasoning: fair on the technical points (names the practices, points to tools); the
  rest is personal and not used here.
- Interests: strong: a public dispute with a former sponsor; read as one side.
- Weigh: use only as the team's stated values (bug-elimination time, careful asserts,
  restrained comptime, fuzzing); verify each with technical sources.

## Findings

- [zig] The Zig team reads users' source code to see how the language affects them,
  test breakage and check performance regressions. ^f1
  > The Zig team regularly checks in on our users' projects.
- [zig/safety] Practices he calls bad Zig: hacks on hacks, abuse of assertions, speeding
  through features without time to eliminate bugs and debt. ^f2
  > Hacks on top of hacks. [Abuse of assertions.](https://kristoff.it/blog/fix-your-asserts/)
- [zig/safety] [zig/test] Bugs are eliminated by dedicating engineering time, not by a
  style guide or language feature alone; he credits TigerBeetle for doing that work. ^f3
  > The sleight of hand misdirects the reader away from the main way bugs are eliminated: by dedicating engineering resources to it.
- [zig/comptime] [zig/perf] The team warned Bun about comptime abuse for years and built
  the time report (0.15) to audit comptime and inline cost on compile times. ^f4
  > We've been trying to warn you about your `comptime` abuse for years.
- [zig/build] [zig/perf] LTO was supported all along (it was on by default until LLVM
  bugs). ^f5
  > Performance increase is attributed to LTO, which Zig has supported for all of Bun's existence.
- [zig/build] [zig/perf] Compile speed reference: the 600k-line Zig compiler builds from
  clean in 16 s and rebuilds an edit in 90 ms with incremental. ^f6
  > I'm clocking 16s to build from scratch with a clean cache, followed by 90ms for each subsequent edit with incremental compilation enabled
- [zig/test] He expects fuzzing of serious Zig code. ^f7
  > The post implies you were diligently fuzzing your Zig code, while during our calls the Bun team told us that they were not fuzzing anything.

## Read

- Whole post; personal and business parts not used.

## Not read

- kristoff.it "Fix your asserts" (lead).
