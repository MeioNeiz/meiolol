# Zig's New Async I/O (Text Version) - Andrew Kelley

<https://andrewkelley.me/post/zig-new-async-io-text-version.html>

[Andrew Kelley](https://andrewkelley.me/) - Zig's New Async I/O (Text Version) (2025 Oct 29)

* * *

# Zig's New Async I/O (Text Version)

In celebration of the [std.Io introduction patchset landing today](https://github.com/ziglang/zig/pull/25592), here is the text version of [a short, interactive demo I gave](https://www.youtube.com/watch?v=mdOxIc0HM04) at [Zigtoberfest 2025](https://zigtoberfest.de/).

This is a preview of the new async I/O primitives that will be available in the upcoming Zig 0.16.0, to be released in about 3-4 months. There is a lot more to get into, but for now here is an introduction into some of the core synchronization API that will be available for all Zig code to use.

To begin, let's try to keep it simple and understand the basics, and then we'll then slowly add more asynchronous things into it.

## Example 0

With our first example, there is nothing asynchronous here. It's basically "Hello, World!" in Zig.

```zig
const std = @import("std");

pub fn main() !void {
    doWork();
}

fn doWork() void {
    std.debug.print("working\n", .{});
    var timespec: std.posix.timespec = .{ .sec = 1, .nsec = 0 };
    _ = std.posix.system.nanosleep(&timespec, &timespec);
}
```

Output:

0s $ zig run example0.zig
0s working
1s $

## Example 1

Next, we're going to set up a little bit. Still not using async/await yet, but I need some tools in my toolbox before we add complexity.

```zig
const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

fn juicyMain(gpa: Allocator, io: Io) !void {
    _ = gpa;

    doWork(io);
}

fn doWork(io: Io) void {
    std.debug.print("working\n", .{});
    io.sleep(.fromSeconds(1), .awake) catch {};
}

pub fn main() !void {
    // Set up allocator.
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer assert(debug_allocator.deinit() == .ok);
    const gpa = debug_allocator.allocator();

    // Set up our I/O implementation.
    var threaded: std.Io.Threaded = .init(gpa);
    defer threaded.deinit();
    const io = threaded.io();

    return juicyMain(gpa, io);
}
```

Output (same as before):

0s $ zig run example0.zig
0s working
1s $

Setting up a `std.Io` implementation is a lot like setting up an allocator. You typically do it once, in main(), and then pass the instance throughout the application. Reusable code should accept an Allocator parameter if it needs to allocate, and it should accept an Io parameter if it needs to perform I/O operations.

In this case, this is an Io implementation based on threads. This is not using KQueue, this is not using IO\_Uring, this is not using an event loop. It is a _threaded_ implementation of the new `std.Io` interface.

This setup will be the same in all the examples, so now we can focus on our example code, which is the same as last time. Still nothing interesting - we just call `doWork` which of course is just calling sleep().

## Example 2

Redundant setup code omitted from here on out.

```zig
fn juicyMain(gpa: Allocator, io: Io) !void {
    _ = gpa;

    var future = io.async(doWork, .{io});

    future.await(io); // idempotent
}

fn doWork(io: Io) void {
    std.debug.print("working\n", .{});
    io.sleep(.fromSeconds(1), .awake) catch {};
}
```

Output (same as before):

0s $ zig run example0.zig
0s working
1s $

Now we're using async/await to call doWork. What async/await means to Zig is to _decouple_ the **calling** of the function to the **returning** of the function.

This code is the same as before. It's exactly the same, because we didn't put any code between the async and await. We do the call, and then immediately wait for the return.

## Example 3

In the next example, we have two things at the same time:

```zig
fn juicyMain(gpa: Allocator, io: Io) !void {
    _ = gpa;

    var a = io.async(doWork, .{ io, "hard" });
    var b = io.async(doWork, .{ io, "on an excuse not to drink Spezi" });

    a.await(io);
    b.await(io);
}

fn doWork(io: Io, flavor_text: []const u8) void {
    std.debug.print("working {s}\n", .{flavor_text});
    io.sleep(.fromSeconds(1), .awake) catch {};
}
```

Output:

0s $ zig run example3.zig
0s working on an excuse not to drink Spezi
0s working hard
1s $

If you look carefully, you can see that it did not wait two seconds; it waited one second because these operations are happening at the same time. This demonstrates why using async/await is useful - you can express asynchrony. Depending on the I/O implementation that you choose, it may be able to take advantage of the asynchrony that you have expressed and make your code go faster. For example in this case, `std.Io.Threaded` was able to do two seconds of work in one second of actual time.

## Example 4

Let's start to bring the example closer to a real world scenario by introducing **failure**.

```zig
fn juicyMain(gpa: Allocator, io: Io) !void {
    var a = io.async(doWork, .{ gpa, io, "hard" });
    var b = io.async(doWork, .{ gpa, io, "on an excuse not to drink Spezi" });

    try a.await(io);
    try b.await(io);
}

fn doWork(gpa: Allocator, io: Io, flavor_text: []const u8) !void {
    // Simulate an error occurring:
    if (flavor_text[0] == 'h') return error.OutOfMemory;

    const copied_string = try gpa.dupe(u8, flavor_text);
    defer gpa.free(copied_string);
    std.debug.print("working {s}\n", .{copied_string});
    io.sleep(.fromSeconds(1), .awake) catch {};
}
```

It's the same code as before, except the first task will return an error.

Guess what happens when this code is run?

Output:

0s $ zig run example4.zig
0s working on an excuse not to drink Spezi
1s error(gpa): memory address 0x7f99ce6c0080 leaked:
1s /home/andy/src/zig/lib/std/Io/Threaded.zig:466:67: 0x1053aae in async (std.zig)
1s     const ac: \*AsyncClosure = @ptrCast(@alignCast(gpa.alignedAlloc(u8, .of(AsyncClosure), n) catch {
1s                                                                   ^
1s /home/andy/src/zig/lib/std/Io.zig:1548:40: 0x1164f94 in async\_\_anon\_27344 (std.zig)
1s     future.any\_future = io.vtable.async(
1s                                        ^
1s /home/andy/misc/talks/zigtoberfest/async-io-examples/example4.zig:8:21: 0x116338a in juicyMain (example4.zig)
1s     var b = io.async(doWork, .{ gpa, io, "on an excuse not to drink Spezi" });
1s                     ^
1s /home/andy/misc/talks/zigtoberfest/async-io-examples/example4.zig:35:21: 0x1163663 in main (example4.zig)
1s     return juicyMain(gpa, io);
1s                     ^
1s /home/andy/src/zig/lib/std/start.zig:696:37: 0x1163c83 in callMain (std.zig)
1s             const result = root.main() catch |err| {
1s                                     ^
1s /home/andy/src/zig/lib/std/start.zig:237:5: 0x1162f61 in \_start (std.zig)
1s     asm volatile (switch (native\_arch) {
1s     ^
1s 
1s thread 1327233 panic: reached unreachable code
1s error return context:
1s /home/andy/src/zig/lib/std/Io.zig:1003:13: 0x11651a8 in await (std.zig)
1s             return f.result;
1s             ^
1s /home/andy/misc/talks/zigtoberfest/async-io-examples/example4.zig:10:5: 0x11633e8 in juicyMain (example4.zig)
1s     try a.await(io);
1s     ^
1s 
1s stack trace:
1s /home/andy/src/zig/lib/std/debug.zig:409:14: 0x103e5a9 in assert (std.zig)
1s     if (!ok) unreachable; // assertion failure
1s              ^
1s /home/andy/misc/talks/zigtoberfest/async-io-examples/example4.zig:27:17: 0x1163698 in main (example4.zig)
1s     defer assert(debug\_allocator.deinit() == .ok);
1s                 ^
1s /home/andy/src/zig/lib/std/start.zig:696:37: 0x1163c83 in callMain (std.zig)
1s             const result = root.main() catch |err| {
1s                                     ^
1s /home/andy/src/zig/lib/std/start.zig:237:5: 0x1162f61 in \_start (std.zig)
1s     asm volatile (switch (native\_arch) {
1s     ^
1s fish: Job 1, 'zig run example4.zig' terminated by signal SIGABRT (Abort)
1s $

The problem is that when the first `try` activates, it skips the second `await` which is then caught by the leak checker.

This is a bug. It's unfortunate though, isn't it? Because we would like to write the code this way.

## Example 5

Here's a fix:

```zig
fn juicyMain(gpa: Allocator, io: Io) !void {
    var a = io.async(doWork, .{ gpa, io, "hard" });
    var b = io.async(doWork, .{ gpa, io, "on an excuse not to drink Spezi" });

    const a_result = a.await(io);
    const b_result = b.await(io);

    try a_result;
    try b_result;
}

fn doWork(gpa: Allocator, io: Io, flavor_text: []const u8) !void {
    // Simulate an error occurring:
    if (flavor_text[0] == 'h') return error.OutOfMemory;

    const copied_string = try gpa.dupe(u8, flavor_text);
    defer gpa.free(copied_string);
    std.debug.print("working {s}\n", .{copied_string});
    io.sleep(.fromSeconds(1), .awake) catch {};
}
```

We do the awaits, then we do the tries. This will fix the problem.

Output:

0s $ zig run example5.zig
0s working on an excuse not to drink Spezi
1s error: OutOfMemory
1s /home/andy/src/zig/lib/std/Io.zig:1003:13: 0x11651d8 in await (std.zig)
1s             return f.result;
1s             ^
1s /home/andy/misc/talks/zigtoberfest/async-io-examples/example5.zig:13:5: 0x1163416 in juicyMain (example5.zig)
1s     try a\_result;
1s     ^
1s /home/andy/misc/talks/zigtoberfest/async-io-examples/example5.zig:38:5: 0x11636e9 in main (example5.zig)
1s     return juicyMain(gpa, io);
1s     ^
1s $

This failed successfully. The error was handled and no resources leaked. But it's a footgun. Let's find a better way to express this...

## Example 6

This is where **cancellation** comes in. cancellation is an extremely handy primitive, because now we can use `defer`, `try`, and `await` like normal, and not only do we fix the bug, but we also get more optimal code.

```zig
fn juicyMain(gpa: Allocator, io: Io) !void {
    var a = io.async(doWork, .{ gpa, io, "hard" });
    defer a.cancel(io) catch {};

    var b = io.async(doWork, .{ gpa, io, "on an excuse not to drink Spezi" });
    defer b.cancel(io) catch {};

    try a.await(io);
    try b.await(io);
}

fn doWork(gpa: Allocator, io: Io, flavor_text: []const u8) !void {
    // Simulate an error occurring:
    if (flavor_text[0] == 'h') return error.OutOfMemory;

    const copied_string = try gpa.dupe(u8, flavor_text);
    defer gpa.free(copied_string);
    std.debug.print("working {s}\n", .{copied_string});
    io.sleep(.fromSeconds(1), .awake) catch {};
}
```

Thanks to cancellation, we now get instant results, because the moment that the first task returns an error, the cancels get run.

Output:

0s $ zig run example6.zig
0s working on an excuse not to drink Spezi
0s error: OutOfMemory
0s /home/andy/misc/talks/zigtoberfest/async-io-examples/example6.zig:13:5: 0x116348c in juicyMain (example6.zig)
0s     try a.await(io);
0s     ^
0s /home/andy/misc/talks/zigtoberfest/async-io-examples/example6.zig:38:5: 0x1163909 in main (example6.zig)
0s     return juicyMain(gpa, io);
0s     ^
0s $

`cancel` is your best friend, because it's going to prevent you from leaking the resource, and it's going to make your code run more optimally.

`cancel` is trivial to understand: it has identical semantics as `await`, except that it _also requests cancellation_. The conditions under which cancellation requests are honored are defined by each I/O implementation.

Both `cancel` and `await` are idempotent with respect to themselves and each other.

## Example 7

Next, let's introduce another real-world scenario: **resource allocation**. In this case, we allocate a string on success, which the caller needs to manage.

```zig
fn juicyMain(gpa: Allocator, io: Io) !void {
    var a = io.async(doWork, .{ gpa, io, "hard" });
    defer if (a.cancel(io)) |s| gpa.free(s) else |_| {};

    var b = io.async(doWork, .{ gpa, io, "on an excuse not to drink Spezi" });
    defer if (b.cancel(io)) |s| gpa.free(s) else |_| {};

    const a_string = try a.await(io);
    const b_string = try b.await(io);
    std.debug.print("finished {s}\n", .{a_string});
    std.debug.print("finished {s}\n", .{b_string});
}

fn doWork(gpa: Allocator, io: Io, flavor_text: []const u8) ![]u8 {
    const copied_string = try gpa.dupe(u8, flavor_text);
    std.debug.print("working {s}\n", .{copied_string});
    io.sleep(.fromSeconds(1), .awake) catch {};
    return copied_string;
}
```

Now we see why `cancel` and `await` have the same API. The deferred cancel calls above free the allocated resource, handling both successful calls (resource allocated) and failed calls (resource not allocated).

Output:

0s $ zig run example7.zig
0s working on an excuse not to drink Spezi
0s working hard
1s finished hard
1s finished on an excuse not to drink Spezi
1s $

The important thing here is that by doing resource management like this, we are able to write standard, idiomatic Zig code below, using `try` and `return` like normal without worrying about special resource management cases.

## Example 8

Now we're switching gears a little bit. It's time to learn why [asynchrony is not concurrency](https://kristoff.it/blog/asynchrony-is-not-concurrency/).

In this example we have a producer sending one item across an unbuffered queue to a consumer.

```zig
fn juicyMain(io: Io) !void {
    var queue: Io.Queue([]const u8) = .init(&.{});

    var producer_task = io.async(producer, .{
        io, &queue, "never gonna give you up",
    });
    defer producer_task.cancel(io) catch {};

    var consumer_task = io.async(consumer, .{ io, &queue });
    defer _ = consumer_task.cancel(io) catch {};

    const result = try consumer_task.await(io);
    std.debug.print("message received: {s}\n", .{result});
}

fn producer(
    io: Io,
    queue: *Io.Queue([]const u8),
    flavor_text: []const u8,
) !void {
    try queue.putOne(io, flavor_text);
}

fn consumer(
    io: Io,
    queue: *Io.Queue([]const u8),
) ![]const u8 {
    return queue.getOne(io);
}
```

We use `async` to spawn the producer and `async` to spawn the consumer.

Output:

0s $ zig run example8.zig
0s message received: never gonna give you up
0s $

This incorrectly succeeds. Depending on your perspective, we either got "lucky" or "unlucky" due to the thread pool having spare concurrency that happened to be available.

To observe the problem, we can artificially limit the `std.Io.Threaded` instance to use a thread pool size of one:

## Example 9

```zig
// Set up our I/O implementation.
    var threaded: std.Io.Threaded = .init(gpa);
    threaded.cpu_count = 1;
    defer threaded.deinit();
    const io = threaded.io();

    return juicyMain(io);
}
```

Output: (deadlock)

Now that it's only using one thread, it deadlocks, because the consumer is waiting to get something from the queue, and the producer is scheduled to run, but it has not run yet.

The problem is that _we needed concurrency, but we asked for asynchrony_.

## Example 10

In order to fix this, we use `io.concurrent` instead of `io.async`. This one can fail with `error.ConcurrencyUnavailable`.

```zig
fn juicyMain(io: Io) !void {
    var queue: Io.Queue([]const u8) = .init(&.{});

    var producer_task = try io.concurrent(producer, .{
        io, &queue, "never gonna give you up",
    });
    defer producer_task.cancel(io) catch {};

    var consumer_task = try io.concurrent(consumer, .{ io, &queue });
    defer _ = consumer_task.cancel(io) catch {};

    const result = try consumer_task.await(io);
    std.debug.print("message received: {s}\n", .{result});
}

fn producer(
    io: Io,
    queue: *Io.Queue([]const u8),
    flavor_text: []const u8,
) !void {
    try queue.putOne(io, flavor_text);
}

fn consumer(
    io: Io,
    queue: *Io.Queue([]const u8),
) ![]const u8 {
    return queue.getOne(io);
}
```

Output:

0s $ zig run example10.zig
0s message received: never gonna give you up
0s $

Now the code is fixed because we correctly expressed that we needed concurrency, which `std.Io.Threaded` honored by oversubscribing.

If I add `-fsingle-threaded` which truly limits the executable to one thread, oversubscription is not available, causing this output:

error: ConcurrencyUnavailable
/home/andy/src/zig/lib/std/Io/Threaded.zig:529:34: 0x1051863 in concurrent (std.zig)
    if (builtin.single\_threaded) return error.ConcurrencyUnavailable;
                                 ^
/home/andy/src/zig/lib/std/Io.zig:1587:25: 0x1158b5f in concurrent\_\_anon\_26591 (std.zig)
    future.any\_future = try io.vtable.concurrent(
                        ^
/home/andy/misc/talks/zigtoberfest/async-io-examples/example10.zig:9:25: 0x1157198 in juicyMain (example10.zig)
    var producer\_task = try io.concurrent(producer, .{
                        ^
/home/andy/misc/talks/zigtoberfest/async-io-examples/example10.zig:48:5: 0x115776a in main (example10.zig)
    return juicyMain(io);
    ^

## Conclusion

There are proof-of-concept `std.Io` implementations using IoUring and KQueue combined with stackful coroutines which show a lot of promise, however that work depends on some language enhancements to be practical. There is also ongoing design work about stackless coroutines. Here are some relevant issues to track for those interested:

-   [Restricted Function Types](https://github.com/ziglang/zig/issues/23367)
-   [Builtin function to tell you the maximum stack size of a given function](https://github.com/ziglang/zig/issues/157)
-   [Eliminate Stack Overflow](https://github.com/ziglang/zig/issues/1639)
-   [Stackless Coroutines](https://github.com/ziglang/zig/issues/23446)
-   [Juicy Main](https://github.com/ziglang/zig/issues/24510)

These APIs are not set in stone. It will probably take a few iterations to get it right. Please try them out in _real world applications_ and let us know how it goes! Let's collaborate on making the I/O interface practical and optimal.

* * *

Thanks for reading my blog post.

[Home Page](https://andrewkelley.me/) | [RSS feed](https://andrewkelley.me/rss.xml) | [Sponsor the Zig Software Foundation](https://ziglang.org/zsf)
