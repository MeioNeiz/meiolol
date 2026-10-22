---
title: TigerBeetle source code (stdx, io, vsr, lsm, testing, build.zig) at Zig 0.16.0
url: https://github.com/tigerbeetle/tigerbeetle
kind: project
commit: 0450c32b2c3c3ab6114f3402cc601341cc8192aa
for: [zig-good-practice, zig-style, zig-errors-safety, zig-memory, zig-api-design, zig-comptime, zig-testing, zig-perf, zig-build]
looked: 2026-10-22
depth: code (stdx/stdx.zig, stdx/bounded_array.zig, stdx/time.zig, stdx/testing/snaptest.zig, io.zig, io/linux.zig, static_allocator.zig, vsr/replica.zig open, vsr/grid.zig write/read, lsm/compaction.zig copy loops, constants.zig, config.zig, testing/marks.zig, testing/exhaustigen.zig, testing/fuzz.zig, fuzz_tests.zig, vopr.zig main, build.zig; assert and length counts ran over 15 files)
relevance: high
grade: A/strong
description: how TigerBeetle's ~159k lines of Zig actually follow Tiger Style: assertions, static allocator, bounded containers, IO completions, snapshot tests, fuzzers, build steps
---
# TigerBeetle source code (stdx, io, vsr, lsm, testing, build.zig) at Zig 0.16.0

Why: check that Tiger Style is practised, collect real excerpts, and see what a large
Zig codebase looks like on 0.16 (closest to our 0.17).

## Assessment

- Evidence: A. Repo created 2020-04-09, 17.2k stars, 923 forks, 127 named
  contributors (143 with anonymous), Apache-2.0, latest release 0.17.9 (2026-07-06),
  pushed 2026-10-16. 247 .zig files, ~159k lines under src/. Production database with
  a deterministic simulator, fuzzers, Jepsen analysis. A tidy test bans AI-agent
  commits ([[tigerbeetle-tidy#^f13]]), so no agent-volume caveat.
- Zig version: pinned to exactly 0.16.0 (build.zig refuses any other); stayed on
  0.14.1 until 2026-09-28, then upgraded straight to 0.16.0 skipping 0.15 (one commit,
  179 files, +5737/-3250). So it lags: one minor behind our 0.17.
- Reasoning: strong. Comments explain why throughout (see excerpts).
- Interests: none beyond the company's reputation.
- Weigh: trust as the reference for assertion style, bounded data structures, explicit
  options and testing infrastructure. The numeric rules are aspirations in places:
  measured below.

## Findings

- [toolchain] [zig/build] build.zig pins an exact Zig version at comptime and fails
  with a clear message on any other. `build.zig` ^f1
  > const zig_version = std.SemanticVersion{
  > "unsupported zig version: expected {f}, found {f}",
- [toolchain] [zig/build] Pinned 0.16.0 is downloaded per repo by `zig/download.sh`
  with SHA-256 checksums per platform. `zig/download.sh` ^f2
  > ZIG_RELEASE="0.16.0"
- [toolchain] [zig/build] On 0.16.0 they force the LLVM backend for every compile
  step because the self-hosted x86_64 backend miscompiles; `-Dllvm=false` opts out for
  quicker Debug builds. `build.zig` ^f3
  > // TODO(Zig): As of 0.16.0 the x86_64 backend has known miscompilations, so LLVM is the default.
  > if (compile.use_llvm == null) compile.use_llvm = true;
- [zig/build] [zig/safety] Default optimise mode is ReleaseSafe, not ReleaseFast:
  safety checks stay on in shipped builds. `build.zig` ^f4
  > const mode = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSafe });
- [zig/build] All top-level steps are declared in one struct literal with
  descriptions, and all `-D` options in another, before any wiring; build helpers take
  an anonymous `options: struct {...}`. `build.zig` ^f5
  > // Top-level steps you can invoke on the command line.
  > // Build options passed with `-D` flags.
- [zig/build] `build.zig` imports nothing from src/ to keep build-script compile time
  low. `build.zig` ^f6
  > // NB: Don't import anything from `./src` to keep compile times low.
- [zig/build] `zig build ci` is a build step with modes (smoke, test, aof, default,
  all); each sub-run is a child `zig build` with a `max_rss` budget, stderr hidden
  unless it fails; the default runs fmt check, `check`, tests, `fuzz -- smoke` and the
  VOPR for both state machines. `build.zig` ^f7
  > smoke, // Quickly check formatting and such.
  > build_ci_step(b, step_ci, .{ "fuzz", "--", "smoke" }, .{ .max_rss = 3 * GiB });
  > // Hide step's stderr unless it fails, to prevent zig build ci output being dominated by VOPR logs.
- [zig/build] [zig/test] Test filters come straight from `zig build test -- <args>`
  via `.filters = b.args`. `build.zig` ^f8
  > .filters = b.args orelse &.{},
- [zig/safety] `config_verify` (extra, expensive assertions) defaults on in Debug and
  off in release builds; fuzzers and VOPR assert at comptime it is on. `build.zig` ^f9
  > .config_verify = b.option(bool, "config_verify", "Enable extra assertions.") orelse
  > comptime assert(constants.verify);
- [zig/memory] Static allocation is enforced mechanically: the replica allocates
  through a `StaticAllocator` that asserts on any alloc, resize or remap once switched
  to `.static` after `open`. `static_allocator.zig`, `vsr/replica.zig` ^f10
  > //! disable it to prevent accidental dynamic allocation at runtime.
  > assert(self.state == .init);
  > // Disable all dynamic allocation from this point onwards.
  > self.static_allocator.transition_from_init_to_static();
- [zig/memory] Free is allowed after init (moving to `.deinit`) so `errdefer` cleanup
  stays simple; once freeing starts, no more allocation. `static_allocator.zig` ^f11
  > /// (To make errdefer cleanup easier to write we also allow calling `free`,
  > // Once you start freeing, you don't stop.
- [zig/safety] [zig/api] `Replica.open` starts with a block of argument assertions,
  including implications (`if (p) assert(...)`), and passes a long options struct
  field by field. `vsr/replica.zig` ^f12
  > assert(options.storage_size_limit % constants.sector_size == 0);
  > if (options.commit_stall_probability) |p| assert(p.numerator <= p.denominator);
- [zig/memory] [zig/errors] Init with errdefer guarded by an `initialized` flag, so the
  owner deinitialises components only on the error path before handover. `vsr/replica.zig` ^f13
  > var initialized = false;
  > errdefer if (!initialized) self.superblock.deinit(allocator);
- [zig/comptime] [zig/safety] Constants are checked against each other in `comptime`
  blocks with long comments giving the invariant. `constants.zig` ^f14
  > // Invariant: to guarantee durability, a log entry from a previous checkpoint can be overwritten
  > assert(vsr_checkpoint_ops >= pipeline_prepare_queue_max);
  > assert(vsr_checkpoint_ops % lsm_compaction_ops == 0);
- [zig/test] [zig/comptime] Config presets are comptime structs; tests and fuzzers
  default to `test_min` (tiny WAL, block size, queues) to reach edge cases cheaply; a
  root file can override via `pub const tigerbeetle_config`. `config.zig`, `fuzz_tests.zig` ^f15
  > /// Not suitable for production, but good for testing code that would be otherwise hard to
  > pub const tigerbeetle_config = @import("config.zig").configs.test_min;
- [zig/safety] Pair assertions, write then read: before writing a block the grid zeroes
  sector padding and asserts it is zeroed; after reading it checks checksum, command,
  checksum of body, expected checksum and zeroed padding, returning a fault enum for
  disk corruption (operating error) while asserting what only a bug could break. `vsr/grid.zig` ^f16
  > // Zero sector padding.
  > assert(stdx.zeroed(
  > if (!header.valid_checksum()) return .invalid_checksum;
  > if (!stdx.zeroed(block[header.size..vsr.sector_ceil(header.size)])) {
- [zig/api] Two arguments of different integer meaning (address u64, checksum u128) go
  through an anonymous options struct `expect: struct { address, checksum }`. `vsr/grid.zig` ^f17
  > fn read_block_validate(block: BlockPtrConst, expect: struct {
- [zig/perf] Hot loops are standalone functions with slices in and counts out, no
  `self`, with a comment saying why; results are structs checked by postcondition
  asserts. `lsm/compaction.zig` ^f18
  > // The three functions below are hot CPU loops doing the actual merging, TigerBeetle's data
  > // plane. To reduce the probability of the optimizer getting confused over pointers, don't
  > fn values_copy(values_target: []Value, values_source: []const Value) u32 {
  > assert(copy_result.produced == copy_result.consumed - copy_result.dropped);
- [zig/memory] [zig/safety] `stdx.copy_disjoint` replaces `@memcpy`: asserts lengths
  (`.exact` or `.inexact` spelled at the call site) and that the slices don't overlap;
  `copy_left`/`copy_right` replace `copyForwards`/`copyBackwards` with direction
  asserts. `stdx/stdx.zig` ^f19
  > pub const SizePrecision = enum { exact, inexact };
  > assert(disjoint_slices(T, T, target, source));
  > assert(@intFromPtr(target.ptr) < @intFromPtr(source.ptr));
- [zig/safety] `maybe(cond)` is the dual of assert: documents that a condition can go
  either way. 303 uses in src/. `stdx/stdx.zig` ^f20
  > /// `maybe` is the dual of `assert`: it signals that condition is sometimes true
  > assert(ok or !ok);
- [zig/test] [zig/errors] In tests `log.err` is downgraded to `warn`, because Zig fails
  any test that logs an error and they want to test error paths. `stdx/stdx.zig` ^f21
  > // Zig fails any test that does `log.err`, but we want to test those code paths here.
- [zig/comptime] [zig/safety] `no_padding(T)` and `equal_bytes(T, a, b)` check at
  comptime that a type has no implicit padding and no pointers before comparing raw
  bytes; extern structs with u128 fields must be 16-aligned. `stdx/stdx.zig` ^f22
  > /// Checks that a type does not have implicit padding.
  > comptime assert(!has_pointers(T));
- [zig/comptime] `array_print` checks at compile time that a fixed buffer fits the
  worst case of the format (all integer args at max). `stdx/stdx.zig` ^f23
  > /// Like std.fmt.bufPrint, but checks, at compile time, that the buffer is sufficiently large.
- [zig/errors] `parse_int` is strict by default (no leading zeros, separators, or `-0`)
  where std accepts them; the std functions are banned by tidy. `stdx/stdx.zig` ^f24
  > /// Strict by default integer parsing.
  > // Examples that parse with std, but should be rejected by default.
- [zig/api] `stdx.cut` (Go's `strings.Cut`) returns a tuple of before and after,
  destructured at the call site; preferred over indexOf/split chains. `stdx/stdx.zig` ^f25
  > /// This is a Zig version of Go's `string.Cut` / Rust's `str::split_once`. Cut turns out to be a
- [zig/api] [toolchain] 0.16 std.Io: `crypto_random_bytes(io, buf)` blocks cancellation
  around `io.randomSecure` and panics if entropy is missing, because `io.random`
  silently falls back to a predictable seed. `stdx/stdx.zig` ^f26
  > /// Panics if the OS fails to provide entropy, like Zig 0.14's `std.crypto.random`. Unlike this,
  > const cancel_protection = io.swapCancelProtection(.blocked);
- [zig/memory] [zig/api] `BoundedArrayType(T, capacity)`: TigerBeetle's own fixed
  capacity array (std's is banned); `push` asserts not full rather than returning an
  error; count stored as u32 behind `count()`. `stdx/bounded_array.zig` ^f27
  > /// A version of standard `BoundedArray` with TigerBeetle-idiomatic APIs.
  > assert(!array.full());
  > // Use an ugly internal name here and expose `pub fn count` as an API.
- [zig/style] Type-returning functions end in `Type` (`BoundedArrayType`,
  `QueueType`, `BitSetType`); the instance is named via `const X = @This()`. `stdx/bounded_array.zig` ^f28
  > pub fn BoundedArrayType(comptime T: type, comptime buffer_capacity: usize) type {
  > const BoundedArray = @This();
- [zig/api] Time is an interface (context pointer plus vtable of monotonic and
  realtime) with `TimeOS` and `TimeSim` implementations, so the simulator can fake
  time. TimeOS panics if the monotonic clock regresses. `stdx/time.zig` ^f29
  > pub const Time = struct {
  > if (m < self.monotonic_guard) @panic("a hardware/kernel bug regressed the monotonic clock");
- [zig/api] IO backend chosen at comptime by OS (io_uring, kqueue, IOCP; epoll for
  clients on Linux for old kernels and containers); one API. `io.zig` ^f30
  > pub const IO = switch (builtin.target.os.tag) {
  > pub const ClientIO = if (builtin.target.os.tag == .linux) IO_LinuxEpoll else IO;
- [zig/api] [zig/memory] IO operations take a caller-owned `*Completion`, a typed
  comptime callback and context; `erase_types` builds the `*anyopaque` trampoline at
  comptime, so no allocation per operation. `io/linux.zig` ^f31
  > completion: *Completion,
  > .callback = erase_types(Context, ReadError!usize, callback),
  > const ctx: Context = @ptrCast(@alignCast(ctx_any));
- [zig/errors] Each IO operation declares its own explicit error set merged with
  `posix.UnexpectedError`; init uses `errdefer |err| switch (err)` to log the likely
  cause of known failures. `io/linux.zig` ^f32
  > } || posix.UnexpectedError;
  > errdefer |err| switch (err) {
  > log.err("likely cause: the syscall is disabled by seccomp", .{});
- [zig/api] [toolchain] On 0.16 the custom IO keeps a `std.Io` only for blocking file
  operations (`aof_blocking_*`); the event loop stays their own io_uring code. `io/linux.zig` ^f33
  > /// The `std.Io` used for blocking file system operations (e.g. `aof_blocking_*`).
- [zig/test] Snapshot tests: `snap(@src(), \\expected)` is a string literal that knows
  its source location; on mismatch `SNAP_UPDATE=1` rewrites the test source;
  `<snap:ignore>` skips volatile parts; `diff_fmt`, `diff_zon`, `diff_hex` helpers. `stdx/testing/snaptest.zig` ^f34
  > //! and, crucially, can _update its own source code_ to match the expected value.
  > //! Re-running the test with `SNAP_UPDATE=1` environmental variable auto-magically updates the
  > //! Snapshots can use `<snap:ignore>` marker to ignore part of input:
- [zig/test] [toolchain] On 0.16 snaptest reads the env via `std.testing.environ`,
  files via `std.Io.Dir.cwd().readFileAlloc(std.testing.io, ...)`, serialises with
  `std.zon.stringify` into `std.Io.Writer.Allocating`. `stdx/testing/snaptest.zig` ^f35
  > std.testing.environ.containsConstant("SNAP_UPDATE");
  > var got: std.Io.Writer.Allocating = .init(std.testing.allocator);
  > try std.zon.stringify.serialize(value, .{}, &got.writer);
- [zig/test] Coverage marks: production code logs `log.mark.info(...)`; a test calls
  `marks.check("...")` then `expect_hit()`, tracing each branch to the minimal test that
  explains it. `testing/marks.zig` ^f36
  > //! In production code, you can mark certain log lines as "this should be covered by a test".
  > try mark.expect_hit(); // ... and don't forget to assert at the end!
- [zig/test] Exhaustive generation: a `Gen` with the PRNG-like interface enumerates
  every choice sequence, so a random test in `while (!g.done())` becomes exhaustive. `testing/exhaustigen.zig` ^f37
  > //! An utility for exhaustive generation of arbitrary data
  > while (!g.done()) {
- [zig/test] Swarm testing helper: random enum weights with a random subset of
  variants disabled. `testing/fuzz.zig` ^f38
  > /// This is swarm testing: some variants are disabled completely,
- [zig/test] Fuzzers are plain seeded programs dispatched from one `fuzz_tests.zig`
  (`zig build fuzz -- lsm_tree [seed]`), not Zig's built-in `--fuzz`; `smoke` runs all
  with seed 123 and fails if one takes over 10 s; `canary` fails on purpose to test the
  harness. `fuzz_tests.zig` ^f39
  > // A fuzzer that intentionally fails, to test fuzzing infrastructure itself
  > .lsm_cache_map => 20_000,
  > if (fuzz_duration.ns > 10 * std.time.ns_per_s) {
- [zig/test] [zig/safety] VOPR refuses ReleaseFast and ReleaseSmall (assertions off),
  and without a seed requires ReleaseSafe for speed; leaks fail the run. `vopr.zig` ^f40
  > // We do not support ReleaseFast or ReleaseSmall because they disable assertions.
  > comptime assert(builtin.mode == .Debug or builtin.mode == .ReleaseSafe);
  > .leak => @panic("memory leaked"),
- [toolchain] [zig/api] 0.16 entry points take `std.process.Init` (`init.io`,
  `init.minimal.args`); CLI parsing via their own `stdx.Flags` into a struct with a
  `@"--"` marker for positionals. `fuzz_tests.zig` ^f41
  > pub fn main(init: std.process.Init) !void {
  > const cli_args = flags.parse(CLIArgs, init.minimal.args);
- [zig/safety] Measured (our script, innermost function, excluding type functions and
  tests, 15 files): 861 functions, 3174 asserts, 3.69 per function. VSR and LSM files
  exceed two (replica 5.9, superblock 4.8, compaction 4.1, journal 3.8, grid 3.2,
  tree 2.2); infrastructure is under one (bounded_array 0.58, io/linux 0.63,
  message_pool 0.84, queue 0.35, ring_buffer 0.32). 35% of functions have no assert.
  src/ holds 8301 `assert(` and 303 `maybe(` calls in ~159k lines. ^f42
- [zig/style] Measured: 84 of those 861 functions (10%) exceed 70 lines; longest
  `Replica.init` 382, `open_data_file` 322, `create_transfer` 277. The 70-line rule is
  ratcheted (only 71-72 flagged), not enforced on old code ([[tigerbeetle-tidy#^f6]]). ^f43
- [zig/style] Measured: `_max`/`_min` suffix names (449 distinct) far outnumber
  `max_`/`min_` prefixes (28), so units-last naming is followed. `usize` appears 1042
  times against 1824 `u32` and 1722 `u64`, mostly for slice indexing: "avoid usize" is
  not absolute. 214 TODOs exist despite "zero technical debt". ^f44
- [zig/style] (inferred) Receiver naming is mixed: about 800 `self:` parameters and
  1600 named receivers (`grid: *Grid`, `array: *BoundedArray`); Tiger Style is silent
  on it, tidy bans only `Self = @This()`. ^f45

## Read

- Files listed in `depth`, the cited functions in full; `vsr/replica.zig` only
  `open` and the static allocator field.
- Assert and length counts: our script over vsr/journal, grid, superblock,
  client_sessions, replica; lsm/table, tree, compaction, manifest_level; stdx
  bounded_array, ring_buffer; io/linux; message_pool; queue; state_machine.

## Not read

- `src/state_machine.zig`, `src/lsm/groove.zig`, `src/vsr/journal.zig` in full.
- `src/stdx/flags.zig` (CLI parser built on comptime reflection), `src/stdx/shell.zig`
  (Zig replacement for shell scripts), `src/scripts/` (CI, release, devhub in Zig).
- `src/testing/cluster.zig`, `storage.zig`, `packet_simulator.zig`: simulator fault
  injection.
