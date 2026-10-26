//! The champion page's rank filter files (ui.champrank), every view's from the root
//! view's Site: its filter tally (filters.Made.ranked) has every view's counts, and its
//! view_builds_rank and view_curves every view's files

const std = @import("std");
const core = @import("core");
const ui = @import("ui");
const html = @import("html.zig");
const filters = @import("filters.zig");
const champion = @import("champion.zig");
const builds_page = @import("builds.zig");
const buildblock = @import("buildblock.zig");
const builds = @import("../builds.zig");

const root = @import("root.zig");
const Site = root.Site;
const Role = core.Role;
const cr = ui.champrank;

comptime {
    std.debug.assert(cr.n_groups == filters.rank_groups.len and cr.n_groups == builds.rank_tiers.len);
}

/// At the site root for every view, as the root view writes them all: under a view's
/// directory, a request for one would go to that view's files (Loaded.get)
pub fn dataPath(a: std.mem.Allocator, v: html.View, ch: root.Champ, part: champion.Part) ![]const u8 {
    const suffix = ([_][]const u8{ "", "-patch", "-all", "-all-patch" })[v.index()];
    const base = try champion.dataPath(a, ch, part);
    return a.print("{s}-rank{s}.bin", .{ base[0 .. base.len - ".bin".len], suffix });
}

/// Every champion's files in every view; none without a tally (a core static build)
pub fn dataFiles(site: *const Site, files: anytype) !void {
    const a = site.arena;
    const made = &site.filter;
    // Matchups' k from the root view's stats for every view: games to stabilise depend on
    // how much true matchup rates differ, much the same across regions and periods
    var ks: [Role.all.len]f64 = undefined;
    for (Role.all, &ks) |r, *k| k.* = champion.usualK(&site.stats, r);
    var i: usize = 0;
    while (i < made.ranked.len) {
        const c = made.ranked[i].champ;
        const vi = made.ranked[i].view;
        var top: [cr.n_groups]std.ArrayList(ui.champpage.TopRole) = @splat(.empty);
        var build: [cr.n_groups]std.ArrayList(ui.champpage.BuildRole) = @splat(.empty);
        var more: [cr.n_groups]std.ArrayList(ui.champpage.MoreRole) = @splat(.empty);
        while (i < made.ranked.len and made.ranked[i].champ == c and made.ranked[i].view == vi) : (i += 1) {
            const x = &made.ranked[i];
            const r = try roleData(site, x, ks[@backingInt(x.role)]);
            try top[x.group].append(a, r.top);
            try build[x.group].append(a, r.build);
            try more[x.group].append(a, r.more);
        }
        const v = html.View.all[vi];
        const ch = site.champs[c];
        try add(site, files, cr.Top, try dataPath(a, v, ch, .top), .{ .groups = items(ui.champpage.TopRole, &top) });
        try add(site, files, cr.Build, try dataPath(a, v, ch, .build), .{ .groups = items(ui.champpage.BuildRole, &build) });
        try add(site, files, cr.More, try dataPath(a, v, ch, .more), .{ .groups = items(ui.champpage.MoreRole, &more) });
    }
}

fn items(comptime T: type, lists: *const [cr.n_groups]std.ArrayList(T)) [cr.n_groups][]const T {
    var out: [cr.n_groups][]const T = undefined;
    for (&out, lists) |*o, l| o.* = l.items;
    return out;
}

fn add(site: *const Site, files: anytype, comptime T: type, path: []const u8, v: T) !void {
    var out: std.ArrayList(u8) = .empty;
    try ui.data.encode(site.arena, T, v, &out);
    try files.append(site.arena, .{ .path = path, .data = out.items });
}

const Roles = struct { top: ui.champpage.TopRole, build: ui.champpage.BuildRole, more: ui.champpage.MoreRole };

fn roleData(site: *const Site, x: *const filters.Ranked, k: f64) !Roles {
    const a = site.arena;
    const v = html.View.all[x.view];
    const ch = site.champs[x.champ];
    const base = root.ratio(x.wins, x.games);
    const curves = if (site.view_curves[v.index()]) |*c| c else null;
    const bracket: core.curvesfile.Bracket = if (x.group >= 1) .high else .all;
    const opps = try a.alloc(ui.champpage.Opp, x.opps.len);
    for (opps, x.opps) |*o, y| {
        const other = site.champs[y.champ];
        const oc = site.filter.roleCount(x.view, x.group, x.role, y.champ);
        const u = champion.VsUsual.of(y.wins, y.games, champion.usual(base, root.ratio(oc.wins, oc.games)), k);
        const curve = if (curves) |cs| cs.get(x.role, bracket, ch.id, other.id) else null;
        o.* = .{
            .champ = y.champ,
            .games = y.games,
            .wins = y.wins,
            .usual = @floatCast(100 * u.mean),
            .gold = if (curve) |cv| cv.estimate(.gold, core.curvesfile.lane_minute - 1).mean else null,
            .page = if (curves) |cs| cs.get(x.role, .all, ch.id, other.id) != null else false,
        };
    }
    const by_patch = try a.alloc(ui.champpage.Patch, x.patches.len);
    for (by_patch, x.patches) |*o, p| o.* = .{ .patch = p.patch, .games = p.games, .wins = p.wins, .rank = p.rank };
    const picked = builds_page.forRank(site, v, ch, x.role, x.group + 1);
    const rels = try a.alloc(ui.champpage.Rel, 1);
    rels[0] = .{ .ally = false, .role = champion.uiRole(x.role), .opps = opps };
    const r = champion.uiRole(x.role);
    return .{
        .top = .{ .role = r, .games = x.games, .wins = x.wins, .share = 0, .rank = x.rank, .of = x.of, .pick = x.pick, .ban = x.ban, .lane = &.{} },
        .build = .{
            .role = r,
            .build = if (picked) |p| try buildblock.data(a, p.picked.f, p.picked.b, ch.name) else null,
            .from = if (picked) |p| p.rank else 0,
        },
        .more = .{ .role = r, .games = x.games, .wins = x.wins, .rels = rels, .by_patch = by_patch, .by_length = &.{} },
    };
}
