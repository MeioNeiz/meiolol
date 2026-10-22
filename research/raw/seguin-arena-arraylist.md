# ArenaAllocators don't play nicely with ArrayLists

<https://www.openmymind.net/Arena-Allocators-and-ArrayLists/>

[home](https://www.openmymind.net/)[dark](https://www.openmymind.net/Arena-Allocators-and-ArrayLists/#)

# ArenaAllocators don't play nicely with ArrayLists

Aug 04, 2026

A while ago, we looked at ArenaAllocators and [why you should view their free as a noop.](https://www.openmymind.net/ArenaAllocator-free-and-Nested-Arenas/) The short version is that, in order for a `free` or `destroy` to actually return memory to the arena, two conditions need to be met:

1.  The freed memory must have been the last allocated memory, and
2.  The freed memory must have been allocated on the Arena's current node (which is an internal detail of how the Arena grows)

Thus, given this code:

```zig
var a = try arena.alloc(u8, 100);
var b = try arena.alloc(u8, 100);
arena.free(b);
arena.free(a);
```

We can be certain that the memory for `b` will be returned to the arena, but can't say what will happen to `a`'s memory. Why? `b` is freed because it was the last allocation and, by definition, had to have come from the arena's current node. After `b` is freed, `a` satisfies the first requirement: it becomes the last allocated memory. However, we don't know whether the allocation of `b` caused a new node to be created; the arena's current node may or may not be the one `a` came from.

If the node thing seems confusing, go read the original post, or just forget about it, because there's a common situation where the first simpler rule isn't met: `ArrayList` (or `Writer.Allocating`) growth. When data is appended to an `ArrayList` it will first try to remap the existing memory (i.e. grow-in-place). But if that fails, it'll allocate a new larger chunk, copy the memory over, and free the previous allocation. See the issue? Here's the code from `array_list.zig`:

```zig
const new_memory = try gpa.alignedAlloc(T, alignment, new_capacity);
@memcpy(new_memory[0..self.items.len], self.items);
gpa.free(old_memory);
```

Even if you aren't interleaving other allocations with your `ArrayList` growth, the allocate + copy + free guarantees that `old_memory` isn't the last allocation (the last allocation is `new_memory`).

Is there a solution? Not really, but there are two things you can do. First, size your `ArrayList` (e.g. with `initCapacity` or `ensureTotalCapacityPrecise`). Second, avoid interleaving other allocations with your appends/writes. If you can do that, you'll hit the `remap` branch much more often and circumvent this issue. Both of those are good to keep in mind regardless of what type of `Allocator` you're using, but with an `ArenaAllocator` the worst case is ~3x the memory.

I know this is obvious, but I never actually thought about it. I'm probably not the only one.
