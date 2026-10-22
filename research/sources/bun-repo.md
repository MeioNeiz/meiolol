---
title: 'Bun (oven-sh/bun) at bun-v1.3.14, its last Zig release: src/CLAUDE.md, bun.zig, ptr/, safety/'
url: https://github.com/oven-sh/bun
kind: project
commit: 0d9b296af33f2b851fcbf4df3e9ec89751734ba4
for: [zig-good-practice, zig-memory, zig-style, zig-errors-safety, zig-api-design]
looked: 2026-10-22
depth: code (sparse checkout of tag bun-v1.3.14: src/CLAUDE.md, CONTRIBUTING.md, scripts/build/zig.ts, src/bun.zig parts, src/ptr/shared.zig, src/safety/)
relevance: medium
grade: A/fair
description: the largest Zig codebase (535k lines) until mid-2026, on a forked Zig with its own std replacements; now rewritten in Rust (HEAD has 0 .zig files)
---
# Bun (oven-sh/bun) at bun-v1.3.14, its last Zig release: src/CLAUDE.md, bun.zig, ptr/, safety/

Why: which Zig idioms did the biggest Zig codebase use, where was it idiosyncratic, and
what does its departure from Zig say about memory practice?

## Assessment

- Evidence: A for scale and use (96k stars, 5105 forks, 448 contributors, created 2021-04,
  release bun-v1.4.4 on 2026-10-22), but the Zig era is over: HEAD (b6a5ecee, 2026-10-22)
  has 0 `.zig` files and 3249 `.rs` files; v1.3.14 (2026-05-12) was the last Zig release
  (see [[bun-in-rust]]).
- Reasoning: fair. The agent notes (src/CLAUDE.md) state rules with short reasons.
- Interests: owned by Anthropic since 2025-12; the rewrite was done with Claude agents.
- Weigh: a counter-model more than a model: forked compiler, private-field syntax that
  upstream Zig lacks, std replaced by `bun.*`, ReleaseFast without bounds checks. Useful
  as evidence of what hurts at scale (lifetimes across GC and manual memory).

## Findings

- [toolchain] Built with a fork of Zig at a pinned commit, downloaded with its own stdlib;
  no system zig. `scripts/build/zig.ts` ^f1
  > Bun uses a FORK of zig at a pinned commit (oven-sh/zig). The compiler
  > The downloaded zig includes its own stdlib (vendor/zig/lib/) — we don't
- [zig/style] [toolchain] Uses `#`-prefixed private struct fields, a feature of its fork,
  not upstream Zig (which has no private fields). `src/CLAUDE.md` ^f2
  > Private fields are fully supported in Zig with the `#` prefix.
- [zig/style] Convention: `@import`s go at the bottom of the file (ptr/shared.zig ends with
  them), never inline in functions, since imports have no side effects. `src/CLAUDE.md`,
  `src/ptr/shared.zig` ^f3
  > Prefer `@import` at the **bottom** of the file
  > **Never** use `@import()` inline inside of functions.
- [zig/api] Decl literals recommended for initialisation. `src/CLAUDE.md` ^f4
  > Decl literals in Zig are recommended.
- [zig/api] [zig/errors] std is wrapped: always `bun.*` over `std.*` for fs, posix, paths,
  strings, because the wrappers keep OS error info (errno, syscall, path) and never use
  `unreachable`. `src/CLAUDE.md` ^f5
  > **Always use `bun.*` APIs instead of `std.*`.**
  > provides cross-platform wrappers that preserve OS error info and never use `unreachable`.
- [zig/errors] System calls return `Maybe(T)`, a tagged union of result or a rich
  `bun.sys.Error`, instead of a Zig error union, so the error carries data; `.unwrap()`
  converts to `try`. `src/CLAUDE.md` ^f6
  > All return `Maybe(T)` — a tagged union of `.result: T` or `.err: bun.sys.Error`:
  > Preserves errno, syscall tag, and file path.
- [zig/memory] One global default allocator (mimalloc) for almost everything. `src/CLAUDE.md`,
  `src/bun.zig` ^f7
  > **Use `bun.default_allocator` for almost everything.** It's backed by mimalloc.
- [zig/memory] [zig/errors] OOM crashes the process via `bun.handleOom(expr)`, which only
  catches `error.OutOfMemory`; `catch bun.outOfMemory()` is banned because it would swallow
  other errors too. `src/CLAUDE.md` ^f8
  > `bun.handleOom(expr)` converts `error.OutOfMemory` into a crash without swallowing other errors:
- [zig/memory] Rust-style smart pointers in Zig: `Shared(*T)`, `AtomicShared`, weak
  pointers, built from a comptime options struct; deref calls the value's `deinit`. `src/ptr/shared.zig` ^f9
  > /// A shared pointer, allocated using the default allocator.
  > /// Whether to call `deinit` on the data before freeing it, if such a method exists.
- [zig/memory] [zig/safety] CheckedAllocator: in CI-assert builds, unmanaged containers
  record the allocator first used and assert every later call passes the same one. `src/safety/alloc.zig` ^f10
  > Use this in unmanaged containers to ensure multiple allocators aren't being used with the same
- [zig/safety] ThreadLock: a debug lock asserting that one thread owns a structure, enabled
  only in CI-assert builds. `src/safety/ThreadLock.zig` ^f11
  > pub fn assertLocked(self: *const Self) void {
  > pub const enabled = bun.Environment.ci_assert;
- [zig/safety] Own `bun.assert`: returns early when asserts are off, `unreachable` in
  Debug, otherwise a reported assertion failure; plus `assertf` with a message. Unlike
  std.debug.assert it is not an optimiser hint in release. `src/bun.zig` ^f12
  > if (comptime !Environment.allow_assert) {
  > pub fn assertf(ok: bool, comptime format: []const u8, args: anytype) callconv(callconv_inline) void {
- [zig/style] Logging by scope enabled with an env var per scope in debug builds. `CONTRIBUTING.md` ^f13
  > Enable logging for a specific zig scope: `BUN_DEBUG_EventLoop=1 bun-debug ...`
- [zig/build] [zig/perf] Zig was one compilation unit: a debug build took about 2.5 minutes
  on Zig changes, much slower than C++ which is many units. `CONTRIBUTING.md` ^f14
  > Bun generally takes about 2.5 minutes to compile a debug build when there are Zig changes.
  > (Zig is one compilation unit, C++ is many)
- [zig/safety] AddressSanitizer on by default in debug builds on Linux and macOS, Zig code
  included (needed a compiler patch, see [[bun-in-rust]]). `CONTRIBUTING.md` ^f15
  > is enabled by default in debug builds of Bun on Linux and macOS. This includes the Zig code and all dependencies.

## Read

- `src/CLAUDE.md`: Zig, bun.* APIs, Memory & Allocators sections
- `CONTRIBUTING.md`: build, debugging, ASAN, logging sections; `scripts/build/zig.ts`: header
- `src/bun.zig`: default_allocator, handleOom, assert, assertf
- `src/ptr/shared.zig`: head and tail; `src/safety/alloc.zig`, `src/safety/ThreadLock.zig`: decl list

## Not read

- the 535k lines of Zig under src/ (not checked out): JSC bindings, bundler, parser
- `.claude/skills/zig-system-calls/SKILL.md`, `implementing-jsc-classes-zig`: agent skills for its Zig
