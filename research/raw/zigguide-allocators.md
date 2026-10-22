# Allocators | zig.guide

<https://zig.guide/standard-library/allocators/>

[Skip to main content](https://zig.guide/standard-library/allocators/#__docusaurus_skipToContent_fallback)

[

**zig.guide**](https://zig.guide/)[Guide](https://zig.guide/)[Posts](https://zig.guide/posts)

[GitHub](https://github.com/sobeston/zig.guide)

[Zig 0.15.2](https://zig.guide/standard-library/allocators)

-   [Zig 0.15.2](https://zig.guide/standard-library/allocators)
-   [Zig 0.13.0](https://zig.guide/0.13/standard-library/allocators)
-   [Zig 0.12.0](https://zig.guide/0.12/standard-library/allocators)
-   [Zig 0.11.0](https://zig.guide/0.11/standard-library/allocators)

-   [Getting Started](https://zig.guide/standard-library/allocators/#)
    
-   [Language](https://zig.guide/standard-library/allocators/#)
    
-   [Standard Library](https://zig.guide/standard-library/allocators/#)
    
    -   [Allocators](https://zig.guide/standard-library/allocators)
    -   [ArrayList](https://zig.guide/standard-library/arraylist)
    -   [Filesystem](https://zig.guide/standard-library/filesystem)
    -   [Readers and Writers](https://zig.guide/standard-library/readers-and-writers)
    -   [Formatting](https://zig.guide/standard-library/formatting)
    -   [JSON](https://zig.guide/standard-library/json)
    -   [Random Numbers](https://zig.guide/standard-library/random-numbers)
    -   [Crypto](https://zig.guide/standard-library/crypto)
    -   [Threads](https://zig.guide/standard-library/threads)
    -   [Hash Maps](https://zig.guide/standard-library/hashmaps)
    -   [Stacks](https://zig.guide/standard-library/stacks)
    -   [Sorting](https://zig.guide/standard-library/sorting)
    -   [Iterators](https://zig.guide/standard-library/iterators)
    -   [Formatting specifiers](https://zig.guide/standard-library/formatting-specifiers)
    -   [Advanced Formatting](https://zig.guide/standard-library/advanced-formatting)
-   [Build System](https://zig.guide/standard-library/allocators/#)
    
-   [Working with C](https://zig.guide/standard-library/allocators/#)
    

-   
-   Standard Library
-   Allocators

Version: Zig 0.15.2

# Allocators

The Zig standard library provides a pattern for allocating memory, which allows the programmer to choose precisely how memory allocations are done within the standard library - no allocations happen behind your back in the standard library.

The most fundamental allocator is [`std.heap.page_allocator`](https://ziglang.org/documentation/master/std/#std.heap.page_allocator). Whenever this allocator makes an allocation, it will ask your OS for entire pages of memory; an allocation of a single byte will likely reserve multiple kibibytes. As asking the OS for memory requires a system call, this is also extremely inefficient for speed.

Here, we allocate 100 bytes as a `[]u8`. Notice how defer is used in conjunction with a free - this is a common pattern for memory management in Zig.

```
const std = @import("std");const expect = std.testing.expect;test "allocation" {    const allocator = std.heap.page_allocator;    const memory = try allocator.alloc(u8, 100);    defer allocator.free(memory);    try expect(memory.len == 100);    try expect(@TypeOf(memory) == []u8);}
```

The [`std.heap.FixedBufferAllocator`](https://ziglang.org/documentation/master/std/#std.heap.FixedBufferAllocator) is an allocator that allocates memory into a fixed buffer and does not make any heap allocations. This is useful when heap usage is not wanted, for example, when writing a kernel. It may also be considered for performance reasons. It will give you the error `OutOfMemory` if it has run out of bytes.

```
test "fixed buffer allocator" {    var buffer: [1000]u8 = undefined;    var fba: std.heap.FixedBufferAllocator = .init(&buffer);    const allocator = fba.allocator();    const memory = try allocator.alloc(u8, 100);    defer allocator.free(memory);    try expect(memory.len == 100);    try expect(@TypeOf(memory) == []u8);}
```

[`std.heap.ArenaAllocator`](https://ziglang.org/documentation/master/std/#std.heap.ArenaAllocator) takes in a child allocator and allows you to allocate many times and only free once. Here, `.deinit()` is called on the arena, which frees all memory. Using `allocator.free` in this example would be a no-op (i.e. does nothing).

```
test "arena allocator" {    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);    defer arena.deinit();    const allocator = arena.allocator();    _ = try allocator.alloc(u8, 1);    _ = try allocator.alloc(u8, 10);    _ = try allocator.alloc(u8, 100);}
```

`alloc` and `free` are used for slices. For single items, consider using `create` and `destroy`.

```
test "allocator create/destroy" {    const byte = try std.heap.page_allocator.create(u8);    defer std.heap.page_allocator.destroy(byte);    byte.* = 128;}
```

The Zig standard library also has a general-purpose debug allocator. This is a safe allocator that can prevent double-free, use-after-free and can detect leaks. Safety checks and thread safety can be turned off via its configuration struct (left empty below). Zig's DebugAllocator is designed for safety over performance, but may still be many times faster than page\_allocator.

```
test "DebugAllocator" {    var gpa: std.heap.DebugAllocator(.{}) = .init;    const allocator = gpa.allocator();    defer {        const deinit_status = gpa.deinit();        //fail test; can't try in defer as defer is executed after we return        if (deinit_status == .leak) expect(false) catch @panic("TEST FAIL");    }    const bytes = try allocator.alloc(u8, 100);    defer allocator.free(bytes);}
```

For high performance (but very few safety features!), the Zig standard library offers [`std.heap.SmpAllocator`](https://ziglang.org/documentation/master/std/#std.heap.SmpAllocator). This is a general-purpose allocator designed for [maximum performance](https://ziglang.org/download/0.14.0/release-notes.html#SmpAllocator) on multithreaded machines.

```
test "SmpAllocator" {    const allocator = std.heap.smp_allocator;    const bytes = try allocator.alloc(u8, 100);    defer allocator.free(bytes);}
```

As an alternative when SmpAllocator is not available or desired, the libc allocator [`std.heap.c_allocator`](https://ziglang.org/documentation/master/std/#std.heap.c_allocator) may be considered. This, however, has the disadvantage of requiring linking Libc, which can be done with `-lc`.

Benjamin Feng's talk [_What's a Memory Allocator Anyway?_](https://www.youtube.com/watch?v=vHWiDx_l4V0) goes into more detail on this topic, and covers the implementation of allocators.

[Edit this page](https://github.com/Sobeston/zig.guide/tree/master/website/versioned_docs/version-0.15.x/02-standard-library/01-allocators.mdx)

Last updated on **Jan 4, 2026** by **kibels**

[

Previous

Imports

](https://zig.guide/language-basics/imports)[

Next

ArrayList

](https://zig.guide/standard-library/arraylist)

Community

-   [GitHub](https://github.com/sobeston/zig.guide)
-   [Mastodon](https://hachyderm.io/@sobeston)
-   [Sponsor zig.guide](https://github.com/sponsors/Sobeston)
