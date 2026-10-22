# 10. I/O and concurrency with std.Io

## 10.1 Io is a parameter, like Allocator

Anything that blocks or is nondeterministic (files, sockets, time, entropy, locks) takes
`io: Io`; code stays agnostic of the concurrency model (Threaded, Evented) and testable
(`std.testing.io`, `Io.failing`). No Io parameter means no I/O, visible in the
signature [[zig-016-release-notes#^f1]], [[ak-async-io-text#^f1]],
[[zig-talk-kelley-flush#^f5]]. Making an Io locally is "like reaching for
`std.heap.page_allocator`" [[zig-016-release-notes#^f3]]; take `init.io` from main.
Allocator stays separate, because a blocking eager Io needs none. Pure stream transforms
take a Writer and need no Io at all [[zig-talk-roadmap-2026#^f8]].

## 10.2 Streams: concrete, buffered in the interface, flushed

`*std.Io.Writer` and `*std.Io.Reader` are concrete structs holding the buffer; the hot
path (copy into the buffer) inlines with no virtual call, and only a full buffer reaches
the vtable. Generic streams forced `anytype` everywhere and passed errors through like
`anyerror`; one-byte writes without a buffer cost about 1000x
[[zig-015-release-notes#^f11]], [[zig-std-io#^f8]], [[zig-talk-kelley-flush#^f10]].

```zig
// ziglang/zig lib/std/Io/Writer.zig:608 @ 0.17.0
pub fn write(w: *Writer, bytes: []const u8) Error!usize {
    if (w.end + bytes.len <= w.buffer.len) {
        @branchHint(.likely);
        @memcpy(w.buffer[w.end..][0..bytes.len], bytes);
        w.end += bytes.len;
        return bytes.len;
    }
    return w.vtable.drain(w, &.{bytes}, 1);
}
```

Using one, from the 0.17 `zig init` template [[zig-repo-docs#^f13]]:

```zig
// ziglang/zig lib/init/src/main.zig:19 @ 0.17.0
    // In order to do I/O operations need an `Io` instance.
    const io = init.io;

    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    try _NAME.printAnotherMessage(stdout_writer);

    try stdout_writer.flush(); // Don't forget to flush!
```

Implementations embed the interface as a field named `interface` and recover themselves
with `@fieldParentPtr`; never copy the interface out, pass `&fw.interface`, and don't
move the concrete writer while it is in use [[zig-std-io#^f13]], [[seguin-new-writer#^f4]]:

```zig
// ziglang/zig lib/std/Io/File/Writer.zig:229 @ 0.17.0
pub fn drain(io_w: *Io.Writer, data: []const []const u8, splat: usize) Io.Writer.Error!usize {
    const w: *Writer = @alignCast(@fieldParentPtr("interface", io_w));
```

Readers report precise, small errors; get details from the implementation
[[zig-015-release-notes#^f13]]:

```zig
// research/raw/zig-015-release-notes.md:653
while (reader.takeDelimiterExclusive('\n')) |line| {
    // do something with line...
} else |err| switch (err) {
    error.EndOfStream, // stream ended not on a line break
    error.StreamTooLong, // line could not fit in buffer
    error.ReadFailed, // caller can check reader implementation for diagnostics
    => |e| return e,
}
```

Memory streams are `std.Io.Reader.fixed(data)` and `Writer.fixed(buf)`; growable output is
`Writer.Allocating` [[zig-016-release-notes#^f23]]. Some streams need a minimum buffer on
the other side (zstd: assert in debug, endless loop in release), so read each stream's
requirement [[seguin-new-io-unsafe#^f1]].

## 10.3 async, cancel, Group

- `io.async` by default: it cannot fail and may run inline. `io.concurrent` only when
  correctness needs real concurrency (producer and consumer on one thread deadlock); it
  allocates and can return `ConcurrencyUnavailable` [[zig-016-release-notes#^f5]],
  [[zig-talk-async-io-zigtoberfest#^f9]], [[kristoff-asynchrony-not-concurrency#^f3]].
- After each `io.async`, immediately `defer` a cancel that frees whatever the task
  returned; then `try fut.await(io)`. Without it, `try` on the first await leaks the
  second; cancel and await are idempotent, and a cancelled task may still have
  succeeded [[zig-016-release-notes#^f6]], [[ak-async-io-text#^f4]]:

```zig
// research/raw/zig-016-release-notes.md:1320
var foo_future = io.async(foo, .{args});
defer if (foo_future.cancel(io)) |resource| resource.deinit() else |_| {}

var bar_future = io.async(bar, .{args});
defer if (bar_future.cancel(io)) |resource| resource.deinit() else |_| {}

const foo_result = try foo_future.await(io);
```

- Many tasks with one lifetime: an `Io.Group`, an "arena of tasks"; `std.Thread.Pool`
  is gone [[zig-016-release-notes#^f9]], [[zig-016-release-notes#^f12]]:

```zig
// research/raw/zig-016-release-notes.md:1359
var group: Io.Group = .init;
defer group.cancel(io);

for (&array) |elem| group.async(io, sleepAppend, .{ io, &sorted, &index, elem });

try group.await(io);
```

- For a few plain operations at once, `Batch` is leaner than futures
  [[zig-016-release-notes#^f10]].

## 10.4 Cancellation is an error

`error.Canceled` propagates through `try`, so errdefer and defer cleanup run on
cancellation for free. Only the code that requested cancellation may swallow it; long
CPU-bound loops call `checkCancel` [[zig-016-release-notes#^f7]],
[[zig-talk-async-io-zigtoberfest#^f7]]. matklad: Reader and Writer erase errors, so
cancellation needs care through them [[matklad-io-threaded#^f4]]. Bake timeouts into the
operation, so code also works single-threaded [[zig-talk-async-io-zigtoberfest#^f16]].

## 10.5 Locks and shared data

Converting from threads: every `Thread.Mutex`, `Condition` and `ResetEvent` becomes its
`Io` type, or it is a bug [[zig-016-release-notes#^f11]]. Lock-free primitives need no
Io. A lock is not enough for shared ownership: one thread can free what another holds,
so refcount and acquire under the lock, with release ordering on the decrement
[[seguin-threads-freeing#^f4]]. TigerBeetle keeps its own io_uring loop on 0.16 and holds
a `std.Io` only for blocking file operations: std.Io did not replace a mature custom
event loop [[tigerbeetle-code#^f33]].
