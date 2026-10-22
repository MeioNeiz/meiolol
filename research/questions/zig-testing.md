---
status: answered
parent: zig-good-practice
priority: soon
area: code
tags: [zig/test]
description: How do the Zig docs and respected projects test Zig code: unit tests, testing allocator, fuzzing, snapshot and simulation testing?
---
# How do the Zig docs and respected projects test Zig code: unit tests, testing allocator, fuzzing, snapshot and simulation testing?

Feeds: docs/zig/README.md (the Zig practice guide, split by topic), then applying it to the repo

## Answer

Tests live beside the code and use `std.testing.allocator` (leak and double-free
checks) and `std.testing.io` (C1). Zig collects tests lazily, so test files must be
referenced from a root `test {}` block, and some projects check the wiring (C2). Use
`expectEqual(expected, actual)` and specific helpers (C3). Error paths rarely run:
`checkAllAllocationFailures` and fault injection (Ghostty's tripwire) exercise them
(C4). Data-driven tests through one `check` function and snapshot tests (self-updating
literals, or files plus `git diff --exit-code`) keep tests cheap to change (C5, C6).
Fuzz with `std.testing.fuzz` and `Smith` against an oracle, or as seeded programs with a
smoke mode and canary (C7, C8); random tests seed from `std.testing.random_seed` and
swarm their weights (C9). Shrink every limit for tests (C10). No stdout in tests; since
0.16 stderr output fails runs, so tests set the log level (C11). Benchmarks and lints can
be tests (C12).

## Claims

- C1: Tests sit beside the code and use testing.allocator and testing.io. for: [[zig-std-containers#^f16]], [[zig-std-testing#^f3]], [[zig-016-release-notes#^f4]], [[zig-langref-017-a#^f32]]
- C2: Test files must be referenced from a discovered test block; unreferenced tests silently skip. for: [[zig-langref-017-b#^f85]], [[zig-std-testing#^f9]], [[roc-zig-compiler#^f6]], [[zls-repo#^f30]]
- C3: Use expectEqual(expected, actual) and specific helpers; no casts needed. for: [[zig-langref-017-a#^f26]], [[zig-std-testing#^f1]], [[zig-std-testing#^f2]]
- C4: OOM and errdefer paths are tested with checkAllAllocationFailures or injected fail points. for: [[liptak-check-all-allocation-failures#^f5]], [[zig-std-testing#^f6]], [[mitchellh-tripwire#^f1]], [[ghostty-repo#^f66]]
- C5: Data-driven tests go through one check function with inputs and expected output as literals. for: [[matklad-how-to-test#^f1]], [[zls-repo#^f31]], [[zls-repo#^f32]]
- C6: Snapshot tests update their expectations automatically. for: [[tigerbeetle-blog-snapshot-testing#^f2]], [[matklad-snapshot-testing#^f1]], [[kristoff-snapshot-testing#^f3]]
- C7: Fuzz with std.testing.fuzz and Smith against an oracle. for: [[zig-std-testing#^f13]], [[zig-016-release-notes#^f41]], [[superhtml-repo#^f21]], [[zig-repo-docs#^f17]]
- C8: Fuzzers can be plain seeded programs with a CI smoke mode and a canary that must fail. for: [[tigerbeetle-code#^f39]], [[tigerbeetle-blog-four-fuzzers#^f1]], [[tigerbeetle-blog-four-fuzzers#^f8]]
- C9: Random tests seed from std.testing.random_seed and swarm their weights. for: [[tigerbeetle-blog-four-fuzzers#^f6]], [[tigerbeetle-blog-swarm-testing#^f2]], [[matklad-test-minimization#^f10]]
- C10: Tests run with minimal limits to reach edge cases fast. for: [[tigerbeetle-code#^f15]]
- C11: Tests do not print to stdout; since 0.16 stderr output marks runs failed. for: [[zig-learn-build-system#^f13]], [[ghostty-repo#^f64]], [[tigerbeetle-code#^f21]]
- C12: Lints and benchmarks can run as tests. for: [[matklad-mechanical-habits#^f1]], [[matklad-mechanical-habits#^f6]], [[tigerbeetle-tidy#^f1]]
- C13: Asserts plus fuzzing are worth more than many unit tests coupled to internals. for: [[kristoff-talk-better-software#^f3]], [[kristoff-fix-your-asserts#^f2]], [[zig-talk-roadmap-2026#^f14]]
- C14: Exhaustive enumeration of small inputs finds minimal failures first. for: [[matklad-generate-all#^f1]], [[matklad-generate-all#^f3]]

## Disagreements

- Built-in fuzzer: SuperHTML and the init template use it; TigerBeetle could not get it
  working and Ghostty uses AFL++; meiolol saw `--fuzz` exit 0 on a crash. Both routes
  work; std's needs its log checked.

## Open

- Whether 0.17's `zig build --fuzz` now exits non-zero on a crash
