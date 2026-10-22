---
title: Comptime Zig ORM (matklad, 2025-03-19)
url: https://matklad.github.io/2025/03/19/comptime-zig-orm.html
kind: article
commit: 
for: [zig-comptime, zig-memory, zig-api-design]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: B/strong
description: Advanced Zig tutorial: an in-memory relational DB typed by a comptime schema (simplified TigerBeetle LSM forest) with FieldEnum, @field, inline for, @Type, reserve/insert split, and the advice to avoid reflection if possible
---
# Comptime Zig ORM (matklad, 2025-03-19)

Why: comptime reflection in practice and where it should stop. Zig 0.14.0 (links its
langref). Stale for 0.17: `@Type(.{ .@"struct" = ... })` was replaced in 0.16 by
`@Struct` and friends; 0.17 `@typeInfo` struct info is struct-of-arrays;
`std.ArrayListUnmanaged` is now plain `std.ArrayList` (0.15). Concepts hold.

## Assessment

- Evidence: B. Code lifted and simplified from TigerBeetle's LSM forest; author knows it
  well. A tutorial, not production code (sorted arrays, scalar API, no deinit).
- Reasoning: strong. Explains each idiom and its alternatives; ends with an explicit
  caveat against the very feature it teaches.
- Interests: none.
- Weigh: take the idioms (FieldEnum, Functions-as-struct, reserve/insert, out buffers,
  named allocators) and the caveat; port reflection code with care.

## Findings

- [zig/api] Newtype ids `pub const ID = enum(u64) { _ };` nested in each struct; same
  definition, distinct types. ^f1
  > Note that although `Account.ID` and `Transfer.ID` have exactly the same definition, they are distinct types.
- [zig/memory] [zig/style] Allocator naming conveys lifetime: `gpa` (free individually),
  `arena` (no per-object free), `scratch` (short-lived, can't outlive the function). ^f2
  > You often see `arena: Allocator`, signifying that memory doesn’t need to be freed on per-object basis, or `scratch: Allocator`, signifying that the memory can be used for short-lived allocations inside the function, but can’t outlive it.
- [zig/api] [zig/memory] Only the call that gets an allocator can allocate, so
  allocation sites are visible from the call. ^f3
  > Only `transfer.create` calls gets an allocator, so it is immediately obvious that only this part of the function can allocate.
- [zig/api] Results into a caller's stack buffer instead of allocating or iterators:
  `db.transfer.filter(query, &transfers_buffer)` returns a slice of it. ^f4
  > I don’t want to allocate the result, and I don’t want to bother with iterators, so I pass a stack-allocated out buffer in.
- [zig/memory] Zig pushes batching: `ensureTotalCapacity` once then
  `appendAssumeCapacity` without a gpa. ^f5
  > Zig _strongly_ pushes you towards batching your allocations, so we preallocate space for a hundred accounts at once, and then append _without_ passing a `gpa` in.
- [zig/comptime] [zig/api] Idiom: pass a group of comptime functions as a `Functions: type`
  struct (`key_fn`, `key_cmp`), since fn is not an expression. ^f6
  > Passing the table of functions as a `Functions` type is a weird idiom of Zig.
- [zig/memory] Table API splits fallible `reserve(gpa, extra)` from infallible `insert`
  with a capacity assert precondition. ^f7
  > memory allocation and data structure modification are split into two functions. Modification proper is infallible, and has a reservation as a precondition.
- [zig/perf] Batch API (`insert(table, values: []const Value)`) is O(N + K log K) vs
  O(N K) for K scalar inserts. ^f8
  > Even with a naive array list, the batched version runs in O(N + K log K), which is much faster than O(N K) of the scalar version repeated K times.
- [zig/comptime] Use `std.meta.FieldEnum(T)` rather than strings for field parameters:
  errors at the call site and greppable `.debit_account`. ^f9
  > Earlier type errors: calling `IndexTableType` with a field that doesn’t exist will error out at the call site, rather than at the definition side.
  > in Zig, field access is always spelled as `.debit_account` syntactically, so it is advantageous to stick to the same convention during meta programming
- [zig/comptime] `inline for` over comptime field list unrolls into direct comparisons
  (`order_by`). ^f10
  > Because the list of fields is known at compile time, the loop is fully unrolled
- [zig/comptime] Struct type built at comptime with `@Type(.{ .@"struct" = ... })` from
  `std.builtin.Type.StructField`s (stale: 0.16 `@Struct`). ^f11
  > break :blk @Type(.{ .@"struct" = .{
- [zig/memory] [zig/errors] `create` reserves in objects and every index, then `errdefer
  comptime unreachable`, then inserts; else a value could land in only some indexes. ^f12
  > Had we not split out fallible `reserve` from infallible `insert`, and kept the allocation inside `insert`, we could have ended in a situation when a value is inserted only in _some_ of the indexes.
- [zig/memory] He is skeptical OOM can be handled consistently; "abort on OOM" camp. ^f13
  > I must admit that I am deeply skeptical that it is possible to consistently handle these kind of issues on memory allocation error correctly, I am in the “abort on OOM” camp personally.
- [zig/comptime] `anytype` for an untypeable query: not dynamic typing, a fresh copy of the
  function per query type. ^f14
  > This is _not_ dynamic typing, rather, it’s monomorphization maximus — every distinct type of `query` will generate a fresh copy of the `filter` function.
- [zig/comptime] Caveat: avoid comptime reflection if possible; it leads to mind-bending
  code. ^f15
  > You should avoid this feature if possible: hopefully, I have successfully convinced you that they can lead to somewhat mind-bending code.
- [zig] Learning method: build toy versions; recommends a raytracer to learn Zig. ^f16
  > Seriously, if you want to learn Zig, go write yourself a raytracer

## Read

- Whole post (db.zig code skimmed in the last section).

## Not read

- Raytracer Construction Kit (2022, linked): lead, low.
