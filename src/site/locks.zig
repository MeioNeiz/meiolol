//! Champion page lock answers (docs/plan/ui/champion-locks.md): the lock rows table
//! (`meiolol lockrows`) loaded once, and an island's data file counted under a view, a
//! rank and a lock stack. Path `<view dir>data/lock/<island>/<slug>/<role>/<rank>/<lk>.bin`
//! (ui.champpage.lockPath): the lock set is in the path, as nginx caches by path alone

const std = @import("std");
const core = @import("core");
const ui = @import("ui");
const html = @import("html.zig");
const buildblock = @import("buildblock.zig");
const champion = @import("champion.zig");
const builds = @import("../builds.zig");
const lockrows = @import("../lockrows.zig");
const lockanswer = @import("../lockanswer.zig");

const Role = core.Role;
const Counts = core.statsfile.Counts;
const cp = ui.champpage;
const Site = @import("root.zig").Site;
const Champ = @import("root.zig").Champ;

const log = std.log.scoped(.site);

pub const prefix = cp.lock_prefix;

// The page writes lock sets with ui.lockbar's kinds and codes: one list
comptime {
    const ui_kinds = std.meta.fieldNames(ui.lockbar.Kind);
    const kinds = std.meta.fieldNames(lockanswer.Kind);
    std.debug.assert(ui_kinds.len == kinds.len and ui.lockbar.codes.len == lockanswer.codes.len);
    for (ui_kinds, kinds, ui.lockbar.codes, lockanswer.codes) |a, b, c, d| {
        std.debug.assert(std.mem.eql(u8, a, b) and std.mem.eql(u8, c, d));
    }
}

/// The table and its Index, freed together
pub const Answers = struct {
    arena: std.heap.ArenaAllocator,
    table: lockrows.Table,
    index: lockanswer.Index,

    /// null when `path` is missing or another binary's types wrote it
    pub fn load(gpa: std.mem.Allocator, io: std.Io, path: []const u8) !?*Answers {
        const t0 = std.Io.Clock.awake.now(io);
        const x = try gpa.create(Answers);
        errdefer gpa.destroy(x);
        x.arena = .init(gpa);
        errdefer x.arena.deinit();
        const f = std.Io.Dir.cwd().openFile(io, path, .{}) catch |err| switch (err) {
            error.FileNotFound => {
                log.info("{s}: none, no lock answers", .{path});
                x.arena.deinit();
                gpa.destroy(x);
                return null;
            },
            else => return err,
        };
        defer f.close(io);
        var buf: [1 << 20]u8 = undefined;
        var r = f.reader(io, &buf);
        x.table = try lockrows.read(&r.interface, x.arena.allocator()) orelse {
            log.warn("{s}: another format, no lock answers", .{path});
            x.arena.deinit();
            gpa.destroy(x);
            return null;
        };
        x.index = try .init(gpa, io, &x.table);
        log.info("{s}: {d} champion-roles, lock answers ready in {d} ms", .{ path, x.table.blocks.len, t0.durationTo(std.Io.Clock.awake.now(io)).toMilliseconds() });
        return x;
    }

    pub fn deinit(x: *Answers, gpa: std.mem.Allocator) void {
        x.index.deinit();
        x.arena.deinit();
        gpa.destroy(x);
    }
};

/// `rest` (a path under the view's directory, after `prefix`) answered from `s`, the
/// view's site, in `s.arena`; null for a path that names nothing
pub fn answer(s: *const Site, x: *const Answers, gpa: std.mem.Allocator, rest: []const u8) !?[]const u8 {
    const q = parse(rest) orelse return null;
    const ch = s.champBySlug(q.slug) orelse return null;
    var out: std.ArrayList(u8) = .empty;
    switch (q.island) {
        .build => try ui.data.encode(s.arena, cp.BuildData, try build(s, x, gpa, ch, q.role, q.rank, &q.locks) orelse return null, &out),
        .more => try ui.data.encode(s.arena, cp.MoreData, try more(s, x, ch, q.role, q.rank, &q.locks) orelse return null, &out),
    }
    return out.items;
}

/// The champion page's server-rendered lock set: `lk` (the query's) as Locks.format
/// writes it, else null (the page renders unlocked and the island asks for its own)
pub fn pageLocks(lk: []const u8) ?lockanswer.Locks {
    const locks = canonical(lk) orelse return null;
    return if (locks.any()) locks else null;
}

/// `ch`'s build in `r` at rank `k` under `locks`, in `s.arena`; null when the view's
/// patch or region isn't in the table
pub fn build(s: *const Site, x: *const Answers, gpa: std.mem.Allocator, ch: Champ, r: Role, k: cp.Rank, locks: *const lockanswer.Locks) !?cp.BuildData {
    const a = s.arena;
    const t = &x.table;
    const tier = tierOf(k);
    const f = filterOf(s, t, k) orelse return null;
    const base = if (s.view_builds[s.view.index()]) |*b| b else null;
    const label = if (base) |b| b.label else "";
    const file = try lockanswer.file(gpa, a, t, &x.index, @intCast(ch.id), r, f, locks, .{}, label, tier) orelse return null;
    const role = try a.create(cp.BuildRole);
    role.* = .{ .role = champion.uiRole(r) };
    if (file.get(@intCast(ch.id), r)) |b| role.build = try buildblock.data(a, &file, b, ch.name);
    var d: cp.BuildData = .{ .roles = role[0..1] };
    if (locks.by.get(.opponent)) |v| for (s.champs) |o| if (o.id == v.v[0]) {
        d.vs = .{ .id = @intCast(o.id), .name = o.name, .icon = try s.icon(o) };
    };
    return d;
}

/// `ch`'s matchups in `r` at rank `k` under `locks`, as the champion page's MoreData with
/// that one role, in `s.arena`; null as `build`
pub fn more(s: *const Site, x: *const Answers, ch: Champ, r: Role, k: cp.Rank, locks: *const lockanswer.Locks) !?cp.MoreData {
    const a = s.arena;
    const t = &x.table;
    const f = filterOf(s, t, k) orelse return null;
    const m = try lockanswer.matchups(a, t, &x.index, @intCast(ch.id), r, f, locks) orelse return null;
    // Table codes by stats index
    const codes = try a.alloc(u8, s.stats.n);
    @memset(codes, 0);
    for (s.champs) |o| codes[o.c] = for (t.dicts.champions, 1..) |id, c| {
        if (id == o.id) break @intCast(c);
    } else 0;
    // relsOf's order: the lane, other roles' enemies, then allies
    var locked: std.ArrayList([]const Counts) = .empty;
    for ([_]u1{ 1, 1, 0 }, 0..) |side, pass| for (Role.all) |r2| {
        if ((pass == 0) != (r2 == r)) continue;
        const by = m.by[side][@backingInt(r2)];
        const l = try a.alloc(Counts, codes.len);
        // Code 0 (not in the table) counts nothing
        for (l, codes) |*o, c| o.* = .{ .games = by[c].games, .wins = by[c].wins };
        try locked.append(a, l);
    };
    const cr: Counts = .{ .games = m.all.games, .wins = m.all.wins };
    const role = try a.create(cp.MoreRole);
    role.* = .{ .role = champion.uiRole(r), .games = cr.games, .wins = cr.wins, .rels = try champion.relsOf(s, ch, r, cr, locked.items) };
    return .{ .name = ch.name, .slug = ch.slug, .ddragon = s.ddragon_version, .champs = try champion.champsOf(s), .roles = role[0..1] };
}

fn tierOf(k: cp.Rank) []const u8 {
    return if (k == .plat) "PLATINUM" else builds.rank_tiers[@backingInt(k) - 1];
}

/// The rows the view and rank `k` count; null when the view's patch or region isn't in `t`
fn filterOf(s: *const Site, t: *const lockrows.Table, k: cp.Rank) ?lockanswer.Filter {
    return .{
        .platform = if (s.view.region == .euw) codeOf(t.dicts.platforms, s.opts.home) orelse return null else null,
        .patch = if (s.view.period == .patch) codeOf(t.dicts.patches, s.opts.patches[0]) orelse return null else null,
        .since = if (s.view.period == .days30) @intCast(@max(0, @divFloor(s.opts.since_ms, std.time.ms_per_s))) else 0,
        .floor = builds.rankOf(tierOf(k)),
    };
}

/// The islands with lock answers
pub const Island = enum { build, more };

const Query = struct { island: Island, slug: []const u8, role: Role, rank: cp.Rank, locks: lockanswer.Locks };

/// `<island>/<slug>/<role>/<rank>/<lk>.bin`. A lock set must be as Locks.format writes
/// it: one URL, one cached copy
fn parse(rest: []const u8) ?Query {
    var it = std.mem.splitScalar(u8, rest, '/');
    const island = std.meta.stringToEnum(Island, it.next() orelse return null) orelse return null;
    const slug = it.next() orelse return null;
    const role = std.meta.stringToEnum(ui.role.Role, it.next() orelse return null) orelse return null;
    const rank = std.meta.stringToEnum(cp.Rank, it.next() orelse return null) orelse return null;
    const last = it.next() orelse return null;
    if (it.next() != null or !std.mem.endsWith(u8, last, ".bin")) return null;
    const locks = pageLocks(last[0 .. last.len - ".bin".len]) orelse return null;
    return .{ .island = island, .slug = slug, .role = coreRole(role), .rank = rank, .locks = locks };
}

fn canonical(lk: []const u8) ?lockanswer.Locks {
    const locks = lockanswer.Locks.parse(lk) orelse return null;
    var buf: [256]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    locks.format(&w) catch return null;
    return if (std.mem.eql(u8, w.buffered(), lk)) locks else null;
}

fn coreRole(r: ui.role.Role) Role {
    return switch (r) {
        .top => .top,
        .jungle => .jungle,
        .mid => .middle,
        .bot => .bottom,
        .support => .utility,
    };
}

fn codeOf(list: []const []const u8, x: []const u8) ?u8 {
    for (list, 0..) |y, i| if (std.mem.eql(u8, x, y)) return @intCast(i);
    return null;
}

test "lock paths parse only in their one form" {
    const q = parse("build/darius/top/emerald/ks8010,vs86.bin").?;
    try std.testing.expectEqualStrings("darius", q.slug);
    try std.testing.expectEqual(.top, q.role);
    try std.testing.expectEqual(.emerald, q.rank);
    try std.testing.expectEqual(86, q.locks.by.get(.opponent).?.v[0]);
    try std.testing.expectEqual(.more, parse("more/darius/top/plat/ks8010.bin").?.island);
    for ([_][]const u8{
        "build/darius/top/emerald/vs86,ks8010.bin",
        "build/darius/top/emerald/.bin",
        "build/darius/top/gold/ks8010.bin",
        "build/darius/middle/plat/ks8010.bin",
        "trends/darius/top/plat/ks8010.bin",
        "build/darius/top/plat/ks8010.bin/x",
        "build/darius/top/plat/ks8010",
    }) |bad| try std.testing.expectEqual(null, parse(bad));
}
