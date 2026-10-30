//! The private numbers' data (ui.pv), one file per champion at
//! /private/models/champ/<id>.bin (draftmodel.zig writeSlices): the shipped draft model's
//! team win chance in each role the champion plays, alone and beside each opponent ("vs")
//! or ally ("with") it has games with, every other slot its role's average pick
const std = @import("std");
const fmt = @import("fmt.zig");
const Role = @import("role.zig").Role;

pub const Pair = struct { role: Role, champion: u32, p: f32, games: u32 };

pub const Line = struct {
    role: Role,
    games: u32,
    /// The chance alone against an average draft, then its 95% range
    win: [3]f32,
    vs: []const Pair,
    with: []const Pair,
};

pub const Name = struct { id: u32, name: []const u8 };

pub const Slice = struct {
    id: u32,
    name: []const u8,
    /// Every champion its pairs name
    names: []const Name,
    roles: []const Line,

    pub fn line(s: *const Slice, r: Role) ?*const Line {
        for (s.roles) |*l| if (l.role == r) return l;
        return null;
    }

    pub fn idOf(s: *const Slice, name: []const u8) ?u32 {
        for (s.names) |n| if (std.mem.eql(u8, n.name, name)) return n.id;
        return null;
    }

    pub fn nameOf(s: *const Slice, id: u32) ?[]const u8 {
        for (s.names) |n| if (n.id == id) return n.name;
        return null;
    }
};

pub fn path(buf: *[48]u8, id: u32) []const u8 {
    var w: std.Io.Writer = .fixed(buf);
    w.writeAll("/private/models/champ/") catch unreachable;
    fmt.write(&w, .int, id) catch unreachable;
    w.writeAll(".bin") catch unreachable;
    return w.buffered();
}

pub fn find(pairs: []const Pair, r: Role, id: u32) ?Pair {
    for (pairs) |x| if (x.role == r and x.champion == id) return x;
    return null;
}

test path {
    var buf: [48]u8 = undefined;
    try std.testing.expectEqualStrings("/private/models/champ/4294967295.bin", path(&buf, std.math.maxInt(u32)));
}
