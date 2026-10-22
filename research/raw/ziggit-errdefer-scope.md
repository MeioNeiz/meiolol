Xion | 2025-02-03 16:52:20 UTC | #1

Like `defer`, `errdefer` is scoped to the block it is defined.

However, unlike `defer`, there are cases where this turns out to be quite a bit of a footgun that requires careful coding around. It is all [documented](https://ziglang.org/documentation/0.13.0/#Common-errdefer-Slip-Ups) somewhat extensively but the ergonomics of the current situation are, I think, rather lacking.

One situation that I run into very often is cleaning up after `getOrPut` on a hashmap:

```
const gop = try map.getOrPut(key);
errdefer if (!gop.found_existing) {
    _ = map.swapRemove(key);
}
if (!gop.found_existing) {
    gop.value_ptr.* = try SomeValue.init(allocator);
}
errdefer if (!gop.found_existing) {
    gop.value_ptr.deinit();
}
```

Needless to say, this is very noisy and repetitive, and the triple-checking of the same condition in different contexts looks especially jarring.

Is there are any discussion about improving this situation? One way that I could see making things better would be to allow `errdefer` statement to be scoped to their parent blocks, e.g. through a syntax similar to labeled `break`:

```
const gop = try map.getOrPut(key);
gop: if (!gop.found_existing) {
    errdefer :gop _ = map.swapRemove(key);
    gop.value_ptr.* = try SomeValue.init(allocator);
    errdefer :gop gop.value_ptr.deinit();
}
```

Conceptually, it would be as though the `errdefer :gop` stanza placed the cleanup routine after the given label; in this case, it would precede the `if` and thus get executed only when the outer scope ends.

Since "outer scope" is commonly the entire function, we might also consider a way to attach `errdefer` to that top-level function scope from any nesting level using some kind of "label keyword" like `:fn`:

```
errdefer :fn _ = map.swapRemove(key);
```

There are likely issues with this approach (interaction with loops comes to mind), so I'm not sure how feasible it truly is. I'd hope some better solution to `errdefer` boilerplate does arrive in the language though, since right now even slightly non-trivial cases can easily get very complicated and verbose.

-------------------------

IntegratedQuantum | 2025-02-03 17:41:19 UTC | #2

You could do it like this to put one of the errdefers into the condition:
```
const gop = try map.getOrPut(key);
if (!gop.found_existing) {
    errdefer _ = map.swapRemove(key);
    gop.value_ptr.* = try SomeValue.init(allocator);
}
errdefer if (!gop.found_existing) {
    map.swapRemove(key).deinit();
}
```
Other than that I guess I'd also suggest to rethink your architecture:
- Can you maybe preallocate/reserve all the memory you need instead of allocating. If you have no `try`s in the function then you don't need any errdefers.
- If you have this pattern many times, then maybe you should use a helper function or helper data structure. It looks like you are trying to cache values, so why not add a Cache data structure that works like this:
```
fn getOrCreate(self: *Cache, key: K, init: anytype, params: anytype) !GetOrPutResult {
    const gop = try self.map.getOrPut(key);
    if(!gop.found_existing) {
        errdefer _ = self.map.swapRemove(key);
        gop.value_ptr.* = try @call(init, params);
    }
    return gop;
};
...
const gop = try cache.getOrCreate(key, SomeValue.init, .{allocator});
errdefer if(!gop.found_existing) {
    cache.swapRemove(key).deinit();
}
```

-------------------------

chadwain | 2025-02-03 18:07:19 UTC | #3

Why not try returning early?

```
const gop = try map.getOrPut(key);
if (gop.found_existing) return;
errdefer _ = map.swapRemove(key);

gop.value_ptr.* = try SomeValue.init(allocator);
errdefer gop.value_ptr.deinit();

...
```

-------------------------

DerpMcDerp | 2025-02-03 23:40:24 UTC | #4

I proposed this awhile back and it was closed as "not planned":

https://github.com/ziglang/zig/issues/19691

-------------------------

