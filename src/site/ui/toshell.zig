//! What the app's page asks of its shell, as JSON the shell's channel.zig FromPage reads
//! (Out, a tagged union as std.json writes one). ui-app.wasm and ui-practice.wasm point
//! `out` at bridge.js's meiolol.send; outside the shell (a dump in a browser, the
//! gallery) it goes nowhere
const std = @import("std");

pub const Out = union(enum) {
    signin: SignIn,
    /// Options weigh your mastery points
    mastery: bool,
    /// Private edition: practice on or off, or a change to its draft (ui/practice.zig)
    practice: Practice,
};

pub const SignIn = struct { username: []const u8, password: []const u8 };

pub const Practice = union(enum) {
    /// The header's button
    on: bool,
    set: Set,
    random,
    clear,
    /// A champion into a seat or ban, 0 empties it; an ally's not locked is a hover
    place: Place,
    /// A lane option: hovered as my pick, locked when it already was
    take: u32,
    /// A ban option: my ban, in my cell's place
    ban: u32,
};

/// Allies by role (Role.all's order), enemies and bans by place; each 0 to 4
pub const Target = union(enum) { ally: u8, enemy: u8, my_ban: u8, their_ban: u8 };

pub const Place = struct { at: Target, champion: u32, locked: bool };

/// Each the index of its choice in the bar
pub const Set = union(enum) { screen: u8, stage: u8, role: u8, pick: u8, minute: u8, lead: u8, win: bool };

pub var out: *const fn ([]const u8) void = ignore;

fn ignore(_: []const u8) void {}

/// Message `tag`. Per tag, so each file compiles in only what it sends (all of Practice
/// cost ui-app.wasm 1 KB gz)
pub fn send(comptime tag: std.meta.Tag(Out), v: @FieldType(Out, @tagName(tag))) void {
    emit(&.{@tagName(tag)}, v);
}

/// Practice's message `op`, per op as send's
pub fn practice(comptime op: std.meta.Tag(Practice), v: @FieldType(Practice, @tagName(op))) void {
    emit(&.{ "practice", @tagName(op) }, v);
}

/// `{"k":{"k2":v}}` by hand: std.json's writer costs a wasm file about 1 KB gz
fn emit(comptime keys: []const []const u8, v: anytype) void {
    var buf: [1024]u8 = undefined;
    // A password passes through here
    defer std.crypto.secureZero(u8, &buf);
    var w: std.Io.Writer = .fixed(&buf);
    inline for (keys) |k| w.writeAll("{\"" ++ k ++ "\":") catch return;
    value(&w, v) catch return;
    w.splatByteAll('}', keys.len) catch return;
    out(w.buffered());
}

fn value(w: *std.Io.Writer, x: anytype) std.Io.Writer.Error!void {
    const T = @TypeOf(x);
    switch (@typeInfo(T)) {
        .bool => try w.writeAll(if (x) "true" else "false"),
        .int => try w.print("{d}", .{x}),
        // As std.json reads a void union field
        .void => try w.writeAll("{}"),
        .pointer => try string(w, x),
        .@"struct" => {
            try w.writeByte('{');
            const names = comptime std.meta.fieldNames(T);
            inline for (names, 0..) |f, i| {
                try w.writeAll((if (i > 0) "," else "") ++ "\"" ++ f ++ "\":");
                try value(w, @field(x, f));
            }
            try w.writeByte('}');
        },
        .@"union" => switch (x) {
            inline else => |v, tag| {
                try w.writeAll("{\"" ++ @tagName(tag) ++ "\":");
                try value(w, v);
                try w.writeByte('}');
            },
        },
        else => @compileError("toshell: no JSON for " ++ @typeName(T)),
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

var sent: [256]u8 = undefined;
var sent_len: usize = 0;

fn record(s: []const u8) void {
    @memcpy(sent[0..s.len], s);
    sent_len = s.len;
}

fn last() []const u8 {
    return sent[0..sent_len];
}

test "a tagged object, strings escaped" {
    const old = out;
    defer out = old;
    out = record;
    send(.signin, .{ .username = "ann", .password = "a\"b\\\x01é" });
    try std.testing.expectEqualStrings("{\"signin\":{\"username\":\"ann\",\"password\":\"a\\\"b\\\\\\u0001é\"}}", last());
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const back = try std.json.parseFromSliceLeaky(Out, arena.allocator(), last(), .{});
    try std.testing.expectEqualStrings("a\"b\\\x01é", back.signin.password);
    send(.mastery, false);
    try std.testing.expectEqual(false, (try std.json.parseFromSliceLeaky(Out, arena.allocator(), last(), .{})).mastery);
}

test "practice's messages read back as written" {
    const old = out;
    defer out = old;
    out = record;
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const all = [_]Practice{
        .{ .on = true },
        .{ .set = .{ .role = 3 } },
        .{ .set = .{ .win = false } },
        .random,
        .clear,
        .{ .place = .{ .at = .{ .their_ban = 4 }, .champion = 266, .locked = true } },
        .{ .take = 103 },
        .{ .ban = 7 },
    };
    for (all) |p| {
        switch (p) {
            inline else => |v, op| practice(op, v),
        }
        const back = try std.json.parseFromSliceLeaky(Out, arena.allocator(), last(), .{});
        try std.testing.expectEqualDeep(Out{ .practice = p }, back);
    }
    practice(.random, {});
    try std.testing.expectEqualStrings("{\"practice\":{\"random\":{}}}", last());
}
