# Using Generics to Inject Stubs when Testing

<https://www.openmymind.net/Using-Generics-To-Inject-Stubs-When-Testing/>

[home](https://www.openmymind.net/)[dark](https://www.openmymind.net/Using-Generics-To-Inject-Stubs-When-Testing/#)

# Using Generics to Inject Stubs when Testing

Feb 07, 2025

I have an unapologetic and, I'd like to think, pragmatic take on testing. I want tests to run fast, not be flaky and not be brittle. By "flaky", I mean tests that randomly fail. By "brittle", I mean tests that break due to seemingly unrelated changes in the code.

I'm happy that the definition of "unit tests" has broadened over the years: it's now acceptable to have "unit tests" do more, i.e. hitting a database. I call the period of time where I (we?) over-relied on dependency injection and mocking frameworks, the "dark ages". Still, I do believe that stubs and similar testing tools can be useful in specific cases.

One pattern that I've recently leveraged is using a generic to inject a stub for testing. For example, imagine we have a `Client` struct which encapsulate communication over the TCP socket:

```zig
const Client = struct {
    stream: net.Stream,

    // Prefix the message with its 4-byte length
    pub fn write(self: Client, data: []const u8) !void {
        var header: [4]u8 = undefined;
        std.mem.writeInt(u32, &header, @intCast(data.len), .big);
        try self.stream.writeAll(&header);
        return self.stream.writeAll(data);
    }
};
```

Admittedly, a unit test for this specific code doesn't make much sense to me. The code itself is trivial, but setting up a test for it wouldn't be straightforward. But what if we did want to test it? Maybe we had a bit more logic with an edge-case that might be hard to reproduce in a broader end-to-end test. Here's how I'd do it:

```zig
pub const Client = ClientT(net.Stream);

fn ClientT(comptime S: type) type {
    return struct {
        stream: S,

        const Self = @This();

        // Prefix the message with its 4-byte length
        pub fn write(self: Self, data: []const u8) !void {
            var header: [4]u8 = undefined;
            std.mem.writeInt(u32, &header, @intCast(data.len), .big);
            try self.stream.writeAll(&header);
            return self.stream.writeAll(data);
        }
    };
}
```

The generic, `ClientT`, exists only for testing purposes. To shield everything else from this implementation detail, we continue to expose a `Client` which behaves exactly like our original version, i.e. it's a `Client` that behaves on a `net.Stream`.

Now we can test our `Client` against something other than a `net.Stream`:

```zig
const TestStream = struct {
    written: std.ArrayListUnmanaged(u8) = .{},

    const allocator = testing.allocator;

    fn deinit(self: *TestStream) void {
        self.written.deinit(allocator);
    }

    pub fn writeAll(self: *TestStream, data: []const u8) !void {
        return self.written.appendSlice(allocator, data);
    }
};
```

Our `TestStream` records all data written. This will allow our tests to assert that, for a given input (or inputs), the correct data was written. Here's a test:

```zig
test "Client: write" {
    var stream = TestStream{};
    defer stream.deinit();

    const client: ClientT(*TestStream) = .{.stream = &stream};

    try client.write("over 9000!");

    // we still need to write this!
    try stream.expectWritten(&.{
        [_]u8{0, 0, 0, 10} ++ "over 9000!",
    });
}
```

By injecting our `TestStream` into the client, we're able to control the interaction between the client and the "stream". Our test calls `client.write`, like normal code would, and, in our tests, this ends up calling our `TestStream.writeAll` method. To finish off this example, we still need to implement the `expectWritten` function, which the above test calls:

```zig
const TestStream = struct {
    // add this field
    read_pos: usize = 0

    written: std.ArrayListUnmanaged(u8) = .{},

    // ... everything else is the same ...

    // add this method
    fn expectWritten(self: *TestStream, expected: []const []const u8) !void {
        var read_pos = self.read_pos;
        var written = self.written.items[read_pos..];
        for (expected) |e| {
            try testing.expectEqual(true, written.len >= e.len);
            try testing.expectEqualSlices(u8, e, written[read_pos..e.len]);
            read_pos += e.len;
        }
        self.read_pos = read_pos;
    }
};
```

There are a lot of different ways we can assert that the expected data was written. The above implementation is straightforward, but by adding the `read_pos` field, we'll be able to incrementally write/assert.

Again, this isn't a pattern that I use often. And there are different ways to achieve the same thing. For example, we could extract the message framing logic (in our case, the 4-byte length header), into its own struct). But I believe every alternative will have some compromises. Therefore it comes down to picking the best option for a given problem, and hopefully this is another tool you can add to your toolbelt.

If you're wondering why we need to prefix the message with its length, you might be interested in my [TCP Message Boundaries post](https://www.openmymind.net/TCP-Server-In-Zig-Part-2-Message-Boundaries/). If you're wondering whether the 2 `writeAll` calls, which will result in at least 2 system calls, can be merged, you might be interested to [learn about `writev`](https://www.openmymind.net/TCP-Server-In-Zig-Part-3-Minimizing-Writes-and-Reads/#writev).
