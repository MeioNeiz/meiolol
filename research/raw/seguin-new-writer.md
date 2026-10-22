# Zig's new Writer

<https://www.openmymind.net/Zigs-New-Writer/>

[home](https://www.openmymind.net/)[dark](https://www.openmymind.net/Zigs-New-Writer/#)

# Zig's new Writer

Jul 17, 2025

As you might have heard, Zig's `Io` namespace is being reworked. Eventually, this will mean the re-introduction of async. As a first step though, the Writer and Reader interfaces and some of the related code have been revamped.

> This post is written based on a mid-July 2025 development release of Zig. It doesn't apply to Zig 0.14.x (or any previous version) and is likely to be outdated as more of the Io namespace is reworked.

Not long ago, I wrote a blog post which tried to explain [Zig's Writers](https://www.openmymind.net/In-Zig-Whats-a-Writer/). At best, I'd describe the current state as "confusing" with two writer interfaces while often dealing with `anytype`. And while `anytype` is convenient, it lacks developer ergonomics. Furthermore, the current design has significant performance issues for some common cases.

### [Drain](https://www.openmymind.net/Zigs-New-Writer/#drain)

The new `Writer` interface is `std.Io.Writer`. At a minimum, implementations have to provide a `drain` function. Its signature looks like:

```zig
fn drain(w: *Writer, data: []const []const u8, splat: usize) Error!usize
```

You might be surprised that this is the method a custom writer needs to implemented. Not only does it take an array of strings, but what's that `splat` parameter? Like me, you might have expected a simpler `write` method:

```zig
fn write(w: *Writer, data: []const u8) Error!usize
```

It turns out that `std.Io.Writer` has buffering built-in. For example, if we want a `Writer` for an `std.fs.File`, we need to provide the buffer:

```zig
var buffer: [1024]u8 = undefined;
var writer = my_file.writer(&buffer);
```

Of course, if we don't want buffering, we can always pass an empty buffer:

```zig
var writer = my_file.writer(&.{});
```

This explains why custom writers need to implement a `drain` method, and not something simpler like `write`.

The simplest way to implement `drain`, and what a lot of the Zig standard library has been upgraded to while this larger overhaul takes place, is:

```zig
fn drain(io_w: *std.Io.Writer, data: []const []const u8, splat: usize) !usize {
    _ = splat;
    const self: *@This() = @fieldParentPtr("interface", io_w);
    return self.writeAll(data[0]) catch return error.WriteFailed;
}
```

We ignore the `splat` parameter, and just write the first value in `data` (`data.len > 0` is guaranteed to be true). This turns `drain` into what a simpler `write` method would look like. Because we return the length of bytes written, `std.Io.Writer` will know that we potentially didn't write all the data and call `drain` again, if necessary, with the rest of the data.

> If you're confused by the call to `@fieldParentPtr`, check out my post on the [upcoming linked list changes](https://www.openmymind.net/Zigs-New-LinkedList-API/).

The actual implementation of `drain` for the `File` is a non-trivial ~150 lines of code. It has platform-specific code and leverages [vectored I/O](https://www.openmymind.net/TCP-Server-In-Zig-Part-3-Minimizing-Writes-and-Reads/#writev) where possible. There's obviously flexibility to provide a simple implementation or a more optimized one.

### [The Interface](https://www.openmymind.net/Zigs-New-Writer/#interface)

Much like the current state, when you do `file.writer(&buffer)`, you don't get an `std.Io.Writer`. Instead, you get a `File.Writer`. To get an actual `std.Io.Writer`, you need to access the `interface` field. This is merely a convention, but expect it to be used throughout the standard, and third-party, library. Get ready to see a lot of `&xyz.interface` calls!

This simplification of `File` shows the relationship between the three types:

```zig
pub const File = struct {

  pub fn writer(self: *File, buffer: []u8) Writer{
    return .{
      .file = self,
      .interface = std.Io.Writer{
        .buffer = buffer,
        .vtable = .{.drain = Writer.drain},
      }
    };
  }

  pub const Writer = struct {
    file: *File,
    interface: std.Io.Writer,
    // this has a bunch of other fields

    fn drain(io_w: *std.Io.Writer, data: []const []const u8, splat: usize) !usize {
      const self: *Writer = @fieldParentPtr("interface", io_w);
      // ....
    }
  }
}
```

The instance of `File.Writer` needs to exist somewhere (e.g. on the stack) since that's where the `std.Io.Writer` interface exists. It's possible that `File` could directly have an `writer_interface: std.Io.Writer` field, but that would limit you to one writer per file and would bloat the `File` structure.

We can see from the above that, while we call `Writer` an "interface", it's just a normal struct. It has a few fields beyond `buffer` and `vtable.drain`, but these are the only two with non-default values; we have to provide them. The `Writer` interface implements a lot of typical "writer" behavior, such as a `writeAll` and `print` (for formatted writing). It also has a number of methods which only a `Writer` implementation would likely care about. For example, `File.Writer.drain` has to call `consume` so that the writer's internal state can be updated. Having all of these functions listed side-by-side in the documentation confused me at first. Hopefully it's something the documentation generation will one day be able to help disentangle.

### [Migrating](https://www.openmymind.net/Zigs-New-Writer/#migrating)

The new `Writer` has taken over a number of methods. For example, `std.fmt.formatIntBuf` no longer exists. The replacement is the `printInt` method of `Writer`. But this requires a `Writer` instance rather than the simple `[]u8` previous required.

It's easy to miss, but the `Writer.fixed([]u8) Writer` function is what you're looking for. You'll use this for any function that was migrating to `Writer` and used to work on a `buffer: []u8`.

While migrating, you might run into the following error: _no field or member function named 'adaptToNewApi' in '...'_. You can see why this happens by looking at the updated implementation of `std.fmt.format`:

```zig
pub fn format(writer: anytype, comptime fmt: []const u8, args: anytype) !void {
    var adapter = writer.adaptToNewApi();
    return adapter.new_interface.print(fmt, args) catch |err| switch (err) {
        error.WriteFailed => return adapter.err.?,
    };
}
```

Because this functionality was moved to `std.Io.Writer`, any `writer` passed into `format` has to be able to upgrade itself to the new interface. This is done, again only be convention, by having the "old" writer expose an `adaptToNewApi` method which returns a type that exposes a `new_interface: std.Io.Writer` field. This is pretty easy to implement using the basic `drain` implementation, and you can find a handful of examples in the standard library, but it's of little help if you don't control the legacy writer.

### [Conclusion](https://www.openmymind.net/Zigs-New-Writer/#conclusion)

I'm hesitant to provide opinion on this change. I don't understand language design. However, while I think this is an improvement over the current API, I keep thinking that adding buffering directly to the `Writer` isn't ideal.

I believe that most languages deal with buffering via composition. You take a reader/writer and wrap it in a BufferedReader or BufferedWriter. This approach seems both simple to understand and implement while being powerful. It can be applied to things beyond buffering and IO. Zig seems to struggle with this model. Rather than provide a cohesive and generic approach for such problems, one specific feature (buffering) for one specific API (IO) was baked into the standard library. Maybe I'm too dense to understand or maybe future changes will address this more holistically.
