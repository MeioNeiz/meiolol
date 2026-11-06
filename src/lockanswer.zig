//! Lock answers (docs/plan/ui/champion-locks.md L2): a champion-role's lock rows under a
//! view and a stack of locks, counted into the builds File the build panel reads, so an
//! answer without locks is the champion-role's build of builds --site. Answers count an
//! Index (each block's rows coded once, at load) in arrays; `reference` counts the rows
//! with builds.Builder, which tests and the bench hold the answers to

const std = @import("std");
const core = @import("core");
const builds = @import("builds.zig");
const ddragon = @import("ddragon.zig");
const lockrows = @import("lockrows.zig");
const par = @import("par.zig");

const Allocator = std.mem.Allocator;
const Role = core.Role;
const Count = builds.Count;
const Value = builds.Value;
const Values = std.EnumArray(builds.Kind, ?Value);

/// What a lock holds to, as the build file's kinds plus the lane opponent, its reach (1
/// melee, 2 ranged: ddragon Reach + 1) and its damage (1 AD, 2 AP: Filter.damage). `rune`
/// and `shard` hold when any of the page's runes (shard rows) is the value
pub const Kind = enum { keystone, runes, rune, shards, shard, spells, start, boots, core2, core3, item4, item5, item6, skills, skill_path, opponent, reach, damage };

/// Each kind's URL code, in Kind's order (`lk=ks8010,vs86`)
pub const codes = [_][]const u8{ "ks", "rp", "ru", "sh", "sd", "sp", "st", "bo", "c2", "c3", "i4", "i5", "i6", "mo", "lv", "vs", "vr", "vd" };

comptime {
    std.debug.assert(codes.len == std.enums.values(Kind).len);
}

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

    /// Whether the row holds to every lock, `d` its table's
    pub fn match(l: *const Locks, r: *const lockrows.Row, vals: *const Values, d: *const ddragon.BuildData, f: *const Filter) bool {
        const opp = r.seat.p.opponent;
        for (std.enums.values(Kind)) |kind| {
            const want = l.by.get(kind) orelse continue;
            const one = want.len == 1 and opp != 0;
            const ok = switch (kind) {
                .opponent => one and opp == want.v[0],
                .reach => one and if (d.reachOf(opp)) |x| @as(u32, @backingInt(x)) + 1 == want.v[0] else false,
                .damage => one and want.v[0] != 0 and f.damageOf(opp) == want.v[0],
                else => if (vals.get(source(kind))) |v| holds(kind, want.slice(), &v) else false,
            };
            if (!ok) return false;
        }
        return true;
    }
};

/// The builds kind whose value a lock of `kind` reads (none for the lane opponent's)
fn source(kind: Kind) builds.Kind {
    return switch (kind) {
        .keystone, .rune => .runes,
        .shard => .shards,
        .opponent, .reach, .damage => unreachable,
        inline else => |k| @field(builds.Kind, @tagName(k)),
    };
}

/// Whether `v`, the row's value of source(kind), holds to a lock of `kind` on `want`
fn holds(kind: Kind, want: []const u32, v: *const Value) bool {
    return switch (kind) {
        .keystone => want.len == 1 and v.v[1] == want[0],
        .rune => want.len == 1 and want[0] != 0 and std.mem.findScalar(u32, &builds.runesIn(v.slice()), want[0]) != null,
        .shard => want.len == 2 and want[0] < 3 and want[1] != 0 and v.v[want[0]] == want[1],
        else => std.mem.eql(u32, want, v.slice()),
    };
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
    /// Per champion id its damage for Kind.damage: 0 neither or unknown, 1 AD, 2 AP. Empty:
    /// no row holds a damage lock
    damage: []const u8 = &.{},

    fn damageOf(f: *const Filter, champion: u32) u8 {
        return if (champion < f.damage.len) f.damage[champion] else 0;
    }

    fn takes(f: Filter, start: u32, platform: u8, patch: u8, rank: ?u8) bool {
        if (f.platform) |x| if (platform != x) return false;
        if (f.patch) |x| if (patch != x) return false;
        if (start < f.since) return false;
        if (f.floor) |lowest| if (rank == null or rank.? > lowest) return false;
        return true;
    }
};

/// `champion` in `role` under `f` and `locks` counted by builds.Builder from the decoded
/// rows, as builds.addSeats counts a set's games; null when the table has no such block
pub fn reference(gpa: Allocator, arena: Allocator, t: *const lockrows.Table, champion: u32, role: Role, f: Filter, locks: *const Locks, o: builds.Options, label: []const u8, min_tier: []const u8) !?builds.File {
    const block = t.block(champion, role) orelse return null;
    var b = try builder(gpa, o);
    defer b.deinit();
    var rest = locks.*;
    rest.by.set(.reach, null);
    rest.by.set(.damage, null);
    var it: lockrows.Rows = .{ .t = t, .b = block };
    while (it.next()) |r| {
        if (!f.takes(r.start, r.platform, r.patch, r.seat.rank)) continue;
        const vals = builds.valuesOf(r.seat.p, r.seat.k, &t.build);
        if (!rest.match(&r, &vals, &t.build, &f)) continue;
        if (!locks.match(&r, &vals, &t.build, &f)) {
            try b.addOpponent(r.seat.p);
            continue;
        }
        b.games += 1;
        b.timelines += @intFromBool(r.seat.k != null);
        try b.addPlayer(r.seat.p, r.seat.k, &t.build);
    }
    return try b.file(arena, &t.build, label, min_tier, o.rows);
}

/// With its rune pages by reach, items by lead and builds by keystone, as builds --site
/// counts (no matchups)
fn builder(gpa: Allocator, o: builds.Options) !builds.Builder {
    var b: builds.Builder = .{ .gpa = gpa, .max_keys = @max(o.max_keys, 2) };
    errdefer b.deinit();
    try b.countSplits(o.min_split_games);
    return b;
}

/// Kinds a row holds one value of, coded per block. keystone and rune follow from runes,
/// shard from shards
const coded = [_]builds.Kind{ .runes, .shards, .spells, .start, .boots, .core2, .core3, .item4, .item5, .item6, .skills, .skill_start, .skill_path };

fn codedAt(kind: builds.Kind) ?usize {
    return std.mem.findScalar(builds.Kind, &coded, kind);
}

/// File.Minute slots: 0 boots, 1 to 6 the finished items
const slots = 7;
const no_rank = 0xff;

/// A row coded: the view's columns, a code per coded kind (0 for none) and the splits
/// builds.Builder counts by
const Coded = struct {
    start: u32,
    opponent: u16,
    platform: u8,
    patch: u8,
    /// Seat.rank, no_rank for none
    rank: u8,
    won: bool,
    picks: bool,
    /// The lane opponent's ddragon Reach + 1; 0 without an opponent or reach
    reach: u8,
    /// builds.Lead + 1, 0 for neither
    lead: u8,
    /// Block.keystones index + 1, 0 for none
    keystone: u8,
    /// Bit i: the team took builds.First i first
    firsts: u8,
    /// Table.dicts.champions code of each ally (0) and enemy (1) by role, 0 for none
    others: [2][Role.count]u8,
    code: [coded.len]u16,
    /// Per slot, Block.items index + 1 (0 for none) and the minute bucket it was bought in
    item: [slots]u16,
    minute: [slots]u8,
};

/// One block's rows coded
const Block = struct {
    rows: []const Coded,
    /// Per coded kind, code c's value at c - 1
    values: [coded.len][]const Value,
    keystones: []const u32,
    items: []const u32,
    /// Past the highest lane opponent's id
    opponents: u32 = 0,

    fn deinit(b: *Block, gpa: Allocator) void {
        gpa.free(b.rows);
        for (b.values) |v| gpa.free(v);
        gpa.free(b.keystones);
        gpa.free(b.items);
    }
};

/// A Table's blocks coded, in its blocks' order. Coding is ~1 us a row, spread over the
/// CPUs; answers then count in arrays, ~15x faster than builds.Builder's hash maps
pub const Index = struct {
    gpa: Allocator,
    blocks: []Block,

    pub fn init(gpa: Allocator, io: std.Io, t: *const lockrows.Table) !Index {
        const champs = try champCodes(gpa, t);
        defer gpa.free(champs);
        const blocks = try gpa.alloc(Block, t.blocks.len);
        errdefer gpa.free(blocks);
        const done = try gpa.alloc(bool, t.blocks.len);
        defer gpa.free(done);
        @memset(done, false);
        errdefer for (blocks, done) |*b, ok| if (ok) b.deinit(gpa);
        // Largest first, so the last few workers don't each wait on a big one
        const order = try gpa.alloc(usize, t.blocks.len);
        defer gpa.free(order);
        for (order, 0..) |*x, i| x.* = i;
        std.mem.sort(usize, order, t.blocks, struct {
            fn f(bs: []const lockrows.Block, a: usize, b: usize) bool {
                return bs[a].rows > bs[b].rows;
            }
        }.f);
        try par.forEach(io, order.len, Ctx{ .gpa = gpa, .t = t, .champs = champs, .order = order, .blocks = blocks, .done = done }, Ctx.run);
        return .{ .gpa = gpa, .blocks = blocks };
    }

    const Ctx = struct {
        gpa: Allocator,
        t: *const lockrows.Table,
        champs: []const u8,
        order: []const usize,
        blocks: []Block,
        done: []bool,

        fn run(c: Ctx, i: usize) !void {
            const at = c.order[i];
            c.blocks[at] = try code(c.gpa, c.t, c.champs, &c.t.blocks[at]);
            c.done[at] = true;
        }
    };

    pub fn deinit(x: *Index) void {
        for (x.blocks) |*b| b.deinit(x.gpa);
        x.gpa.free(x.blocks);
    }
};

fn Dict(comptime T: type) type {
    return struct {
        map: std.AutoArrayHashMapUnmanaged(T, void) = .empty,

        /// 1.. for each new value
        fn code(d: *@This(), gpa: Allocator, comptime C: type, x: T) !C {
            const e = try d.map.getOrPut(gpa, x);
            return std.math.cast(C, e.index + 1) orelse error.TooManyCodes;
        }

        fn take(d: *const @This(), gpa: Allocator) ![]const T {
            return gpa.dupe(T, d.map.keys());
        }
    };
}

/// Table.dicts.champions' codes by champion id
fn champCodes(gpa: Allocator, t: *const lockrows.Table) ![]u8 {
    var most: u32 = 0;
    for (t.dicts.champions) |id| most = @max(most, id);
    const out = try gpa.alloc(u8, @as(usize, most) + 1);
    @memset(out, 0);
    for (t.dicts.champions, 1..) |id, c| out[id] = @intCast(c);
    return out;
}

fn code(gpa: Allocator, t: *const lockrows.Table, champs: []const u8, block: *const lockrows.Block) !Block {
    const d = &t.build;
    var values: [coded.len]Dict(Value) = @splat(.{});
    var keystones: Dict(u32) = .{};
    var items: Dict(u32) = .{};
    defer {
        for (&values) |*v| v.map.deinit(gpa);
        keystones.map.deinit(gpa);
        items.map.deinit(gpa);
    }
    const rows = try gpa.alloc(Coded, block.rows);
    errdefer gpa.free(rows);
    var it: lockrows.Rows = .{ .t = t, .b = block };
    for (rows) |*out| {
        const r = it.next().?;
        const p = r.seat.p;
        const vals = builds.valuesOf(p, r.seat.k, d);
        out.* = .{
            .start = r.start,
            .opponent = std.math.cast(u16, p.opponent) orelse return error.TooManyCodes,
            .platform = r.platform,
            .patch = r.patch,
            .rank = r.seat.rank orelse no_rank,
            .won = p.won,
            .picks = r.seat.k != null,
            .reach = if (p.opponent == 0) 0 else if (d.reachOf(p.opponent)) |x| @as(u8, @backingInt(x)) + 1 else 0,
            .lead = if (builds.leadOf(p.lead)) |x| @as(u8, @backingInt(x)) + 1 else 0,
            .keystone = if (p.keystone != 0 and p.keystone <= std.math.maxInt(u16)) try keystones.code(gpa, u8, p.keystone) else 0,
            .firsts = 0,
            .others = undefined,
            .code = @splat(0),
            .item = @splat(0),
            .minute = @splat(0),
        };
        for (&out.others, [_][Role.count]u32{ r.allies, r.enemies }) |*cs, ids| {
            for (cs, ids) |*c, id| c.* = if (id < champs.len) champs[id] else 0;
        }
        for (coded, &out.code, &values) |kind, *c, *dict| {
            if (vals.get(kind)) |v| c.* = try dict.code(gpa, u16, v);
        }
        const k = r.seat.k orelse continue;
        if (k.boots != 0) if (d.bootsOf(k.boots)) |boots| {
            out.item[0] = try items.code(gpa, u16, boots);
            out.minute[0] = @intCast(builds.minuteOf(k.boots_ms));
        };
        for (k.core[0..k.core_len], k.core_ms[0..k.core_len], 1..) |item, ms, slot| {
            out.item[slot] = try items.code(gpa, u16, item);
            out.minute[slot] = @intCast(builds.minuteOf(ms));
        }
        for (k.firsts, 0..) |on, i| out.firsts |= @as(u8, @intFromBool(on)) << @intCast(i);
    }
    std.debug.assert(it.next() == null);
    var b: Block = .{ .rows = rows, .values = undefined, .keystones = &.{}, .items = &.{} };
    for (rows) |r| b.opponents = @max(b.opponents, @as(u32, r.opponent) + 1);
    var n: usize = 0;
    errdefer for (b.values[0..n]) |v| gpa.free(v);
    for (&b.values, &values) |*out, *dict| {
        out.* = try dict.take(gpa);
        n += 1;
    }
    b.keystones = try keystones.take(gpa);
    errdefer gpa.free(b.keystones);
    b.items = try items.take(gpa);
    return b;
}

/// The locks on a block's codes: per coded kind the codes every lock on it allows
const Match = struct {
    allow: [coded.len]?std.DynamicBitSetUnmanaged = @splat(null),
    opponent: ?u32 = null,
    reach: ?u32 = null,
    /// Filter.damage's value the lane opponent must have
    damage: ?u32 = null,
    table: []const u8 = &.{},

    fn init(arena: Allocator, b: *const Block, locks: *const Locks, f: *const Filter) !Match {
        var m: Match = .{ .table = f.damage };
        for (std.enums.values(Kind)) |kind| {
            const want = locks.by.get(kind) orelse continue;
            // No row holds a value of 0 here (no opponent, reach or damage) or a lock of two
            const one = if (want.len == 1 and want.v[0] != 0) want.v[0] else std.math.maxInt(u32);
            switch (kind) {
                .opponent => m.opponent = one,
                .reach => m.reach = one,
                .damage => m.damage = one,
                else => {},
            }
            if (kind == .opponent or kind == .reach or kind == .damage) continue;
            const j = codedAt(source(kind)).?;
            const vs = b.values[j];
            if (m.allow[j] == null) {
                m.allow[j] = try .initFull(arena, vs.len + 1);
                m.allow[j].?.unset(0);
            }
            for (vs, 1..) |*v, c| if (!holds(kind, want.slice(), v)) m.allow[j].?.unset(c);
        }
        return m;
    }

    fn takes(m: *const Match, r: *const Coded) bool {
        return m.rest(r) and m.lane(r);
    }

    /// Every lock but the lane opponent's reach and damage
    fn rest(m: *const Match, r: *const Coded) bool {
        if (m.opponent) |x| if (r.opponent != x) return false;
        for (m.allow, r.code) |a, c| if (a) |set| if (!set.isSet(c)) return false;
        return true;
    }

    /// The lane opponent's reach and damage locks
    fn lane(m: *const Match, r: *const Coded) bool {
        if (m.reach) |x| if (r.reach != x) return false;
        if (m.damage) |x| if (r.opponent == 0 or r.opponent >= m.table.len or m.table[r.opponent] != x) return false;
        return true;
    }
};

/// What builds.Builder splits a player's counts by: Split.none role-wide, then reach,
/// lead and keystone groups
const Split = enum { none, reach, lead, keystone };

/// The coded kinds each split counts, as builds.Builder.counts
const split_kinds = blk: {
    var out: [4][]const usize = undefined;
    for (std.enums.values(Split), &out) |split, *o| {
        const list: []const builds.Kind = switch (split) {
            .none => &coded,
            .reach => &builds.reach_kinds,
            .lead => &builds.lead_kinds,
            .keystone => &builds.keystone_kinds,
        };
        var at: []const usize = &.{};
        for (coded, 0..) |kind, j| {
            if (std.mem.findScalar(builds.Kind, list, kind) != null) at = at ++ .{j};
        }
        const fixed = at[0..at.len].*;
        o.* = &fixed;
    }
    break :blk out;
};

/// A block's counts under one answer's view and locks: per group (0 role-wide, 1 and 2
/// by reach, 3 and 4 by lead, then one per keystone) its players and each counted coded
/// kind's codes
const Counts = struct {
    b: *const Block,
    games: u32 = 0,
    timelines: u32 = 0,
    totals: []Count,
    /// Per group and coded kind, where its codes' counts start in `counts`; null when not
    /// counted
    at: [][coded.len]?u32,
    counts: []Count,
    minutes: []builds.Minutes,
    /// Role-wide, by lane opponent id
    opponents: []Count,
    first_item: [builds.minute_buckets]Count = @splat(.{}),
    firsts: [1 + builds.firsts_len]Count = @splat(.{}),

    const first_keystone = 5;

    fn splitOf(g: usize) Split {
        return switch (g) {
            0 => .none,
            1, 2 => .reach,
            3, 4 => .lead,
            else => .keystone,
        };
    }

    fn init(arena: Allocator, b: *const Block) !Counts {
        const groups = first_keystone + b.keystones.len;
        const at = try arena.alloc([coded.len]?u32, groups);
        var n: u32 = 0;
        for (at, 0..) |*a, g| {
            a.* = @splat(null);
            for (split_kinds[@backingInt(splitOf(g))]) |j| {
                a[j] = n;
                n += @intCast(b.values[j].len + 1);
            }
        }
        const totals = try arena.alloc(Count, groups);
        @memset(totals, .{});
        const counts = try arena.alloc(Count, n);
        @memset(counts, .{});
        const minutes = try arena.alloc(builds.Minutes, slots * (b.items.len + 1));
        @memset(minutes, @splat(0));
        const opponents = try arena.alloc(Count, b.opponents);
        @memset(opponents, .{});
        return .{ .b = b, .totals = totals, .at = at, .counts = counts, .minutes = minutes, .opponents = opponents };
    }

    fn add(n: *Counts, r: *const Coded) void {
        n.games += 1;
        n.timelines += @intFromBool(r.picks);
        n.group(0, .none, r);
        if (r.opponent != 0 and r.reach != 0) n.group(r.reach, .reach, r);
        if (r.lead != 0) n.group(2 + r.lead, .lead, r);
        if (r.keystone != 0) n.group(first_keystone - 1 + @as(usize, r.keystone), .keystone, r);
        if (!r.picks) return;
        for (r.item, r.minute, 0..) |item, minute, slot| {
            if (item != 0) n.minutes[slot * (n.b.items.len + 1) + item][minute] += 1;
        }
        if (r.item[1] != 0) bump(&n.first_item[r.minute[1]], r.won);
        bump(&n.firsts[0], r.won);
        for (n.firsts[1..], 0..) |*x, i| if (r.firsts >> @intCast(i) & 1 != 0) bump(x, r.won);
    }

    /// In its lane opponent's counts alone (builds.Builder.addOpponent)
    fn opponent(n: *Counts, r: *const Coded) void {
        if (r.opponent != 0) bump(&n.opponents[r.opponent], r.won);
    }

    fn group(n: *Counts, g: usize, comptime split: Split, r: *const Coded) void {
        bump(&n.totals[g], r.won);
        inline for (split_kinds[@backingInt(split)]) |j| {
            if (r.code[j] != 0) bump(&n.counts[n.at[g][j].? + r.code[j]], r.won);
        }
    }

    fn bump(c: *Count, won: bool) void {
        c.games += 1;
        c.wins += @intFromBool(won);
    }

    /// Into `b` as builds.Builder would have counted them: each group's top `rows`
    /// options per kind (every rune and shard), which are all its file can show
    fn fill(n: *const Counts, arena: Allocator, b: *builds.Builder, champion: u32, role: Role, rows: usize) !void {
        b.games = n.games;
        b.timelines = n.timelines;
        const buf = try arena.alloc(Top.Option, rows);
        for (n.totals, n.at, 0..) |all, at, g| {
            if (all.games == 0) continue;
            const split = splitOf(g);
            const into, const opp: u16 = switch (split) {
                .none => .{ b, 0 },
                .reach => .{ b.reach.?, @intCast(g) },
                .lead => .{ b.lead.?, @intCast(g - 2) },
                .keystone => .{ b.keystone.?, @intCast(n.b.keystones[g - first_keystone]) },
            };
            try into.putTotal(champion, role, opp, null, all);
            for (split_kinds[@backingInt(split)]) |j| {
                const kind = coded[j];
                const counts = n.counts[at[j].?..][0 .. n.b.values[j].len + 1];
                var sum: Count = .{};
                var top: Top = .{ .buf = buf };
                for (counts[1..], n.b.values[j]) |c, *v| if (c.games > 0) {
                    sum.games += c.games;
                    sum.wins += c.wins;
                    top.add(v, c);
                };
                if (sum.games == 0) continue;
                try into.putTotal(champion, role, opp, kind, sum);
                for (top.items()) |o| try into.putOption(champion, role, opp, kind, o.v.slice(), o.c);
                if (kind == .runes) {
                    if (split == .none) try putEach(arena, into, champion, role, opp, .keystone, sum, counts[1..], n.b.values[j]);
                    try putEach(arena, into, champion, role, opp, .rune, sum, counts[1..], n.b.values[j]);
                } else if (kind == .shards) try putEach(arena, into, champion, role, opp, .shard, sum, counts[1..], n.b.values[j]);
            }
        }
        for (n.opponents, 0..) |c, opp| if (c.games > 0) try b.putOpponent(champion, role, @intCast(opp), c);
        if (n.timelines == 0) return;
        for (0..slots) |slot| for (n.b.items, 1..) |item, c| {
            const hist = n.minutes[slot * (n.b.items.len + 1) + c];
            if (std.mem.allEqual(u32, &hist, 0)) continue;
            try b.putMinutes(champion, role, @intCast(slot), item, hist);
        };
        for (n.first_item) |x| if (x.games > 0) {
            try b.putFirstItem(champion, role, n.first_item);
            break;
        };
        try b.putFirsts(champion, role, n.firsts);
    }
};

/// keystone, rune or shard from the runes (shards) values' counts: each option once per
/// player holding it, as Builder.addEach (rune 0 or shard 0 skipped)
fn putEach(arena: Allocator, b: *builds.Builder, champion: u32, role: Role, opp: u16, kind: builds.Kind, total: Count, counts: []const Count, values: []const Value) !void {
    var by: std.AutoArrayHashMapUnmanaged(Value, Count) = .empty;
    for (counts, values) |c, *v| if (c.games > 0) {
        var each: [6]Value = undefined;
        var len: usize = 0;
        switch (kind) {
            .keystone => {
                each[0] = .of(&.{v.v[1]});
                len = 1;
            },
            .rune => for (builds.runesIn(v.slice())) |x| if (x != 0) {
                each[len] = .of(&.{x});
                len += 1;
            },
            .shard => for (v.v[0..3], 0..) |x, row| if (x != 0) {
                each[len] = .of(&.{ @intCast(row), x });
                len += 1;
            },
            else => unreachable,
        }
        for (each[0..len]) |x| {
            const e = try by.getOrPutValue(arena, x, .{});
            e.value_ptr.games += c.games;
            e.value_ptr.wins += c.wins;
        }
    };
    try b.putTotal(champion, role, opp, kind, total);
    for (by.keys(), by.values()) |*v, c| try b.putOption(champion, role, opp, kind, v.slice(), c);
}

/// The most played options, ties to the lower value, as Builder.file orders them
const Top = struct {
    buf: []Option,
    len: usize = 0,

    const Option = struct { v: *const Value, c: Count };

    fn before(x: Option, y: Option) bool {
        if (x.c.games != y.c.games) return x.c.games > y.c.games;
        return std.mem.order(u32, &x.v.v, &y.v.v) == .lt;
    }

    fn add(t: *Top, v: *const Value, c: Count) void {
        const o: Option = .{ .v = v, .c = c };
        const cap = t.buf.len;
        if (cap == 0 or t.len == cap and !before(o, t.buf[t.len - 1])) return;
        var i = if (t.len < cap) t.len else t.len - 1;
        while (i > 0 and before(o, t.buf[i - 1])) : (i -= 1) t.buf[i] = t.buf[i - 1];
        t.buf[i] = o;
        if (t.len < cap) t.len += 1;
    }

    fn items(t: *const Top) []const Option {
        return t.buf[0..t.len];
    }
};

/// `champion` in `role` under `f` and `locks` as a builds File in `arena`, with its rune
/// pages by reach, items by lead and builds by keystone as builds --site makes them (no
/// matchups); null when the table has no such block. Equal to `reference`'s
pub fn file(gpa: Allocator, arena: Allocator, t: *const lockrows.Table, x: *const Index, champion: u32, role: Role, f: Filter, locks: *const Locks, o: builds.Options, label: []const u8, min_tier: []const u8) !?builds.File {
    const bi = t.blockIndex(champion, role) orelse return null;
    const block = &x.blocks[bi];
    const m: Match = try .init(arena, block, locks, &f);
    var n: Counts = try .init(arena, block);
    for (block.rows) |*r| {
        if (!f.takes(r.start, r.platform, r.patch, if (r.rank == no_rank) null else r.rank) or !m.rest(r)) continue;
        n.opponent(r);
        if (m.lane(r)) n.add(r);
    }
    var b = try builder(gpa, o);
    defer b.deinit();
    try n.fill(arena, &b, champion, role, o.rows);
    return try b.file(arena, &t.build, label, min_tier, o.rows);
}

/// `champion` in `role`'s games and wins under `f` and `locks`; null when the table has
/// no such block
pub fn count(arena: Allocator, t: *const lockrows.Table, x: *const Index, champion: u32, role: Role, f: Filter, locks: *const Locks) !?Count {
    const bi = t.blockIndex(champion, role) orelse return null;
    const block = &x.blocks[bi];
    const m: Match = try .init(arena, block, locks, &f);
    var out: Count = .{};
    for (block.rows) |*r| {
        if (!f.takes(r.start, r.platform, r.patch, if (r.rank == no_rank) null else r.rank) or !m.takes(r)) continue;
        Counts.bump(&out, r.won);
    }
    return out;
}

/// A champion-role's games under a view and locks, and with each ally (`by[0]`) and
/// against each enemy (`by[1]`) by role, indexed by Table.dicts.champions code
pub const Matchups = struct {
    all: Count = .{},
    by: [2][Role.count][]Count,
};

/// `champion` in `role` under `f` and `locks`, its games with and against every other
/// champion, in `arena`; null when the table has no such block
pub fn matchups(arena: Allocator, t: *const lockrows.Table, x: *const Index, champion: u32, role: Role, f: Filter, locks: *const Locks) !?Matchups {
    const bi = t.blockIndex(champion, role) orelse return null;
    const block = &x.blocks[bi];
    const m: Match = try .init(arena, block, locks, &f);
    var out: Matchups = .{ .by = undefined };
    for (&out.by) |*side| for (side) |*by| {
        by.* = try arena.alloc(Count, t.dicts.champions.len + 1);
        @memset(by.*, .{});
    };
    for (block.rows) |*r| {
        if (!f.takes(r.start, r.platform, r.patch, if (r.rank == no_rank) null else r.rank) or !m.takes(r)) continue;
        Counts.bump(&out.all, r.won);
        for (r.others, &out.by) |cs, *side| for (cs, side) |c, by| {
            if (c != 0) Counts.bump(&by[c], r.won);
        };
    }
    return out;
}

/// A keystone, finished item or lane opponent's games under the view (`all`), and under
/// the view and the locks too
pub const Choice = struct { id: u32, all: Count = .{}, locked: Count = .{} };

/// A champion-role's keystones, finished items (any slot, once a game) and lane opponents,
/// each list by games under the view, most first
pub const Choices = struct {
    all: Count = .{},
    locked: Count = .{},
    keystones: []Choice,
    items: []Choice,
    opponents: []Choice,
};

/// `champion` in `role`'s Choices under `f` and `locks`, in `arena`; null as `count`
pub fn choices(arena: Allocator, t: *const lockrows.Table, x: *const Index, champion: u32, role: Role, f: Filter, locks: *const Locks) !?Choices {
    const bi = t.blockIndex(champion, role) orelse return null;
    const block = &x.blocks[bi];
    const m: Match = try .init(arena, block, locks, &f);
    const keystones = try arena.alloc(Choice, block.keystones.len);
    for (keystones, block.keystones) |*o, id| o.* = .{ .id = id };
    const items = try arena.alloc(Choice, block.items.len);
    for (items, block.items) |*o, id| o.* = .{ .id = id };
    var opponents: std.AutoArrayHashMapUnmanaged(u16, Choice) = .empty;
    var out: Choices = .{ .keystones = keystones, .items = items, .opponents = &.{} };
    for (block.rows) |*r| {
        if (!f.takes(r.start, r.platform, r.patch, if (r.rank == no_rank) null else r.rank)) continue;
        const locked = m.takes(r);
        const bump = struct {
            fn add(o: *Choice, won: bool, in: bool) void {
                Counts.bump(&o.all, won);
                if (in) Counts.bump(&o.locked, won);
            }
        }.add;
        Counts.bump(&out.all, r.won);
        if (locked) Counts.bump(&out.locked, r.won);
        if (r.keystone != 0) bump(&keystones[r.keystone - 1], r.won, locked);
        // Slot 0 is boots
        for (r.item[1..], 1..) |c, i| {
            if (c == 0 or std.mem.findScalar(u16, r.item[1..i], c) != null) continue;
            bump(&items[c - 1], r.won, locked);
        }
        if (r.opponent != 0) {
            const e = try opponents.getOrPut(arena, r.opponent);
            if (!e.found_existing) e.value_ptr.* = .{ .id = r.opponent };
            bump(e.value_ptr, r.won, locked);
        }
    }
    out.opponents = opponents.values();
    for ([_][]Choice{ out.keystones, out.items, out.opponents }) |list| std.mem.sort(Choice, list, {}, struct {
        fn more(_: void, a: Choice, b: Choice) bool {
            return if (a.all.games != b.all.games) a.all.games > b.all.games else a.id < b.id;
        }
    }.more);
    return out;
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
    try std.testing.expectEqual(2, Locks.parse("vr2,vd1").?.by.get(.reach).?.v[0]);
    for ([_][]const u8{ "ks", "xx1", "ks1,ks2", "ks1.", "ksa", "lv1.2.3.4.5.6.7.8.9" }) |bad| try std.testing.expectEqual(null, Locks.parse(bad));
}
