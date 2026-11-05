//! matchup/index.html: the matchup finder (ui.finder). Each champion's roles and, per
//! role and for all of them together, three short lists of lane pairs with a matchup
//! page: the patch's clear win rate moves (as the patch page picks them), the hardest
//! lanes and the lane bullies, in the island's data-bin. A pick's matchups are the champion page's
//! data files (champion.dataFiles), fetched by ui-findergrid.wasm
const std = @import("std");
const core = @import("core");
const root = @import("root.zig");
const html = @import("html.zig");
const shell = @import("shell.zig");
const champion = @import("champion.zig");
const matchup = @import("matchup.zig");
const tierlist = @import("tierlist.zig");
const assets = @import("assets.zig");
const patchday = @import("../patchday.zig");
const ui = @import("ui");
const fd = ui.finder;

const Writer = std.Io.Writer;
const Role = core.Role;
const Curves = core.curvesfile.Curves;
const Site = root.Site;
const tpl = html.tpl;

/// Pairs per role (or All) in each list: the card shows fd.shown, its button the rest
const kept = 25;
/// Hardest lanes and lane bullies: fewer games and a pair's luck tops the lists
const list_games = 500;

pub fn writePage(site: *const Site, w: *Writer) !void {
    const a = site.arena;
    const p = try site.page(
        "Lane matchups | meiolol",
        "Find a lane matchup: the most played pairs in each role and this patch's biggest win rate moves, each with how the lane unfolds minute by minute.",
        .matchups,
        .matchups,
    );
    try shell.open(w, p);
    const d = try a.create(fd.Data);
    d.* = try data(site, if (site.curves) |*c| c else null);
    var f: fd.Finder = try .init(a, d, site.view.query());
    f.bin = try bin(a, d.*);
    var t: ui.Tree = .{};
    var h: ui.H = .init(a, &t);
    t.root = f.view(&h);
    if (h.oom) return error.OutOfMemory;
    try ui.html.write(&t, t.root, w);
    var g: fd.Grid = .{
        .root = try std.mem.concat(a, u8, &.{ "/", site.view.dir() }),
        .query = site.view.query(),
        .js = try std.mem.concat(a, u8, &.{ "/", assets.findergrid_js.path }),
        .wasm = assets.findergrid_wasm.path,
    };
    var tg: ui.Tree = .{};
    var hg: ui.H = .init(a, &tg);
    tg.root = g.view(&hg);
    if (hg.oom) return error.OutOfMemory;
    try ui.html.write(&tg, tg.root, w);
    try tpl.render(w,
        \\<script src="{js}" data-wasm="{wasm}" defer></script>
        \\
    , .{
        .js = html.Link{ .path = assets.finder_js.path },
        .wasm = assets.finder_wasm.path,
    });
    try shell.close(w, p);
}

pub fn data(site: *const Site, curves: ?*const Curves) !fd.Data {
    const a = site.arena;
    const champs = try a.alloc(fd.Other, site.champs.len);
    const roles = try a.alloc([]const ui.role.Role, site.champs.len);
    for (site.champs, champs, roles) |ch, *o, *rs| {
        o.* = .{ .name = ch.name, .key = ch.key, .slug = ch.slug };
        rs.* = try rolesOf(site, ch.c);
    }
    // Each role's, then All's
    const hard = try a.alloc([]const fd.Pair, Role.all.len + 1);
    const bully = try a.alloc([]const fd.Lead, Role.all.len + 1);
    var every: std.ArrayList(LanePair) = .empty;
    for (Role.all, hard[0..Role.all.len], bully[0..Role.all.len]) |r, *h, *b| {
        const pairs = if (curves) |c| try lanePairs(site, c, r) else &.{};
        try every.appendSlice(a, pairs);
        h.* = try hardest(a, pairs);
        b.* = try bullies(a, pairs);
    }
    hard[Role.all.len] = try hardest(a, every.items);
    bully[Role.all.len] = try bullies(a, every.items);
    var d: fd.Data = .{
        .ddragon = site.ddragon_version,
        .champs = champs,
        .roles = roles,
        .hard = hard,
        .bully = bully,
        .sub = try a.print("{f} games {s}", .{ root.Thousands{ .n = site.games }, try tierlist.scopeOf(site, site.view, site.when) }),
    };
    if (site.patchday) |*pd| {
        d.moved = try moved(site, pd);
        d.patch = pd.cur_patch;
        d.patch_query = (html.View{ .region = site.view.region, .period = .patch }).query();
    }
    return d;
}

/// Roles with games, most first: the champion page's order
fn rolesOf(site: *const Site, c: usize) ![]const ui.role.Role {
    const a = site.arena;
    var list: std.ArrayList(Role) = .empty;
    for (Role.all) |r| if (site.stats.champRole(r, c).games > 0) try list.append(a, r);
    std.mem.sort(Role, list.items, RoleGames{ .site = site, .c = c }, RoleGames.more);
    const out = try a.alloc(ui.role.Role, list.items.len);
    for (list.items, out) |r, *o| o.* = champion.uiRole(r);
    return out;
}

const RoleGames = struct {
    site: *const Site,
    c: usize,
    fn more(ctx: RoleGames, x: Role, y: Role) bool {
        return ctx.site.stats.champRole(x, ctx.c).games > ctx.site.stats.champRole(y, ctx.c).games;
    }
};

/// site.champs' index of champion `id`
fn index(site: *const Site, id: u32) ?u16 {
    const c = site.stats.index(id) orelse return null;
    return @intCast(site.by_c[c] orelse return null);
}

/// A role's lane pairs with a page and list_games, from the curve's side
const LanePair = struct { role: ui.role.Role, x: u16, y: u16, games: u32, wins: u32, gold: i16 };

fn lanePairs(site: *const Site, curves: *const Curves, r: Role) ![]const LanePair {
    var list: std.ArrayList(LanePair) = .empty;
    for (curves.curves) |*cv| {
        const hd = cv.header;
        if (hd.role != @backingInt(r) or !matchup.isPage(hd)) continue;
        const x = index(site, hd.a) orelse continue;
        const y = index(site, hd.b) orelse continue;
        const e = site.stats.enemy(r, r, site.champs[x].c, site.champs[y].c);
        if (e.games < list_games) continue;
        const v: core.curvesfile.View = .{ .curve = cv, .flipped = false };
        const gold = v.estimate(.gold, core.curvesfile.lane_minute - 1).mean;
        try list.append(site.arena, .{ .role = champion.uiRole(r), .x = x, .y = y, .games = e.games, .wins = e.wins, .gold = gold });
    }
    return list.items;
}

/// From the side that wins less, the lowest win rate first: in the order shown, as on the
/// champions list (list_games keeps the thin pairs off)
fn hardest(a: std.mem.Allocator, pairs: []const LanePair) ![]const fd.Pair {
    const list = try a.alloc(fd.Pair, pairs.len);
    for (pairs, list) |p, *o| {
        const swap = 2 * p.wins > p.games;
        o.* = .{ .role = p.role, .x = if (swap) p.y else p.x, .y = if (swap) p.x else p.y, .games = p.games, .wins = if (swap) p.games - p.wins else p.wins };
    }
    std.mem.sort(fd.Pair, list, {}, struct {
        fn f(_: void, p: fd.Pair, q: fd.Pair) bool {
            return @as(u64, p.wins) * q.games < @as(u64, q.wins) * p.games;
        }
    }.f);
    return list[0..@min(list.len, kept)];
}

/// From the side ahead, the biggest gold lead at lane_minute first (the curve's estimate,
/// already shrunk toward the champions' usual lanes)
fn bullies(a: std.mem.Allocator, pairs: []const LanePair) ![]const fd.Lead {
    const list = try a.alloc(fd.Lead, pairs.len);
    for (pairs, list) |p, *o| {
        const swap = p.gold < 0;
        o.* = .{
            .role = p.role,
            .x = if (swap) p.y else p.x,
            .y = if (swap) p.x else p.y,
            .games = p.games,
            .wins = if (swap) p.games - p.wins else p.wins,
            .gold = if (swap) -p.gold else p.gold,
        };
    }
    std.mem.sort(fd.Lead, list, {}, struct {
        fn f(_: void, p: fd.Lead, q: fd.Lead) bool {
            return p.gold > q.gold;
        }
    }.f);
    return list[0..@min(list.len, kept)];
}

/// Per role, then All, the win rate moves too big to be luck (the patch page's test),
/// biggest first, each from the side that gained
fn moved(site: *const Site, pd: *const patchday.PatchDay) ![]const []const fd.Move {
    const a = site.arena;
    const out = try a.alloc([]const fd.Move, Role.all.len + 1);
    for (Role.all, out[0..Role.all.len]) |r, *x| x.* = try movedIn(a, pd, r, SiteIndex{ .site = site });
    out[Role.all.len] = try movedIn(a, pd, null, SiteIndex{ .site = site });
    return out;
}

const SiteIndex = struct {
    site: *const Site,
    fn of(s: SiteIndex, id: u32) ?u16 {
        return index(s.site, id);
    }
};

/// `ids.of(id)`: the champion's index in fd.Data.champs, null without a page. `r` null: all
fn movedIn(a: std.mem.Allocator, pd: *const patchday.PatchDay, r: ?Role, ids: anytype) ![]const fd.Move {
    const o = pd.opts;
    var list: std.ArrayList(fd.Move) = .empty;
    for (pd.matchups) |m0| {
        if (r != null and m0.role != r.? or !m0.win.clear(o.min_pair_games, o.z)) continue;
        const m = if (m0.win.z > 0) m0 else pd.matchup(m0.role, m0.b, m0.a).?;
        const x = ids.of(m.a) orelse continue;
        const y = ids.of(m.b) orelse continue;
        try list.append(a, .{
            .role = champion.uiRole(m.role),
            .x = x,
            .y = y,
            .d = @floatCast(m.win.delta()),
            .games = m.win.cur.games,
            .wins = m.win.cur.wins,
        });
    }
    std.mem.sort(fd.Move, list.items, {}, struct {
        fn f(_: void, p: fd.Move, q: fd.Move) bool {
            return p.d > q.d;
        }
    }.f);
    return list.items[0..@min(list.items.len, kept)];
}

/// `v` as ui.data, base64: the island root's data-bin
fn bin(a: std.mem.Allocator, v: fd.Data) ![]const u8 {
    var raw: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, fd.Data, v, &raw);
    const e = std.base64.standard.Encoder;
    const out = try a.alloc(u8, e.calcSize(raw.items.len));
    return e.encode(out, raw.items);
}

test "moved: clear moves only, biggest first, from the side that gained; All" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const Counts = core.curvesfile.Counts;
    const mv = struct {
        fn f(r: Role, a: u32, b: u32, prev: Counts, cur: Counts) patchday.MatchupMove {
            return .{ .role = r, .a = a, .b = b, .win = .of(prev, cur) };
        }
    }.f;
    const pd: patchday.PatchDay = .{
        .matchups = &.{
            // Thin (150 games a patch): out however big
            mv(.top, 1, 2, .{ .games = 150, .wins = 90 }, .{ .games = 150, .wins = 68 }),
            mv(.top, 3, 4, .{ .games = 1000, .wins = 500 }, .{ .games = 1000, .wins = 560 }),
            mv(.top, 5, 6, .{ .games = 2000, .wins = 1000 }, .{ .games = 2000, .wins = 1100 }),
            // 16 down from 60 to 45 against 17: listed from 17's side, first
            mv(.top, 16, 17, .{ .games = 1000, .wins = 600 }, .{ .games = 1000, .wins = 450 }),
            // Not clear (z ~1.3); no move at all; another role; no page for 99
            mv(.top, 7, 8, .{ .games = 500, .wins = 250 }, .{ .games = 500, .wins = 270 }),
            mv(.top, 11, 12, .{ .games = 500, .wins = 250 }, .{ .games = 500, .wins = 250 }),
            mv(.middle, 13, 14, .{ .games = 1000, .wins = 500 }, .{ .games = 1000, .wins = 600 }),
            mv(.top, 15, 99, .{ .games = 1000, .wins = 500 }, .{ .games = 1000, .wins = 600 }),
        },
    };
    const Ids = struct {
        fn of(_: @This(), id: u32) ?u16 {
            return if (id == 99) null else @intCast(id);
        }
    };
    const got = try movedIn(arena.allocator(), &pd, .top, Ids{});
    const want = [_][2]u16{ .{ 17, 16 }, .{ 3, 4 }, .{ 5, 6 } };
    try std.testing.expectEqual(want.len, got.len);
    for (want, got) |w, g| {
        try std.testing.expectEqual(w[0], g.x);
        try std.testing.expectEqual(w[1], g.y);
    }
    try std.testing.expectApproxEqAbs(15, got[0].d, 1e-4);
    try std.testing.expectEqual(1000, got[0].games);
    try std.testing.expectEqual(550, got[0].wins);
    try std.testing.expectApproxEqAbs(6, got[1].d, 1e-4);
    // All: every role's, biggest first
    const every = try movedIn(arena.allocator(), &pd, null, Ids{});
    try std.testing.expectEqual(4, every.len);
    try std.testing.expectEqual(13, every[1].x);
    try std.testing.expectEqual(ui.role.Role.mid, every[1].role);
}

test "hardest: the lowest win rate first, from the side that wins less" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const got = try hardest(arena.allocator(), &.{
        // 39.7% on many games, 39.2% on fewer: 39.2 first, as shown
        .{ .role = .mid, .x = 1, .y = 2, .games = 5000, .wins = 1985, .gold = 0 },
        .{ .role = .support, .x = 4, .y = 3, .games = 600, .wins = 365, .gold = 0 },
    });
    try std.testing.expectEqual(3, got[0].x);
    try std.testing.expectEqual(235, got[0].wins);
    try std.testing.expectEqual(1, got[1].x);
}
