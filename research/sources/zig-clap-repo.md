---
title: 'zig-clap (Hejsil/zig-clap): clap.zig, parsers, build.zig, examples'
url: https://github.com/Hejsil/zig-clap
kind: project
commit: 05faf3905e8548f5cc269a8836e154065e70128d
for: [zig-good-practice, zig-comptime, zig-api-design, zig-errors-safety, zig-testing, zig-style, zig-build]
looked: 2026-10-22
depth: code (clap.zig: parseParamsComptime, Diagnostic, ParseOptions, parse, Result, Arguments; clap/parsers.zig; build.zig; example/simple.zig; README)
relevance: high
grade: A/fair
description: the most used Zig argument parser (3.3k lines); parses a help-text spec at comptime into a typed result struct; tracks Zig master (0.17-dev)
---
# zig-clap (Hejsil/zig-clap): clap.zig, parsers, build.zig, examples

Why: how does a small, widely used library design a comptime-heavy API: type generation,
errors at compile time, diagnostics, ownership of results, tests?

## Assessment

- Evidence: A. Created 2018-03, 1629 stars, 100 forks, 36 contributors, release 0.12.0
  (2026-04), pushed 2026-08-31; the default argument parser in many Zig projects. Author
  Hejsil is a long-time Zig contributor.
- Reasoning: fair. Doc comments explain the generated types and ownership; little on why.
- Interests: none known.
- Weigh: a good model for a comptime API with a runtime escape hatch; master tracks
  0.17-dev (1941), so a few std type names differ from 0.17.0.

## Findings

- [toolchain] Master needs Zig 0.17.0-dev.1941; tagged releases pair with tagged Zig, and the
  README gives a fetch command for each. `build.zig.zon`, `README.md` ^f1
  > .minimum_zig_version = "0.17.0-dev.1941+71115f0ab",
  > Version of zig-clap that works with latest build of Zigs master branch
- [zig/comptime] [zig/api] The parameter spec is a help-text string parsed at comptime;
  the result array has exactly the parsed length, and a bad spec is a compile error with
  line and column. `clap.zig` ^f2
  > pub fn parseParamsComptime(comptime str: []const u8) [countParams(str)]Param(Help) {
  > @compileError(std.fmt.comptimePrint("error:{}:{}: Failed to parse parameter:\n{s}", .{
- [zig/comptime] Comptime string parsing needs a raised branch quota, set with a comment on
  why it stays. `clap.zig` ^f3
  > @setEvalBranchQuota(std.math.maxInt(u32));
- [zig/comptime] The same parser works at run time (`parseParams(allocator, str)`), so the
  comptime path is a convenience over ordinary code, not a separate implementation. `clap.zig` ^f4
  > pub fn parseParams(allocator: std.mem.Allocator, str: []const u8) ![]Param(Help) {
- [zig/comptime] The result type is generated: one struct field per named parameter, type
  from the parameter's value parser, built with `@Struct`; the doc comment shows the
  struct a given spec produces. `clap.zig` ^f5
  > return @Struct(
  > /// The result will contain an `args` field which contains all the non positional arguments passed
- [zig/comptime] [zig/api] Value parsers are a comptime anonymous struct of functions keyed
  by value name (`.usize = int(usize, 0)`), looked up with `@field`; users pass their own
  struct to add types. `clap/parsers.zig`, `clap.zig` ^f6
  > pub const default = .{
  > /// @field(value_parsers, param.id.value())
- [zig/comptime] Generic functions return a function: `int(T, base)` returns a parser via a
  local struct's fn. `clap/parsers.zig` ^f7
  > pub fn int(comptime T: type, comptime base: u8) fn ([]const u8) std.fmt.ParseIntError!T {
- [zig/errors] [zig/api] Errors carry detail through an optional Diagnostic out-pointer in
  the options struct; the error union stays plain and the caller reports with
  `diag.report`. `clap.zig`, `example/simple.zig` ^f8
  > diagnostic: ?*Diagnostic = null,
  > try diag.reportToFile(init.io, .stderr(), err);
- [zig/errors] The parser's error set is a named `Error` in the streaming module, switched on
  by the reporter with an else for user parser errors. `clap/streaming.zig`, `clap.zig` ^f9
  > streaming.Error.MissingValue => try stream.print(
- [zig/errors] A parser that cannot fail declares the empty error set `error{}`. `clap/parsers.zig` ^f10
  > pub fn string(in: []const u8) error{}![]const u8 {
- [zig/api] [zig/memory] Options struct with defaults: the allocator is a required field;
  the rest have defaults and doc comments. `clap.zig` ^f11
  > pub const ParseOptions = struct {
  > terminating_positional: usize = std.math.maxInt(usize),
- [zig/memory] The result owns an arena holding every allocation; `deinit` frees it in
  one call, and the doc says the caller owns it. `clap.zig` ^f12
  > /// The result of `parse`. Is owned by the caller and should be freed with `deinit`.
  > result.arena.deinit();
- [zig/memory] `errdefer arena.deinit()` right after creating the arena, before any
  fallible call. `clap.zig` ^f13
  > var arena = std.heap.ArenaAllocator.init(opt.allocator);
  > errdefer arena.deinit();
- [zig/api] [toolchain] 0.17 main takes `std.process.Init` and uses its `gpa`, `io` and
  `minimal.args`. `example/simple.zig` ^f14
  > pub fn main(init: std.process.Init) !void {
  > .allocator = init.gpa,
- [zig/style] Imports at the bottom of every file (`const std = @import("std");` last),
  like Bun. `clap.zig`, `build.zig`, `example/simple.zig` ^f15
  > pub const parsers = @import("clap/parsers.zig");
- [zig/test] Tests inline in the same file after the code they test, with small local
  helpers (`testParseParams`, `testErr`, `testHelp`) and `std.testing.allocator`; a final
  `test { _ = args; ... }` pulls in submodules' tests. `clap.zig` ^f16
  > fn testParseParams(str: []const u8, expected_params: []const Param(Help)) !void {
  > .allocator = std.testing.allocator,
- [zig/build] build.zig exposes the module with `b.addModule`, tests that module, builds
  examples in a loop, and emits autodocs from the test artifact (`getEmittedDocs`). `build.zig` ^f17
  > const clap_mod = b.addModule("clap", .{
  > .source_dir = tests.getEmittedDocs(),
- [zig/build] Examples are compiled as part of the default `all` step, so README code cannot
  rot without breaking the build. `build.zig` ^f18
  > const example_step = b.step("examples", "Build examples");
  > all_step.dependOn(example_step);
- [zig/api] Layered API: `parse` (OS args, arena) wraps `parseEx` (any iterator), which
  wraps a streaming parser for callers who want no allocation. `clap.zig` ^f19
  > /// Same as `parseEx` but uses the `args.OsIterator` by default.

## Read

- `clap.zig`: lines 1-200, 530-1075, 2186-2200; `clap/parsers.zig`: head
- `build.zig`, `build.zig.zon`, `README.md` (install and first example), `example/simple.zig`

## Not read

- `clap/streaming.zig` body: the allocation-free core
- help and usage formatting (`clap.zig` 1315-2185)
