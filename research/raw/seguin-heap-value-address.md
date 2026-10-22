# Zig: Use The Heap to Know A Value's Address

<https://www.openmymind.net/Zig-Use-The-Heap-To-Know-A-Values-Address/>

[home](https://www.openmymind.net/)[dark](https://www.openmymind.net/Zig-Use-The-Heap-To-Know-A-Values-Address/#)

# Zig: Use The Heap to Know A Value's Address

Mar 15, 2024

You'll often find yourself wanting to know the address of a newly created value which gets returned from a function. This can happen for a number of reasons, but the most common is creating bidirectional references. For example, if we create a pool of objects, we often want those objects to reference the pool. You might end up with something like:

```zig
fn init(allocator: Allocator, count: usize) !Pool {
  var conns = try allocator.alloc(count, Conn);
  errdefer allocator.free(conns);

  var pool = Pool{
    .conns = conns;
  }

  for (0..count) |i| {
    // This won't work
    conns[i] = Conn.open(&pool);
  }

  return pool;
}

fn deinit(self: *const Pool, allocator: Allocator) void {
  allocator.free(self.conns);
}
```

The above skeleton is almost certainly not what you want and would segfault if used as part of a larger program. When we call `Call.open(&pool)`, we're passing the address of the `pool` value on the stack. When we return `pool`, we're returning a copy. Thus, whoever called `init` gets a copy which will have its own address.

Taking the address of a stack variable and using it beyond the lifetime of the stack is a common error. This error manifests itself in different scenarios but when the problem you're trying to solve is _I need to know the address of X (`pool` in the above case)_, you have two options.

The first is to make this the callers problem. Our `init` would be changed to take a `*Pool`:

```zig
fn init(allocator: Allocator, count: usize, pool: *Pool) !void {
  var conns = try allocator.alloc(count, Conn);
  errdefer allocator.free(conns);

  for (0..count) |i| {
    conns[i] = Conn.open(pool);
  }

  pool.conns = conns;
}
```

You see this pattern a lot in C libraries and you'll see it now and again in Zig code too.

Your other, probably more common, option is to put `pool` on the heap:

```zig
fn init(allocator: Allocator, count: usize) !*Pool {
  const pool = try allocator.create(Pool);
  errdefer allocator.destroy(pool);

  var conns = try allocator.alloc(count, Conn);
  errdefer allocator.free(conns);

  pool.* = .{
    .conns = conns,
  };

  for (0..count) |i| {
    conns[i] = Conn.open(pool);
  }

  return pool;
}

fn deinit(self: *Pool, allocator: Allocator) void {
  allocator.free(self.conns);
  // cannot use self after this!
  allocator.destroy(self);
}
```

Notice that our function returns a `*Pool` instead of `Pool`. Also notice that to create our array of `conns`, we're using `allocator.alloc`, but to create `pool`, we're using `allocator.create`. And, related, to free `conns` we're using `allocator.free`, but to free `pool`, we're using `allocator.destroy`. This tripped me up when I started to learn Zig, but you get used to it. `alloc/free` is to create and free an array of items, whereas `create/destroy` is to create and free a single item.

Generally speaking, it's obvious whether a value can stay on the stack or has to be pushed onto the heap. The point of this post is to say: it's ok to create a value on the heap. You will find yourself in situations where you need to know the address of a value but don't know its final resting place (because you're returning the value to the caller and that, as far as your function is concerned, is its "owner"). When that happens, a reasonable (and in many cases only) option is to make the "final resting place", the heap. Just make sure to `destroy` the created item when its no longer needed.
