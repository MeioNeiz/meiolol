---
title: 'Ghostty (ghostty-org/ghostty): Zig code idioms'
url: https://github.com/ghostty-org/ghostty
kind: project
commit: 08a9518340e19487bd5fdf96963583fb32f0c41f
for: [zig-good-practice, zig-memory, zig-comptime, zig-api-design, zig-errors-safety, zig-testing, zig-perf, zig-build, zig-style]
looked: 2026-10-22
depth: code (build.zig, src/build/, src/terminal/ page PageList size stream, src/datastruct/, src/apprt*, src/config/Config.zig, src/cli/args.zig, C API, tripwire, simd, fuzz harness)
relevance: high
grade: A/strong
description: Ghostty terminal emulator (Mitchell Hashimoto et al.), ~365k lines of Zig 0.17; page-based offset memory, comptime backends, reflection config parser, tripwire fault injection, C ABI libs
---
# Ghostty (ghostty-org/ghostty): Zig code idioms

Why: how does a large, respected, cross-platform Zig app on Zig 0.17 structure code, memory,
errors, comptime, tests and build?

## Assessment

- Evidence: A. Created 2022-03, pushed 2026-10-22, 62.5k stars, 3.7k forks, 422 contributors,
  MIT, tags to v1.3.1 plus `tip`; ~365k lines of Zig in src/, 4513 `test` blocks; ships on
  macOS, Linux, wasm (libghostty-vt). build.zig.zon `minimum_zig_version = "0.17.0"`, so
  everything here is current for meiolol's Zig.
- Reasoning: strong. Doc comments routinely give the why, the measured cost (15-20%, 4x,
  50%+) and the alternatives rejected (std MemoryPool, std.debug.assert, lazyDependency).
- Interests: none (MIT, non-profit-backed); the author wrote the Zig posts in
  [[mitchellh-tripwire]], [[mitchellh-ghostty-and-useful-zig-patterns]] and the other mitchellh-* notes, so those share its origin.
- Weigh: terminal hot paths justify perf tricks (inlineAssert, mmap pages, packed u64 cells)
  that a batch pipeline may not need; copy the reasoning, measure before copying the trick.
  Some comments are stale (size.zig says u16, code is u32). Agent use is allowed with
  disclosure (AGENTS.md), so recent code may be partly agent-written; the core terminal
  design predates that.

## Findings

### Style and layout

- [zig/style] Files are structs: a file starts with a `//!` module doc and `const Name = @This();`, then imports, then fields. `src/terminal/PageList.zig:1-4` ^f1
  > //! Maintains a linked list of pages to make up a terminal screen
  > const PageList = @This();
- [zig/style] Generic type functions name the returned struct `Self` (102 uses); file-structs use the real type name (114 files), e.g. `const Config = @This();`. `src/datastruct/untouched_pool.zig:35` ^f2
  > const Self = @This();
- [zig/style] A package's `main.zig` only re-exports public names and runs `refAllDecls` in a test, so every container is compiled and tested. `src/datastruct/main.zig:10-25` ^f3
  > pub const CircBuf = circ_buf.CircBuf;
  > @import("std").testing.refAllDecls(@This());
- [zig/style] To keep the import graph small, Config imports single files into a local namespace struct instead of the whole terminal package. `src/config/Config.zig:46-55` ^f4
  > We do this instead of importing all of terminal/main.zig to
  > limit the dependency graph.
- [zig/style] Doc comments state the why and the cost, not the what; e.g. a flag that can be a false positive exists because it makes erase operations faster. `src/terminal/page.zig:2032-2035` ^f5
  > Why have this weird false positive flag at all? This makes VT operations
  > At the time of writing this, the speed difference is around 4x.
- [zig/style] Config fields use `@"kebab-case"` identifiers so field names are the CLI and file keys, and doc comments on them feed the generated man pages. `src/config/Config.zig:1-9,177` ^f6
  > These fields map directly to the
  > @"font-family": RepeatableString = .{},
- [zig/style] Each file declares one scoped logger (189 files), named after the module. `src/terminal/PageList.zig:31` ^f7
  > const log = std.log.scoped(.page_list);
- [zig/style] Workarounds for other software are collected in one quirks.zig file, as a last resort. `src/quirks.zig:1-5` ^f8
  > centralizes all our
  > sad environment-specific hacks that we have to do to make things work.
- [zig/style] AGENTS.md: `zig fmt .`, and run filtered tests because the full suite is slow. `AGENTS.md` ^f9
  > Prefer to run targeted tests with `-Dtest-filter` because the full

### Memory

- [zig/memory] Long-lived structs are unmanaged: Terminal stores no allocator, `deinit` takes one, and deinit ends by poisoning `self`. `src/terminal/Terminal.zig:376-385` ^f10
  > pub fn deinit(self: *Terminal, alloc: Allocator) void {
  > self.* = undefined;
- [zig/memory] Config owns one arena for everything it parses; deinit frees it in one call; the parameter name says which allocator (`alloc_gpa` vs the arena). `src/config/Config.zig:4019,4041-4054` ^f11
  > _arena: ?ArenaAllocator = null,
  > if (self._arena) |arena| arena.deinit();
  > pub fn load(alloc_gpa: Allocator) !Config {
- [zig/memory] A terminal page is one contiguous page-aligned block holding rows, cells and all metadata, so it can be copied or serialised as a unit. `src/terminal/page.zig:142-156` ^f12
  > fully self-contained unit that can be
  > Pages are always backed by a single contiguous block of memory that is
- [zig/memory] Inside a page, references are typed offsets from the base, not pointers: `Offset(T)` is a packed struct over an int so it can carry methods. `src/terminal/size.zig:40-71` ^f13
  > This is a packed struct so we can attach methods to an int.
  > pub fn Offset(comptime T: type) type {
- [zig/memory] Page backing memory comes from mmap/VirtualAlloc directly, not a Zig Allocator, for speed and guaranteed zeroed pages. `src/terminal/page.zig:30-37,234-240` ^f14
  > You cannot use custom allocators with this structure because
  > it is critical to performance that we use mmap.
- [zig/memory] Zero is the empty state everywhere, so a freshly mapped page needs no initialisation of cells or metadata; a test pins `Cell` zero to empty. `src/terminal/page.zig:2135-2136,2777-2785` ^f15
  > The zero value of this struct must be a valid cell representing empty,
  > A page treats zero as the
- [zig/memory] Ghostty wrote UntouchedPool because std.heap.MemoryPool keeps its free list inside items, touching demand-paged memory. `src/datastruct/untouched_pool.zig:6-32` ^f16
  > std.heap.MemoryPool keeps its free list inside the items intrusively,
  > demand-paged, that write forces the OS to create a physical page
- [zig/memory] Node pool avoids std MemoryPool because its arena backing wastes memory on growth. `src/terminal/PageList.zig:309-317` ^f17
  > We don't use a std memory pool here because it is backed by an arena
- [zig/memory] A field with no default value forces every construction site to decide who owns the memory (pool vs heap). `src/terminal/PageList.zig:65-77` ^f18
  > This has no default on purpose so that every construction site
- [zig/memory] Global allocator: libc malloc in ReleaseSafe/ReleaseFast (faster), the std safe/debug allocator in Debug for leak detection, libc under Valgrind. `src/global.zig:89-111` ^f19
  > Use the libc allocator if it is available because it is WAY
  > can get easy memory leak detection in debug modes.
- [zig/memory] OS queries take a caller buffer and return a slice into it; temporary needs use a stack FixedBufferAllocator. `src/os/homedir.zig:13,49-50` ^f20
  > pub inline fn home(io: std.Io, environ_map: *const std.process.Environ.Map, buf: []u8) !?[]const u8 {
  > var fba = std.heap.FixedBufferAllocator.init(&tempBuf);
- [zig/memory] An optional allocator in Options makes the VT stream fully allocation-free when absent; features needing heap are dropped. `src/terminal/stream.zig:22-26` ^f21
  > Allocator to use. If this is not set then the stream
  > will be fully allocation free. There are some operations
- [zig/memory] Pools are preheated with counts justified by use (one viewport pin, one cursor pin). `src/terminal/PageList.zig:46-49` ^f22
  > The number of pins we preheat the pin pool with: the viewport pin that
- [zig/memory] HACKING.md: Zig catches its own leaks but not C libraries', so a `run-valgrind` build step exists. `HACKING.md` ^f23
  > Ghostty uses many third-party libraries that are written in C.
- [zig/memory] Global `alloc()` returns `std.testing.allocator` in tests, so code reaching global state still leak-checks. `src/global.zig:265-266` ^f24
  > if (builtin.is_test) return std.testing.allocator;

### Errors and safety

- [zig/safety] Ghostty replaces std.debug.assert with an inline assert in release builds: on Zig 0.15.2 the call was not always optimised away and cost 15-20% in hot loops; Debug keeps std's for stack traces. `src/quirks.zig:32-57` ^f25
  > always optimized away in `ReleaseFast` mode, at least in Zig 0.15.2.
  > cause significant overhead (as much as 15-20%) when they don't get
  > .debug => std.debug.assert,
- [zig/safety] Two tiers of checks: normal asserts, plus slow integrity checks only in Debug, because they made the terminal unusable. `src/build_config.zig:60-71` ^f26
  > True if we should have slow runtime safety checks. The initial motivation
  > be used for real work. We'd love to have an option to run a build with
- [zig/safety] Integrity checking is a fallible `verifyIntegrity` returning a named error set, and an `assertIntegrity` wrapper that logs and panics. `src/terminal/page.zig:336-382` ^f27
  > pub const IntegrityError = error{
  > @panic("page integrity violation");
- [zig/safety] Debug-only fields use `if (cond) T else void`, so they cost nothing in release builds. `src/terminal/page.zig:231-232` ^f28
  > pause_integrity_checks: if (build_options.slow_runtime_safety) usize else void =
- [zig/errors] `errdefer comptime unreachable;` after the last fallible step asserts at compile time that nothing below can fail (27 sites). `src/terminal/PageList.zig:677` ^f29
  > errdefer comptime unreachable;
- [zig/errors] Each acquisition in init is followed immediately by its errdefer. `src/terminal/PageList.zig:647-675` ^f30
  > errdefer pool.deinit();
  > errdefer releasePages(&pool, page_list);
- [zig/errors] When an error means internal corruption, code switches over every member of the error set, with no else, before panicking, so a new error is a compile error. `src/terminal/PageList.zig:181-196` ^f31
  > error.OutputSizeMismatch,
  > @panic("failed to clone compressed terminal page");
- [zig/errors] Public functions name narrow error sets (`Allocator.Error!T`) rather than inferring. `src/terminal/PageList.zig:635-638` ^f32
  > ) Allocator.Error!PageList {
- [zig/errors] Config parsing collects diagnostics (key, message, file:line) in a list and keeps going; only OOM is returned. `src/cli/args.zig:40-42,159-161` ^f33
  > When diagnostics are present, only allocation errors will be returned.
  > OOM is not recoverable since we need to allocate to
- [zig/errors] Diagnostic location is a tagged union (none, cli index, file+line), and a `format(writer)` method prints it. `src/cli/diagnostics.zig:19,49-55` ^f34
  > pub fn format(self: *const Diagnostic, writer: *std.Io.Writer) !void {
- [zig/errors] In generic code, the inferred error set is merged with known ones and narrowed with `@errorCast`, so a switch with `else` compiles for any T. `src/cli/args.zig:155-158` ^f35
  > const ErrSet = @TypeOf(err) || error{ Unknown, OutOfMemory } || Error;
- [zig/errors] At a void interface boundary the fallible implementation is wrapped: the error is logged as a warning and a flag is set. `src/terminal/stream_terminal.zig:609-618` ^f36
  > self.vtFallible(action, value) catch |err| {
  > log.warn("error handling VT action action={} err={}", .{ action, err });
- [zig/errors] At the C ABI, Zig errors become an `enum(c_int)` Result with negative codes; out params return objects. `src/terminal/c/result.zig`, `src/terminal/c/osc.zig:21-31` ^f37
  > out_of_memory = -1,
  > const ptr = alloc.create(osc.Parser) catch

### Comptime

- [zig/comptime] Backends are picked at comptime from build options, so each binary has exactly one apprt and no vtable. `src/apprt.zig:39-50` ^f38
  > so that every build has exactly one application runtime implementation.
  > pub const runtime = switch (build_config.artifact) {
- [zig/comptime] The renderer is a generic over a GraphicsAPI type (Metal or OpenGL); optional capabilities are probed with `@hasDecl`, falling back to void. `src/renderer.zig:37-42`, `src/renderer/generic.zig:96` ^f39
  > pub const Renderer = GenericRenderer(GraphicsAPI);
  > pub const ExportedFrame = if (@hasDecl(GraphicsAPI, "ExportedFrame")) GraphicsAPI.ExportedFrame else void;
- [zig/comptime] Duck-typed Context parameter with documented required and optional methods; the optional one is called only if `@hasDecl`. `src/datastruct/cache_table.zig:20-28,97` ^f40
  > [OPTIONAL] Eviction callback.
  > if (comptime @hasDecl(Context, "evicted")) self.context.evicted(
- [zig/comptime] Stream(H) calls `handler.vt(comptime action, value)` where the value type depends on the action, so handlers switch on a comptime tag and dispatch is static; tests define a tiny handler inline. `src/terminal/stream.zig:3952` ^f41
  > pub fn vt(self: *@This(), comptime action: Action.Tag, value: Action.Value(action)) void {
- [zig/comptime] The CLI/config parser walks struct fields at comptime and calls a type's `parseCLI` hook, picking the call shape by its parameter count. `src/cli/args.zig:311,339-346` ^f42
  > inline for (info.@"struct".field_names, info.@"struct".field_types, info.@"struct".field_attrs) |field, field_type, field_attrs| {
  > 1 arg = (input) => output
- [zig/comptime] Optional capabilities of the destination struct are detected by name: `_arena`, `_diagnostics`, `compatibility`, `help`, `parseManuallyHook`. `src/cli/args.zig:67,90,100` ^f43
  > const arena_available = @hasField(T, "_arena");
- [zig/comptime] `changed(comptime key)` finds the field at comptime; the change iterator turns a runtime index into comptime via `inline` switch prongs. `src/config/Config.zig:5301-5343` ^f44
  > requires the key to be comptime known to make this more efficient.
  > inline 0...(fields.len - 1) => |i| {
- [zig/comptime] Generic code ends with `@compileLog(T)` plus `@compileError` for unsupported types, so the error names the type. `src/config/Config.zig:5285-5288` ^f45
  > @compileLog(T);
  > @compileError("unsupported field type");
- [zig/comptime] [toolchain] Types are built with the 0.17 builtins `@Union`, `@Enum`, `@Int` (no `@Type`), with the field lists read through `field_names`/`field_types`. `src/apprt/action.zig:446-466`, `src/lib/enum.zig:43`, `src/terminal/page.zig:2419` ^f46
  > break :cvalue @Union(.@"extern", null, &names, &types, &attrs);
  > return @Enum(TagInt, .exhaustive, names_actual, &(values: {
  > const Ones = @Int(.unsigned, @bitSizeOf(Field));
- [zig/comptime] [toolchain] The tagged-union subset from [[mitchellh-zig-comptime-tagged-union-subset]] at 0.17: filter the union's SoA field lists, then build the union and its tag with `@Union` and `@Enum`. `src/input/Binding.zig:1468-1505` ^f96
  > inline for (field_names, field_types, field_attrs) |field_name, field_type, field_attr| {
  > @Enum(TagInt, .exhaustive, names[0..i], &values),
- [zig/comptime] Comptime-generated bit masks over packed structs turn multi-field questions into one AND and compare, which vectorises. `src/terminal/page.zig:2428-2440` ^f47
  > Masked compares are the key to making bulk row/cell processing fast.
- [zig/comptime] `comptime` blocks assert ABI sizes and alignment invariants. `src/apprt/action.zig:475-484`, `src/terminal/page.zig:158-166` ^f48
  > For ABI compatibility, we expect that this is our union size.
- [zig/comptime] A tripwire module compiles to nothing outside tests: its check functions use the inline calling convention when disabled. `src/tripwire.zig:86-90,219-223` ^f49
  > Outside of unit tests, this module is free and completely optimized away.
  > return if (!enabled) .@"inline" else .auto;
- [zig/comptime] An error set can be derived from a function type at comptime. `src/tripwire.zig:116-124` ^f50
  > .@"fn" => |info| @typeInfo(info.return_type.?).error_union.error_set,

### API design

- [zig/api] Constructors take `(io, alloc, opts)` with an Options struct whose fields carry documented defaults. `src/terminal/Terminal.zig:281-333` ^f51
  > max_scrollback_bytes: ?usize = 10_000,
  > io_impl: std.Io,
- [zig/api] Decl literals are used throughout for init and empty values. `src/terminal/Terminal.zig:337`, `src/terminal/stream.zig:593`, `src/datastruct/blocking_queue.zig:66` ^f52
  > var screen_set: ScreenSet = try .init(io_impl, alloc, .{
  > var parser: Parser = .init();
  > mutex: std.Io.Mutex = .init,
- [zig/api] Ownership transfer is written in the doc comment. `src/terminal/stream.zig:56-57` ^f53
  > This takes ownership of the handler and will call deinit
- [zig/api] A borrowed-or-owned result is a tagged union with its own deinit, so callers free uniformly. `src/terminal/PageList.zig:133-158` ^f54
  > borrowed: *const Page,
  > .borrowed => {},
- [zig/api] C API rules: opaque pointers for long-lived objects, sized structs, and a `_MAX_VALUE` sentinel in every C enum to force int size. `src/terminal/c/AGENTS.md`, `AGENTS.md` ^f55
  > Prefer opaque pointers for long-lived objects, such as
  > All C enums in `include/ghostty/vt/` must have a `_MAX_VALUE = GHOSTTY_ENUM_MAX_VALUE`
- [zig/api] A test checks every Zig enum value against the C header, so the hand-written header can't drift. `src/lib/enum.zig:105-111`, `src/apprt/action.zig:440-442` ^f56
  > Verify that for every key in enum T, there is a matching declaration in
  > try lib.checkGhosttyHEnum(Key, "GHOSTTY_ACTION_");
- [zig/api] Optional vs required interface: actions are optional to implement; required runtime functions are called directly so a missing one fails to compile. New tags go last for ABI. `src/apprt/action.zig:60-68` ^f57
  > Required functionality is called directly on the runtime structure so
  > compatibility, new actions should be added to the end of the enum.
- [zig/api] Generated enums keep removed keys as integer holes so values stay stable in ABI or serialised formats. `src/lib/enum.zig:8-10` ^f58
  > A null key removes that field while preserving its integer hole.
- [zig/api] Library feature gates are a packed struct of bools with defaults, set from one `-Dvt-features` option. `src/terminal/build_options.zig:45-68` ^f59
  > pub const Features = packed struct {
  > Optional features for lib artifacts. Disabling a feature removes
- [zig/api] Renamed config keys keep working through a comptime string map of compatibility handlers. `src/config/Config.zig:62-69` ^f60
  > .{ "background-blur-radius", cli.compatibilityRenamed(Config, "background-blur") },
- [zig/api] `std.Io` is passed explicitly as a parameter (0.16+ style), even to small helpers like home-dir lookup. `src/os/homedir.zig:13` ^f61
  > fn homeUnix(io: std.Io, environ_map: *const std.process.Environ.Map, buf: []u8) !?[]const u8 {

### Testing

- [zig/test] Tests sit in the same file as the code, after it (4513 `test` blocks in src/). `src/terminal/page.zig:2888` ^f62
  > test "Page init" {
- [zig/test] The root test block imports every package so one test binary runs everything. `src/main_ghostty.zig:234-266` ^f63
  > _ = @import("datastruct/main.zig");
  > _ = @import("terminal/main.zig");
- [zig/test] [toolchain] Since Zig 0.16 any test output to stderr marks the run failed, so Ghostty sets test log level to err. `src/main.zig:30-35` ^f64
  > Zig 0.16.0 has made test logging more strict. Now, *anything* that gets
  > std.testing.log_level = std.log.Level.err;
- [zig/test] Ghostty's tripwire library injects failures at named points to exercise errdefer paths, which it calls a top source of Zig bugs. `src/tripwire.zig:1-12` ^f65
  > Improper `errdefer` is one of the highest sources of bugs in Zig code.
  > to test every possible error path.
- [zig/test] A test loops over every fail point of `init` and expects the error, with testing.allocator checking for leaks. `src/terminal/PageList.zig:9673-9687` ^f66
  > for (std.meta.tags(init_tw.FailPoint)) |tag| {
  > leak memory (testing.allocator verifies) since we're exiting early.
- [zig/test] Table-driven tests use an array of anonymous structs. `src/terminal/stream.zig:3961-3974` ^f67
  > const cases = [_]struct {
- [zig/test] On wasm, test builds swap the global page pool for the native one so its memory goes through the leak-checking allocator. `src/terminal/PageList.zig:327-333` ^f68
  > Test builds use the native pool even on wasm so that pool memory goes
- [zig/test] Fuzzing is AFL++ on exported C entry points, with a fixed-buffer bump allocator reset per input; the first input byte picks the SIMD or the scalar path. `test/fuzz-libghostty/src/fuzz_stream.zig:8-65` ^f69
  > every fuzz input resets the bump pointer to the start.
  > Use the first byte to decide between the scalar and slice paths
- [zig/test] Checked, not there: no `std.testing.fuzz` use in src/ (grep at this commit); fuzzing lives outside the build's test step.
  (inferred) ^f70
- [zig/test] Regression tests explain the invariant and link the issue. `src/terminal/page.zig:2762-2766` ^f71
  > Our intention is for a maxed-out capacity to always fit
- [zig/test] Some things aren't automated: the input/IME stack has a manual test matrix in HACKING.md. `HACKING.md` ^f72
  > If you modify any part of the input stack, you must manually verify

### Performance

- [zig/perf] Row and Cell are `packed struct(u64)` so one integer load reads every field; Backing is derived from type info, not hardcoded. `src/terminal/page.zig:2008,2092-2095,2137` ^f73
  > pub const Cell = packed struct(u64) {
  > pub const Backing = @typeInfo(Row).@"struct".backing_integer.?;
- [zig/perf] Cell arrays start on a cache line so rows don't straddle an extra line. `src/terminal/page.zig:129-140` ^f74
  > line so that row cells always start on a cache line. This avoids
- [zig/perf] A `lanes(T)` helper returns twice the suggested vector length, or null when the target has no SIMD, in which case a scalar loop runs. `src/simd/main.zig:12-22` ^f75
  > This is twice the native vector width so that each iteration works
  > const native = std.simd.suggestVectorLength(T) orelse return null;
- [zig/perf] [toolchain] The everyday SIMD idiom at 0.17, in the VT print scan: `@splat` constants, whole-vector loads, `@reduce(.Or, ...)`, `@bitCast` to an `@Int` mask, `@ctz`, then the scalar loop as tail. The comment says the loop didn't auto-vectorise. `src/terminal/stream.zig:869-894` ^f97
  > const bits: @Int(.unsigned, lanes) = @bitCast(stop);
  > while (end < cps.len and (cps[end] & ~@as(u32, 0x9F)) != 0) end += 1;
- [zig/perf] Heaviest SIMD kernels are C++ (Highway) behind `extern "c"`, with a Zig scalar fallback chosen at comptime. `src/simd/index_of.zig:4-17` ^f76
  > extern "c" fn ghostty_simd_index_of(
  > if (comptime options.simd) {
- [zig/perf] Micro-choices cite measurement: zeroing a page as u64 rather than u8. `src/terminal/page.zig:330-332` ^f77
  > we can and it's empirically quite a bit faster.
- [zig/perf] wasm builds default to simd128, a 50%+ win on VT streams. `src/build/Config.zig:118-124` ^f78
  > performance win for the terminal hot paths (50%+ on
- [zig/perf] log_level is info outside Debug so expensive debug-log arguments compile away. `src/main_ghostty.zig:201-211` ^f79
  > our debug logs are very expensive to
- [zig/perf] Plain implementations first, admitted in docs: the SPSC queue is deliberately naive until benchmarks say otherwise. `src/datastruct/blocking_queue.zig:24-28` ^f80
  > is purposely naive to build something quickly, but we should benchmark
- [zig/perf] Integer widths follow domain limits (u16 cells per dimension), declared once in size.zig and derived elsewhere; one comment there is stale (says u16, value is maxInt(u32)). `src/terminal/size.zig:4-22` ^f81
  > Based on 2^16 being enough for any reasonable terminal size and allowing
  > pub const max_page_size = std.math.maxInt(u32);
  > The maximum size of a page in bytes. We use a u16 here because any

### Build

- [zig/build] build.zig delegates to a `src/build/` package: one file per artifact (GhosttyExe, GhosttyLib, GhosttyLibVt...) plus custom steps. `src/build/main.zig:1-3` ^f82
  > Build logic for Ghostty. A single build.zig file became far too complex
- [zig/build] One `Config` struct gathers every `-D` option and target tweak; artifacts take `*const Config` and `*const SharedDeps`. `build.zig:21-23`, `src/build/GhosttyExe.zig:13` ^f83
  > This defines all the available build options (e.g. `-D`). If you
  > pub fn init(b: *std.Build, cfg: *const Config, deps: *const SharedDeps) !Ghostty {
- [zig/build] Config writes itself into a `build_options` module; app code rebuilds it via `fromOptions()` and maps generated enums back with `stringToEnum(@tagName)`. `src/build/Config.zig:684-802` ^f84
  > Rehydrate our Config from the comptime options. Note that not all
  > .app_runtime = std.meta.stringToEnum(ApprtRuntime, @tagName(options.app_runtime)).?,
- [zig/build] A comptime check fails the build unless the Zig major.minor matches exactly, reading the minimum from build.zig.zon. `src/build/zig.zig:4-17`, `build.zig:13-18` ^f85
  > Your Zig version v{f} does not meet the required build version of v{f}
  > .minimum_zig_version = "0.17.0",
- [zig/build] All `b.step` calls sit at the top of build() so the list of steps documents itself. `build.zig:61-63` ^f86
  > All our steps which we'll hook up later. The steps are shown
- [zig/build] Platform libraries are lazy dependencies, fetched only when the target needs them. `src/build/SharedDeps.zig:234` ^f87
  > if (b.lazyDependency("freetype", .{
- [zig/build] [toolchain] The 0.16 module model requires every file to be in exactly one module per compile, so a module shared with a dependency is created once eagerly. `src/build/SharedDeps.zig:24-59` ^f88
  > Sharing one instance is also a hard requirement (not just an
  > to exactly one module within a Compile graph.
- [zig/build] The test binary uses a baseline CPU, Debug, frame pointers and LLVM; `-Dtest-filter` is a repeatable list option. `build.zig:44-48,379-392` ^f89
  > Filter for test. Only applies to Zig tests.
  > .target = config.baselineTarget(b.graph.io),
- [zig/build] Being a dependency is detected (`dep_prefix`) and switches the defaults to the lib-only build. `src/build/Config.zig:86-93` ^f90
  > Default dependency builds to libghostty-vt-only mode. Consumers can
- [zig/build] C exports happen only when this file is the root, so Zig-module consumers don't get the symbols. `src/lib_vt.zig:174-177` ^f91
  > if (@import("root") == lib) {
- [zig/build] [toolchain] Zig 0.17 removed setting env vars on run steps the old way; the call is commented out with a FIXME. `build.zig:287` ^f92
  > FIXME: This is not possible after Zig 0.17.
- [toolchain] 0.17 names in use: `std.lang.Optimize`, modes `.debug .safe .small .fast`, `std.heap.SafeAllocator`, `@backingInt`, `std.lang.CallingConvention`. `src/build/Config.zig:20`, `src/global.zig:378` ^f93
  > optimize: std.lang.Optimize,
  > const GPA = std.heap.SafeAllocator;
- [zig/build] The Valgrind run step rebuilds the exe for a baseline CPU, since Valgrind can't handle newer instructions. `build.zig:331-336` ^f94
  > We need to rebuild Ghostty with a baseline CPU target.
- [zig/build] An `.Exe`/`.Lib`/wasm artifact kind is detected at comptime from builtin, and an unsupported mode fails with @compileLog plus @compileError. `src/build_config.zig:73-98` ^f95
  > return switch (builtin.output_mode) {
  > @compileError("unsupported artifact output mode");

## Read

- `build.zig`, `src/build/main.zig`, `zig.zig`, `Config.zig` (1-200, 680-816), `GhosttyExe.zig`, `SharedDeps.zig` (1-80)
- `src/terminal/size.zig` (1-150), `page.zig` (1-420, 1722-1800, 2000-2200, 2380-2480, tests list), `PageList.zig` (1-440, 580-720, 7195-7240, init error test), `Terminal.zig` (1-60, 275-400), `stream.zig` (Stream head, a test), `stream_terminal.zig` (vt)
- `src/datastruct/` main, untouched_pool, intrusive_linked_list, circ_buf, blocking_queue, cache_table heads
- `src/apprt.zig`, `apprt/runtime.zig`, `apprt/action.zig` (Action, CValue), `src/renderer.zig`, `renderer/generic.zig` head
- `src/config/Config.zig` (head, arena/load, clone/changed), `src/cli/args.zig` (parse, parseIntoField), `cli/diagnostics.zig`
- `src/main_c.zig`, `src/lib_vt.zig` exports, `src/terminal/c/` AGENTS.md, result, osc; `src/lib/enum.zig`, `lib/union.zig` head
- `src/tripwire.zig`, `src/quirks.zig`, `src/build_config.zig`, `src/global.zig` alloc, `src/main.zig`, `main_ghostty.zig` logging and tests, `src/simd/main.zig`, `index_of.zig`, `src/os/homedir.zig`
- `test/fuzz-libghostty/` README, AGENTS.md, fuzz_stream.zig; AGENTS.md, HACKING.md

## Not read

- `src/terminal/Screen.zig`, `Selection.zig`, `ref_counted_set.zig`, `hash_map.zig`, `bitmap_allocator.zig`: offset-based containers inside a page
- `src/font/`, `src/renderer/Metal.zig`/`OpenGL.zig`: the GraphicsAPI interface's full required decl list
- `src/termio/`, `src/Surface.zig`: threads, mailboxes, libxev event loop
- `src/benchmark/`, `src/synthetic/`: benchmark harness and synthetic VT data
- `src/lib/TinyIo.zig`, `lib/compat/`: an Io shim
