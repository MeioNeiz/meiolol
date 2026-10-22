---
title: 'Zig 0.17 std allocators: Allocator vtable, arena, fixed buffer, SafeAllocator, process.Init'
url: https://codeberg.org/ziglang/zig/src/tag/0.17.0/lib/std/heap
kind: project
commit: 0.17.0
for: [zig-memory, zig-api-design, zig-errors-safety]
looked: 2026-10-22
depth: code (std/mem/Allocator.zig, heap.zig, heap/ArenaAllocator.zig, FixedBufferAllocator.zig, SafeAllocator.zig, debug_allocator.zig header, start.zig callMain, process.zig Init)
relevance: high
grade: A/strong
description: Zig 0.17.0 allocator interface and implementations, and how start.zig hands main a gpa, arena and Io
---
# Zig 0.17 std allocators

Why: the canonical type-erased interface pattern, which allocator the std picks per build
mode, and how a 0.17 main receives its allocators.

## Assessment

- Evidence: A. The std itself (see [[zig-std-containers]] for repo signals); the
  allocators are used by the compiler and every Zig program.
- Reasoning: strong. Module doc comments state guarantees and costs (DebugAllocator
  "less than 1%" efficiency for one byte), Options fields say when to change them.
- Interests: none.
- Weigh: 0.17 is mid-migration: SafeAllocator is new, DebugAllocator deprecated; the
  pattern (ptr + vtable, `allocator()` method) is stable since 0.14.

## Findings

- [zig/api] The interface is a file-as-struct with two fields, a type-erased `ptr` and a
  `*const VTable` of function pointers; the module doc comment is `//!`. `std/mem/Allocator.zig:1` ^f1
  > //! The standard memory allocation interface.
  > const Allocator = @This();
  > ptr: *anyopaque,
  > vtable: *const VTable,
- [zig/api] The vtable is small (alloc, resize, remap, free) and each entry documents
  preconditions; convenience API (create, alloc, dupe, free) lives as methods on the
  interface, not in the vtable. `std/mem/Allocator.zig:24` ^f2
  > pub const VTable = struct {
  > /// `new_len` must be greater than zero.
  > free: *const fn (*anyopaque, memory: []u8, alignment: Alignment, ret_addr: usize) void,
- [zig/api] Raw vtable calls are `pub inline` but documented as implementer-only, so
  wrappers can forward without a user-facing convenience layer. `std/mem/Allocator.zig:144` ^f3
  > /// This function is not intended to be called except from within the
  > /// implementation of an `Allocator`.
  > pub inline fn rawAlloc(a: Allocator, len: usize, alignment: Alignment, ret_addr: usize) ?[*]u8 {
- [zig/api] Implementations expose `pub fn allocator(self: *T) Allocator` building the
  interface with an anonymous vtable literal; each vtable fn recovers `self` with
  `@ptrCast(@alignCast(ctx))`. `std/heap/FixedBufferAllocator.zig:19` ^f4
  > pub fn allocator(self: *FixedBufferAllocator) Allocator {
  > const self: *FixedBufferAllocator = @ptrCast(@alignCast(ctx));
- [zig/memory] (inferred) Since the interface stores `&self`, the implementation must not
  be moved or copied after `allocator()` is called: keep it in a `var` with a stable
  address. ^f5
- [zig/api] The vtable entries return `?[*]u8` or `bool`; the error union
  (`Error = error{OutOfMemory}`) is added by the wrapper methods. `std/mem/Allocator.zig:14` ^f6
  > pub const Error = error{OutOfMemory};
  > alloc: *const fn (*anyopaque, len: usize, alignment: Alignment, ret_addr: usize) ?[*]u8,
- [zig/safety] `free` sets the memory to undefined before releasing it, so in safe builds
  use-after-free reads garbage patterns rather than plausible old data. `std/mem/Allocator.zig:468` ^f7
  > pub fn free(self: Allocator, memory: anytype) void {
  > @memset(bytes, undefined);
- [zig/test] Doc tests are named after the declaration (`test print {`), so they render
  as usage examples in generated docs. `std/mem/Allocator.zig:515` ^f8
  > const a = std.testing.allocator;
  > defer free(a, s);
- [zig/api] [toolchain] `allocPrint` is deprecated in 0.17; `Allocator.print` builds the
  string through `Io.Writer.Allocating` and maps error.WriteFailed to OutOfMemory. `std/mem/Allocator.zig:506` ^f9
  > pub fn print(a: Allocator, comptime format: []const u8, args: anytype) Error![]u8 {
  > var aw = try std.Io.Writer.Allocating.initCapacity(a, format.len);
  > error.WriteFailed => return error.OutOfMemory,
- [zig/test] `Allocator.failing` is a constant interface whose alloc always returns null,
  built from `noAlloc` stubs the std exports for implementers. `std/mem/Allocator.zig:554` ^f10
  > /// An allocator that always fails to allocate.
  > pub const failing: Allocator = .{
  > .alloc = noAlloc,
- [zig/memory] ArenaAllocator wraps a child allocator; individual frees only reclaim the
  latest allocation; it is threadsafe in 0.17 if the child is. `std/heap/ArenaAllocator.zig:1` ^f11
  > //! you can allocate and then free it all together. Calls to free an individual item only
  > //! The `Allocator` implementation provided is threadsafe, given that `child_allocator`
- [zig/memory] Arena `State` can be stored instead of the whole arena (no child
  allocator copy) and promoted back; `State.init` is a decl literal. `std/heap/ArenaAllocator.zig:13` ^f12
  > /// Inner state of ArenaAllocator. Can be stored rather than the entire ArenaAllocator
  > /// as a memory-saving optimization.
  > pub fn promote(state: State, child_allocator: Allocator) ArenaAllocator {
- [zig/perf] `reset(.retain_capacity)` keeps one big buffer for loops, so after the
  largest iteration no more backing allocations happen. `std/heap/ArenaAllocator.zig:89` ^f13
  > /// This will pre-heat the arena for future allocations by allocating a
  > /// less often than before. If `reset()` is used in a loop, this means that after the
  > /// biggest operation, no memory allocations are performed anymore.
- [zig/style] Long-form design reasoning sits in `//` comments inside the function body
  (two reset strategies weighed), API contract in `///` above it. `std/heap/ArenaAllocator.zig:113` ^f14
  > // The reset function can be implemented with two basic approaches:
- [zig/memory] FixedBufferAllocator bumps an index over a caller buffer and offers a
  separate lock-free `threadSafeAllocator()` vtable; mixing the two is documented unsafe. `std/heap/FixedBufferAllocator.zig:31` ^f15
  > /// Provides a lock free thread safe `Allocator` interface to the underlying `FixedBufferAllocator`
  > /// Using this at the same time as the interface returned by `allocator` is not thread safe.
- [zig/memory] [toolchain] 0.17 adds `std.heap.SafeAllocator`; `DebugAllocator` and its
  Config are deprecated aliases. `std/heap.zig:14` ^f16
  > pub const SafeAllocator = @import("heap/SafeAllocator.zig");
  > /// Deprecated; use `SafeAllocator`.
  > pub const DebugAllocator = @import("heap/debug_allocator.zig").DebugAllocator;
- [zig/safety] SafeAllocator guarantees: deinit reports leaks, mismatches panic or fault,
  cross-instance frees caught by a canary, write-after-free mostly detected. `std/heap/SafeAllocator.zig:1` ^f17
  > //! * `deinit` reports all leaks and frees all backing memory.
  > //! * Allocations from other `SafeAllocator` instances cause a panic (if `Options.canary` differ).
  > //! * Most writes after free will segmentation fault or are eventually detected and panic.
- [zig/api] Options struct with defaults that depend on build mode, passed by value to
  `init(backing, options)`; `deinit` returns the leak count instead of a Check enum. `std/heap/SafeAllocator.zig:621` ^f18
  > /// Must be thread-safe for this allocator to be thread-safe
  > options: Options,
  > /// Returns the number of leaks
- [zig/safety] Layout invariants are checked with `comptime { assert(...) }` blocks next
  to the type they constrain. `std/heap/SafeAllocator.zig:110` ^f19
  > assert(@alignOf(@This()) == @alignOf(usize));
  > assert(@sizeOf(@This()) == @sizeOf(usize));
- [zig/perf] Per-thread state is padded to a cache line with a zero-size aligned field to
  avoid false sharing. `std/heap/SafeAllocator.zig:95` ^f20
  > /// Avoid false sharing.
  > _: void align(std.atomic.cache_line) = {},
- [zig/memory] DebugAllocator's doc is candid that its checks cost: over 100 bytes of
  overhead per one-byte allocation, so it is a debug tool, not a production heap. `std/heap/debug_allocator.zig:20` ^f21
  > //! These features require the allocator to be quite slow and wasteful. For
  > //! it requires more than 100 bytes of overhead to manage the allocation for
- [zig/memory] start.zig picks main's gpa by mode: SafeAllocator in Debug and
  ReleaseSafe, c_allocator when linking libc, smp_allocator otherwise. `std/start.zig:780` ^f22
  > const use_safe_allocator = !is_wasm and switch (builtin.mode) {
  > .debug, .safe => true,
  > std.heap.smp_allocator
- [zig/api] [toolchain] 0.17 `main` can take `std.process.Init`: a process-lifetime
  threadsafe arena, a gpa with leak checking in Debug, an `Io`, the environment map and
  preopens; `Init.Minimal` gives only args and environ. `std/process.zig:24` ^f23
  > /// A standard set of pre-initialized useful APIs for programs to take
  > /// Permanent storage for the entire process, cleaned automatically on
  > /// A default-selected general purpose allocator for temporary heap
- [zig/errors] Leaks at exit are logged but do not change the exit code. `std/start.zig:806` ^f24
  > _ = safe_allocator.deinit(); // Leaks do not affect return code.
- [zig/errors] An error returned from main is logged with `{t}` (tag name) and the error
  return trace dumped, exit code 1. `std/start.zig:843` ^f25
  > std.log.err("{t}", .{err});
  > else => if (@errorReturnTrace()) |trace| std.debug.dumpErrorReturnTrace(trace),
- [zig/errors] Error sets are declared as named `pub const XError = error{...}` with a doc
  comment per error, composed with `||`. `std/process.zig:60` ^f26
  > pub const CurrentPathError = error{
  > /// Buffer is too small to contain the current path.
  > } || Io.Cancelable || Io.UnexpectedError;
- [zig/errors] `process.fatal` logs and exits 1: the std's own idiom for unrecoverable
  CLI errors, used by start.zig itself. `std/process.zig:698` ^f27
  > pub fn fatal(comptime format: []const u8, format_arguments: anytype) noreturn {
  > std.log.err(format, format_arguments);
- [zig/memory] [toolchain] Checked, not there in 0.17 lib/std (grep):
  `GeneralPurposeAllocator`, `process.argsAlloc`, `argsWithAllocator`; use SafeAllocator
  (or main's `init.gpa`) and `init.minimal.args`. ^f28

## Read

- `std/mem/Allocator.zig`: all but realloc internals
- `std/heap/ArenaAllocator.zig`: public API, reset comment, alloc head
- `std/heap/FixedBufferAllocator.zig`: lines 1-80
- `std/heap/SafeAllocator.zig`: header, Options, init, deinit, allocator
- `std/heap/debug_allocator.zig`: module doc and Config
- `std/start.zig`: callMain, wrapMain; `std/process.zig`: Init, CurrentPathError, fatal

## Not read

- `std/heap/SmpAllocator.zig`, `PageAllocator.zig`, `BufferFirstAllocator.zig`,
  `memory_pool.zig`: production heaps and pools; MemoryPool matters for many same-type
  objects
- ArenaAllocator lock-free internals (cmpxchg node list)
