---
title: 'Zig 0.17 compiler data-oriented design: Ast, Zir, InternPool'
url: https://codeberg.org/ziglang/zig/src/tag/0.17.0/src/InternPool.zig
kind: project
commit: 0.17.0
for: [zig-perf, zig-style, zig-errors-safety]
looked: 2026-10-22
depth: code (std/zig/Ast.zig header, Node, extraData, parse; std/zig/Zir.zig header, Inst, Ref, Data, Trailing docs; src/InternPool.zig header, Local, String, Key, Item, Index, get, indexToKey)
relevance: high
grade: A/strong
description: The Zig compiler's own data structures (AST, ZIR, intern pool) as the reference for struct-of-arrays, typed indices and extra arrays
---
# Zig 0.17 compiler data-oriented design

Why: the compiler is the largest, most performance-tuned Zig codebase; its IR layouts
are the canonical example of the DOD style (Andrew Kelley's DOD talk, applied).

## Assessment

- Evidence: A. The self-hosted compiler, the core team's main product; Ast.zig and
  Zir.zig ship in the std, InternPool.zig (12984 lines) in src/.
- Reasoning: strong. Comments state size goals and guard them with comptime asserts;
  doc comments say how to interpret each tag's payload.
- Interests: none.
- Weigh: these are extreme designs for millions of nodes; the techniques (u32 typed
  indices, SoA, side arrays) transfer, the full machinery (sharded, per-thread pools)
  only for hot, huge data.

## Findings

- [zig/perf] The AST is three flat arrays: tokens and nodes as MultiArrayList slices and
  a `[]u32` extra_data; nodes refer to each other by index, not pointer. `std/zig/Ast.zig:17` ^f1
  > tokens: TokenList.Slice,
  > nodes: NodeList.Slice,
  > extra_data: []u32,
- [zig/perf] Offsets are u32 (`ByteOffset = u32`), halving index size on 64-bit. `std/zig/Ast.zig:26` ^f2
  > pub const ByteOffset = u32;
- [zig/safety] Indices are non-exhaustive `enum(u32)` types (Node.Index, OptionalIndex,
  Offset), so a node index cannot be passed where a token index is expected. `std/zig/Ast.zig:2919` ^f3
  > /// Index into `nodes`.
  > pub const Index = enum(u32) {
- [zig/perf] Optional indices use a sentinel `none = maxInt(u32)` value instead of
  `?u32`, keeping them 4 bytes, with `unwrap()` to a real optional at use. `std/zig/Ast.zig:2936` ^f4
  > /// Index into `nodes`, or null.
  > pub const OptionalIndex = enum(u32) {
  > none = std.math.maxInt(u32),
  > return if (oi == .none) null else @fromBackingInt(@intCast(@backingInt(oi)));
- [zig/perf] A node is a 1-byte tag, a main token and an 8-byte untagged data union; the
  sizes are guarded by a comptime assert (only outside safety builds, where untagged
  unions get a hidden tag). `std/zig/Ast.zig:2978` ^f5
  > // Goal is to keep this under one byte for efficiency.
  > assert(@sizeOf(Tag) == 1);
  > assert(@sizeOf(Data) == 8);
- [zig/style] Each Tag value's doc comment says which Data field is active and what it
  means, since the union is untagged. `std/zig/Ast.zig:3001` ^f6
  > /// The `data` field is a `.opt_token_and_node`:
  > /// The `main_token` field is the `test` token.
- [zig/perf] Variable-size payloads go in `extra_data` as u32 words, decoded by a comptime
  `extraData(index, T)` that walks T's fields with inline for. `std/zig/Ast.zig:305` ^f7
  > pub fn extraData(tree: Ast, index: ExtraIndex, comptime T: type) T {
  > inline for (info.field_names, info.field_types, 0..) |field_name, field_type, i| {
  > else => @compileError("unexpected field type: " ++ @typeName(field_type)),
- [zig/perf] `parse` pre-sizes the token list from a measured ratio, with the number
  stated in the comment. `std/zig/Ast.zig:153` ^f8
  > // Empirically, the zig std lib has an 8:1 ratio of source bytes to token count.
  > try tokens.ensureTotalCapacity(gpa, estimated_token_count);
- [zig/memory] `parse` uses `defer tokens.deinit` then `toOwnedSlice` + `errdefer` on the
  slice: ownership moves once, and cleanup follows it. `std/zig/Ast.zig:167` ^f9
  > var tokens_slice = tokens.toOwnedSlice();
  > errdefer tokens_slice.deinit(gpa);
- [zig/perf] ZIR is designed so later stages never touch the AST again except for
  errors: one representation per phase, each self-contained. `std/zig/Zir.zig:5` ^f10
  > //! The minimum amount of information needed to represent a list of ZIR instructions.
  > //! machine code, without any memory access into the AST tree token list, node list,
- [zig/perf] Strings are interned into one `string_bytes` buffer and referenced by u32
  index; index 0 reserved. `std/zig/Zir.zig:26` ^f11
  > /// In order to store references to strings in fewer bytes, we copy all
  > /// string bytes into here. String bytes can be null. It is up to whomever
  > /// Index 0 is reserved for special cases.
- [zig/perf] Instructions are tag (u8) + 8-byte Data in a MultiArrayList; the layout is
  guarded by a comptime size assert with a comment saying why. `std/zig/Zir.zig:2515` ^f12
  > // Make sure we don't accidentally add a field to make this union
  > // bigger than expected. Note that in Debug builds, Zig is allowed
  > assert(@sizeOf(Data) == 8);
- [zig/perf] One enum(u32) `Ref` spans two spaces: values below a static length are
  well-known InternPool entries (u8_type...), the rest instruction indices. `std/zig/Zir.zig:2225` ^f13
  > /// If the integer tag value is < InternPool.static_len, then it
  > /// corresponds to an InternPool index. Otherwise, this refers to a ZIR
  > /// The tag type is specified so that it is safe to bitcast between `[]u32`
- [zig/style] Payload structs document their trailing variable data in a `Trailing:`
  doc comment listing what follows in extra. `std/zig/Zir.zig:2566` ^f14
  > /// 0. Output for every outputs_len
  > /// 1. Input for every inputs_len
- [zig/perf] Flags are packed into `packed struct(u16)` with explicit backing size. `std/zig/Zir.zig:2581` ^f15
  > pub const Small = packed struct(u16) {
  > is_volatile: bool,
  > outputs_len: u7,
- [zig/perf] InternPool splits API and storage: `Key` is a rich tagged union for callers,
  `Item` is a u8 tag plus u32 data in storage; `get` encodes a Key, `indexToKey` decodes. `src/InternPool.zig:3932` ^f16
  > pub const Item = struct {
  > /// The doc comments on the respective Tag explain how to interpret this.
  > pub fn indexToKey(ip: *const InternPool, index: Index) Key {
- [zig/perf] Interning makes equality cheap: two same-typed values are equal iff their
  indices are equal. `src/InternPool.zig:3939` ^f17
  > /// Two values which have the same type can be equality compared simply
  > /// by checking if their indexes are equal, provided they are both in
- [zig/perf] Per-thread `Local` state, each part cache-line aligned, with a per-thread
  arena to avoid allocator contention and keep old pointers valid for racing readers. `src/InternPool.zig:960` ^f18
  > shared: Shared align(std.atomic.cache_line),
  > /// allocated into this `arena` (for the `Id` of the thread performing the mutation). An
  > /// arena is used to avoid contention on the GPA, and to ensure that any code which retains
- [zig/memory] The pool stores `ArenaAllocator.State`, not a full arena, per thread (the
  memory-saving form the arena docs offer). `src/InternPool.zig:975` ^f19
  > arena: std.heap.ArenaAllocator.State,
- [zig/memory] Insert path: reserve with `ensureUnusedCapacity(1)` first, then
  `appendAssumeCapacity` in each branch, so the switch body cannot fail midway. `src/InternPool.zig:7263` ^f20
  > try items.ensureUnusedCapacity(1);
  > items.appendAssumeCapacity(.{
- [zig/safety] Invariants are asserted at the point of use (161 `assert(` in
  InternPool.zig), e.g. on keys before interning. `src/InternPool.zig:7276` ^f21
  > assert(ptr_type.child != .none);
  > assert(ptr_type.sentinel == .none or ip.typeOf(ptr_type.sentinel) == ptr_type.child);
- [zig/memory] Removed entries keep their slot (tag `removed`) so indices held elsewhere
  stay valid. `src/InternPool.zig:4790` ^f22
  > /// This special tag represents a value which was removed from this pool via
  > /// `InternPool.remove`. The item remains allocated to preserve indices, but
- [zig/style] Receivers are named after the type, short (`ip: *InternPool`,
  `tree: *const Ast`, `w: *Writer`), not `self`: 85 `(ip: *` vs 12 `(self: ` in
  InternPool.zig, 102 `(tree: ` vs 1 in Ast.zig (counted with grep). `src/InternPool.zig:6451` ^f23
  > pub fn indexToKey(ip: *const InternPool, index: Index) Key {
- [zig/style] File-as-struct files name themselves (`const Ast = @This();`, `const Writer =
  @This();`); 128 std files do this at top level vs 3 with `const Self = @This();`
  (counted with grep over lib/std). `std/zig/Ast.zig:11` ^f24
  > const Ast = @This();
- [zig/api] [toolchain] 0.17 code converts enums with `@backingInt`/`@fromBackingInt`;
  the std uses them 4045 times vs 74 leftover `@intFromEnum` (grep over lib/std). `std/zig/Ast.zig:2925` ^f25
  > const result: OptionalIndex = @fromBackingInt(@intCast(@backingInt(i)));
- [zig/style] A file-level `//!` comment says what the structure is and how it relates to
  neighbours in the pipeline. `std/zig/Zir.zig:1` ^f26
  > //! Zig Intermediate Representation.
  > //! Astgen.zig converts AST nodes to these untyped IR instructions. Next,

## Read

- `std/zig/Ast.zig`: lines 1-320, Node (2914-3010), Data union
- `std/zig/Zir.zig`: lines 1-80, Inst head, Ref, Data, Asm payload
- `src/InternPool.zig`: lines 1-120, Local, String, Key head, Item, Index, Tag head,
  get head, indexToKey head

## Not read

- `src/Sema.zig`, `src/Air.zig`, `src/codegen/`: same patterns at the next stage;
  Air liveness may show bit-packed side tables
- InternPool sharded map and lock-free reads (`Shard`, `acquire`)
- `std/zig/AstGen.zig`: how the producer side writes extra data (`addExtra`)
