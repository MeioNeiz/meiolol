# ArenaAllocator.free and Nested Arenas

<https://www.openmymind.net/ArenaAllocator-free-and-Nested-Arenas/>

[home](https://www.openmymind.net/)[dark](https://www.openmymind.net/ArenaAllocator-free-and-Nested-Arenas/#)

# ArenaAllocator.free and Nested Arenas

Mar 15, 2025

What happens when you `free` with an ArenaAllocator? You might be tempted to look at the documentation for [std.mem.Allocator.free](https://ziglang.org/documentation/master/std/#std.mem.Allocator.free) which says "Free an array allocated with alloc". But this is the one thing we're sure it _won't_ do.

In its current implementation, calling `free` usually does nothing: the freed memory isn't made available for subsequent allocations by the arena, and it certainly isn't released back to the operating system. However, under specific conditions `free` will make the memory re-usable by the arena. The only way to really "free" the memory is to call `deinit`.

The only case when we're guaranteed that the memory will be reusable by the arena is when it was the last allocation made:

```zig
const str1 = try arena.dupe(u8, "Over 9000!!!");
arena.free(str1);
```

Above, whatever memory was allocated to duplicate our string will be available for subsequent allocations made with `arena`. In the following case, the two calls to `arena.free` do nothing:

```zig
const str1 = try arena.dupe(u8, "ab");
const str2 = try arena.dupe(u8, "12");
arena.free(str1);
arena.free(str2);
```

In order to "fix" this code, we'd need to reverse the order of the two frees:

```zig
const str1 = try arena.dupe(u8, "ab");
const str2 = try arena.dupe(u8, "12");
arena.free(str2);  //swapped this line with the next
arena.free(str1);
```

Now, when we call `arena.free(str2)`, the memory allocated for `str2` will be available to subsequent allocations. But what happens when we call `arena.free(str1)`? The answer, again, is: _it depends_. It has to do with the internal state of the arena. Simplistically, an `ArenaAllocator` keeps a linked list of memory buffers. Imagine something like:

```text
buffer_list.head -> ------------
                    |   next   | -> null
                    |   ----   |
                    |          |
                    |          |
                    |          |
                    |          |
                    |          |
                    ------------
```

Our linked list has a single node along with 5 bytes of available space. After we allocate `str1`, it looks like:

```text
buffer_list.head -> ------------
                    |   next   | -> null
                    |   ----   |
            str1 -> |    a     |
                    |    b     |
                    |          |
                    |          |
                    |          |
                    ------------
```

Then, when we allocate `str2`, it looks like:

```text
buffer_list.head -> ------------
                    |   next   | -> null
                    |   ----   |
            str1 -> |    a     |
                    |    b     |
            str2 -> |    1     |
                    |    2     |
                    |          |
                    ------------
```

When we free `str2`, it goes back to how it was before:

```text
buffer_list.head -> ------------
                    |   next   | -> null
                    |   ----   |
            str1 -> |    a     |
                    |    b     |
                    |          |
                    |          |
                    |          |
                    ------------
```

Which means that when we `arena.free(str1)`, it **will** make that memory available again. However, if instead of allocating two strings, we allocate three:

```zig
const str1 = try arena.dupe(u8, "ab");
const str2 = try arena.dupe(u8, "12");
const str3 = try arena.dupe(u8, "()");
arena.free(str3);
arena.free(str2);
arena.free(str1);
```

Our first buffer doesn't have enough space for the new string, so a new node is prepended to our linked list:

```text
buffer_list.head -> ------------    ------------
                    |   next   | -> |   next   | -> null
                    |   ----   |    |   ----   |
            str3 -> |    (     |    |    a     | <- str1
                    |    )     |    |    b     |
                    |          |    |    1     | <- str2
                    |          |    |    2     |
                    |          |    |          |
                    ------------    ------------
```

When we call `arena.free(str3)`, the memory for that allocation will be made available, but subsequent frees, even if they're in the correct order (i.e. freeing `str2` then `str1`) will be noops. The ArenaAllocator doesn't have the capability to go back to act on anything but the head of our linked list, even if it's empty.

In short, when we `free` the last allocation, that memory will _always_ be made available. But subsequent `frees` only behave this way if (a) they're also in order and (b) happen to be allocate within the same internal memory node.

### [Nested Arenas](https://www.openmymind.net/ArenaAllocator-free-and-Nested-Arenas/#nested)

Zig's allocator are said to be composable. When we create an `ArenaAllocator`, we pass a single parameter: an allocator. That parent allocator (1) can be any other type of allocator. You can, for example, create an `ArenaAllocator` on top of a `FixedBufferAllocator`. You can also create an `ArenaAllocator` on top of another `ArenaAllocator`.

(1) Zig calls this the "child allocator", but that doesn't make any sense to me.

This kind of thing often happens within libraries, where an API takes an `std.mem.Allocator` and the library creates an `ArenaAllocator`. And what happens when the provided allocator was already an arena? Libraries aside, I'm mean something like:

```zig
var parent_arena = ArenaAllocator.init(gpa_allocator);
const parent_allocator = parent_arena.allocator();

var inner_arena = ArenaAllocator.init(parent_allocator);
const inner_allocator = inner_arena.allocator();

_ = try inner_allocator.dupe(u8, "Over ");
_ = try inner_allocator.dupe(u8, "9000!");

inner_arena.deinit();
```

It does work, but at best, when `deinit` is called, the memory will be made available to be re-used by `inner_arena`. Except in simple cases, allocations made by `inner_arena` are likely to span multiple buffers of `parent_arena`, and of course you can still make allocations directly in `parent_arena` which can generate its own new buffers or simply make the ordering requirement impossible to fulfill. For example, if we make an allocation in `parent_arena` before `inner_arena.deinit();` is called:

```zig
_ = try parent_allocator.dupe(u8, "!!!");
inner_arena.deinit();
```

Then the `deinit` does nothing.

So while nesting ArenaAllocator's works, I don't think there's any advantage over using a single Arena. And, I think in many cases where you have an "inner\_arena", like in a library, it's better if the caller provides a non-Arena parent allocator so that all the memory is really freed when the library is done with it. Of course, there's a transparency issue here. Unless the library documents exactly how it's using your provided allocator, or unless you explore the code - and assuming the implementation doesn't change - it's hard to know what you should use.
