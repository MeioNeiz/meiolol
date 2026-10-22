---
title: 'ZLS (zigtools/zls): build.zig, main, Server, DocumentStore, InternPool, tests'
url: https://github.com/zigtools/zls
kind: project
commit: 82ba5351ca8acc07f59b552cb7ba8b5fb4315722
for: [zig-good-practice, zig-style, zig-memory, zig-errors-safety, zig-api-design, zig-testing, zig-build]
looked: 2026-10-22
depth: code (build.zig, main.zig, Server.zig create/destroy, DocumentStore deinit, DocumentScope, testing.zig, tracy.zig, InternPool head, tests/)
relevance: high
grade: A/fair
description: the Zig language server, written in Zig, tracks Zig master and already on 0.17.0; a 37k-line codebase maintained alongside the compiler
---
# ZLS (zigtools/zls): build.zig, main, Server, DocumentStore, InternPool, tests

Why: what recurring Zig idioms does a large, long-lived Zig codebase that tracks Zig master
use for allocators, init/deinit, errors, logging, tests and build.zig, on Zig 0.17?

## Assessment

- Evidence: A. Created 2020-04, pushed 2026-10-22, 5286 stars, 465 forks, 198
  contributors, release 0.17.0 (2026-10-19). Default branch targets Zig master; maintainers
  overlap with Zig core (InternPool and tracy.zig copied from the compiler). 37.6k lines in
  src/; CI with coverage (codecov).
- Reasoning: fair. Code comments explain the non-obvious (issue links, "set below"); no
  style or contributing doc in the repo.
- Interests: none known.
- Weigh: the most 0.17-current non-std codebase read; trust its std.Io and build API usage
  as current. Its analyser/ dir is admitted future work.

## Findings

- [toolchain] [zig/build] Targets Zig 0.17.0 as both build and runtime minimum; the
  default branch follows Zig master and the ZLS version must match Zig. `build.zig.zon`,
  `README.md` ^f1
  > .minimum_zig_version = "0.17.0",
  > The default branch of ZLS targets [Zig master](https://ziglang.org/download/).
- [zig/build] Dependencies pinned by archive URL of a commit plus content hash; heavy
  optional ones (tracy) are `.lazy = true` and fetched only when enabled via
  `b.lazyDependency`. `build.zig.zon`, `build.zig` ^f2
  > const tracy_dependency = b.lazyDependency("tracy", .{
- [zig/build] build.zig factors module construction into helper functions taking an
  anonymous options struct, so the release loop over 12 targets and the normal build share
  one definition. `build.zig` ^f3
  > fn createZLSModule(
  > options: struct {
- [zig/build] Generated code (version data from the langref, Config.zig and schema.json)
  is produced by a host-built tool run from build.zig; `zig build gen` copies outputs back
  into the source tree with `addUpdateSourceFiles`. `build.zig` ^f4
  > const update_source = b.addUpdateSourceFiles();
  > update_source.addCopyFileToSource(gen_cmd.addOutputFileArg("Config.zig"), "src/Config.zig");
- [zig/build] Root-only steps (gen, release, test) are guarded by `b.isRoot()` so ZLS as
  a dependency exposes only the module; the module is registered with `b.modules.put`. `build.zig` ^f5
  > if (!b.isRoot()) return;
  > b.modules.put(b.allocator, "zls", zls_module) catch @panic("OOM");
- [zig/build] A `check` step compiles without installing, for fast editor feedback;
  `-Dtest-filter` is a repeatable option passed to every test artifact. `build.zig` ^f6
  > const check = b.step("check", "Check if ZLS compiles");
  > const test_filters = b.option([]const []const u8, "test-filter", "Skip tests that do not match filter") orelse &.{};
- [zig/memory] [zig/build] Build-script OOM is not handled: `catch @panic("OOM")` in
  build.zig only (4 uses in all of src/ and build.zig). `build.zig` ^f7
  > run_test_steps.append(b.allocator, run_tests) catch @panic("OOM");
- [zig/memory] Allocator chosen once in main: DebugAllocator in Debug (and single-threaded
  release), c_allocator when linking libc, wasm_allocator on wasi, else smp_allocator;
  optional tracy and randomly failing wrappers stack on top. `src/main.zig` ^f8
  > var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
  > std.heap.smp_allocator;
  > var failing_allocator_state = if (exe_options.enable_failing_allocator) zls.testing.FailingAllocator.init(inner_allocator, exe_options.enable_failing_allocator_likelihood) else {};
- [zig/test] [zig/memory] A build option turns on a FailingAllocator that fails 1 in N
  allocations at random in the real binary, to exercise OOM paths beyond unit tests. `src/testing.zig` ^f9
  > /// the chance that an allocation will fail is `1/likelihood`
- [zig/api] [toolchain] 0.17 main takes `std.process.Init.Minimal` (environ and args) and
  builds its own `std.Io.Threaded`; the test checker uses `std.process.Init` which hands
  over `io` and `gpa`. `src/main.zig`, `tests/analysis_check.zig` ^f10
  > pub fn main(init: std.process.Init.Minimal) !u8 {
  > var threaded: std.Io.Threaded = .init(allocator, .{
  > const gpa = init.gpa;
- [zig/api] `io` and `allocator` are passed explicitly as leading parameters through the
  whole call tree, `io` first. `src/main.zig` ^f11
  > ) error{ Canceled, OutOfMemory }!?[]const u8 {
  > environ_map: *const std.process.Environ.Map,
- [zig/api] Long-lived heap objects use `create(options) !*T` / `destroy()`, with an
  options struct whose fields carry doc comments on their contracts (thread safety);
  value types use `init`/`deinit`. `src/Server.zig` ^f12
  > pub fn create(options: CreateOptions) std.mem.Allocator.Error!*Server {
  > /// Must be thread-safe unless the ZLS module is in single_threaded mode or the Io implementation has no parallelism.
- [zig/memory] create pairs every acquisition with errdefer; fields not ready at struct
  init are `undefined` with a `// set below` comment. `src/Server.zig` ^f13
  > const server = try allocator.create(Server);
  > errdefer allocator.destroy(server);
  > .ip = undefined, // set below
- [zig/memory] [zig/safety] deinit ends with `self.* = undefined;` so use-after-deinit
  shows as 0xaa garbage in safe builds. `src/DocumentStore.zig` ^f14
  > self.* = undefined;
- [zig/memory] Init functions build the value, `errdefer value.deinit(allocator)` right
  after, then return it: deinit doubles as the error-path cleanup, so it must cope with a
  partly filled value. `src/DocumentScope.zig`, `src/main.zig` ^f15
  > errdefer document_scope.deinit(allocator);
  > errdefer result.deinit(allocator);
- [zig/memory] Unmanaged containers default to `.empty` as field defaults and take the
  allocator on each call (0.15+ style). `src/Server.zig` ^f16
  > pending_show_messages: std.ArrayList(types.window.ShowMessageParams) = .empty,
- [zig/memory] Request handlers get a per-request arena (92 `arena:` parameters in src/)
  alongside the long-lived gpa. `src/Server.zig` ^f17
  > pub fn initAnalyser(server: *Server, arena: std.mem.Allocator, handle: ?*DocumentStore.Handle) Analyser {
- [zig/errors] Error sets are explicit and narrow in signatures (185 `error{OutOfMemory}`
  in src/) and composed with `||`; inferred `!T` mostly at the top (main). `src/main.zig`,
  `src/Server.zig` ^f18
  > const ParseArgsError = std.mem.Allocator.Error || std.Io.File.Writer.Error;
  > pub const LoopError = std.mem.Allocator.Error ||
- [zig/errors] `catch unreachable` is kept for errors ruled out by an earlier check, often
  with a comment saying why (18 uses). `src/Uri.zig` ^f19
  > const parsed_uri = std.Uri.parse(uri.raw) catch unreachable; // The Uri is guranteed to be valid
- [zig/errors] [zig/api] Fatal errors in build logic use `std.process.fatal` with a
  message, not a bare panic; `{t}` prints an error or enum tag name. `build.zig` ^f20
  > else => |e| std.process.fatal("Failed to read '.git' directory: {t}", .{e}),
- [zig/style] Logging: one `const log = std.log.scoped(.name);` per file; main sets
  `std_options.log_level = .debug` and filters at run time in a custom `logFn`, because the
  comptime level would remove messages before the handler sees them. `src/main.zig` ^f21
  > // Always set this to debug to make std.log call into our handler, then control the runtime
  > const log = std.log.scoped(.main);
- [zig/style] The log handler formats into a fixed 4096-byte stack buffer with a
  `std.Io.Writer.fixed`, truncating with "..." rather than allocating. `src/main.zig` ^f22
  > var writer: std.Io.Writer = .fixed(&buffer);
- [zig/safety] Assertions: `const assert = std.debug.assert;` alias per file; ~234 assert
  calls in 37k lines, plus doc comments stating preconditions ("Asserts that ..."). `src/DocumentScope.zig`,
  `src/analyser/InternPool.zig` ^f23
  > /// Asserts that `node_idx != .root`
  > const assert = std.debug.assert;
- [zig/safety] [zig/comptime] comptime asserts check buffer-size relations at compile time. `src/main.zig` ^f24
  > comptime std.debug.assert(buffer.len >= zls.lsp.minimum_logging_buffer_size);
- [zig/style] File-as-struct: TitleCase files (Server.zig, DocumentStore.zig, InternPool.zig)
  are structs with top-level fields and `const Server = @This();`; snake_case files
  (offsets.zig, ast.zig) are namespaces. Fields come first, then imports. `src/Server.zig`,
  `src/analyser/InternPool.zig` ^f25
  > const Server = @This();
  > // public fields
- [zig/style] A root file re-exports modules and forces analysis of every decl in tests
  with `std.testing.refAllDecls(@This())` in a comptime block. `src/zls.zig` ^f26
  > std.testing.refAllDecls(@This());
- [zig/perf] [zig/api] Typed indices: `enum(u32) { _ }` for handles into arrays, with a
  separate OptionalIndex using maxInt as `none` instead of `?u32` (no extra tag byte).
  0.17 converts with `@fromBackingInt`/`@backingInt`. `src/DocumentScope.zig` ^f27
  > pub const OptionalIndex = enum(u32) {
  > none = std.math.maxInt(u32),
  > return @fromBackingInt(@backingInt(index));
- [zig/perf] InternPool (copied from the compiler) stores items in a MultiArrayList plus a
  `u32` extra array and flags as `packed struct(u32)`. `src/analyser/InternPool.zig` ^f28
  > items: std.MultiArrayList(Item),
  > pub const Flags = packed struct(u32) {
- [zig/perf] Profiling: tracy zones via `tracy.trace(@src())` + `defer zone.end()` in ~96
  functions; when disabled `trace` is an inline fn returning an empty struct, so it costs
  nothing. `src/tracy.zig`, `src/Server.zig` ^f29
  > pub inline fn trace(comptime src: std.lang.SourceLocation) Ctx {
  > if (!enable) return .{};
- [zig/test] Tests live in a separate tests/ tree (tests.zig imports each file in a
  comptime block) plus inline tests in src/ run as a second test artifact. `tests/tests.zig`,
  `build.zig` ^f30
  > _ = @import("lsp_features/hover.zig");
  > .name = "src test",
- [zig/test] Feature tests are table-like: source text with a `<cursor>` marker and the
  expected output as multiline string literals, through a shared helper. `tests/lsp_features/hover.zig` ^f31
  > \\const foo = bool<cursor>;
  > const cursor_idx = std.mem.find(u8, source, "<cursor>").?;
- [zig/test] Analysis tests are annotated Zig files: a comment with carets under a
  symbol states its expected type and value; build.zig adds one run step per file. `tests/analysis/array.zig`,
  `build.zig` ^f32
  > //    ^^^^^^^^^ (type)([3]u8)
  > const run_check = std.Build.Step.Run.create(b, b.fmt("run analysis on {s}", .{entry.name}));
- [zig/test] Own expectEqual serialises both sides to JSON and prints a line diff, for
  readable failures on big structs. `src/testing.zig` ^f33
  > const expected_stringified = std.json.Stringify.valueAlloc(allocator, expected, options) catch @panic("OOM");
- [zig/test] Tests use `std.testing.allocator` as a file-level const, so leaks fail tests. `tests/lsp_features/hover.zig` ^f34
  > const allocator: std.mem.Allocator = std.testing.allocator;
- [zig/test] Debug-only helpers refuse to compile in release with `@compileError`. `src/testing.zig` ^f35
  > if (builtin.mode != .Debug) @compileError("this function should only be used in debug mode!");
- [toolchain] 0.17 renames visible here: `std.lang.Type`, `std.lang.SourceLocation`,
  `std.lang.Optimize`, `@EnumLiteral()`, `std.mem.find` (was indexOf),
  `std.array_hash_map.Auto`. `src/analyser/InternPool.zig`, `src/main.zig` ^f36
  > int_type: std.lang.Type.Int,
  > comptime scope: @EnumLiteral(),
  > map: std.array_hash_map.Auto(void, void),
- [zig/api] Vtable interface done by hand the std way: a struct with `ptr: *anyopaque` and
  `vtable: &.{...}`, implementations cast back with `@ptrCast(@alignCast(ctx))`. `src/testing.zig` ^f37
  > const self: *FailingAllocator = @ptrCast(@alignCast(ctx));
- [zig/comptime] Idiom counts in src/ (37.6k lines): 62 `anytype`, 12 `inline for`, 10
  `@compileError`, 0 `usingnamespace`: comptime used sparingly. ^f38
- [zig/style] Checked, not there: no CONTRIBUTING or style document in the repo; style is
  `zig fmt` plus convention. ^f39

## Read

- `build.zig`: lines 1-700; `build.zig.zon`, `README.md`: all
- `src/main.zig`: logFn, parseArgs, main; `src/Server.zig`: head, create/destroy
- `src/DocumentStore.zig`: deinit, getHandle; `src/DocumentScope.zig`: Index types, init/deinit
- `src/testing.zig`, `src/tracy.zig` head, `src/zls.zig`, `src/analyser/InternPool.zig` head
- `tests/tests.zig`, `tests/lsp_features/hover.zig` head and helper, `tests/analysis/array.zig` head
- grep counts over src/

## Not read

- `src/analysis.zig` (7k lines): the type resolver itself
- `src/bsp.zig`: build-on-save and the build runner protocol
- `src/features/`: per-LSP-feature modules
