---
title: Learning Zig - Coding In Zig (Karl Seguin)
url: https://www.openmymind.net/learning_zig/coding_in_zig/
kind: book
commit:
for: [zig-memory, zig-api-design, zig-comptime, zig-testing, zig-build]
looked: 2026-10-22
depth: docs (whole chapter)
relevance: high
grade: B/fair
description: Chapter on ownership in hash maps and ArrayList, pointer invalidation, anytype and @hasField test factories, build.zig basics and dependencies
---
# Learning Zig - Coding In Zig (Karl Seguin)

Why: ownership pitfalls with std containers, and how a practitioner uses anytype.

## Assessment

- Evidence: B. Widely read intro by the http.zig maintainer; this chapter is updated to
  0.16 (juicy main, `std.Io.File`, unmanaged `ArrayList`).
- Reasoning: fair to strong on ownership (walks the failure, two fixes, costs); weak on
  the build system, which he says he does not understand well.
- Interests: none known.
- Weigh: trust the ownership material. The build and dependency section is stale and
  partly wrong for 0.17 (see ^f13).

## Findings

- [zig/memory] A pointer from `getPtr` into a hash map is invalidated by `remove` (and by growth); reading it afterwards gives garbage. ^f1
  > The `getPtr` method returns a pointer to the value in the map, in our case, it returns a `*User`. Herein lies the problem, `remove` makes our `entry` pointer invalid.
- [zig/memory] Fixes: take a copy with `get`, or store pointers (`*const User`) so the map holds addresses of values it doesn't own. ^f2
  > The first is that we could use `get` instead of `getPtr`. This would return a `User` instead of a `*User` and thus would return copy of the value in `lookup`.
- [zig/memory] Arguments and stored values are shallow copies: map and caller each own a separate copy. ^f3
  > Our above code has **two** users, each with their own owner. `goku` is owned by `main`, and its copy is owned by `lookup`.
- [zig/memory] Map keys must outlive the map; a key slice into a reused read buffer silently corrupts every key. ^f4
  > The truth is that they require long-lived values **as well as** long-lived keys!
- [zig/memory] The fix is for the map's owner to `dupe` keys, and then free them before `deinit`: the map can't, because keys may be literals or from another allocator. ^f5
  > const owned_name = try allocator.dupe(u8, name);
  > First, the keys could be string literals, which cannot be freed. Second, they could have been created with a different allocator.
- [zig/api] Wrap such cleanup in your own type's `deinit` rather than open-coding it at call sites. ^f6
  > At this point, it would probably make sense to create our own `UserLookup` type and encapsulate this cleanup logic in our `deinit` function.
- [zig/api] 0.15+ `ArrayList` is unmanaged: start from `.empty`, pass the allocator to `append` and `deinit`. ^f7
  > var arr: std.ArrayList(User) = .empty;
  > try arr.append(allocator, .{.name = owned_name, .power = i});
- [zig/api] 0.16 juicy main hands `main` an `Io` and a general allocator. ^f8
  > pub fn main(init: std.process.Init) !void {
  > const allocator = init.gpa;
- [zig/style] No private fields or properties: a field access is always a field access. He prefixes internal fields with an underscore and thinks the lack of privacy a mistake. ^f9
  > In Zig, if it looks like a field access, it **is** a field access. Personally, I think the lack of private fields is a mistake
- [zig/comptime] `anytype` is compile-time duck typing: a missing method is a compile error at the call. ^f10
  > Type checking happens at compile-time and for each type used, a correctly typed function is created.
- [zig/api] Before 0.15, `anytype` was the usual way to take a writer; now take `*std.Io.Writer`. ^f11
  > But, prior to Zig 0.15 - which redesigned the Writer and Reader interfaces - the use of anytype for a generic writer was common.
- [zig/test] Test-data factory: `anytype` plus `@hasField` lets a test set only the fields it cares about. ^f12
  > In many of our tests, we need a `User`, but we only want to specify the fields relevant to the test.
  > .id = if (@hasField(T, "id")) data.id else 0,
- [zig/build] (inferred) Stale for 0.17: `"a" ** 85` (array `**` removed in 0.17), `b.createModule("calc", .{...})` (createModule takes only options), and a dummy `.hash` to learn the real one (`zig fetch --save` writes it). ^f13
- [zig/test] He says `refAllDecls(@This())` in a `test {}` block pulls in nested containers' tests. ^f14
  > @import("std").testing.refAllDecls(@This());
- [zig/test] (inferred) Limit on ^f14: `refAllDecls` only references the container's direct declarations; files reached only through nested decls need their own reference. The 0.17 std `refAllDecls` loops over `std.meta.declarations(T)` only, and 0.17 has no `refAllDeclsRecursive`. ^f15
- [zig/test] The test runner is silent on success; `--summary all` shows counts. ^f16
  > By default, Zig's test runner only outputs on failure. Use `zig build test --summary all` if, like me, pass or fail, you always want a summary.
- [zig/build] He admits not understanding the build system well enough to explain it. ^f17
  > The truth is, I don't understand Zig's build system well enough to explain it.

## Read

- Whole chapter.
