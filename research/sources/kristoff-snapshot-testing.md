---
title: Dead Simple Snapshot Testing In Zig (Loris Cro, 2025)
url: https://kristoff.it/blog/dead-simple-snapshot-testing/
kind: article
commit:
for: [zig-testing, zig-build]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: B/strong
description: Zine's file-based snapshot tests: zig build test regenerates outputs into committed snapshot dirs and fails on git diff --exit-code
---
# Dead Simple Snapshot Testing In Zig (Loris Cro, 2025)

Why: meiolol has a site pipeline; file-level golden tests fit it.

## Assessment

- Evidence: B. Used in Zine (Loris's SSG); Feb 2025, Zig 0.14. Zig team member.
- Reasoning: strong; principle, setup and the condition it depends on (auditable diffs).
- Interests: his own project.
- Weigh: build API calls (`iterateAssumeFirstIteration`, `build_root.handle`) may have
  moved under std.Io in 0.16; the pattern is version-independent.

## Findings

- [zig/test] Snapshot testing: assert against known-good outputs and let the tests regenerate them. ^f1
  > You use your tests to generate (and update) known good values automatically.
- [zig/test] For in-source snapshots, TigerBeetle's approach rewrites the Zig test source; for file outputs he uses build-system integration tests. ^f2
  > When your tests are expressed as Zig `test {}` definitions, you can use a library to update the snapshot by directly modifying the Zig source code that contains your tests.
- [zig/build] `zig build test` rebuilds each fixture into its committed `snapshot/`, then `git add` and `git diff --cached --exit-code` fail the step on any change. ^f3
  > Running `zig build test` will loop over all websites under `tests/` and build each one, placing each output in the corresponding `snapshot/` directory.
  > An empty diff is a success, while any change is considered a test failure.
- [zig/test] Snapshots are only as useful as their diffs are readable. ^f4
  > the effectiveness of snapshot testing is **directly** proportional to how easy it is to audit a diff.
- [zig/build] Prefer `b.addRunArtifact` to running `zig build` as a subprocess; Zine is an exception. ^f5
  > Normally you would want to use `b.runArtifact` to invoke your program.

## Read

- Whole post.
