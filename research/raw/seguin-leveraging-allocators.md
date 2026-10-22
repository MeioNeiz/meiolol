# Leveraging Zig's Allocators

<https://www.openmymind.net/Leveraging-Zigs-Allocators/>

[home](https://www.openmymind.net/)[dark](https://www.openmymind.net/Leveraging-Zigs-Allocators/#)

# Leveraging Zig's Allocators

Jun 05, 2024

Let's say we wanted to write [an HTTP server library for Zig](https://github.com/karlseguin/http.zig). At the core of this library, we might have a pool of threads to handle requests. Keeping things simple, it might look something like:

```zig
fn run(worker: *Worker) void {
  while (queue.pop()) |conn| {
    const action = worker.route(conn.req.url);
    action(conn.req, conn.res) catch { // TODO: 500 };
    worker.write(conn.res);
  }
}
```

As a user of this library, a sample action might be:

```zig
fn greet(req: *http.Request, res: *http.Response) void {
  res.status = 200;
  res.body = "hello!;
}
```

This is promising, but we can probably expect that users of our library will want to write more dynamic content. If we assume that our server is given an allocator on startup, we could pass this allocator into the actions:

```zig
fn run(worker: *Worker) void {
  // added
  const allocator = worker.server.allocator;

  while (queue.pop()) |conn| {
    const action = worker.route(conn.req.url);

    // we now pass allocator into action
    action(allocator, conn.req, conn.res) catch { // TODO: 500 };

    worker.write(conn.res);
  }
}
```

Which would allow users to write actions like:

```zig
fn greet(allocator: Allocator, req: *http.Request, res: *http.Response) !void {
  const name = req.query("name") orelse "guest";

  res.status = 200;
  res.body = try std.fmt.allocPrint(allocator, "Hello {s}", .{name});
}
```

While this is a step in the right direction, there's an obvious issue: the allocated greeting is never freed. Our `run` function can't just call `allocator.free(conn.res.body)` after writing the response because, in some cases, the body might not need to be freed. We could structure our API so that the action has to `write()` the response and thus be able to `free` any allocations it made, but that would make it impossible to add some features, like supporting middleware.

The best and simplest solution is to use an `ArenaAllocator`. The way it works is simple: when we `deinit` the arena all of its allocations are freed.

```zig
fn run(worker: *Worker) void {
  const allocator = worker.server.allocator;

  while (queue.pop()) |conn| {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const action = worker.route(conn.req.url);
    action(arena.allocator(), conn.req, conn.res) catch { // TODO: 500 };
    worker.write(conn.res);
  }
}
```

Because `std.mem.Allocator` is an "[interface](https://www.openmymind.net/Zig-Interfaces/)", our action doesn't need to change. An `ArenaAllocator` is a great option for an HTTP server because they're bound to a request, which has a well defined/understood lifetime and is relatively short lived. And while it's possible to abuse them, it's probably safe to say: use them more!

We can take this a bit further and re-use the same arena. That might not seem too useful, but take a look at this:

```zig
fn run(worker: *Worker) void {
  const allocator = worker.server.allocator;

  var arena = std.heap.ArenaAllocator.init(allocator);
  defer arena.deinit();

  while (queue.pop()) |conn| {
    // Here be magic!
    defer _ = arena.reset(.{.retain_with_limit = 8192});

    const action = worker.route(conn.req.url);
    action(arena.allocator(), conn.req, conn.res) catch { // TODO: 500 };
    worker.write(conn.res);
  }
}
```

We've moved our arena outside the loop but the important part is inside: after each request, we reset the arena and retain up to 8K of memory. That means that, for many requests, we'll never have to go to our underling allocator (`worker.server.allocator`) to get more memory. This can significantly improve performance.

Now imagine a sad world where we couldn't reset our arena with `retain_with_limit`. Could we still apply the same optimization? Yes, by creating our own allocator which first attempts to use a `FixedBufferAllocator` and then falling back to our arena.

Zig has `std.heap.StackFallbackAllocator`, but this requires a comptime-known length (since its on the stack), which is a big limitations. It could have been used in this specific example, but in my actual HTTP server, the size is configurable and thus not comptime known.

Here's our full `FallBackAllocator`:

```zig
const FallbackAllocator = struct {
  primary: Allocator,
  fallback: Allocator,
  fba: *std.heap.FixedBufferAllocator,

  pub fn allocator(self: *FallbackAllocator) Allocator {
    return .{
      .ptr = self,
      .vtable = &.{.alloc = alloc, .resize = resize, .free = free},
    };
  }

  fn alloc(ctx: *anyopaque, len: usize, ptr_align: u8, ra: usize) ?[*]u8 {
    const self: *FallbackAllocator = @ptrCast(@alignCast(ctx));
    return self.primary.rawAlloc(len, ptr_align, ra)
           orelse self.fallback.rawAlloc(len, ptr_align, ra);
  }

  fn resize(ctx: *anyopaque, buf: []u8, buf_align: u8, new_len: usize, ra: usize) bool {
    const self: *FallbackAllocator = @ptrCast(@alignCast(ctx));
    if (self.fba.ownsPtr(buf.ptr)) {
      if (self.primary.rawResize(buf, buf_align, new_len, ra)) {
        return true;
      }
    }
    return self.fallback.rawResize(buf, buf_align, new_len, ra);
  }

  fn free(_: *anyopaque, _: []u8, _: u8, _: usize) void {
    // we noop this since, in our specific case, we know
    // the fallback is an arena, which won't free individual items
  }
};
```

If the `*anyopaque`, `ptrCast` and `@alignCast` are confusing, checkout my post on [exploring Zig interfaces](https://www.openmymind.net/Zig-Interfaces/).

Our `alloc` implementation first tries to allocate using our "primary" allocator. If that fails, we use our "fallback" allocator. `resize`, which we have to implement as part of the `std.mem.Allocator` interface, determines which allocator owns the memory we're trying to resize and then calls its `rawResize`. To keep this somewhat simple, I left out the implementation of `free` - which is OK in this specific case since "primary" is going to be a `FixedBufferAllocator` and "fallback" is going to be an `ArenaAllocator` (thus, all the freeing happens when the arena's `deinit` or `reset` are called).

Now we need to change our `run` method to take advantage of this new allocator:

```zig
fn run(worker: *Worker) void {
  const allocator = worker.server.allocator;

  // this is the underlying memory for our FixedBufferAllocator
  const buf = try allocator.alloc(u8, 8192);
  defer allocator.free(buf);

  var fba = std.heap.FixedBufferAllocator.init(buf);

  while (queue.pop()) |conn| {
    defer fba.reset();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var fallback = FallbackAllocator{
      .fba = &fba,
      .primary = fba.allocator(),
      .fallback = arena.allocator(),
    };

    const action = worker.route(conn.req.url);
    action(fallback.allocator(), conn.req, conn.res) catch { // TODO: 500 };
    worker.write(conn.res);
  }
}
```

This achieves something similar to resetting our arena with a `retain_with_limit`. We create a `FixedBufferAllocator` which can be reused for each request. This represents the 8K of memory we were previously retaining. Because an action might need more memory, we still need our `ArenaAllocator`. By wrapping our `FixedBufferAllocator` and our `ArenaAllocator` in our `FallbackAllocator` we ensure that any allocations will first try to use the (very fast) `FixedBufferAllocator` and when that's full, use the `ArenaAllocator`.

Because we're exposing an `std.mem.Allocator`, we're able to make these changes, tweaking how we want our allocator to work, without breaking `greet`.

Hopefully this example highlights what I consider two real benefits to explicit allocators: simplifying resource management (via something like an `ArenaAllocator`) and improved performance by re-using allocations (like we did with `retain_with_limit` or with our`FixedBufferAllocator`).
