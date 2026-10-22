---
title: "256 Lines or Less: Test Case Minimization (matklad, 2026-04-20)"
url: https://matklad.github.io/2026/04/20/test-case-minimization.html
kind: article
commit: 
for: [zig-testing, zig-comptime, zig-api-design]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: B/strong
description: A 256-line Zig property-testing library: a finite RNG over an entropy slice, a World stepped by weighted random actions with swarm weights, and minimisation by searching entropy size in a child process
---
# 256 Lines or Less: Test Case Minimization (matklad, 2026-04-20)

Why: a small DIY fuzz and simulation harness. Zig 0.16 (juicy main `std.process.Init`,
`std.process.spawn(io, ...)`, `io.random`, `std.Io.File.stdin().reader(io, ...)`), so
current for 0.17 except possibly small renames.

## Assessment

- Evidence: B. Expert's own tool, used to find a real algorithmic flaw in a consensus
  prototype; full code in a gist.
- Reasoning: strong. Explains each choice (finite RNG, decisions as you go, fresh shorter
  entropy instead of mutation) and limits ("simplistic even").
- Interests: none.
- Weigh: a direct template for meiolol property tests; the unbiased range code is
  copied from Zig std, he warns "Use at your own risk!".

## Findings

- [zig/test] Core abstraction: a Finite RNG, a PRNG whose bytes are pre-generated and can
  run out (`error{OutOfEntropy}`). ^f1
  > the core abstraction here is a Finite Random Number Generator — a PRNG where all numbers are pre-generated, and can run out.
- [zig/style] File-as-struct: `entropy: []const u8,` field at top level, `const FRNG =
  @This();`, `pub fn init(entropy) FRNG`. ^f2
  > In Zig, files are structs
- [zig/comptime] `array(comptime size)` returns `[size]u8` by slicing with a comptime
  length (`[0..size].*`). ^f3
  > Because `size` is a `comptime` constant, slicing `[]const u8` with `[0..size]` returns a pointer to array, `*const [size]u8`.
- [zig/comptime] [zig/safety] `int(frng, Int: type)` asserts at comptime that Int is
  unsigned and the target is little-endian, rather than being endian-clean. ^f4
  > for simplicity, we encode our endianness assumption as a compile-time assertion.
- [zig/comptime] Target info is Zig code: `@import("builtin")` exposes `cpu` etc. as
  comptime constants, no `--cfg` side channel. ^f5
  > Instead, the compiler materializes all information about target CPU as Zig code.
- [zig/api] Return an index, not a pointer, when picking from a slice: avoids const and
  mut versions and works across parallel arrays (`xs[try frng.index(xs)]`). ^f6
  > A simpler and more general solution is to return an index:
- [zig/test] Code the system to crash on anything unexpected and feed random inputs; then
  coverage of inputs gives confidence. ^f7
  > If we code our system to crash if anything unexpected happens and our random inputs cover the space of all possible inputs, we get a measure of confidence that bugs will be detected in testing.
- [zig/test] [zig/comptime] `weighted(weights: anytype)` returns
  `std.meta.FieldEnum(@TypeOf(weights))`, picking an action proportional to weight; used
  as `switch (try world.frng.weighted(.{ .request = 10, .message = 20, .crash = 1 }))`. ^f8
  > const action = try world.frng.weighted(.{
- [zig/comptime] Study std.meta and std.enums to learn Zig reflection. ^f9
  > if you want to quickly learn Zig’s reflection capabilities, study the implementation of `std.meta` and `std.enums`
- [zig/test] Swarm testing: generate the action weights themselves at random at test
  start (`swarm_weights`). ^f10
  > I always find it hard to figure out which weights are reasonable, and like to generate the weights themselves at random at the start of the test
- [zig/test] Running out of entropy counts as a pass; decisions are made as you go from the
  current World state, not a pre-generated action list. ^f11
  > We aren’t generating a complete list of actions up-front. Rather, we make random decisions as we go
- [zig/errors] He often wants to peel off one error: `catch |err| switch (err) {
  error.OutOfEntropy => return, else => return err }`. ^f12
  > whenever I handle errors in Zig, very often I want to discharge just a single error from the error set.
- [zig/test] Entropy size measures test complexity, so binary search the minimal failing
  size; a fresh shorter random slice works better than mutating the failing one. ^f13
  > You can **binary search** the minimal amount of entropy that’s enough for the test to fail.
  > But a much simpler approach seems to work in practice — just generated a fresh, shorter entropy slice.
- [zig/test] [zig/safety] Assertion failures crash and Zig has no unwinding, so the
  searcher runs each test as a child process with entropy on stdin; a run is reproduced
  from (size, seed). ^f14
  > There’s no unwinding in Zig. For this reason, we’ll move the search code to a different process.
  > just two numbers, entropy size and seed, are needed to reproduce a single run of the test
- [zig/api] 0.16 juicy main: `pub fn main(init: std.process.Init)` gives gpa, io and
  args; Zig avoids ambient IO and threads an Io wherever a syscall happens. ^f15
  > These days, Zig eschews global ambient IO capabilities, and requires threading an Io instance whenever we need to make a syscall.
- [zig/safety] The search loop is `for (0..1024) |_| { ... } else @panic("safety
  counter");`, his bounded-loop habit. ^f16
  > } else @panic("safety counter");
- [zig/api] Options as inline anonymous structs in signatures, e.g. `run_once(driver,
  options: struct { size: u32, seed: u64, quiet: bool })` and union(enum) results. ^f17
  > fn run_once(driver: Driver, options: struct {

## Read

- Whole post.

## Not read

- The gist FRNG.zig (full 256 lines): lead, would be the template to copy.
- tigerbeetle.com "Swarm Testing Data Structures": reader "tigerbeetle".
