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
const meio = @import("../meio.zig");
const ddragon = @import("../ddragon.zig");

const Role = core.Role;
const Counts = core.statsfile.Counts;
const cp = ui.champpage;
const pd = ui.pvdata;
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

/// The table and its Index, and Meio's fitted model (`meiolol meio`) beside them, freed
/// together
pub const Answers = struct {
    arena: std.heap.ArenaAllocator,
    table: lockrows.Table,
    index: lockanswer.Index,
    /// null: no meio_path, its file missing or another build's
    meio: ?meio.Model = null,

    /// null when `path` is missing or another binary's types wrote it
    pub fn load(gpa: std.mem.Allocator, io: std.Io, path: []const u8, meio_path: ?[]const u8) !?*Answers {
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
        x.meio = null;
        errdefer x.index.deinit();
        if (meio_path) |p| x.meio = try loadMeio(io, p, x.arena.allocator());
        log.info("{s}: {d} champion-roles, lock answers ready in {d} ms", .{ path, x.table.blocks.len, t0.durationTo(std.Io.Clock.awake.now(io)).toMilliseconds() });
        return x;
    }

    fn loadMeio(io: std.Io, path: []const u8, arena: std.mem.Allocator) !?meio.Model {
        const f = std.Io.Dir.cwd().openFile(io, path, .{}) catch |err| switch (err) {
            error.FileNotFound => {
                log.info("{s}: none, no Meio under locks", .{path});
                return null;
            },
            else => return err,
        };
        defer f.close(io);
        var buf: [1 << 20]u8 = undefined;
        var r = f.reader(io, &buf);
        const m = try meio.load(&r.interface, arena);
        if (m == null) log.warn("{s}: another build's, no Meio under locks", .{path});
        return m;
    }

    pub fn deinit(x: *Answers, gpa: std.mem.Allocator) void {
        x.index.deinit();
        x.arena.deinit();
        gpa.destroy(x);
    }
};

/// `rest` (a path under the view's directory, after `prefix`) answered from `s`, the
/// view's site, in `s.arena`; null for a path that names nothing
pub fn answer(s: *Site, x: *const Answers, gpa: std.mem.Allocator, rest: []const u8) !?[]const u8 {
    const q = parse(rest) orelse return null;
    const ch = s.champBySlug(q.slug) orelse return null;
    var out: std.ArrayList(u8) = .empty;
    switch (q.island) {
        .build => try ui.data.encode(s.arena, cp.BuildData, try build(s, x, gpa, ch, q.role, q.rank, &q.locks) orelse return null, &out),
        .more => try ui.data.encode(s.arena, cp.MoreData, try more(s, x, ch, q.role, q.rank, &q.locks) orelse return null, &out),
        .top => try ui.data.encode(s.arena, cp.TopData, try top(s, x, ch, q.role, q.rank, &q.locks) orelse return null, &out),
        // The Meio period: public, as the view's numbers are (estimates.md E0d)
        .meio => try ui.data.encode(s.arena, pd.Meio, try meioOf(s, x, ch, q.role, q.rank, &q.locks) orelse return null, &out),
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
    if (file.get(@intCast(ch.id), r)) |b| role.build = try buildblock.data(a, &file, b, ch.name, s.damage);
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

/// `ch`'s games and wins in `r` at rank `k` under `locks`, for the champion page's
/// StatStrip: a TopData of that one role and nothing else, in `s.arena`; null as `build`
pub fn top(s: *const Site, x: *const Answers, ch: Champ, r: Role, k: cp.Rank, locks: *const lockanswer.Locks) !?cp.TopData {
    const a = s.arena;
    const f = filterOf(s, &x.table, k) orelse return null;
    const n = try lockanswer.count(a, &x.table, &x.index, @intCast(ch.id), r, f, locks) orelse return null;
    const role = try a.create(cp.TopRole);
    role.* = .{ .role = champion.uiRole(r), .games = n.games, .wins = n.wins, .share = 0, .pick = 0, .ban = 0, .lane = &.{} };
    return .{ .name = "", .slug = "", .icon = "", .patch = "", .ddragon = "", .champs = &.{}, .roles = role[0..1] };
}

/// Most keystones and items in a Meio answer; opponents are all listed (Matchups)
const meio_choices = 40;

/// The locks Meio models: one keystone, one finished item (any slot) and one lane
/// opponent, at most two of them (common.md "model -> locks")
const Stack = struct {
    keystone: ?u16 = null,
    item: ?u16 = null,
    /// The lane opponent's champion id
    opponent: ?u16 = null,

    fn of(l: *const lockanswer.Locks, any_slot: *bool) error{ Kind, Deep }!Stack {
        var st: Stack = .{};
        for (std.enums.values(lockanswer.Kind)) |kind| {
            const want = l.by.get(kind) orelse continue;
            const one = if (want.len == 1) std.math.cast(u16, want.v[0]) else null;
            switch (kind) {
                .keystone => st.keystone = one orelse return error.Kind,
                .opponent => st.opponent = one orelse return error.Kind,
                .item4, .item5, .item6 => {
                    if (st.item != null) return error.Deep;
                    st.item = one orelse return error.Kind;
                    any_slot.* = true;
                },
                else => return error.Kind,
            }
        }
        if (st.depth() > 2) return error.Deep;
        return st;
    }

    fn depth(st: Stack) u8 {
        return @as(u8, @intFromBool(st.keystone != null)) + @intFromBool(st.item != null) + @intFromBool(st.opponent != null);
    }

    /// Meio's win rate for `cr` under the stack; null deeper than two or where it has none
    fn rate(st: Stack, m: *const meio.Model, region: u1, br: meio.Brackets, cr: u16) ?meio.Estimate {
        const opp: ?u16 = if (st.opponent) |o| crOf(o, cr) else null;
        const ks: u32 = st.keystone orelse 0;
        const item: u32 = st.item orelse 0;
        return switch (st.depth()) {
            0 => m.rateIn(.champion, region, br, cr, 0),
            1 => if (opp) |o| m.rateIn(.matchup, region, br, cr, o) else if (st.keystone != null) m.rateIn(.keystone, region, br, cr, ks) else m.rateIn(.item, region, br, cr, item),
            2 => if (opp) |o|
                if (st.keystone != null) m.rateIn(.keystone_matchup, region, br, cr, ks << 16 | o) else m.rateIn(.item_matchup, region, br, cr, item << 16 | o)
            else
                m.rateIn(.keystone_item, region, br, cr, ks << 16 | item),
            else => null,
        };
    }
};

/// champion | role << 13, as truth.crOf; the role is `cr`'s (a lane opponent's)
fn crOf(id: u16, cr: u16) u16 {
    return id | (cr & ~@as(u16, 0x1fff));
}

/// Meio under `locks` for `ch` in `r` at rank `k`, beside the raw counts of the view
fn meioOf(s: *const Site, x: *const Answers, ch: Champ, r: Role, k: cp.Rank, locks: *const lockanswer.Locks) !?pd.Meio {
    const a = s.arena;
    const t = &x.table;
    const f = filterOf(s, t, k) orelse return null;
    const c = try lockanswer.choices(a, t, &x.index, @intCast(ch.id), r, f, locks) orelse return null;
    var d: pd.Meio = .{ .gap = .none, .any_slot = false, .games = c.locked.games, .wins = c.locked.wins, .stack = null, .gold = null, .keystones = &.{}, .items = &.{}, .opponents = &.{} };
    const st = Stack.of(locks, &d.any_slot) catch |err| switch (err) {
        error.Kind => blk: {
            d.gap = .kind;
            break :blk null;
        },
        error.Deep => blk: {
            d.gap = .deep;
            break :blk null;
        },
    };
    // Plat+ and Emerald+ pool the mid and high brackets (Gold sits in mid too), Diamond+
    // the high one; Master+'s pick is narrower than any bracket
    const br: ?meio.Brackets = switch (k) {
        .plat, .emerald => .{ .mask = 0b1100 },
        .diamond => .{ .mask = 0b1000 },
        .master => null,
    };
    if (br == null and d.gap == .none) d.gap = .master;
    if (x.meio == null and d.gap == .none) d.gap = .no_model;
    const m: ?*const meio.Model = if (d.gap == .none) &x.meio.? else null;
    const region: u1 = @intFromBool(s.view.region == .euw);
    const cr: u16 = @intCast(ch.id | @as(u32, @backingInt(r)) << 13);
    const lane_gold = st != null and st.?.keystone == null and st.?.item == null;
    if (m) |model| {
        d.stack = est(st.?.rate(model, region, br.?, cr));
        if (lane_gold) {
            const o: u32 = if (st.?.opponent) |id| crOf(id, cr) else 0;
            d.gold = est(model.avgIn(.gold14, region, br.?, cr, o));
        }
        var roles: std.ArrayList(pd.RoleEst) = .empty;
        for (Role.all) |r2| {
            const cr2: u16 = @intCast(ch.id | @as(u32, @backingInt(r2)) << 13);
            const e = est(model.rateIn(.champion, region, br.?, cr2, 0)) orelse continue;
            try roles.append(a, .{ .role = champion.uiRole(r2), .meio = e });
        }
        d.roles = roles.items;
    }
    const lists = [_]struct { []const lockanswer.Choice, *[]const pd.Choice, []const ddragon.Named }{
        .{ c.keystones, &d.keystones, t.build.runes },
        .{ c.items, &d.items, t.build.items },
        .{ c.opponents, &d.opponents, &.{} },
    };
    for (lists, 0..) |l, i| {
        const from, const into, const names = l;
        const out = try a.alloc(pd.Choice, if (i == 2) from.len else @min(from.len, meio_choices));
        for (out, from[0..out.len]) |*o, cc| {
            const name = if (i == 2) champName(s, cc.id) else if (ddragon.find(names, cc.id)) |n| n.name else "";
            var with = st orelse Stack{};
            const id16 = std.math.cast(u16, cc.id);
            switch (i) {
                0 => with.keystone = id16,
                1 => with.item = id16,
                else => with.opponent = id16,
            }
            const e = if (m != null and id16 != null and with.depth() <= 2) with.rate(m.?, region, br.?, cr) else null;
            // Lane gold against the opponent: only where the stack has no keystone or item
            const gold = if (i == 2 and lane_gold and m != null and id16 != null) est(m.?.avgIn(.gold14, region, br.?, cr, crOf(id16.?, cr))) else null;
            o.* = .{ .id = cc.id, .name = name, .games = cc.locked.games, .wins = cc.locked.wins, .meio = est(e), .gold = gold };
        }
        into.* = out;
    }
    return d;
}

fn champName(s: *const Site, id: u32) []const u8 {
    for (s.champs) |c| if (c.id == id) return c.name;
    return "";
}

fn est(e: ?meio.Estimate) ?pd.Est {
    const x = e orelse return null;
    const own = std.math.clamp(@round(x.own), 0, std.math.maxInt(u32));
    return .{ .p = @floatCast(x.p), .lo = @floatCast(x.lo), .hi = @floatCast(x.hi), .own = @intFromFloat(own) };
}

fn tierOf(k: cp.Rank) []const u8 {
    return if (k == .plat) "PLATINUM" else builds.rank_tiers[@backingInt(k) - 1];
}

/// The rows the view and rank `k` count; null when the view's patch or
/// region isn't in `t`
fn filterOf(s: *const Site, t: *const lockrows.Table, k: cp.Rank) ?lockanswer.Filter {
    return .{
        .platform = if (s.view.region == .euw) codeOf(t.dicts.platforms, s.opts.home) orelse return null else null,
        .patch = if (s.view.period == .patch) codeOf(t.dicts.patches, s.opts.patches[0]) orelse return null else null,
        .since = if (s.view.period == .days30) @intCast(@max(0, @divFloor(s.opts.since_ms, std.time.ms_per_s))) else 0,
        .floor = builds.rankOf(tierOf(k)),
        .damage = s.damage,
    };
}

/// The islands with lock answers
pub const Island = enum { build, more, top, meio };

const Query = struct { island: Island, slug: []const u8, role: Role, rank: cp.Rank, locks: lockanswer.Locks };

/// `<island>/<slug>/<role>/<rank>/<lk>.bin`. A lock set must be as Locks.format writes
/// it: one URL, one cached copy. Meio's no lock set is pd.no_locks
fn parse(rest: []const u8) ?Query {
    var it = std.mem.splitScalar(u8, rest, '/');
    const island = std.meta.stringToEnum(Island, it.next() orelse return null) orelse return null;
    const slug = it.next() orelse return null;
    const role = std.meta.stringToEnum(ui.role.Role, it.next() orelse return null) orelse return null;
    const rank = std.meta.stringToEnum(cp.Rank, it.next() orelse return null) orelse return null;
    const last = it.next() orelse return null;
    if (it.next() != null or !std.mem.endsWith(u8, last, ".bin")) return null;
    const lk = last[0 .. last.len - ".bin".len];
    // The other islands' unlocked numbers are the view's files; Meio has none
    const locks = if (island == .meio and std.mem.eql(u8, lk, pd.no_locks)) lockanswer.Locks{} else pageLocks(lk) orelse return null;
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
    try std.testing.expectEqual(.top, parse("top/darius/top/plat/ks8010.bin").?.island);
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
