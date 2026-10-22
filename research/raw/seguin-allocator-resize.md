# Allocator.resize

<https://www.openmymind.net/Allocator-resize/>

[home](https://www.openmymind.net/)[dark](https://www.openmymind.net/Allocator-resize/#)

# Allocator.resize

Mar 27, 2025

There are four important methods on Zig's `std.mem.Allocator` interface that Zig developers must be comfortable with:

-   `alloc(T, n)` - which creates an array of `n` items of type `T`,
-   `free(ptr)` - which frees memory allocate with `alloc` (although, this [is implementation specific](https://www.openmymind.net/ArenaAllocator-free-and-Nested-Arenas/)),
-   `create(T)` - which creates a single item of type `T`, and
-   `destroy(ptr)` - which destroys an item created with `create`

While you might never need to use them, the `Allocator` interface has other methods which, if nothing else, can be useful to be aware of and informative to learn about.

In particularly, the `resize` method is used to try and resize an existing allocation to a larger (or smaller) size. The main promise of `resize` is that it's guaranteed _not_ to move the pointer. However, to satisfy that guarantee, resize is allowed to fail, in which case nothing changes.

We can imagine a simple allocation:

```text
// var buf = try allocator.alloc(u8, 5);
// buf[0] = 'h'

           0x102e00000
           -------------------------------
buf.ptr -> |  h  |     |     |     |     |
          --------------------------------
```

Now, if we were to call `allocator.resize(buf, 7)`, there are be two possible outcomes. The first is that the call returns `false`, indicating that the resize operation fails, and thus nothing changed::

```text
0x102e00000
           -------------------------------
buf.ptr -> |  h  |     |     |     |     |
          --------------------------------
```

However, when `resize` succeeds and returns `true`, the allocated space has grown without having relocated (i.e. moved) the pointer:

```text
0x102e00000
           -------------------------------------------
buf.ptr -> |  h  |     |     |     |     |     |     |
          --------------------------------------------
```

Now under what circumstances `resize` succeeds and fails is a black box. It depends on a lot of factors and is going to be allocator-specific. For example, for me, this code prints `false` indicating that the resize failed:

```zig
const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const allocator = gpa.allocator();
    _ = gpa.detectLeaks();

    const buf = try allocator.alloc(usize, 10);
    std.debug.print("{any}\n", .{allocator.resize(buf, 20)});
    allocator.free(buf);
}
```

Because we're using a `GeneralPurposeAllocator` (that name is deprecated in Zig 0.14 in favor of `DebugAllocator`) we could dive into its internals and try to leverage knowledge of its implementation to force a resize to succeed, but a simpler option is to resize our buffer to `0`:

```zig
const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const allocator = gpa.allocator();
    _ = gpa.detectLeaks();

    const buf = try allocator.alloc(usize, 10);
    // change 20 -> 0
    std.debug.print("{any}\n", .{allocator.resize(buf, 0)});
    allocator.free(buf);
}
```

Success, the code now prints `true`, indicating that the resize succeeded. However, I also get **segfault**. Can you guess what we're doing wrong?

In our above visualization, we saw how a successful resize does not move our pointer. We can confirm this by looking at the address of `buf.ptr` before and after our resize. This code still segfaults, but it prints out the information first:

```zig
pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const allocator = gpa.allocator();
    _ = gpa.detectLeaks();

    const buf = try allocator.alloc(usize, 10);
    std.debug.print("address before resize: {*}\n", .{buf.ptr});
    std.debug.print("resize succeeded: {any}\n", .{allocator.resize(buf, 0)});
    std.debug.print("address after resize: {*}\n", .{buf.ptr});
    allocator.free(buf);
}
```

So far, we've only considered the `ptr` of our slice, but, like the criminal justice system, a slice is represented by two separate yet equally important groups: a `ptr` and a `len`. If we change our code to also look at the `len` of `buf`, the issue might become more obvious:

```zig
// change the 1st and 3rd line to also print buf.len:
std.debug.print("address & len before resize: {*} {d}\n", .{buf.ptr, buf.len});
std.debug.print("resize succeeded: {any}\n", .{allocator.resize(buf, 0)});
std.debug.print("address & len after resize: {*} {d}\n", .{buf.ptr, buf.len});
```

This is what I get:

```text
address & len before resize: usize@100280000 10
resize succeeded: true
address & len after resize: usize@100280000 10
Segmentation fault at address 0x100280000
```

While it isn't the cleanest output, notice that even after we successfully resize our ptr, the length remains unchanged (i.e. `10`). Herein lies our bug problem. `resize` updates the underlying memory, it doesn't update the length of the slice. That's something we need to take care of. Here's a non-crashing version:

```zig
const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const allocator = gpa.allocator();
    _ = gpa.detectLeaks();

    var buf = try allocator.alloc(usize, 10);
    if (allocator.resize(buf, 0)) {
        std.debug.print("resize succeeded!\n", .{});
        buf.len = 0;
    } else {
        // we need to handle the case where resize doesn't succeed
    }

    allocator.free(buf);
}
```

What's left out of the above code is handling the case where `resize` fails. This becomes application specific. In most cases, where we're likely resizing to a larger size, we'll generally need to fallback to calling `alloc` to create our larger memory, and then, most likely, `@memcpy` to copy data from the existing (now too small) buffer to the newly created larger one.
