//! Build pages (src/builds.zig): what players take on a champion in a role this patch,
//! most played first, never ranked by win rate or called "best" (docs/concept.md,
//! docs/production-key.md). Every row shows games and pick share; a win rate only with
//! rate_games behind it and always with its 95% range; rows under solid_games greyed.
//! Pages in every view with a builds file: a patch's, or the last 30 days' (builds
//! --site); champion pages show each view's strip as their filters pick it.

const std = @import("std");
const core = @import("core");
const root = @import("root.zig");
const html = @import("html.zig");
const tpl = html.tpl;
const plural = @import("text.zig").plural;
const builds = @import("../builds.zig");
const ddragon = @import("../ddragon.zig");
const scope = @import("scope.zig");
const filters = @import("filters.zig");

const Writer = std.Io.Writer;
const Role = core.Role;
const Site = root.Site;
const Champ = root.Champ;
const File = builds.File;
const Kind = builds.Kind;

/// Below this a row shows no win rate: ±10 points at 100 games, wider below
pub const rate_games = 100;
/// Below this a row is greyed out
pub const solid_games = 400;
const rows_shown = 6;
const pages_shown = 4;
/// A role gets a page when it has this share of the champion's games in the file
const min_role_share = 0.1;
/// The build page's rune view shows a tree when one of its runes has this share
const min_tree_share = 0.02;

pub fn path(a: std.mem.Allocator, ch: Champ, r: Role) ![]const u8 {
    return a.print("build/{s}-{s}.html", .{ ch.slug, root.roleSlug(r) });
}

/// The build `ch` has a page for in `r`
pub fn shown(f: *const File, champion: u32, r: Role) ?File.Build {
    const b = f.get(champion, r) orelse return null;
    var all: u64 = 0;
    for (Role.all) |other| {
        if (f.get(champion, other)) |o| all += o.games;
    }
    if (b.games == 0 or @as(f64, @floatFromInt(b.games)) < min_role_share * @as(f64, @floatFromInt(all))) return null;
    return b;
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
const Picked = struct {
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

fn pickFrom(slot: *const ?File, period: html.Period, get: anytype, args: anytype) ?Picked {
    const f = if (slot.*) |*f| f else return null;
    return .{ .f = f, .b = @call(.auto, get, .{f} ++ args) orelse return null, .period = period };
}

/// A page per champion and role with enough of the champion's games
pub fn paths(site: *const Site, f: *const File, list: *std.ArrayList([]const u8)) !void {
    try list.append(site.arena, index_path);
    for (site.champs) |ch| for (Role.all) |r| {
        if (shown(f, ch.id, r) == null) continue;
        try list.append(site.arena, try path(site.arena, ch, r));
    };
}

pub const index_path = "build/index.html";

/// Every champion and role with a build page, by role
pub fn writeIndex(site: *const Site, w: *Writer, f: *const File) !void {
    const a = site.arena;
    const period = try periodText(a, f, site.view.period);
    const title = try a.print("Builds, {s} | meiolol", .{period});
    const desc = try a.print("Runes, items and skill order per champion and role in ranked solo/duo {s}, {s}.", .{ site.view.region.in(), period });
    var p = site.page(title, desc, index_path, .champions);
    // A view without builds switches to its champions list
    for (html.View.all, &p.counterparts.?) |v, *there| {
        if (site.view_builds[v.index()] == null)
            there.* = try std.mem.concat(a, u8, &.{ v.dir(), "champions.html" });
    }
    try html.head(w, p);
    try tpl.render(w,
        \\<h1>Builds, {period}</h1>
        \\<p class="muted">What players take per champion and role: ranked solo/duo {in}, {period}, {ranks}. A role is listed when it has a tenth or more of the champion's games.</p>
        \\
    , .{ .period = period, .in = site.view.region.in(), .ranks = try rankLabel(a, f.min_tier) });
    for (Role.all) |r| {
        var any = false;
        for (site.champs) |ch| any = any or shown(f, ch.id, r) != null;
        if (!any) continue;
        try tpl.renderPart(w, "<h2>{role}</h2>\n<ul class=\"build-list\">", .{ .role = root.roleName(r) });
        for (site.champs) |ch| {
            const b = shown(f, ch.id, r) orelse continue;
            try tpl.render(w,
                \\<li><a class="champ" href="{href}"><img src="{icon}" alt="" loading="lazy" width="32" height="32">{name}</a> <span class="muted">{games}</span></li>
            , .{
                .href = try a.print("{s}-{s}.html", .{ ch.slug, root.roleSlug(r) }),
                .icon = site.icon(ch),
                .name = ch.name,
                .games = b.games,
            });
        }
        try w.writeAll("</ul>\n");
    }
    try html.foot(w, p);
}

/// `rest`: "<champion>-<role>" from build/<rest>.html; false for no such page
pub fn route(site: *const Site, w: *Writer, f: *const File, rest: []const u8) !bool {
    const dash = std.mem.lastIndexOfScalar(u8, rest, '-') orelse return false;
    const ch = site.champBySlug(rest[0..dash]) orelse return false;
    const r = root.roleFromSlug(rest[dash + 1 ..]) orelse return false;
    const b = shown(f, ch.id, r) orelse return false;
    try writePage(site, w, f, ch, r, b);
    return true;
}

/// Champion page, in `r`'s section: view `v`'s most played choice of each kind with its
/// games, share and win rate (a past-games fact, the build page's framing), and a link to
/// v's build page; false when v has none. `from`: the champion page's path, at the site
/// root
pub fn strip(site: *const Site, w: *Writer, ch: Champ, r: Role, from: []const u8, v: html.View) !bool {
    const picked = pick(site, v, shown, .{ ch.id, r }) orelse return false;
    const f = picked.f;
    const b = picked.b;
    // The previous patch's build has no page
    const href: ?html.Link = if (picked.newer != null) null else .{ .root = site.toShared(from), .up = v.dir(), .path = try path(site.arena, ch, r) };
    try tpl.renderPart(w,
        \\<div class="bstrip"><p class="bhead"><b>Most played build</b> {chip} <span class="muted">{when}, {in}, {ranks}: {games} game{s}.</span>{link}</p>
        \\<div class="bks">
    , .{
        .chip = site.chip(site.regionDim(v.region), try picked.chipPeriod(site), rankDim(f.min_tier)),
        .when = try picked.when(site),
        .in = v.region.in(),
        .ranks = try rankLabel(site.arena, f.min_tier),
        .games = root.Thousands{ .n = b.games },
        .s = plural(b.games),
        .link = tpl.when(href != null, tpl.t(" <a href=\"{href}\">Full build: runes, items and skill order</a>", .{ .href = href orelse html.Link{ .root = "", .path = "" } })),
    });
    try top(w, f, b, null, .runes, "Runes");
    if (f.trees.len == 0) try top(w, f, b, null, .shards, "Shards");
    try top(w, f, b, null, .spells, "Spells");
    try top(w, f, b, null, .start, "Start");
    try top(w, f, b, null, .boots, "Boots");
    try top(w, f, b, null, .core3, "First 3 items");
    try top(w, f, b, null, .skill_start, "Levels 1-3");
    try top(w, f, b, null, .skills, "Skill priority");
    try w.writeAll("</div></div>\n");
    return true;
}

/// Matchup page: what `x` players took against `y` in `r` (File.matchups), each cell
/// marked when it is also x's most played in the role, beside every rune's pick and win
/// rate there, the runes taken more or less often than usual (runeShifts) on top.
/// Nothing when the pair has too few games for the file. `from`: the page's path
pub fn vsStrip(site: *const Site, w: *Writer, r: Role, x: Champ, y: Champ, from: []const u8) !void {
    const pv = patchView(site);
    const picked = pick(site, pv, File.getVs, .{ x.id, r, y.id }) orelse return;
    const f = picked.f;
    const b = picked.b;
    const usual = f.get(x.id, r);
    const chip = site.chip(site.regionDim(pv.region), try picked.chipPeriod(site), rankDim(f.min_tier));
    const href: ?html.Link = if (picked.newer != null or shown(f, x.id, r) == null) null else blk: {
        const to = try path(site.arena, x, r);
        break :blk if (site.view.period == .patch)
            .{ .root = site.toRoot(from), .path = to }
        else
            .{ .root = site.toShared(from), .up = pv.dir(), .path = to };
    };
    try tpl.renderPart(w,
        \\<div class="mu-build"><section class="mu-card"><h2>Most played build {chip}</h2><p class="mu-note">{games} game{s}, {patch}, {in}, {ranks}.{link}</p>
        \\<div class="bks">
    , .{
        .chip = chip,
        .games = root.Thousands{ .n = b.games },
        .s = plural(b.games),
        .patch = try picked.when(site),
        .in = pv.region.in(),
        .ranks = try rankLabel(site.arena, f.min_tier),
        .link = tpl.when(href != null, tpl.t(" <a href=\"{href}\">{x}'s full {lane} build</a>", .{ .href = href orelse html.Link{ .root = "", .path = "" }, .x = x.name, .lane = root.roleName(r) })),
    });
    try top(w, f, b, usual, .runes, "Runes");
    if (f.trees.len == 0) try top(w, f, b, usual, .shards, "Shards");
    try top(w, f, b, usual, .start, "Start");
    try top(w, f, b, usual, .boots, "Boots");
    try top(w, f, b, usual, .core2, "First 2 items");
    try top(w, f, b, usual, .core3, "First 3 items");
    try top(w, f, b, usual, .skills, "Skill priority");
    try w.writeAll("</div></section>\n");
    if (f.trees.len > 0 and b.get(.rune) != null) {
        const shifts = try runeShifts(site.arena, b, usual);
        try tpl.renderPart(w, "<section class=\"mu-card\"><h2>Runes against {y} {chip}</h2><div class=\"mu-rbody\"><div>\n", .{ .y = y.name, .chip = chip });
        _ = try runeStats(w, f, b, true);
        try tpl.renderPart(w, "</div><div>\n", .{});
        if (shifts.len > 0) {
            try tpl.renderPart(w, "<ul class=\"rshift\">\n", .{});
            for ([_]bool{ true, false }) |more| {
                var any = false;
                for (shifts) |sh| any = any or (sh.here > sh.usual) == more;
                if (!any) continue;
                try tpl.renderPart(w, "<li><span>{label}</span>", .{ .label = if (more) "Taken more" else "Taken less" });
                for (shifts) |sh| if ((sh.here > sh.usual) == more) try shiftChip(w, f, sh);
                try tpl.renderPart(w, "</li>\n", .{});
            }
            try tpl.renderPart(w, "</ul>\n<p class=\"mu-note\">Share of {x} players against {y}, then in {x}'s other {lane} games; runes {gap}+ points apart.</p>\n", .{ .x = x.name, .y = y.name, .lane = root.roleName(r), .gap = shift_points });
        } else try tpl.renderPart(w, "<p class=\"mu-note\">Every rune picked within {gap} points of {x}'s other {lane} games.</p>\n", .{ .gap = shift_points, .x = x.name, .lane = root.roleName(r) });
        try w.writeAll("</div></div></section>\n");
    }
    try w.writeAll("</div>\n");
}

/// A rune counts as taken differently in a matchup when its pick share is this many
/// points away from the champion's in the role. Win rates don't enter: pulled toward the
/// row's by File.shrinkK (about 6,000 games for runes in matchups), no rune's moves 2
/// points from its usual in any EUW matchup with a file (16.20, 2,002 pairs)
const shift_points = 10;
/// Under this many players a rune's share is left out either way
const shift_games = rate_games;

const Shift = struct { id: u32, here: f64, usual: f64, o: File.Option };

/// Runes whose share of `b`'s players is shift_points away from the usual build's,
/// largest move first
fn runeShifts(a: std.mem.Allocator, b: File.Build, usual: ?File.Build) ![]const Shift {
    const rows = b.get(.rune) orelse return &.{};
    const ur = (usual orelse return &.{}).get(.rune) orelse return &.{};
    var list: std.ArrayList(Shift) = .empty;
    for (rows.options) |o| {
        if (o.games < shift_games) continue;
        const u = if (find(ur.options, o.v)) |q| pct(q.games, ur.games) else 0;
        const here = pct(o.games, rows.games);
        if (@abs(here - u) >= shift_points) try list.append(a, .{ .id = o.v[0], .here = here, .usual = u, .o = o });
    }
    // Taken less: the usual rune left out in the matchup is found from the usual side
    for (ur.options) |q| {
        if (q.games < shift_games or find(rows.options, q.v) != null) continue;
        const u = pct(q.games, ur.games);
        if (u >= shift_points) try list.append(a, .{ .id = q.v[0], .here = 0, .usual = u, .o = .{ .v = q.v, .games = 0, .wins = 0 } });
    }
    std.mem.sort(Shift, list.items, {}, struct {
        fn f(_: void, p: Shift, q: Shift) bool {
            return @abs(p.here - p.usual) > @abs(q.here - q.usual);
        }
    }.f);
    return list.items;
}

fn shiftChip(w: *Writer, f: *const File, s: Shift) !void {
    const n = ddragon.find(f.runes, s.id) orelse return;
    var buf: [32]u8 = undefined;
    const rate = if (s.o.games >= rate_games) try std.fmt.bufPrint(&buf, ", {d:.1}% won", .{pct(s.o.wins, s.o.games)}) else "";
    try tpl.renderPart(w,
        \\<span class="rsh" title="{name}: {games} games{rate}"><img src="{src}" alt="" loading="lazy">{name} <b>{here:.0}%</b> <small>usually {usual:.0}%</small></span>
    , .{
        .name = n.name,
        .games = s.o.games,
        .rate = rate,
        .src = n.icon,
        .here = s.here,
        .usual = s.usual,
    });
}

fn sameTop(rows: File.Rows, usual: ?File.Build, kind: Kind) bool {
    const u = usual orelse return false;
    const ur = u.get(kind) orelse return false;
    return rows.options.len > 0 and ur.options.len > 0 and std.mem.eql(u32, ur.options[0].v, rows.options[0].v);
}

/// Index of the option with the highest win rate once each is pulled toward its slot's
/// (`games` players, `wins` won) by `k` games (File.shrinkK), taking the low end of
/// that estimate's range (one standard error), so a few lucky games can't top it and
/// near ties go to the option with more games. Only options showing a win rate
/// (rate_games); null under `min` of them, or without k (older files)
fn highest(options: []const File.Option, games: u32, wins: u32, k: ?f64, min: usize) ?usize {
    const kk = k orelse return null;
    const base = @as(f64, @floatFromInt(wins)) / @as(f64, @floatFromInt(@max(games, 1)));
    var hi: ?usize = null;
    var best: f64 = 0;
    var n: usize = 0;
    for (options, 0..) |o, i| {
        if (o.games < rate_games) continue;
        n += 1;
        const g = @as(f64, @floatFromInt(o.games)) + kk;
        const s = (@as(f64, @floatFromInt(o.wins)) + kk * base) / g - @sqrt(base * (1 - base) / g);
        if (hi == null or s > best) {
            hi = i;
            best = s;
        }
    }
    return if (n >= min) hi else null;
}

/// Whether a kind gets a highest win rate mark: chosen before the game or in its first
/// minutes. A finished item's win rate mostly says how the game was going when it was
/// bought (Mejai's wins ~80%: nobody finishes it in a lost game), and boots follow it
fn marked(kind: Kind) bool {
    return switch (kind) {
        .boots, .core2, .core3 => false,
        else => true,
    };
}

/// A row's highest(): its players are its options' (one rune of a row each). A row's
/// only rune with a win rate is its highest, so every row with a win rate has a ring
fn highestInRow(row: []const File.Option, k: ?f64) ?usize {
    var games: u32 = 0;
    var wins: u32 = 0;
    for (row) |o| {
        games += o.games;
        wins += o.wins;
    }
    return highest(row, games, wins, k, 1);
}

fn pct(n: u32, all: u32) f64 {
    return 100 * @as(f64, @floatFromInt(n)) / @as(f64, @floatFromInt(@max(all, 1)));
}

/// One kind's most played option: value, then games, share and win rate; "same as
/// usual" when it is also `usual`'s most played. Below it the option with the highest
/// win rate (highest()) when that is another one; a rune page on the same trees as
/// its runes ringed in the most played page
fn top(w: *Writer, f: *const File, b: File.Build, usual: ?File.Build, kind: Kind, comptime title: []const u8) !void {
    const rows = b.get(kind) orelse return;
    if (rows.options.len == 0) return;
    const o = rows.options[0];
    const hi = if (marked(kind)) highest(rows.options, rows.games, rows.wins, f.shrinkK(kind, b.opponent != 0), 2) else null;
    const other: ?File.Option = if (hi) |i| if (i > 0) rows.options[i] else null else null;
    const ringed = if (other) |h| kind == .runes and f.trees.len > 0 and h.v[0] == o.v[0] and h.v[5] == o.v[5] else false;
    try tpl.render(w,
        \\<div class="bk {kind}{thin}"><span>{title}{same}</span><div class="bv">{value}</div><small title="{games} of {all} players took this">{games} games · {share:.0}%{rate}</small>{hw}</div>
        \\
    , .{
        .kind = @tagName(kind),
        .thin = tpl.when(o.games < solid_games, " thin"),
        .title = title,
        .same = tpl.when(sameTop(rows, usual, kind), tpl.t(" <em class=\"muted\">same as usual</em>", .{})),
        .value = tpl.call(cell, .{ f, b, kind, o.v, if (ringed) other.?.v else null }),
        .share = pct(o.games, rows.games),
        .all = root.Thousands{ .n = rows.games },
        .games = root.Thousands{ .n = o.games },
        .rate = tpl.when(o.games >= rate_games, tpl.t("<br>{wr:.1}% won{also}", .{
            .wr = pct(o.wins, o.games),
            .also = tpl.when(hi != null and hi.? == 0, tpl.t(", the highest win rate", .{})),
        })),
        .hw = if (other) |h| tpl.t(
            \\<div class="bhw"><span>{label}</span>{value}<small>{wr:.1}% won · {games} games · {share:.0}%</small></div>
        , .{
            .label = if (ringed) "Highest win rate page: blue rings" else "Highest win rate",
            .value = tpl.when(!ringed, tpl.t("<div class=\"bv\">{v}</div>", .{ .v = tpl.call(value, .{ f, kind, h.v, true }) })),
            .wr = pct(h.wins, h.games),
            .games = root.Thousands{ .n = h.games },
            .share = pct(h.games, rows.games),
        }) else null,
    });
}

/// The strip's value: the rune page with the most played shards as the in-game tree,
/// `ringed` (another page on the same trees) marking its other runes
fn cell(w: *Writer, f: *const File, b: File.Build, kind: Kind, v: []const u32, ringed: ?[]const u32) !void {
    if (kind == .runes) {
        const shards: ?[]const u32 = if (b.get(.shards)) |r| if (r.options.len > 0) r.options[0].v else null else null;
        if (try runePage(w, f, v, shards, ringed)) return;
    }
    try value(w, f, kind, v, true);
}

fn findTree(f: *const File, id: u32) ?ddragon.Tree {
    for (f.trees) |t| if (t.id == id) return t;
    return null;
}

/// `v` (a .runes value) as the in-game page: every rune of the primary tree and of the
/// secondary's rows (its keystones left out), the chosen ones lit, those only in
/// `ringed` (a page on the same trees) ringed, and `shards` (a .shards value) on the
/// shard rows. False, writing nothing, without the trees (files before 20 Oct 2026)
fn runePage(w: *Writer, f: *const File, v: []const u32, shards: ?[]const u32, ringed: ?[]const u32) !bool {
    const primary = findTree(f, v[0]) orelse return false;
    const secondary = findTree(f, v[5]) orelse return false;
    if (secondary.slots.len == 0) return false;
    try w.writeAll("<div class=\"rp\"><div class=\"rt\">");
    try rune(w, f.runes, primary.id, "rh", true);
    for (primary.slots, 0..) |slot, i| {
        try w.writeAll(if (i == 0) "<div class=\"rr ks\">" else "<div class=\"rr\">");
        for (slot) |id| try rune(w, f.runes, id, mark(v[1..5], if (ringed) |g| g[1..5] else &.{}, id), std.mem.indexOfScalar(u32, v[1..5], id) != null);
        try w.writeAll("</div>");
    }
    try w.writeAll("</div><div class=\"rt\">");
    try rune(w, f.runes, secondary.id, "rh", true);
    for (secondary.slots[1..]) |slot| {
        try w.writeAll("<div class=\"rr\">");
        for (slot) |id| try rune(w, f.runes, id, mark(v[6..8], if (ringed) |g| g[6..8] else &.{}, id), std.mem.indexOfScalar(u32, v[6..8], id) != null);
        try w.writeAll("</div>");
    }
    try w.writeAll("</div>");
    if (shards) |s| {
        try w.writeAll("<div class=\"rt rs\" title=\"Most played stat shards\">");
        for (ddragon.shard_rows, 0..) |row, i| {
            try w.writeAll("<div class=\"rr\">");
            for (row) |id| try rune(w, &ddragon.shards, id, "", i < s.len and s[i] == id);
            try w.writeAll("</div>");
        }
        try w.writeAll("</div>");
    }
    try w.writeAll("</div>");
    return true;
}

/// "hw" for a rune in `ringed` and not in `lit`
fn mark(lit: []const u32, ringed: []const u32, id: u32) []const u8 {
    const in = std.mem.indexOfScalar(u32, ringed, id) != null and std.mem.indexOfScalar(u32, lit, id) == null;
    return if (in) "hw" else "";
}

/// A rune's icon, dimmed unless `lit`; the name on hover, as alt text only when lit
fn rune(w: *Writer, list: []const ddragon.Named, id: u32, class: []const u8, lit: bool) !void {
    const n = ddragon.find(list, id) orelse return w.writeAll("<i></i>");
    try tpl.render(w,
        \\<img class="{class}{state}" src="{src}" alt="{alt}" title="{name}" loading="lazy">
    , .{
        .class = class,
        .state = if (lit) (if (class.len == 0) "on" else " on") else (if (class.len == 0) "off" else " off"),
        .src = n.icon,
        .alt = if (lit) n.name else "",
        .name = n.name,
    });
}

/// Build page: the most played rune pages as in-game trees, each with games, share and
/// win rate, and the highest win rate page (highest()) if it is not among them. False
/// without the trees, for the table instead
fn pages(w: *Writer, f: *const File, b: File.Build) !bool {
    if (f.trees.len == 0) return false;
    const rows = b.get(.runes) orelse return false;
    if (rows.options.len == 0) return false;
    const hi = highest(rows.options, rows.games, rows.wins, f.shrinkK(.runes, false), 2);
    try w.writeAll("<div class=\"rpages\">\n");
    for (rows.options, 0..) |o, i| {
        if (i >= pages_shown and i != hi) continue;
        try tpl.renderPart(w, "<div class=\"rpc{thin}{hw}\">{tags}", .{
            .thin = tpl.when(o.games < solid_games, " thin"),
            .hw = tpl.when(i == hi, " hw"),
            .tags = tpl.call(tags, .{ i, hi }),
        });
        if (!try runePage(w, f, o.v, null, null)) try value(w, f, .runes, o.v, true);
        try tpl.renderPart(w,
            \\<small>{games} games · {share:.1}%<br>{rate}</small></div>
            \\
        , .{
            .games = o.games,
            .share = pct(o.games, rows.games),
            .rate = tpl.call(winRate, .{ o.games, o.wins }),
        });
    }
    try tpl.renderPart(w, "</div>\n<p class=\"muted caption\">Most played rune pages first. Share of {games} players.</p>\n", .{
        .games = rows.games,
    });
    return true;
}

/// "most played" on the first option, "highest win rate" on option `hi`
fn tags(w: *Writer, i: usize, hi: ?usize) !void {
    if (i != 0 and i != hi) return;
    try w.writeAll("<span class=\"tags\">");
    if (i == 0) try w.writeAll("<span class=\"tag mp\">most played</span>");
    if (i == hi) try w.writeAll("<span class=\"tag hw\">highest win rate</span>");
    try w.writeAll("</span>");
}

/// Build page and matchup page: every rune players took, laid out as in game with its
/// pick rate, win rate and games; in each row the most played lit and the highest win rate (highest()) ringed.
/// Trees by keystone players, then those with a rune on min_tree_share. False without
/// trees or per-rune counts (files before 21 Oct 2026)
fn runeStats(w: *Writer, f: *const File, b: File.Build, short: bool) !bool {
    if (f.trees.len == 0) return false;
    const rows = b.get(.rune) orelse return false;
    if (rows.options.len == 0) return false;
    const vs = b.opponent != 0;
    const k_rune = f.shrinkK(.rune, vs);
    const Shown = struct { tree: ddragon.Tree, keystones: u32, most: u32 };
    var shown_trees: [8]Shown = undefined;
    var n: usize = 0;
    for (f.trees) |t| {
        if (n == shown_trees.len) break;
        var s: Shown = .{ .tree = t, .keystones = 0, .most = 0 };
        for (t.slots, 0..) |slot, i| for (slot) |id| {
            const g = if (find(rows.options, &.{id})) |o| o.games else 0;
            if (i == 0) s.keystones += g;
            s.most = @max(s.most, g);
        };
        if (@as(f64, @floatFromInt(s.most)) < min_tree_share * @as(f64, @floatFromInt(rows.games))) continue;
        shown_trees[n] = s;
        n += 1;
    }
    std.mem.sort(Shown, shown_trees[0..n], {}, struct {
        fn lt(_: void, x: Shown, y: Shown) bool {
            return if (x.keystones != y.keystones) x.keystones > y.keystones else x.most > y.most;
        }
    }.lt);
    try w.writeAll("<div class=\"rx\">");
    for (shown_trees[0..n]) |s| {
        try w.writeAll("<div class=\"rt\">");
        try rune(w, f.runes, s.tree.id, "rh", true);
        for (s.tree.slots, 0..) |slot, i| {
            try w.writeAll(if (i == 0) "<div class=\"rr ks\">" else "<div class=\"rr\">");
            var row: [8]File.Option = undefined;
            var ids: [8]u32 = undefined;
            const len = @min(slot.len, row.len);
            for (slot[0..len], 0..) |id, j| {
                ids[j] = id;
                row[j] = find(rows.options, &.{id}) orelse .{ .v = &.{}, .games = 0, .wins = 0 };
            }
            try statRow(w, f.runes, ids[0..len], row[0..len], rows.games, k_rune);
            try w.writeAll("</div>");
        }
        try w.writeAll("</div>");
    }
    if (b.get(.shard)) |sr| if (sr.options.len > 0) {
        try w.writeAll("<div class=\"rt rs\">");
        for (ddragon.shard_rows, 0..) |ids, i| {
            try w.writeAll("<div class=\"rr\">");
            var row: [3]File.Option = undefined;
            for (ids, &row) |id, *o| o.* = find(sr.options, &.{ @intCast(i), id }) orelse .{ .v = &.{}, .games = 0, .wins = 0 };
            try statRow(w, &ddragon.shards, &ids, &row, sr.games, f.shrinkK(.shard, vs));
            try w.writeAll("</div>");
        }
        try w.writeAll("</div>");
    };
    if (short) {
        try tpl.renderPart(w,
            \\</div>
            \\<p class="mu-note">Pick rate, win rate, games. <span class="key mp"></span> most played <span class="key hw"></span> highest win rate, adjusted for few games</p>
            \\
        , .{});
        return true;
    }
    try tpl.renderPart(w,
        \\</div>
        \\<p class="muted caption">Under each rune: share of {games} players, win rate (from {rated} games), then games. <span class="key mp"></span> most played in its row{hw}.</p>
        \\
    , .{
        .games = root.Thousands{ .n = rows.games },
        .rated = rate_games,
        .hw = if (k_rune) |k| tpl.t(", <span class=\"key hw\"></span> highest win rate in its row among runes with {rated}+ games, each pulled toward the row's by {k} games (how much runes really differ, from every champion{vs}) and taken at the low end of its range", .{
            .k = root.Thousands{ .n = @round(k) },
            .rated = rate_games,
            .vs = tpl.when(vs, " in its matchups"),
        }) else null,
    });
    return true;
}

/// A rune's game count in its narrow column: 950, 9.5k, 95k
fn shortCount(w: *Writer, n: u32) !void {
    if (n == 0) return;
    if (n < 1000) return w.print("{d}", .{n});
    if (n < 10_000) return w.print("{d:.1}k", .{@as(f64, @floatFromInt(n)) / 1000});
    try w.print("{d}k", .{n / 1000});
}

fn find(options: []const File.Option, v: []const u32) ?File.Option {
    for (options) |o| if (std.mem.eql(u32, o.v, v)) return o;
    return null;
}

/// One row of runeStats: each rune's icon, share, win rate and games
fn statRow(w: *Writer, list: []const ddragon.Named, ids: []const u32, row: []const File.Option, all: u32, k: ?f64) !void {
    var most: ?usize = null;
    for (row, 0..) |o, i| {
        if (o.games > 0 and (most == null or o.games > row[most.?].games)) most = i;
    }
    const hi = highestInRow(row, k);
    for (ids, row, 0..) |id, o, i| {
        const n = ddragon.find(list, id) orelse continue;
        const share = pct(o.games, all);
        var buf: [32]u8 = undefined;
        const rate = if (o.games >= rate_games) try std.fmt.bufPrint(&buf, ", {d:.1}% won", .{pct(o.wins, o.games)}) else "";
        try tpl.render(w,
            \\<span class="rc{state}" title="{name}: {games} games, {share:.1}%{rate}"><img src="{src}" alt="{name}" loading="lazy"><b>{pick}{few}</b><i>{wr}</i><em>{n}</em></span>
        , .{
            .state = if (i == most and i == hi) " on hw" else if (i == most) " on" else if (i == hi) " hw" else if (share < 1) " off" else "",
            .name = n.name,
            .games = o.games,
            .share = share,
            .rate = rate,
            .src = n.icon,
            .pick = tpl.when(share >= 1, tpl.t("{p:.0}%", .{ .p = share })),
            .few = tpl.when(o.games > 0 and share < 1, "<1%"),
            .wr = tpl.when(o.games >= rate_games, tpl.t("{wr:.1}%", .{ .wr = pct(o.wins, o.games) })),
            .n = tpl.call(shortCount, .{o.games}),
        });
    }
}

/// A builds file's min_tier as a scope chip's rank
fn rankDim(tier: []const u8) scope.Dim {
    for (filters.tiers, 0..) |t, i| if (std.mem.eql(u8, t, tier)) return .rank(i);
    return .plat;
}

/// "PLATINUM" -> "Platinum IV and up"; "" -> "every player in Platinum+ games"
pub fn rankLabel(a: std.mem.Allocator, tier: []const u8) ![]const u8 {
    if (tier.len == 0) return "every player in Platinum+ games";
    const name = try std.ascii.allocLowerString(a, tier);
    name[0] = std.ascii.toUpper(name[0]);
    const apex = std.mem.eql(u8, tier, "MASTER") or std.mem.eql(u8, tier, "GRANDMASTER") or std.mem.eql(u8, tier, "CHALLENGER");
    return a.print("{s}{s} and up", .{ name, if (apex) "" else " IV" });
}

fn writePage(site: *const Site, w: *Writer, f: *const File, ch: Champ, r: Role, b: File.Build) !void {
    const a = site.arena;
    const page_path = try path(a, ch, r);
    const ranks = try rankLabel(a, f.min_tier);
    const period = try periodText(a, f, site.view.period);
    const title = try a.print("{s} {s} build: runes, items, skill order, {s} | meiolol", .{
        ch.name, root.roleName(r), period,
    });
    const role = try std.ascii.allocLowerString(a, root.roleName(r));
    const desc = try a.print("What players take on {s} in the {s} role in ranked solo/duo {s}, {s}: rune pages, summoner spells, starting items, boots, first items and skill order, with games and win rates.", .{
        ch.name, role, site.view.region.in(), period,
    });
    var p = site.page(title, desc, page_path, .champions);
    const champ_path = try a.print("champion/{s}.html", .{ch.slug});
    for (html.View.all, &p.counterparts.?) |v, *there| {
        const has = if (site.view_builds[v.index()]) |*o| shown(o, ch.id, r) != null else false;
        if (!has) there.* = try std.mem.concat(a, u8, &.{ champ_path, v.query() });
    }
    try html.head(w, p);
    try tpl.render(w,
        \\<div class="hero"><img src="{icon}" alt="" width="72" height="72"><div><h1>{name} {role} build</h1>
        \\<p class="muted">{chip} What players take on {name} in the {lower} role: ranked solo/duo {in}, {period}, {ranks}. {games} game{s}{rate}.</p></div></div>
        \\
    , .{
        .chip = site.chip(site.regionDim(site.view.region), try periodDim(a, f, site.view.period), rankDim(f.min_tier)),
        .icon = site.icon(ch),
        .name = ch.name,
        .role = root.roleName(r),
        .lower = role,
        .in = site.view.region.in(),
        .period = period,
        .ranks = ranks,
        .games = root.Thousands{ .n = b.games },
        .s = plural(b.games),
        .rate = tpl.when(b.games >= rate_games, tpl.t(", win rate {wr}", .{
            .wr = tpl.call(winRate, .{ b.games, b.wins }),
        })),
    });

    var others: usize = 0;
    for (Role.all) |o| others += @intFromBool(shown(f, ch.id, o) != null);
    if (others > 1) {
        try w.writeAll("<nav class=\"tabs\">");
        for (Role.all) |o| {
            if (shown(f, ch.id, o) == null) continue;
            try tpl.render(w, "<a href=\"{href}\"{current}>{label}</a>", .{
                .href = try a.print("{s}-{s}.html", .{ ch.slug, root.roleSlug(o) }),
                .current = tpl.flag(o == r, "aria-current=\"page\""),
                .label = root.roleName(o),
            });
        }
        try w.writeAll("</nav>\n");
    }
    if (b.games < solid_games) {
        try tpl.render(w,
            \\<p class="note">More data needed: {games} game{s} so far. Rows under {solid} games are greyed out and under {rated} show no win rate; with few games the most played choices can still change places.</p>
            \\
        , .{ .games = b.games, .s = plural(b.games), .solid = solid_games, .rated = rate_games });
    }
    try tpl.render(w,
        \\<p class="muted">Most played first: what players take, not a ranking. Win rates show a 95% range (±) from the number of games; two rows whose ranges overlap may not differ at all. Rows under {solid} games are greyed out; under {rated} there is no win rate. Marked: the most played{hw}.</p>
        \\
    , .{
        .solid = solid_games,
        .rated = rate_games,
        // Files before 21 Oct 2026 have no k, so no highest win rate marks
        .hw = tpl.when(f.shrink.len > 0, tpl.t(", and the highest win rate among options with {rated}+ games once each is pulled toward the average by k games (k from how much options of a kind really differ across every champion{ks}) and taken at the low end of its range, so a few lucky games can't top it. None on boots and finished items: their win rates mostly say how the game was going when they were bought (nobody finishes Mejai's in a game they're losing)", .{
            .rated = rate_games,
            .ks = if (f.shrinkK(.rune, false)) |kr| if (f.shrinkK(.start, false)) |ki| tpl.t(": {r} for a rune, {i} for starting items", .{
                .r = root.Thousands{ .n = @round(kr) },
                .i = root.Thousands{ .n = @round(ki) },
            }) else null else null,
        })),
    });

    try w.writeAll("<h2>Runes</h2>\n");
    const explored = try runeStats(w, f, b, false);
    const paged = try pages(w, f, b);
    if (!explored) try table(w, f, b, .keystone, "Keystone", "players");
    if (!paged) try table(w, f, b, .runes, "Rune page", "players");
    if (!explored) try table(w, f, b, .shards, "Stat shards", "players");
    try w.writeAll("<h2>Summoner spells</h2>\n");
    try table(w, f, b, .spells, "Spells", "players");
    try w.writeAll("<h2>Items</h2>\n");
    const items_from = "players with a match timeline";
    try table(w, f, b, .start, "Starting items", items_from);
    try table(w, f, b, .boots, "Boots", "players with boots or two finished items");
    try table(w, f, b, .core2, "First two finished items", "players who finished two items");
    try table(w, f, b, .core3, "First three finished items", "players who finished three items: longer games, so compare these win rates with each other rather than with the champion's overall");
    try w.writeAll("<h2>Skill priority</h2>\n");
    try table(w, f, b, .skills, "Order", "players with a match timeline who reached level 11");
    try table(w, f, b, .skill_start, "Levels 1 to 3", "players with a match timeline");
    const to_site = site.toShared(page_path);
    try tpl.render(w,
        \\<p class="muted"><a href="{champ}">{name}</a> · <a href="{site}method.html#builds">How builds are counted</a></p>
        \\
    , .{ .champ = site.champHref(ch, to_site), .name = ch.name, .site = to_site });
    try html.foot(w, p);
}

/// "52.3% ±2.4", or "few games" under rate_games
fn winRate(w: *Writer, games: u32, wins: u32) !void {
    if (games < rate_games) return w.writeAll("<span class=\"muted\">few games</span>");
    const n: f64 = @floatFromInt(games);
    const rate = @as(f64, @floatFromInt(wins)) / n;
    try tpl.render(w, "{rate:.1}% <span class=\"muted\">±{pm:.1}</span>", .{
        .rate = 100 * rate,
        .pm = 196 * @sqrt(rate * (1 - rate) / n),
    });
}

fn table(w: *Writer, f: *const File, b: File.Build, kind: Kind, comptime title: []const u8, comptime of: []const u8) !void {
    try w.writeAll("<div class=\"table-scroll\"><table class=\"build\">\n<thead><tr><th>" ++ title ++
        "</th><th class=\"num\">Games</th><th class=\"num\">Share</th><th class=\"num\">Win rate</th></tr></thead>\n<tbody>\n");
    const rows = b.get(kind) orelse File.Rows{ .kind = kind, .games = 0, .wins = 0, .options = &.{} };
    if (rows.options.len == 0) {
        try w.writeAll("<tr class=\"thin\"><td colspan=\"4\">More data needed</td></tr>\n");
    }
    const hi = if (marked(kind)) highest(rows.options, rows.games, rows.wins, f.shrinkK(kind, false), 2) else null;
    for (rows.options, 0..) |o, i| {
        if (i >= rows_shown and i != hi) continue;
        try tpl.render(w,
            \\<tr{class}><td>{value}{tags}</td><td class="num">{games}</td><td class="num">{share:.1}%</td><td class="num">{rate}</td></tr>
            \\
        , .{
            .class = if (i == hi) tpl.flag(true, "class=\"hw\"") else tpl.flag(o.games < solid_games, "class=\"thin\""),
            .value = tpl.call(value, .{ f, kind, o.v, false }),
            .tags = tpl.call(tags, .{ i, hi }),
            .games = o.games,
            .share = pct(o.games, rows.games),
            .rate = tpl.call(winRate, .{ o.games, o.wins }),
        });
    }
    try tpl.renderPart(w, "</tbody></table></div>\n<p class=\"muted caption\">Share of {games} " ++ of ++ ".</p>\n", .{
        .games = rows.games,
    });
}

/// `compact`: icons without names beside them (names on hover), shards one a line
fn value(w: *Writer, f: *const File, kind: Kind, v: []const u32, compact: bool) !void {
    switch (kind) {
        .keystone, .boots, .rune => {
            if (v[0] == 0) return w.writeAll("No boots");
            try named(w, if (kind == .boots) f.items else f.runes, v[0], !compact);
        },
        .shard => if (ddragon.find(&ddragon.shards, v[1])) |n| try tpl.writeEscaped(n.name, w),
        .spells => for (v, 0..) |x, i| {
            if (i > 0) try w.writeAll(" ");
            try named(w, f.spells, x, !compact);
        },
        .runes => for (v, 0..) |x, i| {
            // Trees (0, 5) as a divider, runes as icons
            if (i == 5) try w.writeAll("<span class=\"sep\">|</span>");
            if (i == 0 or i == 5) continue;
            try named(w, f.runes, x, false);
        },
        .shards => for (v, 0..) |x, i| {
            if (i > 0) try w.writeAll(if (compact) "<br>" else " · ");
            if (ddragon.find(f.runes, x)) |n| try tpl.writeEscaped(n.name, w) else try w.print("#{d}", .{x});
        },
        .start => for (v) |x| try named(w, f.items, x, false),
        .core2, .core3 => for (v, 0..) |x, i| {
            if (i > 0) try w.writeAll("<span class=\"sep\">›</span>");
            try named(w, f.items, x, false);
        },
        .skills, .skill_start => for (v, 0..) |x, i| {
            if (i > 0) try w.writeAll(if (kind == .skills) "<span class=\"sep\">›</span>" else " ");
            try tpl.render(w, "<b>{key}</b>", .{ .key = switch (x) {
                1 => "Q",
                2 => "W",
                3 => "E",
                else => "?",
            } });
        },
    }
}

/// Icon (name as alt and title), and the name beside it with `label`
fn named(w: *Writer, list: []const ddragon.Named, id: u32, label: bool) !void {
    var buf: [16]u8 = undefined;
    const n = ddragon.find(list, id) orelse ddragon.Named{ .id = id, .name = try std.mem.print(&buf, "#{d}", .{id}) };
    if (n.icon.len > 0) {
        try tpl.render(w,
            \\<img class="icon" src="{src}" alt="{name}" title="{name}" width="28" height="28" loading="lazy">
        , .{ .src = n.icon, .name = n.name });
    }
    if (label or n.icon.len == 0) try tpl.render(w, "<span class=\"label\">{name}</span>", .{ .name = n.name });
}

test "highest win rate: pulled toward the slot's by k games, two or more options" {
    const o = struct {
        fn f(games: u32, wins: u32) File.Option {
            return .{ .v = &.{}, .games = games, .wins = wins };
        }
    }.f;
    // 70% in 30 games shows no win rate, so is never marked; 54% in 500 games
    const opts = [_]File.Option{ o(1200, 600), o(700, 360), o(500, 270), o(30, 21) };
    try std.testing.expectEqual(2, highest(&opts, 2430, 1251, 1000, 2));
    try std.testing.expectEqual(null, highest(&opts, 2430, 1251, null, 2));
    // The low end of the range: 53% in 100 games is less sure than 52% in 2,000
    try std.testing.expectEqual(0, highest(&.{ o(2000, 1040), o(100, 53) }, 2100, 1093, 0, 2));
    try std.testing.expectEqual(null, highest(&.{ o(1900, 1000), o(90, 60) }, 1990, 1060, 1000, 2));
    // A rune row: its only rated rune is ringed
    try std.testing.expectEqual(0, highest(&.{ o(1900, 1000), o(90, 60) }, 1990, 1060, 1000, 1));
}

test "rank label" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try std.testing.expectEqualStrings("Platinum IV and up", try rankLabel(a, "PLATINUM"));
    try std.testing.expectEqualStrings("Master and up", try rankLabel(a, "MASTER"));
    try std.testing.expectEqualStrings("every player in Platinum+ games", try rankLabel(a, ""));
}

test "rune shifts: 10+ points from usual, runes left out of the matchup too" {
    const rows = struct {
        fn of(options: []const File.Option) [1]File.Rows {
            return .{.{ .kind = .rune, .games = 1000, .wins = 500, .options = options }};
        }
    };
    const usual_rows = rows.of(&.{
        .{ .v = &.{8010}, .games = 600, .wins = 300 },
        .{ .v = &.{8008}, .games = 400, .wins = 200 },
        .{ .v = &.{8444}, .games = 300, .wins = 150 },
        .{ .v = &.{8299}, .games = 50, .wins = 25 },
    });
    const vs_rows = rows.of(&.{
        .{ .v = &.{8010}, .games = 800, .wins = 400 },
        .{ .v = &.{8008}, .games = 150, .wins = 75 },
        // Under shift_games: never listed
        .{ .v = &.{8021}, .games = 50, .wins = 25 },
    });
    const usual: File.Build = .{ .champion = 1, .role = .top, .games = 1000, .wins = 500, .kinds = &usual_rows };
    const vs: File.Build = .{ .champion = 1, .role = .top, .opponent = 2, .games = 1000, .wins = 500, .kinds = &vs_rows };
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const got = try runeShifts(arena.allocator(), vs, usual);
    try std.testing.expectEqual(3, got.len);
    const want = [_]struct { u32, f64, f64 }{ .{ 8444, 0, 30 }, .{ 8008, 15, 40 }, .{ 8010, 80, 60 } };
    for (want, got) |w, g| {
        try std.testing.expectEqual(w[0], g.id);
        try std.testing.expectApproxEqAbs(w[1], g.here, 1e-9);
        try std.testing.expectApproxEqAbs(w[2], g.usual, 1e-9);
    }
    try std.testing.expectEqual(0, (try runeShifts(arena.allocator(), vs, null)).len);
}
