//! champions.html and the role pages: every champion's win rate, by role

const std = @import("std");
const core = @import("core");
const ui = @import("ui");
const html = @import("html.zig");
const assets = @import("assets.zig");
const spread = @import("../spread.zig");
const patchday = @import("../patchday.zig");
const filters = @import("filters.zig");

const Writer = std.Io.Writer;
const Role = core.Role;
const tpl = html.tpl;

const Champ = @import("root.zig").Champ;
const Site = @import("root.zig").Site;
const ratio = @import("root.zig").ratio;
const earlyNote = @import("root.zig").earlyNote;
const roleName = @import("root.zig").roleName;

/// Below this share of all games a champion's row is a rare pick, listed on request
pub const min_pick_rate = 0.004;
/// And below this share of the champion's own games, as a role it rarely plays
pub const min_role_share = 0.1;

const Row = struct {
    ch: Champ,
    role: Role,
    games: u32,
    wins: u32,
    /// Of the champion's games, the share in this role
    share: f64,
    /// Under min_pick_rate or min_role_share: listed only on request
    rare: bool,
};

/// Every champion's games in `role`, or in each role it plays when null, by the win rate
/// shown (ties most played first; the minimum games keeps a few lucky games off the top);
/// the browser sorts by any column (ui.tiers)
fn tierRows(site: *const Site, role: ?Role) ![]Row {
    var rows: std.ArrayList(Row) = .empty;
    for (Role.all) |r| {
        if (role != null and role.? != r) continue;
        for (site.champs) |ch| {
            const cr = site.stats.champRole(r, ch.c);
            if (cr.games == 0) continue;
            const share = @as(f64, @floatFromInt(cr.games)) / @as(f64, @floatFromInt(@max(ch.games, 1)));
            try rows.append(site.arena, .{
                .ch = ch,
                .role = r,
                .games = cr.games,
                .wins = cr.wins,
                .share = share,
                .rare = ratio(cr.games, site.games) < min_pick_rate or share < min_role_share,
            });
        }
    }
    std.mem.sort(Row, rows.items, {}, struct {
        fn f(_: void, a: Row, b: Row) bool {
            return a.games > b.games;
        }
    }.f);
    std.mem.sort(Row, rows.items, {}, struct {
        fn f(_: void, a: Row, b: Row) bool {
            return ratio(a.wins, a.games) > ratio(b.wins, b.games);
        }
    }.f);
    return rows.items;
}

pub const Rank = struct { rank: usize, of: usize };

/// The champion's place in its role's champions table (rare picks left out, as the table
/// hides them); null when it is one
pub fn roleRank(site: *const Site, r: Role, id: u32) !?Rank {
    const rows = try tierRows(site, r);
    var n: usize = 0;
    var rank: ?usize = null;
    for (rows) |row| {
        if (row.rare) continue;
        n += 1;
        if (row.ch.id == id) rank = n;
    }
    return if (rank) |k| .{ .rank = k, .of = n } else null;
}

pub const table_span = ui.fmt.table_span;

pub const wrColour = ui.fmt.wrColour;

/// The champions table's data file, in each view's directory
pub const data_path = "data/tiers.bin";

/// The view's champions table, every role, for ui.tiers: tierRows' rows and order
fn tiersData(site: *const Site) !ui.tiers.Data {
    const a = site.arena;
    const rows = try tierRows(site, null);
    const champs = try a.alloc(ui.tiers.Champ, site.champs.len);
    for (champs, site.champs) |*c, ch| c.* = .{ .name = ch.name, .key = ch.key, .slug = ch.slug, .banned = ch.banned };
    const out = try a.alloc(ui.tiers.Row, rows.len);
    const s = &site.spread;
    for (out, rows) |*o, row| {
        const pd = if (site.patchday) |*pd| pd else null;
        const move = if (pd) |x| x.champion(row.ch.id, row.role) else null;
        const sp = if (s.get(row.ch.id)) |c| (if (c.players >= s.min_players) c else null) else null;
        o.* = .{
            .champ = @intCast(site.by_c[row.ch.c].?),
            .role = @fromBackingInt(@as(u8, @backingInt(row.role))),
            .games = row.games,
            .wins = row.wins,
            .share = @floatCast(row.share),
            .spread = if (sp) |c| .{ .players = c.players, .p25 = c.p25, .p75 = c.p75, .shape = c.shape } else null,
            .patch = if (move) |m| .{
                .prev = .{ m.win.prev.games, m.win.prev.wins },
                .cur = .{ m.win.cur.games, m.win.cur.wins },
                .clear = m.win.clear(pd.?.opts.min_role_games, pd.?.opts.z),
            } else null,
        };
    }
    return .{
        .games = site.games,
        .min = ui.tiers.defaultMin(site.games),
        .spread_min_games = s.min_games,
        .cur_patch = if (site.patchday) |pd| pd.cur_patch else "",
        .prev_patch = if (site.patchday) |pd| pd.prev_patch else "",
        .region_in = site.view.region.in(),
        .ddragon = site.ddragon_version,
        .query = site.view.query(),
        .champs = champs,
        .rows = out,
    };
}

/// data/tiers.bin
pub fn dataFile(site: *const Site) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    try ui.data.encode(site.arena, ui.tiers.Data, try tiersData(site), &out);
    return out.items;
}

/// Every view's rank file (ui.tiers.RankData at rank_paths) from the root view's filter
/// tally (filters.Made.ranked), rows as tierRows'. Patch moves come from the region's 30
/// days, which hold both patches (a patch view's tally has the current one only)
pub fn rankFiles(site: *const Site, files: anytype) !void {
    const a = site.arena;
    const made = &site.filter;
    if (made.ranked.len == 0) return;
    const n_v = html.View.count;
    const n_g = filters.rank_groups.len;
    const n_r = Role.all.len;
    const n_c = site.champs.len;
    // Ranked's index by champion, view, group and role; each champion's games by view and
    // group over its roles
    const at = try a.alloc(?u32, n_c * n_v * n_g * n_r);
    @memset(at, null);
    const champ_games = try a.alloc(u64, n_c * n_v * n_g);
    @memset(champ_games, 0);
    for (made.ranked, 0..) |x, i| {
        const cvg = (@as(usize, x.champ) * n_v + x.view) * n_g + x.group;
        at[cvg * n_r + @backingInt(x.role)] = @intCast(i);
        champ_games[cvg] += x.games;
    }
    const pd = if (site.patchday) |*pd| pd else null;
    const champs = try a.alloc(ui.tiers.Champ, n_c);
    for (champs, site.champs) |*c, ch| c.* = .{ .name = ch.name, .key = ch.key, .slug = ch.slug, .banned = 0 };
    for (html.View.all, 0..) |v, vi| {
        var groups: [n_g]ui.tiers.Data = undefined;
        for (&groups, 0..) |*d, g| {
            var rows: std.ArrayList(ui.tiers.Row) = .empty;
            for (0..n_c) |c| for (0..n_r) |r| {
                const cvg = (c * n_v + vi) * n_g + g;
                const x = made.ranked[at[cvg * n_r + r] orelse continue];
                if (x.games == 0) continue;
                const days = (c * n_v + 2 * (vi / 2)) * n_g + g;
                try rows.append(a, .{
                    .champ = @intCast(c),
                    .role = @fromBackingInt(@as(u8, @backingInt(x.role))),
                    .games = x.games,
                    .wins = x.wins,
                    .share = @floatCast(ratio(x.games, champ_games[cvg])),
                    .spread = null,
                    .patch = if (pd) |p| patchOf(p, if (at[days * n_r + r]) |k| made.ranked[k].patches else &.{}) else null,
                    .rates = .{ x.pick, x.ban },
                });
            };
            std.mem.sort(ui.tiers.Row, rows.items, {}, struct {
                fn f(_: void, x: ui.tiers.Row, y: ui.tiers.Row) bool {
                    const rx = ratio(x.wins, x.games);
                    const ry = ratio(y.wins, y.games);
                    return if (rx != ry) rx > ry else x.games > y.games;
                }
            }.f);
            const games: u32 = @intCast(made.gamesAt(vi, g));
            d.* = .{
                .games = games,
                .min = ui.tiers.defaultMin(games),
                .spread_min_games = site.spread.min_games,
                .cur_patch = if (pd) |p| p.cur_patch else "",
                .prev_patch = if (pd) |p| p.prev_patch else "",
                .region_in = v.region.in(),
                .ddragon = site.ddragon_version,
                .query = v.query(),
                .rank = @fromBackingInt(@intCast(g + 1)),
                .champs = champs,
                .rows = rows.items,
            };
        }
        var out: std.ArrayList(u8) = .empty;
        try ui.data.encode(a, ui.tiers.RankData, .{ .groups = groups }, &out);
        try files.append(a, .{ .path = ui.tiers.rank_paths[vi], .data = out.items });
    }
}

/// The current patch against the previous one, as the base rows' (patchday.PatchDay
/// champions: enough games on both)
fn patchOf(pd: *const patchday.PatchDay, patches: []const filters.RankedPatch) ?ui.tiers.Patch {
    var prev: core.curvesfile.Counts = .{};
    var cur: core.curvesfile.Counts = .{};
    for (patches) |p| {
        if (std.mem.eql(u8, p.patch, pd.prev_patch)) prev = .{ .games = p.games, .wins = p.wins };
        if (std.mem.eql(u8, p.patch, pd.cur_patch)) cur = .{ .games = p.games, .wins = p.wins };
    }
    const r = patchday.Rate.of(prev, cur);
    if (!r.enough(pd.opts.min_role_games)) return null;
    return .{ .prev = .{ prev.games, prev.wins }, .cur = .{ cur.games, cur.wins }, .clear = r.clear(pd.opts.min_role_games, pd.opts.z) };
}

comptime {
    std.debug.assert(ui.tiers.n_groups == filters.rank_groups.len);
    std.debug.assert(ui.tiers.shape_points == spread.shape_points and ui.tiers.shape_step == spread.shape_step and ui.tiers.shape_reach == spread.shape_reach);
    for (Role.all, 0..) |r, i| {
        std.debug.assert(std.mem.eql(u8, roleName(r), ui.tiers.Role.names[i]));
        std.debug.assert(std.mem.eql(u8, r.label(), ui.tiers.Role.slugs[i]));
    }
}

/// The ui.tiers island, rendered from the same data its file carries (ui-stats.wasm
/// adopts it). The role icons stay outside it: string styles, which the tree refuses
fn writeIsland(site: *const Site, w: *Writer, role: ?Role, at: ui.urls.Page) !void {
    const a = site.arena;
    const d = try a.create(ui.tiers.Data);
    d.* = try tiersData(site);
    var bytes: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, ui.tiers.Data, d.*, &bytes);
    var t: ui.tiers.Tiers = .init(d, try ui.tiers.prepare(a, d, "/"), if (role) |x| @fromBackingInt(@as(u8, @backingInt(x))) else null);
    t.view_index = @intCast(site.view.index());
    t.path = try a.print("{f}", .{at});
    t.src = try std.mem.concat(a, u8, &.{ "/", site.view.dir(), data_path });
    t.stamp = ui.tiers.stamp(bytes.items);
    var tree: ui.Tree = .{};
    var h: ui.H = .init(a, &tree);
    tree.root = t.view(&h);
    if (h.oom) return error.OutOfMemory;
    try ui.html.write(&tree, tree.root, w);
    try tpl.render(w, "\n<script src=\"{js}\" data-wasm=\"{wasm}\" defer></script>\n", .{
        .js = html.Link{ .path = assets.stats_js.path },
        .wasm = assets.stats_wasm.path,
    });
}

pub fn writeTierList(site: *const Site, w: *Writer, role: ?Role) !void {
    const a = site.arena;
    const name = if (role) |r| roleName(r) else "All";
    const title = if (role) |r|
        try a.print("{s} lane champions, {s} | meiolol", .{ roleName(r), site.period() })
    else
        try a.print("Champions, {s} | meiolol", .{site.period()});
    const desc = try a.print("{s} champions in ranked solo queue {s}, {s}: win rate, its change this patch, how players' own win rates spread, pick and ban rates.", .{ name, site.view.region.in(), site.when });
    const at: ui.urls.Page = .{ .champions = if (role) |r| @import("root.zig").urlRole(r) else null };
    var p = try site.page(title, desc, at, .champions);
    // The island's toolbar picks the view
    p.counterparts = null;
    try html.head(w, p);
    try earlyNote(site, w);
    try writeIsland(site, w, role, at);
    try html.foot(w, p);
}
