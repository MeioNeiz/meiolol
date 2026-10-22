# Zig: Freeing resources referenced in multiple threads

<https://www.openmymind.net/Zig-Freeing-Resources-Referenced-In-Multiple-Threads/>

[home](https://www.openmymind.net/)[dark](https://www.openmymind.net/Zig-Freeing-Resources-Referenced-In-Multiple-Threads/#)

# Zig: Freeing resources referenced in multiple threads

May 21, 2024

As you learn Zig, you'll see examples of memory being allocated and through the use of `defer`, freed. Often, these allocations and deallocations are wrapped in `init` and `deinit` functions. But whatever specific implementation is used, the point is to show a common pattern which is suitable in simple cases. It isn't too much of a leap to take such examples and apply them to more complicated scenarios where allocation and deallocation might happen in different parts of the code.

In [Zig's HashMap - Part 2](https://www.openmymind.net/Zigs-HashMap-Part-2/) we saw a common example of more complicated memory management. It is up to us to decide and enforce the lifetime of a hashmap's keys and values. Even here simple cases can be complicated. If we want tie the lifetime of a value to the hashmap, we can store the value directly in the hashmap. But care must be taken since the address of these values can change as the hashmap changes (i.e. as the hashmap grows any references to its values will become invalid). This example, taken from that blog post, crashes since `first` becomes an invalid reference as `lookup` grows:

```zig
const std = @import("std");

pub fn main() !void {
  var gpa = std.heap.GeneralPurposeAllocator(.{}){};
  const allocator = gpa.allocator();

  var lookup = std.AutoHashMap(usize, usize).init(allocator);
  defer lookup.deinit();

  try lookup.put(100, 100);
  const first = lookup.getPtr(100).?;

  for (0..50) |i| {
    try lookup.put(i, i);
  }
  first.* = 200;
}
```

As systems grow more complex and data lives longer, managing memory tends to get more complicated. One case where this is particularly true is in multithreaded programming. Let's consider a simple cache; we begin with just two fields:

```zig
const Cache = struct {
  allocator: Allocator,
  lookup: std.StringHashMapUnmanaged([]const u8),

  pub fn init(allocator: Allocator) Cache {
    return .{
      .lookup = .{},
      .allocator = allocator,
    };
  }

  // TODO
}
```

A reasonable first attempt at creating a `put` method might go something like:

```zig
pub fn put (self: *Cache, key: []const u8, value: []const u8) !void {
  const allocator = self.allocator;
  const gop = try self.lookup.getOrPut(allocator, key);

  if (gop.found_existing) {
    // if we had an existing entry for this key, free it.
    allocator.free(gop.key_ptr.*);
    allocator.free(gop.value_ptr.*);
  }

  gop.key_ptr.* = try allocator.dupe(u8, key);
  gop.value_ptr.* = try allocator.dupe(u8, value);
}
```

If we were to implement `get` and `deinit`, we'd have a skeleton. Now, to make this thread-safe, we'd need to synchronize access to `lookup`, probably with a `std.Thread.Mutex` or `std.Thread.RwLock`. But there's another thread-safety issue in `put`, one specific to manual memory management that won't be fixed with just a mutex. Can you spot it?

Imagine that our cache is populated with data when two threads interact with it thusly: one calls `cache.get("goku")` while another calls `cache.put("goku", "9000!")`. A mutex would serialize access to `lookup`, but that wouldn't stop thread 2 from freeing the value now referenced by thread 1. This isn't strictly a multithreading problem. References to a value or a hashmap entry (or whatever), can always be referenced from multiple places. But in a single threaded context, there's almost always a clear lifetime and owner for data. More importantly, there's a simple execution model. Look at it this way: in a single threaded context, if we have:

```zig
if (cache.get("goku")) |power| {
  ...
}
```

We know that `cache` can't be mutated while we're in the `if` block (unless we explicit do something to mutate it). Because of this, `power` cannot be invalidated or leaked. But in a multithreaded context, while our `if` block might not mutate the cache, another thread could. The simple execution model is gone.

I've written at length about having a deep understanding of your data's lifetime and ownership. That leads to clear decisions about where data must be freed: _the memory must be freed when it's replaced or when we deinitialize the cache_. In a multithreaded context, in addition to that insight, we also need a more generic perspective: _the memory must be freed when the last reference is no longer needed_.

What does that mean in practice? First, we'll add a new type:

```zig
const Entry = struct {
  rc: usize,
  value: []const u8,
  allocator: Allocator,
}
```

Our `lookup` will now be an `std.StringHashMapUnmanaged(*Entry)`. The `rc` field is a reference counter. Whenever we get an entry, we'll increment `rc` by 1. Whenever we're done with an entry, we'll decrement `rc` by 1. When `rc` reaches 0, the entry can be freed. In other words, we don't track the lifetime of a value (i.e., until it's replaced or until the cache is deinitialized), but rather its usage. Let's implement that now:

```zig
const Entry = struct {
  rc: usize,
  value: []const u8,
  allocator: Allocator,

  pub fn acquire(self: *Entry) void {
    _ = @atomicRmw(usize, &self.rc, .Add, 1, .monotonic);
  }

  pub fn release(self: *Entry) void {
    if (@atomicRmw(usize, &self.rc, .Sub, 1, .monotonic) == 1) {
      const allocator = self.allocator;
      allocator.free(self.value);
      allocator.destroy(self);
    }
  }
};
```

`@atomicRmw` atomically modifies the value and returns the previous value. That's why we free our value and destroy the entry in `release` when it returns `1`: if the "previous value" was 1, then the current value (after we subtracted 1) is 0, meaning there are no more references to our entry.

Now our cache's `get` methods. We previously skipped this because, in our simple implementation, the read path didn't participate in memory management. This is no longer true:

```zig
pub fn get(self: *Cache, key: []const u8) ?*Entry {
  self.lock.lockShared();
  defer self.lock.unlockShared();

  var entry = self.lookup.get(key) orelse return null;
  entry.acquire();

  return entry;
}
```

Without telling you, we've added a `std.Thread.RwLock` to our cache which we see here for the first time. We also `acquire` the entry, increasing it's `rc` counter by 1. We return the full `*Entry` because the calling code is responsible for calling `release()`:

```zig
if (cache.get("goku")) |power| {
  defer power.release();
  ...
}
```

If you were trying to really optimize this code, you might be tempted to write `get` like so:

```zig
pub fn get(self: *Cache, key: []const u8) ?*Entry {
  self.lock.lockShared();
  const entry = self.lookup.get(key);
  self.lock.unlockShared();

  var e = entry orelse return null;
  e.acquire();
  return e;
}
```

Notice that we've narrowed our lock and no longer hold it over the call to `acquire`. This seems correct since `acquire` atomically increments `rc`, right?. But this version is wrong in the same way as or original naive implementation was. Consider `entry` just after the lock is released; `rc` hasn't been incremented yet. Or put differently, our reference hasn't been registered yet. This opens the small window where another thread could `release` its own reference to this entry, possibly causing the entry to clean itself up.

Finally, we have our enhanced `put`:

```zig
pub fn put(self: *Cache, key: []const u8, value: []const u8) !void {
  const allocator = self.allocator;

  // All of this can be done without having to lock!
  const entry = try allocator.create(Entry);
  errdefer allocator.destroy(entry);
  entry.* = .{
    .rc = 1,
    .allocator = allocator,
    .value = try allocator.dupe(u8, value),
  };
  errdefer entry.release();

  var existing: ?*Entry = null;

  {
    self.lock.lock();
    defer self.lock.unlock();
    const gop = try self.lookup.getOrPut(allocator, key);
    if (gop.found_existing) {
      // get a reference to the existing value, so that we can release our
      // reference to it
      existing = gop.value_ptr.*;
    } else {
      // This is a new entry, dupe the key. The cache itself owns this key now
      gop.key_ptr.* = try allocator.dupe(u8, key);
    }

    gop.value_ptr.* = entry;
  }

  // This can also be done without having to lock
  if (existing) |e| {
    e.release();
  }
}
```

There's a lot more going on here the before. First, when we create the entry, we set `rc` to 1. This is because the reference that our hashmap has to the entry is like any other. This is a bit more obvious when we consider the second point: to replace an entry, we don't free it, we `release()` it. Because the entry might still be referenced by another thread, all we can do is **un**register our interest. If we call `e.release()` and happen to be the last reference to the entry, then yes the entry will freed. This highlights why our hashmap stores a `*Entry` and why, in the above `put`, we store `entry` on the heap using `allocator.create`: the hashmap doesn't own or manage the entry. The `entry` isn't owned by anyone and can be shared and referenced by any thread or any part of the code. The reference count is needed, not because we care about how many references there are, but because we want to detect when there are no references.

Not related specifically to multithreaded, but we don't store a copy of the `key` with the `Entry`. This is an optimization, once we have an entry for a key, say "goku", there's really no need to re-dupe that key. This is because the key, unlike our value, is immutable. In this case, I'd say that the owner of the key is the cache itself. I chose this implementation because it's both more efficient and because it highlights how these different techniques end up living side by side and the impact that has on the complexity of the systems.

Another optimization I've made is to narrow the scope of our write lock. You might be surprised to see that `existing.release()` is not called under lock, despite making the case that `entry.acquire()` in `get` had to be. The entire point of this exercise is to make sure that `rc` doesn't become `0` while we still have live references. When we get a new reference we need to make sure no thread decrements `rc` before we can increment it. If it does, and if `rc` becomes 0, our reference will become invalid. Once we have our reference and incremented `rc` to represent our interest, assuming every `acquire()` is paired with a `release()`, `rc` can never reach 0 prematurely and our reference is always valid until we call `release()`. After `release()` is called, the reference should not be used. But the reality of our implementation means that it'll either be freed as part of the call to `release()` or at some indeterminate time in the future.

Reference counting isn't always something you'll need to rely on when sharing data across threads. Some workloads maintain clear ownership and lifetimes across threads. On the flip side, while we looked at referencing counting in the context of a cache, this is a pattern that can be used for other types of shared data. Further, while we looked at a thread-safe implementation of reference counting (known as ARC, Atomically Reference Counted), reference counting in a single thread context can be useful in some situations as well. In these cases we don't need our lock and can simply increment and decrement `rc` using `+=1` and `-=1`.

I wrote a thread-safe, expiration-aware, [LRU cache for Zig](https://github.com/karlseguin/cache.zig) and this is the solution I ended up adopting to deal with entries being removed or replaced while still being referenced from other threads. I've been meaning to blog about it for a while. More recently, I came across the problem again, in another piece of code. I figured if I keep running into this then others might too.
