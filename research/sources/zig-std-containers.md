---
title: 'Zig 0.17 std containers: ArrayList, hash maps, MultiArrayList'
url: https://codeberg.org/ziglang/zig/src/tag/0.17.0/lib/std
kind: project
commit: 0.17.0
for: [zig-memory, zig-api-design, zig-style, zig-perf]
looked: 2026-10-22
depth: code (std/array_list.zig, array_hash_map.zig, hash_map.zig, multi_array_list.zig, std.zig)
relevance: high
grade: A/strong
description: Zig 0.17.0 std container source read as the reference for idiomatic allocation, naming and doc comments
---
# Zig 0.17 std containers: ArrayList, hash maps, MultiArrayList

Why: how the std itself shapes container APIs in 0.17 (unmanaged, `.empty`, capacity
variants, pointer invalidation docs), as the model for meiolol's own types.

## Assessment

- Evidence: A. The canonical standard library of the language, written and reviewed by
  the core team; 1334 contributors on the GitHub mirror (moved to Codeberg Nov 2025),
  43k stars, MIT. Every container has inline tests next to the code.
- Reasoning: strong. Doc comments state complexity, pointer invalidation and asserts per
  function; comments explain layout choices (single allocation, fingerprints).
- Interests: none.
- Weigh: the std carries deprecated aliases during migrations (Managed, ArrayHashMap,
  ArrayListUnmanaged); copy the non-deprecated forms only.

## Findings

- [zig/api] In 0.17 `std.ArrayList(T)` is the unmanaged list: it stores no allocator,
  every allocating method takes `gpa: Allocator` after `self`. `std/std.zig:52` ^f1
  > pub fn ArrayList(comptime T: type) type {
  > return array_list.Aligned(T, null);
- [zig/api] [toolchain] The allocator-storing list survives only as deprecated
  `array_list.Managed`; `ArrayListUnmanaged` is a deprecated alias. `std/array_list.zig:10` ^f2
  > /// Deprecated.
  > pub fn Managed(comptime T: type) type {
  > /// Deprecated; use `ArrayList`.
- [zig/api] Containers initialise with a `pub const empty: Self` decl literal, used as
  `var list: ArrayList(i32) = .empty;`; default field init is deprecated. `std/array_list.zig:655` ^f3
  > /// An ArrayList containing no elements.
  > pub const empty: Self = .{
  > /// Default initialization of this struct is deprecated; use `.empty` instead.
- [zig/memory] `deinit` takes `*Self` plus the allocator and ends with `self.* = undefined`,
  so use after deinit is caught in safe builds. `std/array_list.zig:690` ^f4
  > pub fn deinit(self: *Self, gpa: Allocator) void {
  > self.pointer_stability.assertUnlocked();
  > gpa.free(self.allocatedSlice());
  > self.* = undefined;
- [zig/style] Doc comment names the parameter `gpa` for the allocator a container keeps
  across calls (general purpose), first after `self`. `std/array_list.zig:1026` ^f5
  > pub fn append(self: *Self, gpa: Allocator, item: T) Allocator.Error!void {
- [zig/api] Naming triad per growing op: `append` (may allocate, returns
  Allocator.Error), `appendAssumeCapacity` (asserts capacity, cannot fail),
  `appendBounded` (no allocator, returns error.OutOfMemory when full). `std/array_list.zig:1036` ^f6
  > /// Asserts that the list can hold one additional item.
  > pub fn appendAssumeCapacity(self: *Self, item: T) void {
  > /// If the list lacks unused capacity for the additional item, returns
  > pub fn appendBounded(self: *Self, item: T) error{OutOfMemory}!void {
- [zig/memory] `initBuffer` backs a list with caller memory; allocator-taking methods are
  then illegal behaviour, so only AssumeCapacity/Bounded methods may be used. `std/array_list.zig:677` ^f7
  > /// Initialize with externally-managed memory. The buffer determines the
  > /// When initialized this way, all functions that accept an Allocator
  > /// argument cause illegal behavior.
- [zig/memory] `toOwnedSlice` transfers ownership and leaves the list empty, trying
  `remap` before a copy; doc comment states who owns the result. `std/array_list.zig:745` ^f8
  > /// The caller owns the returned memory. Empties this ArrayList.
  > /// Its capacity is cleared, making deinit() safe but unnecessary to call.
  > if (gpa.remap(old_memory, self.items.len)) |new_items| {
- [zig/style] Every mutating method documents pointer invalidation, complexity and asserts
  in fixed phrases ("Invalidates element pointers if", "This operation is O(N).",
  "Asserts that"). `std/array_list.zig:806` ^f9
  > /// This operation is O(N).
  > /// Invalidates element pointers if additional memory is needed.
  > /// Invalidates pre-existing pointers to elements at and after `index`.
  > /// Asserts that the index is in bounds or equal to the length.
- [zig/safety] Containers carry a `pointer_stability: debug.SafetyLock` (zero-size in
  release) and check it in every method that may move memory; `lockPointers` turns a
  dangling-pointer bug into an assertion. `std/array_list.zig:651` ^f10
  > /// Used to detect memory safety violations.
  > pointer_stability: debug.SafetyLock,
  > /// Puts the unmanaged array list into a state where any method call that would
- [zig/perf] `ensureTotalCapacityPrecise` tries `remap` in place before alloc+copy, and
  the comment says why: realloc would copy unused capacity. `std/array_list.zig:1362` ^f11
  > // Here we avoid copying allocated but unused bytes by
  > // attempting a resize in place, and falling back to allocating
  > // a new buffer and doing our own copy. With a realloc() call,
- [zig/perf] Growth is 1.5x plus a cache-line's worth of elements, saturating. `std/array_list.zig:1550` ^f12
  > const init_capacity: comptime_int = @max(1, std.atomic.cache_line / @sizeOf(T));
  > return minimum +| (minimum / 2 + init_capacity);
- [zig/errors] Integer overflow of a requested size is reported as error.OutOfMemory via
  a small helper using @addWithOverflow, not a panic. `std/array_list.zig:1558` ^f13
  > /// Integer addition returning `error.OutOfMemory` on overflow.
  > fn addOrOom(a: usize, b: usize) error{OutOfMemory}!usize {
  > const result, const overflow = @addWithOverflow(a, b);
- [zig/comptime] `print` is only valid for byte lists and says so with `comptime assert`,
  then maps the Writer's error.WriteFailed back to error.OutOfMemory with an exhaustive
  switch. `std/array_list.zig:1169` ^f14
  > comptime assert(T == u8);
  > var aw: std.Io.Writer.Allocating = .fromArrayList(gpa, self);
  > error.WriteFailed => return error.OutOfMemory,
- [zig/perf] `appendNTimes` is `inline` for a stated codegen reason (comptime value gives
  a better memset), not by habit. `std/array_list.zig:1199` ^f15
  > /// The function is inline so that a comptime-known `value` parameter will
  > /// have a more optimal memset codegen in case it has a repeated byte pattern.
- [zig/test] Tests sit at the bottom of the same file, use testing.allocator, and
  `testing.failing_allocator` to check the OOM path. `std/array_list.zig:1767` ^f16
  > test "appendNTimes with failing allocator" {
  > const a = testing.failing_allocator;
  > try testing.expectError(error.OutOfMemory, list.appendNTimes(a, 2, 10));
- [zig/api] [toolchain] 0.17 array hash maps live under `std.array_hash_map` as `Auto`,
  `String` and `Custom`; the top-level `AutoArrayHashMapUnmanaged` names are deprecated
  aliases. `std/std.zig:39` ^f17
  > /// Deprecated; use `array_hash_map.Auto`.
  > pub const AutoArrayHashMapUnmanaged = array_hash_map.Auto;
- [zig/api] ArrayHashMap keeps insertion order and is the choice when iteration matters;
  its doc says it stores no allocator and is cheap for few entries. `std/array_hash_map.zig:47` ^f18
  > /// Insertion order is preserved. In general, this data structure supports the same
  > /// This type does not store an `Allocator` field - the `Allocator` must be passed in
  > /// If iterating over the table entries is a strong usecase and needs to be fast,
- [zig/comptime] Hash map behaviour is a comptime `Context` type with `hash` and `eql`
  decls; a zero-size context is inferred, a stateful one forces the `*Context` variant
  via @compileError. `std/array_hash_map.zig:301` ^f19
  > if (@sizeOf(Context) != 0)
  > @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call getOrPutContext instead.");
- [zig/perf] Adapted contexts let a map of u32 offsets into one byte buffer be looked up
  by a `[]const u8`: the string-interning pattern. `std/hash_map.zig:93` ^f20
  > pub const StringIndexContext = struct {
  > bytes: *const std.ArrayList(u8),
  > pub fn eql(ctx: @This(), a: []const u8, b: u32) bool {
- [zig/api] getOrPut returns pointers plus `found_existing` and leaves the value
  undefined for the caller to fill: one lookup for insert-or-update. `std/array_hash_map.zig:296` ^f21
  > /// Otherwise, puts a new item with undefined value, and
  > /// the `Entry` pointer points to it. Caller should then initialize
- [zig/comptime] Bad comptime parameters fail at type construction with a readable
  @compileError, not at use. `std/hash_map.zig:513` ^f22
  > if (max_load_percentage <= 0 or max_load_percentage >= 100)
  > @compileError("max_load_percentage must be between 0 and 100.");
- [zig/perf] HashMapUnmanaged is one allocation (header, metadata, entries) with 7-bit
  fingerprints; comments give the cache-miss reasoning. `std/hash_map.zig:520` ^f23
  > // This means that the hashmap only holds one live allocation, to
  > // reduce memory fragmentation and struct size.
  > /// costly function call.
- [zig/perf] `@branchHint(.cold)` marks the empty-map early return and `grow`, with a
  comment on why cold rather than unlikely. `std/hash_map.zig:970` ^f24
  > // We use cold instead of unlikely to force a jump to this case,
  > // no matter the weight of the opposing side.
  > @branchHint(.cold);
- [zig/errors] `errdefer comptime unreachable;` after the last fallible call proves at
  compile time that nothing below can fail, so no cleanup path is needed. `std/hash_map.zig:1437` ^f25
  > try map.allocate(allocator, new_cap);
  > errdefer comptime unreachable;
- [zig/perf] MultiArrayList stores each struct field (or union tag and payload) in its own
  array to cut padding and touch only the fields a loop needs; call `slice()` once and
  `items(.field)` per field. `std/multi_array_list.zig:9` ^f26
  > /// This allows for memory savings if the struct or union has padding,
  > /// and also improves cache usage if only some fields or just tags
  > /// If you are accessing multiple fields, call slice() first to compute the pointers,
- [zig/comptime] [toolchain] MultiArrayList computes its layout at comptime from 0.17's
  struct-of-arrays type info (`field_names`, `field_types`, `field_attrs`) and sorts
  fields by alignment in a labelled block. `std/multi_array_list.zig:178` ^f27
  > const field_names = @typeInfo(Elem).@"struct".field_names;
  > const field_types = @typeInfo(Elem).@"struct".field_types;
  > @setEvalBranchQuota(3 * field_names.len * std.math.log2(field_names.len));
- [zig/style] Generic type functions use `const Self = @This();` inside the returned
  anonymous struct (array_list, hash maps, MultiArrayList all do). `std/multi_array_list.zig:176` ^f28
  > const Self = @This();
- [zig/style] std.zig lists types (TitleCase) then namespaces (snake_case files), with
  deprecations as doc-commented aliases kept for a release. `std/std.zig:67` ^f29
  > /// Deprecated; use `lang`.
  > /// To be removed after Zig 0.17.0.
  > pub const builtin = lang;
- [zig/safety] Asserts are dense but targeted: 26 `assert(` in array_list.zig, 16 in
  hash_map.zig, mostly preconditions on capacity and indices (counted with grep). ^f30

## Read

- `std/array_list.zig`: Managed header, all of Aligned (unmanaged), tests skimmed
- `std/array_hash_map.zig`: header, Custom fields, getOrPut family
- `std/hash_map.zig`: contexts, HashMapUnmanaged layout, getIndex, grow
- `std/multi_array_list.zig`: lines 1-260, sort, capacityInBytes
- `std/std.zig`: top-level exports

## Not read

- `std/array_hash_map.zig` index header internals (Index(I) sized by count)
- `std/bit_set.zig`, `deque.zig`, `priority_queue.zig`, `static_string_map.zig`: same
  patterns likely, StaticStringMap matters for comptime lookup tables
