//! What the app's page asks of its shell, as JSON the shell's channel.zig FromPage reads
//! (a tagged union, as std.json writes one). ui-app.wasm points `send` at bridge.js's
//! meiolol.send; outside the shell (a dump in a browser, the gallery) it goes nowhere
const std = @import("std");

pub const Out = union(enum) {
    signin: SignIn,
};

pub const SignIn = struct { username: []const u8, password: []const u8 };

pub var send: *const fn (Out) void = ignore;

fn ignore(_: Out) void {}

/// By hand: std.json's writer costs ui-app.wasm about 1 KB gz
pub fn json(o: Out, w: *std.Io.Writer) std.Io.Writer.Error!void {
    switch (o) {
        .signin => |x| {
            try w.writeAll("{\"signin\":{\"username\":");
            try string(w, x.username);
            try w.writeAll(",\"password\":");
            try string(w, x.password);
            try w.writeAll("}}");
        },
    }
}

fn string(w: *std.Io.Writer, s: []const u8) std.Io.Writer.Error!void {
    try w.writeByte('"');
    for (s) |c| switch (c) {
        '"', '\\' => try w.writeAll(&.{ '\\', c }),
        0...0x1f => {
            const hex = "0123456789abcdef";
            try w.writeAll(&.{ '\\', 'u', '0', '0', hex[c >> 4], hex[c & 15] });
        },
        else => try w.writeByte(c),
    };
    try w.writeByte('"');
}

test "a tagged object, strings escaped" {
    var buf: [128]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try json(.{ .signin = .{ .username = "ann", .password = "a\"b\\\x01é" } }, &w);
    try std.testing.expectEqualStrings("{\"signin\":{\"username\":\"ann\",\"password\":\"a\\\"b\\\\\\u0001é\"}}", w.buffered());
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const back = try std.json.parseFromSliceLeaky(Out, arena.allocator(), w.buffered(), .{});
    try std.testing.expectEqualStrings("a\"b\\\x01é", back.signin.password);
}
