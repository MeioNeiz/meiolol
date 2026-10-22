# A Programmer-Friendly I/O Abstraction Over io_uring and kqueue

<https://tigerbeetle.com/blog/2022-11-23-a-friendly-abstraction-over-iouring-and-kqueue/>

[Docs](https://docs.tigerbeetle.com/) [Pricing](https://tigerbeetle.com/cloud#pricing) [Blog](https://tigerbeetle.com/blog) [Company](https://tigerbeetle.com/company) [Stories](https://tigerbeetle.com/stories) [ 14.8K ](https://www.youtube.com/@tigerbeetledb)[ 17.2K](https://github.com/tigerbeetle/tigerbeetle)

[Cloud](https://tigerbeetle.com/cloud)

# A Programmer-Friendly I/O Abstraction Over io\_uring and kqueue

Nov 23, 2022

-   [
    
    King Butcher
    
    ](https://x.com/kingprotty)
-   [
    
    Phil Eaton
    
    ](https://x.com/eatonphil)

Consider this tale of I/O and performance. We’ll start with blocking I/O, explore io\_uring and kqueue, and take home an event loop very similar to some software you may find familiar.

This is a twist on King’s talk at [Software You Can Love Milan ’22](https://www.youtube.com/watch?v=Ul8OO4vQMTw).

## [Classical approach](https://tigerbeetle.com/blog/2022-11-23-a-friendly-abstraction-over-iouring-and-kqueue/#classical-approach)

When you want to read from a file you might `open()` and then call `read()` as many times as necessary to fill a buffer of bytes from the file. And in the opposite direction, you call `write()` as many times as needed until everything is written. It’s similar for a TCP client with sockets, but instead of `open()` you first call `socket()` and then `connect()` to your server. Fun stuff.

In the real world though you can’t always read everything you want immediately from a file descriptor. Nor can you always write everything you want immediately to a file descriptor.

You can [switch a file descriptor into non-blocking mode](https://stackoverflow.com/questions/12773509/read-is-not-blocking-in-socket-programming/12775464#12775464) so the call won’t block while data you requested is not available. But system calls are still expensive, incurring context switches and cache misses. In fact, networks and disks have become so fast that these costs can start to approach the cost of doing the I/O itself. For the duration of time a file descriptor is unable to read or write, you don’t want to waste time continuously retrying read or write system calls.

## [Batching and readiness](https://tigerbeetle.com/blog/2022-11-23-a-friendly-abstraction-over-iouring-and-kqueue/#batching-and-readiness)

So you switch to io\_uring on Linux or kqueue on FreeBSD/macOS. (I’m skipping the generation of epoll/select users.) These APIs let you submit requests to the kernel to learn about readiness: when a file descriptor is ready to read or write. You can send readiness requests in batches (also referred to as queues). Completion events, one for each submitted request, are available in a separate queue.

Being able to batch I/O like this is especially important for TCP servers that want to multiplex reads and writes for multiple connected clients.

However in io\_uring, you can even go one step further. Instead of having to call `read()` or `write()` in userland after a readiness event, you can request that the kernel do the `read()` or `write()` itself with a buffer you provide. Thus almost all of your I/O is done in the kernel, amortizing the overhead of system calls.

If you haven’t seen io\_uring or kqueue before, you’d probably like an example! Consider this code: a simple, minimal, not-production-ready TCP echo server.

```
const std = @import("std");
const os = std.os;
const linux = os.linux;
const allocator = std.heap.page_allocator;

const State = enum{ accept, recv, send };
const Socket = struct {
    handle: os.socket_t,
    buffer: [1024]u8,
    state: State,
};

pub fn main() !void {
    const entries = 32;
    const flags = 0;
    var ring = try linux.IO_Uring.init(entries, flags);
    defer ring.deinit();

    var server: Socket = undefined;
    server.handle = try os.socket(os.AF.INET, os.SOCK.STREAM, os.IPPROTO.TCP);
    defer os.closeSocket(server.handle);

    const port = 12345;
    var addr = std.net.Address.initIp4(.{127, 0, 0, 1}, port);
    var addr_len: os.socklen_t = addr.getOsSockLen();

    try os.setsockopt(server.handle, os.SOL.SOCKET, os.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    try os.bind(server.handle, &addr.any, addr_len);
    const backlog = 128;
    try os.listen(server.handle, backlog);

    server.state = .accept;
    _ = try ring.accept(@ptrToInt(&server), server.handle, &addr.any, &addr_len, 0);

    while (true) {
        _ = try ring.submit_and_wait(1);

        while (ring.cq_ready() > 0) {
            const cqe = try ring.copy_cqe();
            var client = @intToPtr(*Socket, @intCast(usize, cqe.user_data));

            if (cqe.res < 0) std.debug.panic("{}({}): {}", .{
                client.state,
                client.handle,
                @intToEnum(os.E, -cqe.res),
            });

            switch (client.state) {
                .accept => {
                    client = try allocator.create(Socket);
                    client.handle = @intCast(os.socket_t, cqe.res);
                    client.state = .recv;
                    _ = try ring.recv(@ptrToInt(client), client.handle, .{.buffer = &client.buffer}, 0);
                    _ = try ring.accept(@ptrToInt(&server), server.handle, &addr.any, &addr_len, 0);
                },
                .recv => {
                    const read = @intCast(usize, cqe.res);
                    client.state = .send;
                    _ = try ring.send(@ptrToInt(client), client.handle, client.buffer[0..read], 0);
                },
                .send => {
                    os.closeSocket(client.handle);
                    allocator.destroy(client);
                },
            }
        }
    }
}
```

This is a great, minimal example. But notice that this code ties io\_uring behavior directly to business logic (in this case, handling echoing data between request and response). It is fine for a small example like this. But in a large application you might want to do I/O throughout the code base, not just in one place. You might not want to keep adding business logic to this single loop.

## [Central I/O dispatch](https://tigerbeetle.com/blog/2022-11-23-a-friendly-abstraction-over-iouring-and-kqueue/#central-io-dispatch)

Instead, you might want to be able to schedule I/O and pass a callback (and sometimes with some application context) to be called when the event is complete.

The interface might look like:

```
io_dispatch.dispatch({
    // some big struct/union with relevant fields for all event types
}, my_callback);
```

This is great! Now your business logic can schedule and handle I/O no matter where in the code base it is.

Under the hood it can decide whether to use io\_uring or kqueue depending on what kernel it’s running on. The dispatch can also batch these individual calls through io\_uring or kqueue to amortize system calls. The application no longer needs to know the details.

Additionally, we can use this wrapper to stop thinking about readiness events, just I/O completion. That is, if we dispatch a read event, the io\_uring implementation would actually ask the kernel to read data into a buffer. Whereas the kqueue implementation would send a “read” readiness event, do the read back in userland, and then call our callback.

And finally, now that we’ve got this central dispatcher, we don’t need spaghetti code in a loop switching on every possible submission and completion event.

## [Interacting with the submission and completion queue](https://tigerbeetle.com/blog/2022-11-23-a-friendly-abstraction-over-iouring-and-kqueue/#interacting-with-the-submission-and-completion-queue)

Every time we call io\_uring or kqueue we both submit event requests and poll for completion events. The io\_uring and kqueue APIs tie these two actions together in the same system call.

To sync our requests to io\_uring or kqueue we’ll build a `flush` function that submits requests and polls for completion events. (In the next section we’ll talk about how the user of the central dispatch learns about completion events.)

To make `flush` more convenient, we’ll build a nice wrapper around it so that we can submit as many requests (and process as many completion events) as possible. To avoid accidentally blocking indefinitely we’ll also introduce a time limit. We’ll call the wrapper `run_for_ns`.

Finally we’ll put the user in charge of setting up a loop to call this `run_for_ns` function, independent of normal program execution.

This is now your traditional event loop.

## [Callbacks and context](https://tigerbeetle.com/blog/2022-11-23-a-friendly-abstraction-over-iouring-and-kqueue/#callbacks-and-context)

You may have noticed that in the API above we passed a callback. The idea is that after the requested I/O has completed, our callback should be invoked. But the question remains: how to track this callback between the submission and completion queue?

Thankfully, io\_uring and kqueue events have user data fields. The user data field is opaque to the kernel. When a submitted event completes, the kernel sends a completion event back to userland containing the user data value from the submission event.

We can store the callback in the user data field by setting it to the callback’s pointer casted to an integer. When the completion for a requested event comes up, we cast from the integer in the user data field back to the callback pointer. Then, we invoke the callback.

## [Getting more expressive](https://tigerbeetle.com/blog/2022-11-23-a-friendly-abstraction-over-iouring-and-kqueue/#getting-more-expressive)

As described above, the struct for `io_dispatch.dispatch` could get quite large handling all the different kinds of I/O events and their arguments. We could make our API a little more expressive by creating wrapper functions for each event type.

So if we wanted to schedule a read function we could call:

```
io_dispatch.read(fd, &buf, nBytesToRead, callback);
```

Or to write, similarly:

```
io_dispatch.write(fd, buf, nBytesToWrite, callback);
```

## [Overflow](https://tigerbeetle.com/blog/2022-11-23-a-friendly-abstraction-over-iouring-and-kqueue/#overflow)

One more thing we need to worry about is that the batch we pass to io\_uring or kqueue has a fixed size (technically, kqueue allows any batch size but using that might introduce unnecessary allocations). So we’ll build our own queue on top of our I/O abstraction to keep track of requests that we could not immediately submit to io\_uring or kqueue.

> To keep this API simple we could allocate for each entry in the queue. Or we could modify the `io_dispatch.X` calls slightly to accept a struct that can be used in an [intrusive linked list](https://www.data-structures-in-practice.com/intrusive-linked-lists/) to contain all request context, including the callback. The latter is [what we do in TigerBeetle](https://github.com/tigerbeetle/tigerbeetle/blob/d15acc663f8882cb02413129e8351bf3238335e6/src/io/linux.zig#L665).

Put another way: every time code calls `io_dispatch`, we’ll try to immediately submit the requested event to io\_uring or kqueue. But if there’s no room, we store the event in an overflow queue.

The overflow queue needs to be processed eventually, so we update our `flush` function (described in [Callbacks and context](https://tigerbeetle.com/blog/2022-11-23-a-friendly-abstraction-over-iouring-and-kqueue/#callbacks-and-context) above) to pull as many events from our overflow queue before submitting a batch to io\_uring or kqueue.

## [A step back](https://tigerbeetle.com/blog/2022-11-23-a-friendly-abstraction-over-iouring-and-kqueue/#a-step-back)

We’ve now built something similar to [libuv](https://github.com/libuv/libuv), the I/O library that Node.js uses. And if you squint, it is basically TigerBeetle’s I/O library! (And interestingly enough, TigerBeetle’s I/O code was [adopted](https://github.com/oven-sh/bun/blob/e14a3af491ece8d1b0309e76ae3022b4fad91f16/src/io/io_linux.zig#L704) into Bun! Open-source for the win!)

Let’s check out how the [Darwin version](https://github.com/tigerbeetle/tigerbeetle/blob/9d3552ba137a773d4b81106739e56cba6cd32a03/src/io/darwin.zig#L436) of TigerBeetle’s I/O library (with kqueue) differs from the [Linux version](https://github.com/tigerbeetle/tigerbeetle/blob/9d3552ba137a773d4b81106739e56cba6cd32a03/src/io/linux.zig#L656). As mentioned, the complete `send` call in the Darwin implementation waits for file descriptor readiness (through kqueue). Once ready, the actual `send` call is made back in userland:

```
pub fn send(
    self: *IO,
    comptime Context: type,
    context: Context,
    comptime callback: fn (
        context: Context,
        completion: *Completion,
        result: SendError!usize,
    ) void,
    completion: *Completion,
    socket: os.socket_t,
    buffer: []const u8,
) void {
    self.submit(
        context,
        callback,
        completion,
        .send,
        .{
            .socket = socket,
            .buf = buffer.ptr,
            .len = @intCast(u32, buffer_limit(buffer.len)),
        },
        struct {
            fn do_operation(op: anytype) SendError!usize {
                return os.send(op.socket, op.buf[0..op.len], 0);
            }
        },
    );
}
```

Compare this to the [Linux version](https://github.com/tigerbeetle/tigerbeetle/blob/9d3552ba137a773d4b81106739e56cba6cd32a03/src/io/linux.zig#L656) (with io\_uring) where the kernel handles everything and there is no send system call in userland:

```
pub fn send(
    self: *IO,
    comptime Context: type,
    context: Context,
    comptime callback: fn (
        context: Context,
        completion: *Completion,
        result: SendError!usize,
    ) void,
    completion: *Completion,
    socket: os.socket_t,
    buffer: []const u8,
) void {
    completion.* = .{
        .io = self,
        .context = context,
        .callback = struct {
            fn wrapper(ctx: ?*anyopaque, comp: *Completion, res: *const anyopaque) void {
                callback(
                    @intToPtr(Context, @ptrToInt(ctx)),
                    comp,
                    @intToPtr(*const SendError!usize, @ptrToInt(res)).*,
                );
            }
        }.wrapper,
        .operation = .{
            .send = .{
                .socket = socket,
                .buffer = buffer,
            },
        },
    };
    // Fill out a submission immediately if possible, otherwise adds to overflow buffer
    self.enqueue(completion);
}
```

Similarly, take a look at `flush` on [Linux](https://github.com/tigerbeetle/tigerbeetle/blob/9d3552ba137a773d4b81106739e56cba6cd32a03/src/io/linux.zig#L66) and [macOS](https://github.com/tigerbeetle/tigerbeetle/blob/9d3552ba137a773d4b81106739e56cba6cd32a03/src/io/darwin.zig#L75) for event processing. Look at `run_for_ns` on [Linux](https://github.com/tigerbeetle/tigerbeetle/blob/9d3552ba137a773d4b81106739e56cba6cd32a03/src/io/linux.zig#L66]) and [macOS](https://github.com/tigerbeetle/tigerbeetle/blob/9d3552ba137a773d4b81106739e56cba6cd32a03/src/io/darwin.zig#L75) for the public API users must call. And finally, look at what puts this all into practice, the loop calling `run_for_ns` in src/main.zig.

## [Windows and IOCP](https://tigerbeetle.com/blog/2022-11-23-a-friendly-abstraction-over-iouring-and-kqueue/#windows-and-iocp)

We’ve come this far and you might be wondering — what about cross-platform support for Windows? The good news is that Windows also has a completion based system similar to io\_uring but without batching, called [IOCP](https://learn.microsoft.com/en-us/windows/win32/fileio/i-o-completion-ports). And for bonus points, TigerBeetle provides the [same I/O abstraction over it](https://github.com/tigerbeetle/tigerbeetle/blob/9d3552ba137a773d4b81106739e56cba6cd32a03/src/io/windows.zig)! But it’s enough to cover just Linux and macOS in this post. :)

## [Beyond a single thread](https://tigerbeetle.com/blog/2022-11-23-a-friendly-abstraction-over-iouring-and-kqueue/#beyond-a-single-thread)

In both this blog post and in TigerBeetle, we implemented a single-threaded event loop. Keeping I/O code single-threaded in userspace is beneficial (whether or not I/O processing is single-threaded in the kernel is not our concern). It’s the simplest code and best for workloads that are not embarrassingly parallel. It is also best for determinism, which is integral to the design of TigerBeetle because it enables us to do Deterministic Simulation Testing

But there are other valid architectures for other workloads.

For workloads that are embarrassingly parallel, like many web servers, you could instead use multiple threads where each thread has its own queue. In optimal conditions, this architecture has the highest I/O throughput possible.

But if each thread has its own queue, individual threads can become starved if an uneven amount of work is scheduled on one thread. In the case of dynamic amounts of work, the better architecture would be to have a single queue but multiple worker threads doing the work made available on the queue.

## [Standalone cross-platform evented I/O library?](https://tigerbeetle.com/blog/2022-11-23-a-friendly-abstraction-over-iouring-and-kqueue/#standalone-cross-platform-evented-io-library)

Hey, maybe we’ll split this out so you can use it too. It’s written in Zig so we can easily expose a C API. Any language with a C foreign function interface (i.e. every language) should work well with it. Keep an eye on [our GitHub](https://github.com/tigerbeetle). :)

Additional resources:

-   [https://www.usenix.org/system/files/conference/hotos15/hotos15-paper-mcsherry.pdf](https://www.usenix.org/system/files/conference/hotos15/hotos15-paper-mcsherry.pdf)
-   [https://github.com/ziglang/zig/issues/8224](https://github.com/ziglang/zig/issues/8224)
-   [https://www.youtube.com/watch?v=lZU6RK0oazM](https://www.youtube.com/watch?v=lZU6RK0oazM)
-   [https://unixism.net/loti/](https://unixism.net/loti/)

MORE POSTS

[

## A Database Without Dynamic Memory Allocation

Phil Eaton · Oct 12, 2022

](https://tigerbeetle.com/blog/2022-10-12-a-database-without-dynamic-memory)

-   [View All Posts](https://tigerbeetle.com/blog)
-   [**RSS**](https://tigerbeetle.com/blog/atom.xml)

 

### Product

[

Cloud

](https://tigerbeetle.com/cloud)[

Pricing

](https://tigerbeetle.com/cloud#pricing)[

Stories

](https://tigerbeetle.com/stories)

### Developers

[

Docs

](https://docs.tigerbeetle.com/)[

GitHub

](https://github.com/tigerbeetle/tigerbeetle)[

Tutorials

](https://github.com/tigerbeetle/tigerlings)[

Releases

](https://github.com/tigerbeetle/tigerbeetle/releases)[

Jepsen

](https://jepsen.io/analyses/tigerbeetle-0.16.11)[

Blog

](https://tigerbeetle.com/blog)

### Connect

[

X

](https://x.com/TigerBeetleDB)[

LinkedIn

](https://www.linkedin.com/company/tigerbeetle/)[

YouTube

](https://www.youtube.com/@tigerbeetledb)[

Email

](mailto:hello@tigerbeetle.com)

### Company

[

About

](https://tigerbeetle.com/company)[

Privacy

](https://tigerbeetle.com/privacy)

### Newsletter

Get monthly highlights and carefully crafted updates.

[Subscribe](https://tigerbeetle.com/newsletter)[

Past Newsletters →

](https://tigerbeetle.com/newsletters)

Correct and Fast

Copyright © 2026 TigerBeetle, Inc. All Rights Reserved.
