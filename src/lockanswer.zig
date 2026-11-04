//! Lock answers (docs/plan/ui/champion-locks.md L2): a champion-role's lock rows under a
//! view and a stack of locks, counted by builds.Builder into the File the build panel
//! reads, so an answer without locks is the champion-role's build of builds --site

const std = @import("std");
const core = @import("core");
const builds = @import("builds.zig");
const ddragon = @import("ddragon.zig");
const lockrows = @import("lockrows.zig");

const Allocator = std.mem.Allocator;
const Role = core.Role;

/// What a lock holds to, as the build file's kinds plus the lane opponent. `rune` and
/// `shard` hold when any of the page's runes (shard rows) is the value
pub const Kind = enum { keystone, runes, rune, shards, shard, spells, start, boots, core2, core3, item4, item5, item6, skills, skill_path, opponent };

/// Each kind's URL code, in Kind's order (`lk=ks8010,vs86`)
const codes = [_][]const u8{ "ks", "rp", "ru", "sh", "sd", "sp", "st", "bo", "c2", "c3", "i4", "i5", "i6", "mo", "lv", "vs" };

comptime {
    std.debug.assert(codes.len == std.enums.values(Kind).len);
}

pub const Value = struct {
    len: u8,
    v: [builds.max_values]u32,

    pub fn of(v: []const u32) Value {
        var x: Value = .{ .len = @intCast(v.len), .v = @splat(0) };
        @memcpy(x.v[0..v.len], v);
        return x;
    }

    fn slice(x: *const Value) []const u32 {
        return x.v[0..x.len];
    }
};

/// At most one lock per kind: a new one in a kind replaces the old
pub const Locks = struct {
    by: std.EnumArray(Kind, ?Value) = .initFill(null),

    pub fn any(l: *const Locks) bool {
        for (l.by.values) |x| if (x != null) return true;
        return false;
    }

    /// The `lk` query's value: comma-separated, each a kind's code and its values joined
    /// by dots. null when malformed, a kind twice or a value too long
    pub fn parse(s: []const u8) ?Locks {
        var l: Locks = .{};
        if (s.len == 0) return l;
        var it = std.mem.splitScalar(u8, s, ',');
        while (it.next()) |part| {
            if (part.len < 3) return null;
            const kind: Kind = for (codes, 0..) |c, i| {
                if (std.mem.eql(u8, c, part[0..2])) break @fromBackingInt(@intCast(i));
            } else return null;
            if (l.by.get(kind) != null) return null;
            var x: Value = .{ .len = 0, .v = @splat(0) };
            var vs = std.mem.splitScalar(u8, part[2..], '.');
            while (vs.next()) |v| {
                if (x.len == builds.max_values) return null;
                x.v[x.len] = std.fmt.parseInt(u32, v, 10) catch return null;
                x.len += 1;
            }
            l.by.set(kind, x);
        }
        return l;
    }

    /// As `parse` reads it, kinds in Kind's order: one URL per lock set, for caches
    pub fn format(l: *const Locks, w: *std.Io.Writer) std.Io.Writer.Error!void {
        var first = true;
        for (std.enums.values(Kind)) |kind| {
            const x = l.by.get(kind) orelse continue;
            if (!first) try w.writeByte(',');
            first = false;
            try w.writeAll(codes[@backingInt(kind)]);
            for (x.slice(), 0..) |v, i| try w.print("{s}{d}", .{ if (i > 0) "." else "", v });
        }
    }

    /// Whether the row holds to every lock
    pub fn match(l: *const Locks, r: *const lockrows.Row, d: *const ddragon.BuildData) bool {
        for (std.enums.values(Kind)) |kind| {
            const want = l.by.get(kind) orelse continue;
            if (!holds(kind, want.slice(), r, d)) return false;
        }
        return true;
    }
};

/// As builds.Builder.addPlayer reads the row's value of `kind`
fn holds(kind: Kind, want: []const u32, r: *const lockrows.Row, d: *const ddragon.BuildData) bool {
    const p = r.seat.p;
    const eql = std.mem.eql;
    switch (kind) {
        .opponent => return want.len == 1 and p.opponent != 0 and p.opponent == want[0],
        .keystone => return want.len == 1 and p.keystone != 0 and p.keystone == want[0],
        .runes => return p.keystone != 0 and eql(u32, want, &.{
            p.primary,  p.keystone,  p.perks[0],                   p.perks[1],
            p.perks[2], p.secondary, @min(p.perks[3], p.perks[4]), @max(p.perks[3], p.perks[4]),
        }),
        .rune => return p.keystone != 0 and want.len == 1 and want[0] != 0 and (p.keystone == want[0] or std.mem.findScalar(u32, &p.perks, want[0]) != null),
        .shards => return p.shards[0] != 0 and eql(u32, want, &p.shards),
        .shard => return p.shards[0] != 0 and want.len == 2 and want[0] < p.shards.len and want[1] != 0 and p.shards[want[0]] == want[1],
        .spells => return p.spells[0] != 0 and eql(u32, want, &.{ @min(p.spells[0], p.spells[1]), @max(p.spells[0], p.spells[1]) }),
        else => {},
    }
    const k = r.seat.k orelse return false;
    switch (kind) {
        .start => {
            if (k.start_overflow or k.start_len == 0) return false;
            var start = k.start;
            std.mem.sort(u32, start[0..k.start_len], {}, std.sort.asc(u32));
            return eql(u32, want, start[0..k.start_len]);
        },
        .boots => {
            if (k.boots == 0 and k.core_len < 2) return false;
            const boots = if (k.boots != 0) d.bootsOf(k.boots) orelse 0 else 0;
            return want.len == 1 and want[0] == boots;
        },
        .core2 => return k.core_len >= 2 and eql(u32, want, k.core[0..2]),
        .core3 => return k.core_len >= 3 and eql(u32, want, k.core[0..3]),
        .item4, .item5, .item6 => {
            const i: usize = @backingInt(kind) - @backingInt(Kind.item4) + 3;
            return k.core_len > i and want.len == 1 and k.core[i] == want[0];
        },
        .skills => return if (k.skillOrder()) |o| eql(u32, want, &o) else false,
        .skill_path => return if (k.skillPath()) |path| eql(u32, want, &path) else false,
        else => unreachable,
    }
}

/// Which rows a view counts (builds.Set's slice and rank floor)
pub const Filter = struct {
    /// Table.dicts.platforms code; null for every platform
    platform: ?u8 = null,
    /// Unix seconds: rows that started before are out
    since: u32 = 0,
    /// Table.dicts.patches code; null for every patch
    patch: ?u8 = null,
    /// Lowest Seat.rank counted (a store.schema.tiers index); null counts every row
    floor: ?u8 = null,

    fn takes(f: Filter, r: *const lockrows.Row) bool {
        if (f.platform) |x| if (r.platform != x) return false;
        if (f.patch) |x| if (r.patch != x) return false;
        if (r.start < f.since) return false;
        if (f.floor) |lowest| if (r.seat.rank == null or r.seat.rank.? > lowest) return false;
        return true;
    }
};

/// Counts `block`'s rows that `f` takes and hold to `locks` into `b`, as
/// builds.addSeats does the games of a set
pub fn count(b: *builds.Builder, t: *const lockrows.Table, block: *const lockrows.Block, f: Filter, locks: *const Locks) !void {
    var it: lockrows.Rows = .{ .t = t, .b = block };
    while (it.next()) |r| {
        if (!f.takes(&r) or !locks.match(&r, &t.build)) continue;
        b.games += 1;
        b.timelines += @intFromBool(r.seat.k != null);
        try b.addPlayer(r.seat.p, r.seat.k, &t.build);
    }
}

/// `champion` in `role` under `f` and `locks` as a builds File in `arena`, with its rune
/// pages by reach, items by lead and builds by keystone as builds --site makes them (no
/// matchups); null when the table has no such block
pub fn file(gpa: Allocator, arena: Allocator, t: *const lockrows.Table, champion: u32, role: Role, f: Filter, locks: *const Locks, o: builds.Options, label: []const u8, min_tier: []const u8) !?builds.File {
    const block = t.block(champion, role) orelse return null;
    var b: builds.Builder = .{ .gpa = gpa, .max_keys = @max(o.max_keys, 2) };
    defer b.deinit();
    try b.countSplits(o.min_split_games);
    try count(&b, t, block, f, locks);
    return try b.file(arena, &t.build, label, min_tier, o.rows);
}

test "locks parse and format back" {
    const l = Locks.parse("vs86,ks8010,c23071.6333").?;
    try std.testing.expectEqual(8010, l.by.get(.keystone).?.v[0]);
    try std.testing.expectEqualSlices(u32, &.{ 3071, 6333 }, l.by.get(.core2).?.slice());
    var buf: [64]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try l.format(&w);
    try std.testing.expectEqualStrings("ks8010,c23071.6333,vs86", w.buffered());
    try std.testing.expect(Locks.parse("").?.any() == false);
    for ([_][]const u8{ "ks", "xx1", "ks1,ks2", "ks1.", "ksa", "lv1.2.3.4.5.6.7.8.9" }) |bad| try std.testing.expectEqual(null, Locks.parse(bad));
}
