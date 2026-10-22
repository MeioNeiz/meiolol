# Is Zig's New Writer Unsafe?

<https://www.openmymind.net/Is-Zigs-New-Io-Unsafe/>

[home](https://www.openmymind.net/)[dark](https://www.openmymind.net/Is-Zigs-New-Io-Unsafe/#)

# Is Zig's New Writer Unsafe?

Sept 20, 2025

If we wanted to write a function that takes one of Zig's new `*std.Io.Reader` and write it to stdout, we might start with something like:

```zig
fn output(r: *std.Io.Reader) !void {
    const stdout = std.fs.File.stdout();
    var buffer: [???]u8 = undefined;
    var writer = stdout.writer(&buffer);
    _ = try r.stream(&writer.interface, .unlimited);
    try writer.interface.flush();
}
```

But what should the size of `buffer` be? If this was a one-and-done, maybe we'd leave it empty or put some seemingly sensible default, like 1K or 4K. If it was a mission critical piece of code, maybe we'd benchmark it or make it platform dependent.

But unless I'm missing something, whatever size we use, this function's behavior is undefined. You see, the issue is that readers can require a specific buffer sizes on a writer (and writers can require a specific buffer size on a reader). For example, this code, with a small buffer of 64, fails an assertion in debug mode, and falls into an endless loop in release mode:

```zig
const std = @import("std");

pub fn main() !void {
    var fixed = std.Io.Reader.fixed(&.{
        40, 181, 47, 253, 36, 110, 149, 0, 0, 88, 111, 118, 101, 114, 32, 57,
        48, 48, 48, 33, 10, 1, 0, 192, 105, 241, 2, 170, 69, 248, 150
    });

    var decompressor = std.compress.zstd.Decompress.init(&fixed, &.{}, .{});
    try output(&decompressor.reader);
}

fn output(r: *std.Io.Reader) !void {
    const stdout = std.fs.File.stdout();
    var buffer: [64]u8 = undefined;
    var writer = stdout.writer(&buffer);
    _ = try r.stream(&writer.interface, .unlimited);
    try writer.interface.flush();
}
```

Some might argue that this is a documentation challenge. It's true that the documentation for `zstd.Decompress` mentions what a `Writer`'s buffer must be. **But this is not a documentation problem**. There are legitimate scenarios where the nature of a `Reader` is unknown (or, at least, difficult to figure out). A type of a reader could be conditional, say based on an HTTP response header. A library developer might take a `Reader` as an input and present their own `Reader` as an output - what buffer requirement should they document?

Worse is that the failure can be conditional on the input. For example, if we change our source to:

```zig
var fixed = std.Io.Reader.fixed(&.{
    40, 181, 47, 253, 36, 11, 89, 0, 0, 111, 118, 101, 114, 32, 57,
    48, 48, 48, 33, 10, 112, 149, 178, 212,
});
```

Everything works, making this misconfiguration particularly hard to catch early.

To me this seems almost impossible - like, I must be doing something wrong. And if I am, I'm sorry. But, if I'm not, this is a problem right?
