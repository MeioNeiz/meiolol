---
title: Zig 0.17 std.json parsing, std.fmt, process.Args, Build.zig API shape
url: https://codeberg.org/ziglang/zig/src/tag/0.17.0/lib/std/json
kind: project
commit: 0.17.0
for: [zig-api-design, zig-errors-safety, zig-memory, zig-build]
looked: 2026-10-22
depth: code (std/json/static.zig head, json/Scanner.zig init and Diagnostics, fmt.zig Alt/parseInt/print family, process/Args.zig, Build.zig options and Graph alloc)
relevance: medium
grade: A/fair
description: Zig 0.17.0 std modules read for options structs, diagnostics out-params, arena-returning parse results and deprecation paths
---
# Zig 0.17 std.json, std.fmt, process.Args, Build.zig

Why: examples in the std of Options structs, a Diagnostics out-parameter, results that
own an arena, comptime hooks, and of a module that panics on OOM by design.

## Assessment

- Evidence: A. The std itself (signals in [[zig-std-containers]]).
- Reasoning: fair. json documents its options well; some internals are older style
  (json/static.zig still imports the deprecated Managed ArrayList).
- Interests: none.
- Weigh: std.json is older code than Io or containers; copy its API ideas (Parsed,
  Leaky variants, Diagnostics) more than its internals.

## Findings

- [zig/api] ParseOptions: every field defaulted and doc-commented, so callers pass `.{}`
  and override one field; inline anonymous enum for a 3-way choice. `std/json/static.zig:16` ^f1
  > pub const ParseOptions = struct {
  > duplicate_field_behavior: enum {
  > ignore_unknown_fields: bool = false,
- [zig/api] Missing JSON fields are handled by struct field defaults, not options. `std/json/static.zig:17` ^f2
  > /// For missing fields, give the Zig struct fields default values.
- [zig/memory] `parseFromSlice` returns `Parsed(T)`, a value plus the heap-allocated arena
  owning everything it points to; one `deinit` frees it all. `std/json/static.zig:56` ^f3
  > pub fn Parsed(comptime T: type) type {
  > arena: *ArenaAllocator,
  > /// You must call `deinit()` of the returned object to clean up allocated resources.
- [zig/memory] The `*Leaky` variant takes any allocator and makes no attempt to free;
  the doc tells you to pass an arena. Two entry points, one per ownership model. `std/json/static.zig:86` ^f4
  > /// Allocations made during this operation are not carefully tracked and may not be possible to individually clean up.
  > /// It is recommended to use a `std.heap.ArenaAllocator` or similar.
- [zig/errors] Building the arena uses a double errdefer: destroy the arena struct, then
  deinit it once initialised, in reverse order of setup. `std/json/static.zig:108` ^f5
  > .arena = try allocator.create(ArenaAllocator),
  > errdefer allocator.destroy(parsed.arena);
  > errdefer parsed.arena.deinit();
- [zig/errors] The error set is computed by a type function from the source type, merged
  with `||`. `std/json/static.zig:192` ^f6
  > pub fn ParseError(comptime Source: type) type {
  > return ParseFromValueError || Source.NextError || Source.PeekError || Source.AllocError;
- [zig/errors] Diagnostics out-param: the caller declares a `Diagnostics` and registers a
  pointer; after an error it reads line, column and byte offset. The error stays a plain
  error code. `std/json/Scanner.zig:1542` ^f7
  > /// To enable diagnostics, declare `var diagnostics = Diagnostics{};` then call `source.enableDiagnostics(&diagnostics);`
  > /// At any time, notably just after an error, call `getLine()`, `getColumn()`, and/or `getByteOffset()`
- [zig/api] The scanner stores `diagnostics: ?*Diagnostics = null`, so diagnostics cost
  nothing unless enabled. `std/json/Scanner.zig:61` ^f8
  > diagnostics: ?*Diagnostics = null,
  > diagnostics.cursor_pointer = &self.cursor;
- [zig/safety] Untrusted-input limit by default: 4 MiB per string or number value, with a
  `*Max` variant to change it. `std/json/Scanner.zig:1569` ^f9
  > /// For security, the maximum size allocated to store a single string or number value is limited to 4MiB by default.
  > pub const default_max_value_len = 4 * 1024 * 1024;
- [zig/api] Init variants are named by input shape (`initStreaming`, `initCompleteInput`),
  and docs say what the allocator is for. `std/json/Scanner.zig:63` ^f10
  > /// The allocator is only used to track `[]` and `{}` nesting levels.
  > pub fn initCompleteInput(allocator: Allocator, complete_input: []const u8) @This() {
- [zig/comptime] Custom parsing is duck-typed: if the target type has a `jsonParse`
  decl, the parser calls it (`std.meta.hasFn`). `std/json/static.zig:260` ^f11
  > if (std.meta.hasFn(T, "jsonParse")) {
  > return T.jsonParse(allocator, source, options);
- [zig/style] json/static.zig still uses `std.array_list.Managed`, deprecated elsewhere:
  the std does not migrate all its code at once. `std/json/static.zig:5` ^f12
  > const ArrayList = std.array_list.Managed;
- [zig/api] [toolchain] `fmt.bufPrint` and `fmt.allocPrint` are deprecated in 0.17 for
  `mem.print` and `Allocator.print`. `std/fmt.zig:597` ^f13
  > /// Deprecated in favor of `mem.print`.
  > /// Deprecated in favor of `Allocator.print`.
- [zig/api] `fmt.alt(value, .method)` picks a format method other than `format` for `{f}`,
  so a type can have several renderings without wrapper types. `std/fmt.zig:283` ^f14
  > /// Helper for calling alternate format methods besides one named "format".
  > try expectFmt("a", "{f}", .{alt(ex, .other)});
- [zig/errors] ParseIntError is two errors, each doc-commented with its meaning. `std/fmt.zig:304` ^f15
  > pub const ParseIntError = error{
  > /// The result cannot fit in the type specified.
  > /// The input was empty or contained an invalid character.
- [zig/comptime] `comptimePrint` returns a pointer to a comptime array sized by `count`,
  the pattern for building strings at compile time. `std/fmt.zig:639` ^f16
  > pub inline fn comptimePrint(comptime fmt: []const u8, args: anytype) *const [count(fmt, args):0]u8 {
- [zig/api] [toolchain] 0.17 args: `process.Args` holds the vector from main's Init;
  `iterate()` on POSIX, `iterateAllocator(gpa)` for portable code, `toSlice(arena)`
  requires an arena. `std/process/Args.zig:453` ^f17
  > /// Use `iterateAllocator` for cross-platform code.
  > /// Returned value may reference several allocations and may point into `a`.
  > /// Thefore, an arena-style allocator must be used.
- [zig/comptime] Platform-specific parts are chosen with a comptime `switch (native_os)`
  over types, and unsupported paths are a @compileError naming the alternative. `std/process/Args.zig:37` ^f18
  > if (native_os == .wasi) @compileError("In WASI, use initAllocator instead.");
- [zig/build] Build API takes options structs with a required `root_module`; the
  executable is built from a module, not a root source file. `std/Build.zig:559` ^f19
  > pub const ExecutableOptions = struct {
  > root_module: *Module,
- [zig/memory] Build.zig allocates from a process arena and panics on OOM (58 times in
  the file): for a short-lived tool, OOM is fatal by design. `std/Build.zig:181` ^f20
  > /// Allocates using the global process arena, failing the build on
  > return graph.arena.allocAdvancedWithRetAddr(T, null, n, @returnAddress()) catch @panic("OOM");
- [zig/build] [toolchain] 0.17 build: configure phase serialises to a `Configuration` for
  a separate make phase. `std/Build.zig:24` ^f21
  > /// The serialized output of configure phase ingested by make phase.

## Read

- `std/json/static.zig`: lines 1-200, jsonParse hook sites
- `std/json/Scanner.zig`: init, Diagnostics, Reader init
- `std/fmt.zig`: Alt/alt, ParseIntError, parseInt doc, print family, comptimePrint
- `std/process/Args.zig`: Iterator API, iterate, toSlice
- `std/Build.zig`: header, Graph alloc helpers, ExecutableOptions, option doc

## Not read

- `std/json/Stringify.zig`: writer-based serialiser options
- `std/zon`: ZON parse with diagnostics (`std.zon.parse.Diagnostics`), likely the newer
  diagnostics design
- `std/Build/Step/*.zig`, Module.zig
