---
title: 'Zig 0.17 std.testing: expectations, testing allocator, allocation-failure checks, Smith fuzzing'
url: https://codeberg.org/ziglang/zig/src/tag/0.17.0/lib/std/testing.zig
kind: project
commit: 0.17.0
for: [zig-testing, zig-memory]
looked: 2026-10-22
depth: code (std/testing.zig, testing/Smith.zig head, testing/FailingAllocator.zig head, deque.zig tests, json.zig test block)
relevance: high
grade: A/strong
description: Zig 0.17.0 std.testing module and the std's own test idioms, including the new Smith-driven fuzz API and an oracle fuzz test
---
# Zig 0.17 std.testing

Why: how the std tests itself in 0.17: argument order, leak checking, OOM coverage,
fuzzing, and how test files get pulled into the build.

## Assessment

- Evidence: A. The std's own test library, used by every std and compiler test.
- Reasoning: strong. `checkAllAllocationFailures` has a worked example and lists its
  failure modes; fuzz helpers explain their `inline`/`noinline` choices.
- Interests: none.
- Weigh: the fuzz API changed in 0.16-0.17 (Smith replaces a raw byte slice); stable
  parts are expect*, testing.allocator and checkAllAllocationFailures.

## Findings

- [zig/test] `expectEqual(expected, actual)`: expected first, and both are coerced by peer
  type resolution, so `expectEqual(0, q.popFront())` works without a cast. `std/testing.zig:51` ^f1
  > /// `actual` and `expected` are coerced to a common type using peer type resolution.
  > pub inline fn expectEqual(expected: anytype, actual: anytype) !void {
  > const T = @TypeOf(expected, actual);
- [zig/test] [toolchain] (inferred) Older advice to write `expectEqual(@as(u32, 0), x)` to
  dodge comptime_int is stale: peer resolution makes the bare literal fine. ^f2
- [zig/test] `testing.allocator` is a SafeAllocator instance that exists only under
  `builtin.is_test`; using it outside tests is a compile error. Same for `testing.io`. `std/testing.zig:20` ^f3
  > pub var allocator_instance: std.heap.SafeAllocator = undefined;
  > pub const allocator = if (builtin.is_test) allocator_instance.allocator() else @compileError("not testing");
  > pub const io = if (builtin.is_test) io_instance.io() else @compileError("not testing");
- [zig/test] Tests get a deterministic random seed set at startup. `std/testing.zig:9` ^f4
  > /// Provides deterministic randomness in unit tests.
  > pub var random_seed: u32 = 0;
- [zig/test] `failing_allocator` fails the first allocation; `FailingAllocator` takes a
  `fail_index` to fail the Nth. `std/testing/FailingAllocator.zig:1` ^f5
  > //! Allocator that fails after N allocations, useful for making sure out of
  > /// The number of successful allocations you can expect from this allocator.
- [zig/test] `checkAllAllocationFailures(allocator, testFn, extra_args)` runs the test once
  to count allocations, then once per allocation with that one failing, and reports
  leaks on each OOM path. `std/testing.zig:1070` ^f6
  > /// Exhaustively check that allocation failures within `test_fn` are handled without
  > /// - Run the test function once to get the total number of allocations.
  > pub fn checkAllAllocationFailures(
- [zig/test] It requires the allocator as `testFn`'s first parameter, deterministic
  allocation counts, and returns SwallowedOutOfMemoryError if code eats an OOM. `std/testing.zig:1075` ^f7
  > /// The provided `test_fn` must have a `std.mem.Allocator` as its first argument,
  > /// Expects that `test_fn` has a deterministic number of memory allocations:
  > ///   didn't return `error.OutOfMemory`, then `error.SwallowedOutOfMemoryError`
- [zig/comptime] Its `extra_args` type is computed from the test fn's signature and wrong
  shapes give a readable @compileError; 0.17 builds the tuple with `@Tuple`. `std/testing.zig:1216` ^f8
  > @compileError("The provided function must have an " ++ @typeName(std.mem.Allocator) ++ " as its first argument");
  > return @Tuple(&extra_args);
- [zig/test] `refAllDecls(@This())` in a bare `test {}` forces analysis of every decl so
  unused code still compiles; std.zig does this for itself. `std/testing.zig:1242` ^f9
  > /// Given a type, references all the declarations inside, so that the semantic analyzer sees them.
  > pub fn refAllDecls(comptime T: type) void {
- [zig/test] Separate test files are pulled in from the module root with a bare `test`
  block of `_ = @import(...)` lines. `std/json.zig:131` ^f10
  > _ = @import("json/test.zig");
  > _ = @import("json/dynamic.zig");
- [zig/test] [toolchain] 0.17 fuzzing: `testing.fuzz(context, testOne, options)` where
  `testOne` takes a `*Smith`, a generator of typed values, instead of raw bytes. `std/testing.zig:1256` ^f11
  > /// Inline to avoid coverage instrumentation.
  > comptime testOne: fn (context: @TypeOf(context), smith: *Smith) anyerror!void,
  > //! Used in conjuncation with `std.testing.fuzz` to generate values
- [zig/test] Smith draws typed and weighted values (`value(T)`, `valueWeighted`,
  `eosWeightedSimple`), so a fuzz test is a loop of random actions until end of stream. `std/testing/Smith.zig:199` ^f12
  > pub noinline fn value(s: *Smith, T: type) T {
  > pub noinline fn valueWeighted(s: *Smith, T: type, weights: []const Weight) T {
- [zig/test] The std's own fuzz test drives Deque and an ArrayList oracle with the same
  random actions and expects equal results, including the `*Bounded` OOM returns. `std/deque.zig:619` ^f13
  > fn fuzzAgainstArrayList(_: void, smith: *std.testing.Smith) anyerror!void {
  > while (!smith.eosWeightedSimple(15, 1)) {
  > l.appendBounded(item),
  > q.pushBackBounded(item),
- [zig/test] The fuzz test also injects a fuzz-controlled allocator whose resize and remap
  fail on `smith.value(bool)`, so growth paths are explored too. `std/deque.zig:520` ^f14
  > const FuzzAllocator = struct {
  > if (new_len > f.bufs[slot].len or f.smith.value(bool)) return false;
- [zig/test] Test names: short strings per behaviour (`test "iterator"`), or the bare decl
  name for doc tests; the oracle test says what it checks. `std/deque.zig:515` ^f15
  > test "fuzz against ArrayList oracle" {
  > try std.testing.fuzz({}, fuzzAgainstArrayList, .{});
- [zig/test] `testing.tmpDir` makes a random dir under .zig-cache/tmp and `cleanup` deletes
  it; it asserts it runs in a test. `std/testing.zig:606` ^f16
  > pub fn tmpDir(opts: Io.Dir.OpenOptions) TmpDir {
  > comptime assert(builtin.is_test);
- [zig/test] `expectEqualDeep` compares through pointers and fields; `expectEqualSlices`
  and `expectEqualStrings` print a diff-style report. `std/testing.zig:761` ^f17
  > /// Pointer values are deeply equal if values they point to are deeply equal.
  > pub inline fn expectEqualDeep(expected: anytype, actual: anytype) error{TestExpectedEqual}!void {
- [zig/test] `testing.Reader` is an Io.Reader double that yields a scripted list of
  chunks, to test short-read handling. `std/testing.zig:1265` ^f18
  > /// A `Io.Reader` that writes a predetermined list of buffers during `stream`.
- [zig/test] Test failures are errors (`error.TestExpectedEqual`,
  `TestUnexpectedResult`), so tests are `!void` and `try` every expect. `std/testing.zig:583` ^f19
  > pub fn expect(ok: bool) !void {
  > if (!ok) return error.TestUnexpectedResult;
- [zig/safety] std.zig pins its own identity with a top-level `comptime` assert, a
  configuration check that costs nothing at runtime. `std/std.zig:247` ^f20
  > debug.assert(@import("std") == @This()); // std lib tests require --zig-lib-dir

## Read

- `std/testing.zig`: header, expectEqual, expect, tmpDir, expectError,
  checkAllAllocationFailures, refAllDecls, fuzz
- `std/testing/Smith.zig`: header and public fns list
- `std/deque.zig`: tests and the fuzz oracle
- `std/json.zig`: test block

## Not read

- `std/Build` fuzz runner side (`zig build --fuzz`, corpus handling)
- `std/zig/parser_fuzz.zig`, `TokenSmith.zig`: parser fuzzing against an oracle, likely
  the most elaborate example
