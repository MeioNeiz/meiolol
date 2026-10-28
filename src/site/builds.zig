//! Build data for the champion and matchup pages (src/builds.zig files): which view's
//! file each page reads, with the previous patch's or a wider rank's when the asked one
//! is thin. Old build/ pages redirect to the champion page in nginx (docs/plan/urls.md)

const std = @import("std");
const core = @import("core");
const root = @import("root.zig");
const html = @import("html.zig");
const tpl = html.tpl;
const plural = @import("text.zig").plural;
const builds = @import("../builds.zig");
const scope = @import("scope.zig");
const filters = @import("filters.zig");

const Writer = std.Io.Writer;
const Role = core.Role;
const Site = root.Site;
const Champ = root.Champ;
const File = builds.File;

/// Below this a row is greyed out
pub const solid_games = 400;

/// Any games of `ch` in `r`: the champion page shows every role it has
fn played(f: *const File, champion: u32, r: Role) ?File.Build {
    const b = f.get(champion, r) orelse return null;
    return if (b.games > 0) b else null;
}

/// The patch view of the site view's region, whose builds matchup pages show
fn patchView(site: *const Site) html.View {
    return .{ .region = site.view.region, .period = .patch };
}

/// "patch 16.21" or "last 30 days": a builds file's games in a view of `period`
fn periodText(a: std.mem.Allocator, f: *const File, period: html.Period) ![]const u8 {
    return switch (period) {
        .patch => a.print("patch {s}", .{f.label}),
        .days30 => f.label,
    };
}

fn periodDim(a: std.mem.Allocator, f: *const File, period: html.Period) !scope.Dim {
    return switch (period) {
        .days30 => .days30,
        .patch => .patch(a, f.label),
    };
}

/// A strip's build: the view's, or in a patch view the previous patch's while the
/// current one has under solid_games of it and the previous more (a new patch's first
/// days)
pub const Picked = struct {
    f: *const File,
    b: File.Build,
    period: html.Period,
    /// The current patch's games of it when the previous patch's is shown
    newer: ?u64 = null,

    /// As a scope chip: the patch shown, the previous one while the current is thin
    fn chipPeriod(p: Picked, site: *const Site) !scope.Dim {
        return periodDim(site.arena, p.f, p.period);
    }

    /// "patch 16.21", "patch 16.20 (16.21: 57 games so far)", "last 30 days"
    fn when(p: Picked, site: *const Site) ![]const u8 {
        const n = p.newer orelse return periodText(site.arena, p.f, p.period);
        return site.arena.print("patch {s} ({s}: {f} game{s} so far)", .{ p.f.label, site.patch, root.Thousands{ .n = n }, plural(n) });
    }
};

fn pick(site: *const Site, v: html.View, get: anytype, args: anytype) ?Picked {
    const cur = pickFrom(&site.view_builds[v.index()], v.period, get, args);
    const prev = pickFrom(&site.view_builds_prev[v.index()], v.period, get, args) orelse return cur;
    const c = cur orelse return .{ .f = prev.f, .b = prev.b, .period = prev.period, .newer = 0 };
    if (c.b.games >= solid_games or prev.b.games <= c.b.games) return c;
    return .{ .f = prev.f, .b = prev.b, .period = prev.period, .newer = c.b.games };
}

/// The build the champion page shows for `ch` in `r`: this patch's, or the previous one's
/// while this one's is thin
pub fn forChampion(site: *const Site, v: html.View, ch: Champ, r: Role) ?Picked {
    return pick(site, v, played, .{ ch.id, r });
}

/// As forChampion under the rank filter: `rank` 0 Platinum+ (forChampion), 1 to 3
/// builds.rank_tiers. A rank with under solid_games of it falls back to the next wider
/// one, `rank` saying which is shown: a few one-tricks are much of a thin high-rank slice
/// (16.21 Master+: 4.5 games per player on a champion and role, weighted by games)
pub const RankPicked = struct { picked: Picked, rank: u8 };

pub fn forRank(site: *const Site, v: html.View, ch: Champ, r: Role, rank: u8) ?RankPicked {
    var at = @min(rank, builds.rank_tiers.len);
    while (at > 0) : (at -= 1) {
        const f = if (site.view_builds_rank[v.index()][at - 1]) |*f| f else continue;
        const b = played(f, ch.id, r) orelse continue;
        if (b.games >= solid_games) return .{ .picked = .{ .f = f, .b = b, .period = v.period }, .rank = at };
    }
    return .{ .picked = forChampion(site, v, ch, r) orelse return null, .rank = 0 };
}

fn pickFrom(slot: *const ?File, period: html.Period, get: anytype, args: anytype) ?Picked {
    const f = if (slot.*) |*f| f else return null;
    return .{ .f = f, .b = @call(.auto, get, .{f} ++ args) orelse return null, .period = period };
}

/// Matchup page: what `x` players took against `y` in `r` (File.matchups), from the
/// patch view of the region; the previous patch's while this one's is thin. Null when
/// the pair has too few games for the file
pub fn forVs(site: *const Site, r: Role, x: Champ, y: Champ) ?Picked {
    return pick(site, patchView(site), File.getVs, .{ x.id, r, y.id });
}
