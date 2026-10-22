---
title: "Roc's Zig compiler (roc-lang/roc src/): AGENT docs, design.md principles, CI lints, invariant helpers"
url: https://github.com/roc-lang/roc
kind: project
commit: 55a9d652c1a4f39285d6d82288aafe9c34bfd647
for: [zig-good-practice, zig-style, zig-errors-safety, zig-testing, zig-perf, zig-memory]
looked: 2026-10-22
depth: docs (AGENTS.md, AGENT.md, src/README.md, design.md Core Principles, Representation Capacity, Dense IDs, Stack Safety) and code (ci/zig_lints.zig, ci/check_test_wiring.zig, src/base/invariant.zig, death_test.zig, collections/safe_list.zig)
relevance: high
grade: B/strong
description: Roc's compiler rewritten in Zig 0.17, 1.1M lines in src/; written rules on invariants vs user errors, unreachable rationale, dense ids, no recursion, enforced by custom Zig lints in CI
---
# Roc's Zig compiler (roc-lang/roc src/): AGENT docs, design.md principles, CI lints, invariant helpers

Why: what written conventions does a big, recent Zig 0.17 codebase hold itself to, and
which does it enforce mechanically?

## Assessment

- Evidence: B. Repo created 2019-01, 6127 stars, 426 forks, 299 contributors; the Zig
  rewrite is recent and not yet shipped as a release (latest tag alpha4-rolling, 2025-08).
  1.1M lines of Zig in src/, 459 snapshot test files, a 7192-line build.zig with dozens of
  check steps. 100 commits between 2026-10-20 and 2026-10-22, and AGENTS.md/AGENT.md
  address coding agents directly: signs of heavily agent-driven development, so volume
  says little.
- Reasoning: strong. design.md states each rule with its reason and the alternatives it
  forbids; the rules are enforced by lints rather than review alone.
- Interests: none known.
- Weigh: the rules on invariants, exhaustive switches and test wiring are well argued and
  cheap to copy. The scale and process (agent rules, 25k-line design doc) are not a model
  for a one-developer project; take the rules, not the bureaucracy.

## Findings

- [toolchain] Requires Zig 0.17.0; src/README advises a ZLS that supports 0.17.0. `build.zig.zon`,
  `src/README.md` ^f1
  > .minimum_zig_version = "0.17.0",
  > run `zls --version` and make sure it supports Zig `0.17.0`.
- [zig/safety] [zig/errors] One rule for compiler invariants everywhere: a debug-only
  assertion in debug builds, `unreachable` in release; never a release runtime check,
  panic, error return or recovery. User-facing failures (bad input, missing files,
  allocation failure, corrupt caches) are reported or propagated, never asserted. `AGENTS.md`,
  `design.md` ^f2
  > A compiler invariant (an assumption that can fail only if the compiler has a bug) is handled the same way everywhere in the compiler
  > User-facing failures (bad source, type errors, missing files, allocation failure, corrupt caches) are not compiler invariants and are reported or propagated, never asserted.
- [zig/safety] Every `unreachable` carries an end-of-line comment naming the upstream
  invariant that makes the case impossible; a build step enforces it for every file. `design.md`,
  `src/check/dispatch_evidence.zig` ^f3
  > Every `unreachable` keyword in the compiler's source carries a `//` comment
  > `zig build run-check-unreachable-rationale` enforces this for
  > return self.kindOrNull() orelse unreachable; // PathStep construction writes only Kind values, and artifact validation rejects any other discriminant
- [zig/safety] Where the invariant cannot be named at the site, `base.invariant(fmt,
  args)`: panics with the message when runtime safety is on, else `unreachable`. `src/base/invariant.zig` ^f4
  > pub inline fn invariant(comptime fmt: []const u8, args: anytype) noreturn {
  > if (std.debug.runtime_safety) std.debug.panic(fmt, args);
- [zig/test] [zig/safety] Death tests pin that an invariant fires: the test re-runs itself
  in a child copy of the test binary and passes when the child panics with the expected
  message, because a panic ends the whole test process. `src/base/death_test.zig` ^f5
  > A violated invariant panics (`base.invariant`), and a panic ends the whole
  > test process, so a test cannot observe one in-process.
- [zig/test] [zig/build] Zig collects tests lazily: `refAllDecls(@This())` is one level and
  pub-only, an unreferenced import adds nothing, so a test file can silently never run.
  Roc checks every `test` decl appears in some test binary's metadata list. `ci/check_test_wiring.zig` ^f6
  > Zig's lazy test collection means a cross-module
  > is one-level and pub-only, and an unreferenced import contributes
- [zig/style] [zig/safety] Lint: a `switch` may have an `else` prong only when it also
  switches on literals or errors; over enums every case must be listed, so a new variant
  fails to compile. `ci/zig_lints.zig` ^f7
  > "{s}:{d}: switch else prong must be exhaustive\n",
- [zig/style] Lints: every `.zig` file starts with a `//!` module doc comment; every top-level
  `pub` decl has a `///` doc comment (except init, deinit, imports, re-exports); no
  horizontal-line separator comments. `ci/zig_lints.zig`, `AGENT.md` ^f8
  > Every `.zig` file should start with module documentation `//!` that describes the module's purpose.
  > "{s}:{d}: pub declaration without doc comment `///`\n"
  > horizontal line separator comment not allowed
- [zig/style] Docs and comments explain WHY, not WHAT or HOW, since implementation detail
  changes; every src/ directory has a README.md. `AGENT.md` ^f9
  > our documentation should be concise, focusing on the WHY and avoiding the WHAT or HOW
- [zig/style] The lints are themselves Zig programs using `std.zig.Ast.parse` over the
  source, run as build steps. `ci/zig_lints.zig` ^f10
  > var tree = try std.zig.Ast.parse(allocator, source, .{ .mode = .zig });
- [zig/perf] [zig/memory] Dense ids: identities are dense store-local integer `...Id`s with
  per-id data as parallel columns on the owning store, not hash maps; a lint rejects a
  HashMap keyed by an `...Id` type. `design.md` ^f11
  > Per-ID data is a parallel column on the owning store, or a
  > The Zig source lint in `ci/zig_lints.zig` rejects a `HashMap` whose first type
- [zig/perf] Why dense columns: they avoid hashing, table growth, repeated key storage,
  allocator traffic and duplicate per-consumer indexes. `design.md` ^f12
  > Direct columns avoid hashing, table growth,
  > repeated key storage, allocator traffic, and duplicate per-consumer indexing
- [zig/memory] [zig/errors] Every count that grows with input has a width chosen per
  field; narrowing a host-sized count is checked, and overflow returns `error.OutOfMemory`
  like a failed allocation, never an unchecked `@intCast`. `design.md`, `src/collections/safe_list.zig` ^f13
  > Converting a host-sized count into one
  > of these widths is checked, and a count past the field's range returns
  > if (new_len > max_len) return error.OutOfMemory;
- [zig/perf] [zig/api] Typed index ranges instead of slices: `SafeRange(Idx)` is a start
  index plus count, stable across reallocation and serialisation where a slice would dangle. `src/collections/safe_list.zig` ^f14
  > This is the conceptual equivalent of slice, but since this is based
  > on indexes in the list rather than pointers, it is reliable across
- [zig/safety] [zig/perf] No recursion over input-shaped data in any stage: walks keep
  pending work on heap-backed frame stacks or worklists; a bigger thread stack or depth
  limit is not an accepted fix; tests run deep shapes on a tiny-stack thread. `design.md` ^f15
  > Direct, indirect, and mutual recursion
  > over any of these structures is forbidden.
  > Stack-safety tests compile and run each deep shape on a thread whose stack is
- [zig/test] Two test kinds: Zig unit tests next to the code with `test` for low-level
  details, and more commonly markdown snapshot files showing each compiler stage's output
  for a snippet, regenerated by a tool and diffed in CI. `AGENT.md` ^f16
  > These are written in `.zig` files using the `test` keyword alongside the code they are testing.
  > Snapshot files `.md` concurrently exercise many parts of the compiler
- [zig/test] [zig/build] Tests run through custom build steps (`zig build run-test-zig --
  --test-filter`), not `zig test`; a `zig build -Dno-bin -fincremental --watch` loop
  type-checks without emitting binaries for fast feedback. `AGENT.md`, `src/README.md` ^f17
  > NEVER use the standard `zig test`, it does not work with our project.
  > Try it with `zig build -Dno-bin -fincremental --watch`
- [zig/memory] DebugAllocator configs must take the stack-trace depth from a build option
  (lint-enforced), so leak traces are tunable in one place. `ci/zig_lints.zig` ^f18
  > DebugAllocator config must use build_options.debug_gpa_stack_trace_frames
- [zig/build] build.zig defines named check steps per rule (unreachable rationale, test
  wiring, `@enumFromInt(0)` ban, panic ban in interpreter, format, lints) so each runs
  alone; a `minici` step runs them all. `ci/zig_lints.zig`, `AGENT.md` ^f19
  > When `zig build minici` fails in one section, fix the issue and rerun that specific failing section until it passes.
- [zig/errors] Error sets composed with `||` and named per module (`ChildError`, `Error`)
  with doc comments. `src/base/death_test.zig` ^f20
  > pub const Error = ChildError || error{ DeathTestDidNotPanic, DeathTestWrongPanic };
- [zig/comptime] Idiom counts in src/ (1.1M lines): 1232 `anytype`, 585 `inline for`,
  250 `@compileError`, 2580 `errdefer`, 1805 `std.debug.assert(`, 3752 `invariant(`,
  70 `catch unreachable`, only 2 `std.log.scoped`. ^f21

## Read

- `AGENTS.md`, `AGENT.md`, `src/README.md`: all
- `design.md`: Core Principles, Representation Capacity, Dense IDs and structural keys, Stack Safety
- `ci/zig_lints.zig`: separator, switch-else, pub doc, DebugAllocator checks; `ci/check_test_wiring.zig` header
- `src/base/invariant.zig`, `src/base/death_test.zig` head, `src/collections/safe_list.zig` head
- grep counts over src/; build.zig step list

## Not read

- `src/check/`, `src/parse/`, `src/layout/`: the compiler stages themselves
- `CONTRIBUTING/fuzzing.md`, `CONTRIBUTING/profiling/`: AFL fuzzing setup and profiling
- the rest of `design.md` (25k lines), mostly Roc semantics
