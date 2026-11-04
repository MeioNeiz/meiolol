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

/// Meio's number for a cell (src/meio.zig Estimate): p, its 80% range, and the games in
/// the cell's own slice (the newest patch, this region and rank)
pub const Est = struct { p: f32, lo: f32, hi: f32, own: u32 };

/// A keystone, finished item or lane opponent beside the lock stack: its games and wins
/// under the stack and the page's view, Meio's number for the stack with it
pub const Choice = struct { id: u32, name: []const u8, games: u32, wins: u32, meio: ?Est };

/// Why Meio has no number for the stack
pub const Gap = enum {
    none,
    /// The renderer has no fitted model (data/export/meio.bin)
    no_model,
    /// Master+: its bracket is wider than the pick, so raw only
    master,
    /// A lock Meio doesn't model (rune page, spells, a core path, ...)
    kind,
    /// More than two locks it models: no three-way terms
    deep,
};

/// Meio under a champion page's lock stack (site/locks.zig meio), at meioPath
pub const Meio = struct {
    gap: Gap,
    /// An item lock counts as built in any slot: the slot isn't modelled
    any_slot: bool,
    /// The stack's games and wins under the page's view
    games: u32,
    wins: u32,
    stack: ?Est,
    /// Lane gold at 14, in gold: under no lock or an opponent lock only
    gold: ?Est,
    keystones: []const Choice,
    items: []const Choice,
    opponents: []const Choice,
};

/// `lk` as lockanswer.Locks.format writes it, "" for none; `view` html.View's index
pub fn meioPath(a: std.mem.Allocator, view: u8, id: u32, r: Role, rank: []const u8, lk: []const u8) ![]const u8 {
    var out: std.Io.Writer.Allocating = .init(a);
    const w = &out.writer;
    try w.writeAll("/private/meio/");
    try fmt.write(w, .int, view);
    try w.writeByte('/');
    try fmt.write(w, .int, id);
    try w.print("/{t}/{s}/{s}.bin", .{ r, rank, if (lk.len == 0) no_locks else lk });
    return out.toOwnedSlice();
}

pub const no_locks = "none";

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
