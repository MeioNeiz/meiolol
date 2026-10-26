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

pub const labels = [_][]const u8{ "Emerald+", "Diamond+", "Master+" };

comptime {
    std.debug.assert(labels.len == filters.rank_groups.len and labels.len == builds.rank_tiers.len);
}

/// At the site root for every view, as the root view writes them all: under a view's
/// directory, a request for one would go to that view's files (Loaded.get)
pub fn dataPath(a: std.mem.Allocator, v: html.View, ch: root.Champ) ![]const u8 {
    const suffix = ([_][]const u8{ "", "-patch", "-all", "-all-patch" })[v.index()];
    return a.print("data/champion/{s}-rank{s}.bin", .{ ch.slug, suffix });
}

/// Every champion's file in every view; none without a tally (a core static build)
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
        var groups: [labels.len]std.ArrayList(cr.Role) = @splat(.empty);
        while (i < made.ranked.len and made.ranked[i].champ == c and made.ranked[i].view == vi) : (i += 1) {
            const x = &made.ranked[i];
            try groups[x.group].append(a, try roleData(site, x, ks[@backingInt(x.role)]));
        }
        const gs = try a.alloc(cr.Group, labels.len);
        for (gs, labels, &groups) |*g, label, roles| g.* = .{ .label = label, .roles = roles.items };
        var out: std.ArrayList(u8) = .empty;
        try ui.data.encode(a, cr.Data, .{ .groups = gs }, &out);
        try files.append(a, .{ .path = try dataPath(a, html.View.all[vi], site.champs[c]), .data = out.items });
    }
}

fn roleData(site: *const Site, x: *const filters.Ranked, k: f64) !cr.Role {
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
    return .{
        .role = champion.uiRole(x.role),
        .games = x.games,
        .wins = x.wins,
        .rank = x.rank,
        .of = x.of,
        .pick = x.pick,
        .ban = x.ban,
        .build = if (picked) |p| try buildblock.data(a, p.picked.f, p.picked.b, ch.name) else null,
        .build_group = if (picked) |p| p.rank else 0,
        .opps = opps,
        .by_patch = by_patch,
    };
}
