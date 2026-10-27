//! matchup/index.html: the matchup finder (ui.finder). Each champion's roles, each role's
//! most played lane pairs with a matchup page, and the patch's clearest win rate moves
//! (as the patch page picks them), in the island's data-bin. A pick's matchups are the
//! champion page's data files (champion.dataFiles), fetched by ui-findergrid.wasm
const std = @import("std");
const core = @import("core");
const root = @import("root.zig");
const html = @import("html.zig");
const champion = @import("champion.zig");
const matchup = @import("matchup.zig");
const assets = @import("assets.zig");
const patchday = @import("../patchday.zig");
const ui = @import("ui");
const fd = ui.finder;

const Writer = std.Io.Writer;
const Role = core.Role;
const Curves = core.curvesfile.Curves;
const Site = root.Site;
const tpl = html.tpl;

pub const path = "matchup/index.html";

/// Pairs per role under Most played
const most_shown = 8;
const moved_shown = 6;
/// The 95% half width of a move: 1.96 standard errors
const ci_z = 1.96;

pub fn writePage(site: *const Site, w: *Writer) !void {
    const a = site.arena;
    const p = try site.page(
        "Lane matchups | meiolol",
        "Find a lane matchup: the most played pairs in each role and this patch's biggest win rate moves, each with how the lane unfolds minute by minute.",
        path,
        .matchups,
    );
    try html.head(w, p);
    const to_site = try site.toShared(path);
    const d = try a.create(fd.Data);
    d.* = try data(site, if (site.curves) |*c| c else null);
    var f: fd.Finder = try .init(a, d, try site.toRoot(path));
    f.bin = try bin(a, d.*);
    var t: ui.Tree = .{};
    var h: ui.H = .init(a, &t);
    t.root = f.view(&h);
    if (h.oom) return error.OutOfMemory;
    try ui.html.write(&t, t.root, w);
    var g: fd.Grid = .{
        .root = f.root,
        .js = try std.mem.concat(a, u8, &.{ to_site, assets.findergrid_js.path }),
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
        .js = html.Link{ .root = to_site, .path = assets.finder_js.path },
        .wasm = assets.finder_wasm.path,
    });
    try html.foot(w, p);
}

pub fn data(site: *const Site, curves: ?*const Curves) !fd.Data {
    const a = site.arena;
    const champs = try a.alloc(fd.Other, site.champs.len);
    const roles = try a.alloc([]const ui.role.Role, site.champs.len);
    for (site.champs, champs, roles) |ch, *o, *rs| {
        o.* = .{ .name = ch.name, .key = ch.key, .slug = ch.slug };
        rs.* = try rolesOf(site, ch.c);
    }
    const most = try a.alloc([]const fd.Pair, Role.all.len);
    for (Role.all, most) |r, *list| list.* = if (curves) |c| try mostPlayed(site, c, r) else &.{};
    var d: fd.Data = .{ .ddragon = site.ddragon_version, .champs = champs, .roles = roles, .most = most };
    if (site.patchday) |*pd| {
        d.moved = try moved(site, pd);
        d.patch = pd.cur_patch;
        d.patch_dir = if (site.view.period == .patch) "" else "patch/";
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

/// Lane pairs with a page, most games first, from the side that won more
fn mostPlayed(site: *const Site, curves: *const Curves, r: Role) ![]const fd.Pair {
    const a = site.arena;
    var list: std.ArrayList(fd.Pair) = .empty;
    for (curves.curves) |cv| {
        const hd = cv.header;
        if (hd.role != @backingInt(r) or !matchup.isPage(hd)) continue;
        const x = index(site, hd.a) orelse continue;
        const y = index(site, hd.b) orelse continue;
        const e = site.stats.enemy(r, r, site.champs[x].c, site.champs[y].c);
        if (e.games == 0) continue;
        const swap = 2 * e.wins < e.games;
        try list.append(a, .{
            .x = if (swap) y else x,
            .y = if (swap) x else y,
            .games = e.games,
            .wins = if (swap) e.games - e.wins else e.wins,
        });
    }
    std.mem.sort(fd.Pair, list.items, {}, struct {
        fn f(_: void, p: fd.Pair, q: fd.Pair) bool {
            return p.games > q.games;
        }
    }.f);
    return list.items[0..@min(list.items.len, most_shown)];
}

/// Win rate moves too big to be luck (the patch page's test), from the side that gained
fn moved(site: *const Site, pd: *const patchday.PatchDay) ![]const fd.Move {
    const a = site.arena;
    const o = pd.opts;
    var list: std.ArrayList(fd.Move) = .empty;
    for (pd.matchups) |m0| {
        if (!m0.win.clear(o.min_pair_games, o.z)) continue;
        const m = if (m0.win.z > 0) m0 else pd.matchup(m0.role, m0.b, m0.a).?;
        const x = index(site, m.a) orelse continue;
        const y = index(site, m.b) orelse continue;
        const rg = m.win.range(ci_z);
        try list.append(a, .{
            .role = champion.uiRole(m.role),
            .x = x,
            .y = y,
            .d = @floatCast(m.win.delta()),
            .ci = @floatCast((rg[1] - rg[0]) / 2),
            .games = m.win.cur.games,
        });
    }
    std.mem.sort(fd.Move, list.items, {}, struct {
        fn f(_: void, p: fd.Move, q: fd.Move) bool {
            return p.d > q.d;
        }
    }.f);
    return list.items[0..@min(list.items.len, moved_shown)];
}

/// `v` as ui.data, base64: the island root's data-bin
fn bin(a: std.mem.Allocator, v: fd.Data) ![]const u8 {
    var raw: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, fd.Data, v, &raw);
    const e = std.base64.standard.Encoder;
    const out = try a.alloc(u8, e.calcSize(raw.items.len));
    return e.encode(out, raw.items);
}
