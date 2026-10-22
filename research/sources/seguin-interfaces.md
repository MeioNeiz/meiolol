---
title: Zig Interfaces (Karl Seguin, 2023)
url: https://www.openmymind.net/Zig-Interfaces/
kind: article
commit:
for: [zig-api-design, zig-comptime]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/fair
description: Builds a ptr+fn-pointer interface, a comptime init that generates the thunk, and recommends tagged unions first
---
# Zig Interfaces (Karl Seguin, 2023)

Why: the classic community explanation of Zig runtime interfaces.

## Assessment

- Evidence: B. Widely cited (his Learning Zig links it); Oct 2023, Zig 0.11.
- Reasoning: fair; explains `*anyopaque` and casts, gives the tagged-union alternative.
- Interests: none known.
- Weigh: the mechanics hold. Stale: he calls `@fieldParentPtr` interfaces infrequent,
  but 0.15's `std.Io.Writer` revived exactly that (his own 2025 post). `anyerror!void`
  in the vtable loses precise errors, which the 0.15 Writer avoids with `error.WriteFailed`.

## Findings

- [zig/api] A runtime interface is a struct of `ptr: *anyopaque` plus function pointers; the implementation casts back with `@ptrCast(@alignCast(ptr))`. ^f1
  > It comes down to two things: using `*anyopaque` to be able to store a pointer to any implementation, and then using `@ptrCast(@alignCast(ptr))` to restore the correct type information.
- [zig/api] With more functions, put the pointers in a `VTable` struct, as `std.mem.Allocator` does. ^f2
  > Because `Allocator` has a few more functions, a nested structure called `VTable` (virtual table) is used to hold the function pointers
- [zig/comptime] A generic `init(ptr: anytype)` can generate the type-erasing thunk so implementations keep normal methods. ^f3
  > Specifically, the Zig compiler will create a version of `init` for each type of `ptr` that the program uses.
- [zig/api] For a closed set of implementations, a tagged union with `inline else` dispatch is simpler; he says use it first. ^f4
  > As far as I'm concerned, tagged unions should be your first option.
- [zig/api] Its limit: third parties can't add implementations. ^f5
  > You can't use it, for example, to create an interface that third parties can create implementations for.
- [zig/api] He described the `@fieldParentPtr` interface style as infrequently used (2023). ^f6
  > This used to be the standard way to create interfaces, but is now infrequently used.
- [zig/errors] His vtable signature returns `anyerror!void`, erasing which errors can happen. ^f7
  > writeAllFn: *const fn (ptr: *anyopaque, data: []const u8) anyerror!void,

## Read

- Whole post.
