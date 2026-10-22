---
title: FRNG.zig gist (matklad, 2026-04)
url: https://gist.githubusercontent.com/matklad/343d13547c8bfe9af310e2ca2fbfe109/raw
kind: project
commit: 
for: [zig-testing, zig-comptime]
looked: 2026-10-22
depth: code (whole file, 255 lines)
relevance: high
grade: C/fair
description: The full 255-line FRNG.zig behind "Test Case Minimization": finite RNG helpers, swarm weights, weighted choice, and a Driver that minimises failing entropy via child processes
origin: matklad-test-minimization
---
# FRNG.zig gist (matklad, 2026-04)

Why: copyable Zig 0.16 source for the property-testing harness in
[[matklad-test-minimization]]. Uses `std.process.spawn(io, ...)`, `io.random`,
`writeStreamingAll`, `{t}` format: Zig 0.16 std, current.

## Assessment

- Evidence: C. One file, written in a sitting for a weekend experiment; no tests of its
  own.
- Reasoning: fair. Code only; the post explains it.
- Interests: none.
- Weigh: a template; check the search loop's bound before copying (f5).

## Findings

- [zig/test] [zig/style] File-as-struct with one field `entropy: []const u8,`, `pub
  const Error = error{OutOfEntropy};`, `const FRNG = @This();`. ^f1
  > pub const Error = error{OutOfEntropy};
- [zig/comptime] [zig/safety] `int` asserts at comptime the integer is unsigned and the
  target little-endian before `@bitCast`. ^f2
  > comptime assert(@import("builtin").cpu.arch.endian() == .little);
- [zig/test] `weighted(frng, weights: anytype)` returns
  `std.meta.FieldEnum(@TypeOf(weights))` via `inline for` over `std.meta.fieldNames`. ^f3
  > pub fn weighted(frng: *FRNG, weights: anytype) Error!std.meta.FieldEnum(@TypeOf(weights)) {
- [zig/api] `Driver.main` takes an `operation: union(enum) { replay: struct {...},
  search: struct { attempts: u32 = 100, size_max: u32 = 4 * 1024 * 1024 } }`: modes as a
  tagged union with defaulted options. ^f4
  > operation: union(enum) {
- [zig/test] (inferred) The search loop checks `if (size > driver.buffer.len) break;`
  but then runs `size_next`, which can exceed the buffer and trip the assert in
  `run_once`; check `size_next` if copying. ^f5
  > if (size > driver.buffer.len) break;

## Read

- Whole file.
