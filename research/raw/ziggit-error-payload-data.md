finlaydotb | 2025-04-17 16:36:20 UTC | #1

Reading https://ziglang.org/documentation/master/#Errors it seems Zig errors cannot contain data.

Unlike in Rust where error could be any value; a tagged union for instance and hence can relay data in the error value. For example https://github.com/marshallpierce/rust-base64/blob/6243bd11f82eb27e6880e69844977e7226e7378b/src/decode.rs#L54

This seems not to be possible in Zig. 

Question is, what is the idiomatic way to now convey some extra data with an error in Zig?

-------------------------

mnemnion | 2025-04-17 16:56:05 UTC | #2

It entirely depends on why you might need extra data. 

For instance, if you want to know the location where something which uses an index fails, you can use a cursor pattern:

```zig
var cursor: usize = 0;
const result = something.spanAnArray(&cursor) catch |err| {
    log.error("Error {s} at index {d}", .{@errorName(err), cursor});
    return err;
};
```
Here, the assumption is that `cursor.*` is used to index and advance along some array.

If you really need a tagged error union, you can simply use a tagged union, and use ordinary control flow to handle it.  These can be promoted to more ordinary errors when desired, so as to be compatible with the expected idioms of Zig.

-------------------------

pierrelgol | 2025-04-17 17:09:09 UTC | #3

You can use something like that, albeit it's not very idiomatic, but hey you do you :slight_smile: 


```
const std = @import("std");

pub fn Result(comptime E: type, comptime T: type) type {
    return union(enum) {
        const Self = @This();
        ok: T,
        err: E,

        pub fn wrap(res: E!T) Self {
            if (res) |v| {
                return .{ .ok = v };
            } else |e| {
                return .{ .err = e };
            }
        }

        pub fn unwrap(self: Self) T {
            std.debug.assert(std.meta.activeTag(self) == .ok);
            return self.ok;
        }

        pub fn unwrapOrErr(self: Self) E!T {
            return if (std.meta.activeTag(self) == .ok) self.ok else return self.err;
        }

        pub fn unwrapOrNull(self: Self) ?T {
            return if (std.meta.activeTag(self) == .ok) self.ok else return null;
        }
    };
}

pub const Err = error{e};

pub fn foo(bar: u32) Result(Err, u32) {
    if (bar == 5) {
        return .{ .ok = 5 };
    } else {
        return .{ .err = error.e };
    }
}

test Result {
    switch (foo(5)) {
        .ok => |v| std.debug.print("{d}", .{v}),
        .err => |e| std.debug.print("{!}", .{e}),
    }
}

```

-------------------------

mnemnion | 2025-04-17 17:30:04 UTC | #4

This doesn't actually get around the problem of error payloads, because `unwrapOrErr` requires that `E` be an error.  

One could do something quite similar, where `E` is a struct which includes an `anyerror` field, or a field containing the relevant error set, then the rest of the struct could carry the payload.

-------------------------

pierrelgol | 2025-04-17 21:28:26 UTC | #5

This is true but you get to convert the switch into a poor man's match statement, which looks cool, but yeah you can't attach anything to it unfortunately.

-------------------------

cryptocode | 2025-04-17 22:02:26 UTC | #6

Quite a few people in the Zig community have rallied around the "Diagnostics pattern" where you return and handle errors per usual, but also allow the caller to interrogate a Diagnostics instance when an error happens. This contains useful information about the error, such as col/line for a parser error, or maybe an errorstring/code combination for a file error.

Depending on situation, the Diagnostics instance can be passed in to every relevant fallible function, or be part of initialization for session-oriented situations.

Here are some examples:

Clap, where you pass diagnostics as an argument: https://github.com/Hejsil/zig-clap/blob/a4e784da8399c51d5eeb5783e6a485b960d5c1f9/example/simple.zig#L18-L26

The Scanner in std lib, where you can ask for diagnostics (if enabled) when errors occur: https://github.com/ziglang/zig/blob/8f8f37fb0fe0ab8d98ca54ba6b51ce3d84222082/lib/std/json/scanner.zig#L191-L196

For my own, I used the approach in Stitch, where you can also ask for diagnostics when an error occurs in the session you have with the library: https://github.com/cryptocode/stitch/blob/9b82da85c70f5c702db9e4e8d498a9661c40ae5b/src/lib.zig#L69

The last one is kinda interesting in that it uses `InKryption`'s idea of using `pub const Diagnostic = union(std.meta.FieldEnum(MyErrorType))` to make sure error enums and diagnostics are always kept in sync. If you forget to sync up, you get a compile error. Very nice imo!

-------------------------

jeffective | 2025-04-17 22:50:35 UTC | #7

You might be interested in this thread, and my response, which in short was "error codes are not values, errors are a refusal to return a value". This is my current understanding of errors. The current default way to return values as "erroneous" is to use a tagged union.

https://ziggit.dev/t/allow-returning-a-value-with-an-error/7746/4?u=kj4tmp

-------------------------

