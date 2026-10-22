# std.Io.Writer.Allocating ate all my memory

<https://www.openmymind.net/std-io-writer-allocating-ate-my-memory/>

[home](https://www.openmymind.net/)[dark](https://www.openmymind.net/std-io-writer-allocating-ate-my-memory/#)

# std.Io.Writer.Allocating ate all my memory

Jul 30, 2026

If I told you that the following prints **1665**:

```zig
var b: std.ArrayList(u8) = try .initCapacity(init.gpa, 1024);
try b.appendSlice(init.gpa, "a" ** 1025);
std.debug.print("{d}\n", .{b.capacity});
```

Would you be able to guess what this prints?

```zig
var w: Io.Writer.Allocating = try .initCapacity(init.gpa, 1024);
try w.writer.writeAll("a" ** 1025);
std.debug.print("{d}\n", .{w.writer.buffer.len});
```

Like me, you might be surprised to see **3204**. What's even weirder is that if you split the write, you get a more reasonable **1668**:

```zig
var w: Io.Writer.Allocating = try .initCapacity(init.gpa, 1024);
try w.writer.writeAll("a" ** 1024);
try w.writer.writeAll("a");
std.debug.print("{d}\n", .{w.writer.buffer.len});
```

What's going on here? It appears to be a bug in the `drain` implementation of `std.Io.Writer.Allocating`. `drain` is the one method a `Writer` has to implement, and, besides `self`, it takes two parameters:

```zig
fn drain(w: *Writer, data: []const []const u8, splat: usize) Error!usiz
```

It takes a list of values to write (to support vectored I/O) and a "splat" count which is the number of times the last value in `data` should be written. `splat` is particularly useful, I believe, for compression. Here's a relevant line from `zstd/Decompress.zig`:

```zig
try w.splatByteAll(d.literal_streams.one[0], len);
```

Where `writer.splatByteAll` finds its way to calling `drain`. So we have some idea of `drain`'s parameters, but why does it grow so much. Here's a simplified version of `Allocating`'s `drain` function:

```zig
fn drain(self: *Allocating, data: []const []const u8, splat: usize) !usize {
  const pattern = data[data.len - 1];
  const splat_len = pattern.len * splat;
  const start_len = self.writer.end;

  for (data) |bytes| {
    try self.ensureUnusedCapacity(bytes.len + splat_len + 1);
    @memcpy(self.writer.buffer[self.writer.end..][0..bytes.len], bytes);
    self.writer.end += bytes.len;
  }

  // ...
}
```

Can you spot the issue? I couldn't, but Claude could. For the common case where `data.len == 1` and `splat == 1`, we're actually reserving 2x the memory: once for the data and once for `splat_len` which is the data again (what the code calls the `pattern`). If we called `drain(&.{"hello", " "}, 100)`, the code would need to reserve space 5 bytes for `"hello"` and 100 bytes for the `pattern` (`" ".len * 100`). But the implementation reserves the splat space for every value, including the pattern itself.

`ArrayList` doesn't suffer from this: it has no splat. If your use-case is simple, if you're just appending bytes, you might want to stick with it.
