# GetOrPut With String Keys

<https://www.openmymind.net/GetOrPut-With-String-Keys/>

[home](https://www.openmymind.net/)[dark](https://www.openmymind.net/GetOrPut-With-String-Keys/#)

# GetOrPut With String Keys

Feb 27, 2025

I've previously blogged about how much I like Zig's `getOrPut` hashmap method. As a brief recap, we can visualize Zig's hashmap as two arrays:

```text
keys:               values:
       --------          --------
       | Paul  |         | 1234 |     @mod(hash("Paul"), 5) == 0
       --------          --------
       |      |          |      |
       --------          --------
       |      |          |      |
       --------          --------
       | Goku |          | 9001 |    @mod(hash("Goku"), 5) == 3
       --------          --------
       |      |          |      |
       --------          --------
```

When we call `get("Paul")`, we could think of this simplified implementation:

```zig
fn get(map: *Self, key: K) ?V {
  const index = map.getIndexOf(key) orelse return null;
  return map.values[index];
}
```

And, when we call `getPtr("Paul")`, we'd have this implementation:

```zig
fn getPtr(map: *Self, key: K) ?*V {
  const index = map.getIndexOf(key) orelse return null;
  // notice the added '&'
  // we're taking the address of the array index
  return &map.values[index];
}
```

By taking the address of the value directly from the hashmap's array, we avoid copying the entire value. That can have performance implications (though not for the integer value we're using here). It also allows us to directly manipulate that slot of the array:

```zig
const value = map.getPtr("Paul") orelse return;
value.* = 10;
```

This is a powerful feature, but a dangerous one. If the underlying array changes, as can happen when items are added to the map, `value` would become invalid. So, while `getPtr` is useful, it requires mindfulness: try to minimize the scope of such references.

Currently, Zig's HashMap doesn't shrink when items are removed, so, for now, removing items doesn't invalidate any pointers into the hashmap. But expect that to change at some point.

### [GetOrPut](https://www.openmymind.net/GetOrPut-With-String-Keys/#getOrPut)

`getOrPut` builds on the above concept. It returns a pointer to the value **and** the key, as well as creating the entry in the hashmap if necessary. For example, given that we already have an entry for "Paul", if we call `map.getOrPut("Paul")`, we'd get back a `value_ptr` that points to a slot in the hahmap's `values` array, as well as a`key_ptr` that points to a slot in the hashmap's `keys` array. If the requested key _doesn't_ exist, we get back the same two pointers, and it's our responsibility to set the value.

If I asked you to increment counters inside of a hashmap, without `getOrPut`, you'd end up with two hash lookups:

```go
// Go
count, exists := counters["hits"]
if exists == false {
  counters["hits"] = 1
} else {
  counters["hits"] = count + 1;
}
```

With `getOrPut`, it's a single hash lookup:

```zig
const gop = try counters.getOrPut("hits");
if (gop.found_existing) {
  gop.value_ptr.* += 1;
} else {
  gop.value_ptr.* = 1;
}
```

### [getOrPut With String Keys](https://www.openmymind.net/GetOrPut-With-String-Keys/#stringKeys)

It seems trivial, but the most important thing to understand about `getOrPut` is that it will set the key for you if the entry has to be created. In our last example, notice that even when `gop.found_existing == false`, we never set `key_ptr` - `getOrPut` automatically sets it to the key we pass in, i.e. `"hits"`.

If we were to put a breakpoint after `getOrPut` returns but before we set the value, we'd see that our two arrays look something like:

```text
keys:               values:
       --------          --------
       |      |          |      |
       --------          --------
       | hits  |         | ???? |
       --------          --------
       |      |          |      |
       --------          --------
```

Where the entry in the `keys` array is set, but the corresponding entry in `values` is left undefined. You'll note that `getOrPut` doesn't take a value. I assume this is because, in some cases, the value might be expensive to derive, so the current API lets us avoid calculating it when `gop.found_existing == true`.

This is important for keys that need to be owned by the hashmap. Most commonly strings, but this applies to any other key which we'll "manage". Taking a step back, if we wanted to track hits in a hashmap, and, most likely, we wanted the lifetime of the keys to be tied to the hashmap, you'd do something like:

```zig
fn register(allocator: Allocator, map: *std.StringHashMap(u32), name: []const u8) !void {
  const owned = try allocator.dupe(u8, name);
  try map.put(owned, 0);
}
```

Creating your "owned" copy of `name`, frees the caller from having to maintain `name` beyond the call to `register`. Now, if this key is removed, or the entire map cleaned up, we need to free the keys. That's why I like the name "owned", it means the hash map "owns" the key (i.e. is responsible for freeing it):

```zig
var it = map.keyIterator();
while (it.next()) |key_ptr| {
  allocator.free(key_ptr.*);
}
map.deinit(allocator);
```

The interaction between key ownership and `getOrPut` is worth thinking about. If we try to merge this ownership idea with our incrementing counter code, we might try:

```zig
fn hit(allocator: Allocator, map: *std.StringHashMap(u32), name: []const u8) !void {
  const owned = try allocator.dupe(u8, name);
  const gop = try map.getOrPut(owned);
  if (gop.found_existing) {
    gop.value_ptr.* += 1;
  } else {
    gop.value_ptr.* = 1;
  }
}
```

But this code has a potential memory leak, can you spot it? (see [Appendix A](https://www.openmymind.net/GetOrPut-With-String-Keys/#appendix-a) for a complete runnable example) When `gop.found_existing == true`, `owned` is never used and never freed. One bad option would be to free `owned` when the entry already exists:

```zig
fn hit(allocator: Allocator, map: *std.StringHashMap(u32), name: []const u8) !void {
  const owned = try allocator.dupe(u8, name);
  const gop = try map.getOrPut(owned);
  if (gop.found_existing) {
    // This line was added. But this is a bad solution
    allocator.free(owned);
    gop.value_ptr.* += 1;
  } else {
    gop.value_ptr.* = 1;
  }
}
```

It works, but we needlessly `dupe` `name` if the entry already exists. Rather than prematurely duping the key in case the entry doesn't exist, we want to delay our `dupe` until we know it's needed. Here's a better option:

```zig
fn hit(allocator: Allocator, map: *std.StringHashMap(u32), name: []const u8) !void {
  // we use `name` for the lookup.
  const gop = try map.getOrPut(name);
  if (gop.found_existing) {
    gop.value_ptr.* += 1;
  } else {
    // this line was added
    gop.key_ptr.* = try allocator.dupe(u8, name);
    gop.value_ptr.* = 1;
  }
}
```

It might seem reckless to pass `name` into `getOrPut`. We need the key to remain valid as long as the map entry exists. Aren't we undermining that requirement? Let's walk through the code. When `hit` is called for a new `name`, `gop.found_existing` will be false. `getOrPut` will insert `name` in our `keys` array. This is bad because we have no `guarantee` that `name` will be valid for as long as we need it to be. But the problem is immediately remedied when we overwrite `key_ptr.*`.

On subsequent calls for an existing `name`, when `gop.found_existing == true`, the `name` is only used as a lookup. It's no different than doing a `getPtr`; `name` only has to be valid for the call to `getOrPut` because `getOrPut` doesn't keep a reference to it when an existing entry is found.

### [Conclusion](https://www.openmymind.net/GetOrPut-With-String-Keys/#conclusion)

This post was a long way to say: don't be afraid to write to `key_ptr.*`. Of course you can screw up your map this way. Consider this example:

```zig
fn hit(allocator: Allocator, map: *std.StringHashMap(u32), name: []const u8) !void {
    // we use `name` for the lookup.
    const gop = try map.getOrPut(name);
    if (gop.found_existing) {
      gop.value_ptr.* += 1;
    } else {
      // what's this?
      gop.key_ptr.* = "HELLO";
      gop.value_ptr.* = 1;
    }
}
```

Because the key is used to organize the map - find where items go and where they are, jamming random keys where they don't belong is going to cause issues. But it can also be used correctly and safely, as long as you understand the details.

### [Appendix A - Memory Leak](https://www.openmymind.net/GetOrPut-With-String-Keys/#appendix-a)

This code `should` report a memory leak.

```zig
const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.detectLeaks();

    // I'm using the Unmanaged variant because the Managed ones are likely to
    // be removed (which I think is a mistake). Using Unmanaged makes this
    // snippet more future-proof. I explain unmanaged here:
    // https://www.openmymind.net/Zigs-HashMap-Part-1/#Unmanaged
    var map: std.StringHashMapUnmanaged(u32) = .{};
    try hit(allocator, &map, "teg");
    try hit(allocator, &map, "teg");

    var it = map.keyIterator();
    while (it.next()) |key_ptr| {
      allocator.free(key_ptr.*);
    }
    map.deinit(allocator);
}

fn hit(allocator: Allocator, map: *std.StringHashMapUnmanaged(u32), name: []const u8) !void {
    const owned = try allocator.dupe(u8, name);
    const gop = try map.getOrPut(allocator, owned);
    if (gop.found_existing) {
      gop.value_ptr.* += 1;
    } else {
      gop.value_ptr.* = 1;
    }
}
```
