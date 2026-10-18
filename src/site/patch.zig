//! patch.html in every view: how the current patch compares with the one before
//! (src/patchday.zig) in the view's region, whole patches whatever its period. Clear
//! moves only, as facts with games and a range; the champion pages' line per role

const std = @import("std");
const core = @import("core");
const root = @import("root.zig");
const html = root.html;
const matchup = @import("matchup.zig");
const patchday = @import("../patchday.zig");

const Writer = std.Io.Writer;
const Site = root.Site;
const Champ = root.Champ;
const tpl = html.tpl;
const PatchDay = patchday.PatchDay;
const ChampionMove = patchday.ChampionMove;
const MatchupMove = patchday.MatchupMove;
const Rate = patchday.Rate;

pub const path = "patch.html";

/// Rows per table: the biggest moves
const max_rows = 20;
/// Fewer champion roles with enough games on both patches: a patch's first days
const early_roles = 100;

pub fn early(p: *const PatchDay) bool {
    return p.champions.len < early_roles;
}

pub fn writePage(site: *const Site, w: *Writer) !void {
    const a = site.arena;
    const pd = site.patchday orelse {
        const pg = site.page("Patch changes | meiolol", "How champions and lane matchups changed from the previous patch.", path, .patch);
        try html.head(w, pg);
        try tpl.render(w, "<h1>Patch changes</h1>\n<p>No earlier patch in the data yet to compare with.</p>\n", .{});
        return html.foot(w, pg);
    };
    const pg = site.page(
        try a.print("Patch {s} against {s}: what changed | meiolol", .{ pd.cur_patch, pd.prev_patch }),
        try a.print("Champions and lane matchups whose win rate or lane gold changed clearly from patch {s} to {s}, with the games behind each.", .{ pd.prev_patch, pd.cur_patch }),
        path,
        .patch,
    );
    try html.head(w, pg);
    const o = pd.opts;
    try tpl.render(w,
        \\<h1>Patch {cur}: what changed</h1>
        \\<p class="lead">Champions and lane matchups on patch {cur} against {prev}, ranked
        \\solo/duo {in}, Platinum+ games: {cur_games} games on {cur} so far, {prev_games} on
        \\{prev}. Whole patches, whichever period is picked above.</p>
        \\<p class="muted">Listed: a champion with {role_games} games in the role on both
        \\patches, a matchup with {pair_games}, and a change clear of chance (z above {z:.2},
        \\about 1 in 100 by luck alone; with a few hundred tested, expect one or two of
        \\those). Ranges hold 99 times in 100. <a href="{up}method.html">Method</a>.</p>
        \\
    , .{
        .cur = pd.cur_patch,
        .prev = pd.prev_patch,
        .in = site.view.region.in(),
        .cur_games = try root.thousands(a, pd.cur_games),
        .prev_games = try root.thousands(a, pd.prev_games),
        .role_games = o.min_role_games,
        .pair_games = o.min_pair_games,
        .z = o.z,
        .up = site.view.up(),
    });

    var up_rows: std.ArrayList(ChampionMove) = .empty;
    var down_rows: std.ArrayList(ChampionMove) = .empty;
    var lane_rows: std.ArrayList(ChampionMove) = .empty;
    for (pd.champions) |m| {
        if (m.win.clear(o.min_role_games, o.z)) try (if (m.win.z > 0) &up_rows else &down_rows).append(a, m);
        if (m.ahead) |r| if (r.clear(o.min_role_games, o.z)) try lane_rows.append(a, m);
    }
    if (up_rows.items.len + down_rows.items.len == 0) {
        if (early(&pd)) try tpl.render(w,
            \\<p class="note">Too early to tell: {n} champion roles have {min} games on both
            \\patches so far. Changes show here as games come in over the patch's first days.</p>
            \\
        , .{ .n = pd.champions.len, .min = o.min_role_games }) else try tpl.render(w,
            \\<p class="note">No champion's win rate changed clearly between the patches.</p>
            \\
        , .{});
    }
    std.mem.sort(ChampionMove, up_rows.items, {}, byWinDelta);
    std.mem.sort(ChampionMove, down_rows.items, {}, byWinDelta);
    std.mem.sort(ChampionMove, lane_rows.items, {}, byAheadDelta);
    try winTable(site, w, &pd, up_rows.items, "more");
    try winTable(site, w, &pd, down_rows.items, "less");
    try laneTable(site, w, &pd, lane_rows.items);
    try matchupTable(site, w, &pd);
    try html.foot(w, pg);
}

fn byWinDelta(_: void, x: ChampionMove, y: ChampionMove) bool {
    return @abs(x.win.delta()) > @abs(y.win.delta());
}

fn byAheadDelta(_: void, x: ChampionMove, y: ChampionMove) bool {
    return @abs(x.ahead.?.delta()) > @abs(y.ahead.?.delta());
}

/// "52.1% of 8,400"
fn rateOf(w: *Writer, c: core.curvesfile.Counts) !void {
    try root.pct(w, c.wins, c.games);
    try w.print(" of {f}", .{Thousands{ .n = c.games }});
}

/// root.thousands without an allocator
const Thousands = struct {
    n: u64,
    pub fn format(t: Thousands, w: *Writer) Writer.Error!void {
        var buf: [20]u8 = undefined;
        const digits = std.fmt.bufPrint(&buf, "{d}", .{t.n}) catch unreachable;
        for (digits, 0..) |c, i| {
            if (i > 0 and (digits.len - i) % 3 == 0) try w.writeByte(',');
            try w.writeByte(c);
        }
    }
};

/// "0.8 to 3.8 points", the size of the gap either way
fn gap(w: *Writer, r: Rate, z: f64) !void {
    const g = r.range(z);
    const lo = if (r.z > 0) g[0] else -g[1];
    const hi = if (r.z > 0) g[1] else -g[0];
    try w.print("{d:.1} to {d:.1} points", .{ lo, hi });
}

fn winTable(site: *const Site, w: *Writer, pd: *const PatchDay, rows: []const ChampionMove, dir: []const u8) !void {
    if (rows.len == 0) return;
    try tpl.renderPart(w,
        \\<h2>Won {dir} often than on {prev}</h2>
        \\<div class="table-scroll"><table class="patch"><thead><tr><th>Champion</th><th>Role</th><th>{prev}</th><th>{cur}</th><th>Gap (99% range)</th></tr></thead><tbody>
        \\
    , .{ .dir = dir, .prev = pd.prev_patch, .cur = pd.cur_patch });
    for (rows[0..@min(rows.len, max_rows)]) |m| {
        const ch = matchup.champ(site, m.id) orelse continue;
        try tpl.render(w, "<tr><td>{champ}</td><td>{role}</td><td>{prev}</td><td>{cur}</td><td>{gap}</td></tr>\n", .{
            .champ = tpl.call(champCell, .{ site, ch }),
            .role = root.roleName(m.role),
            .prev = tpl.call(rateOf, .{m.win.prev}),
            .cur = tpl.call(rateOf, .{m.win.cur}),
            .gap = tpl.call(gap, .{ m.win, pd.opts.z }),
        });
    }
    try tpl.renderPart(w, "</tbody></table></div>\n{more}", .{ .more = tpl.call(more, .{rows.len}) });
}

fn champCell(w: *Writer, site: *const Site, ch: Champ) !void {
    try site.champLink(w, ch, site.view.up());
}

fn more(w: *Writer, n: usize) !void {
    if (n > max_rows) try w.print("<p class=\"muted small\">And {d} more, smaller.</p>\n", .{n - max_rows});
}

fn laneTable(site: *const Site, w: *Writer, pd: *const PatchDay, rows: []const ChampionMove) !void {
    if (rows.len == 0) return;
    try tpl.renderPart(w,
        \\<h2>Ahead in lane at {minute} min, more or less often</h2>
        \\<div class="table-scroll"><table class="patch"><thead><tr><th>Champion</th><th>Role</th><th>{prev}</th><th>{cur}</th><th>Gap (99% range)</th></tr></thead><tbody>
        \\
    , .{ .minute = core.curvesfile.lane_minute, .prev = pd.prev_patch, .cur = pd.cur_patch });
    for (rows[0..@min(rows.len, max_rows)]) |m| {
        const ch = matchup.champ(site, m.id) orelse continue;
        const r = m.ahead.?;
        try tpl.render(w, "<tr><td>{champ}</td><td>{role}</td><td>{prev}</td><td>{cur}</td><td>{dir} {gap}</td></tr>\n", .{
            .champ = tpl.call(champCell, .{ site, ch }),
            .role = root.roleName(m.role),
            .prev = tpl.call(rateOf, .{r.prev}),
            .cur = tpl.call(rateOf, .{r.cur}),
            .dir = if (r.z > 0) "more:" else "less:",
            .gap = tpl.call(gap, .{ r, pd.opts.z }),
        });
    }
    try tpl.renderPart(w, "</tbody></table></div>\n{more}", .{ .more = tpl.call(more, .{rows.len}) });
}

/// Matchups whose median gold moved clearly at some minute, or whose win rate did, from
/// the side that gained
fn matchupTable(site: *const Site, w: *Writer, pd: *const PatchDay) !void {
    const a = site.arena;
    const o = pd.opts;
    var rows: std.ArrayList(MatchupMove) = .empty;
    for (pd.matchups) |m| {
        const gold_up = if (m.gold) |g| g.cur > g.prev else false;
        const win_clear = m.win.clear(o.min_pair_games, o.z);
        if (m.gold == null and !win_clear) continue;
        const up = if (m.gold != null) gold_up else m.win.z > 0;
        try rows.append(a, if (up) m else pd.matchup(m.role, m.b, m.a).?);
    }
    if (rows.items.len == 0) return;
    std.mem.sort(MatchupMove, rows.items, {}, byGold);
    // Matchup pages with patch curves are in the patch view
    const to_patch = if (site.view.period == .patch) "" else "patch/";
    try tpl.renderPart(w,
        \\<h2>Lane matchups that moved</h2>
        \\<div class="table-scroll"><table class="patch"><thead><tr><th>Matchup</th><th>Role</th><th>Median gold lead</th><th>Won, {prev}</th><th>Won, {cur}</th></tr></thead><tbody>
        \\
    , .{ .prev = pd.prev_patch, .cur = pd.cur_patch });
    for (rows.items[0..@min(rows.items.len, max_rows)]) |m| {
        const x = matchup.champ(site, m.a) orelse continue;
        const y = matchup.champ(site, m.b) orelse continue;
        try tpl.render(w, "<tr><td><a href=\"{href}\">{x} vs {y}</a></td><td>{role}</td><td>{gold}</td><td>{prev}</td><td>{cur}</td></tr>\n", .{
            .href = try std.mem.concat(a, u8, &.{ to_patch, try matchup.path(a, m.role, x, y) }),
            .x = x.name,
            .y = y.name,
            .role = root.roleName(m.role),
            .gold = tpl.call(goldCell, .{m.gold}),
            .prev = tpl.call(rateOf, .{m.win.prev}),
            .cur = tpl.call(rateOf, .{m.win.cur}),
        });
    }
    try tpl.renderPart(w,
        \\</tbody></table></div>
        \\{more}<p class="muted small">From the first champion's side. Gold: the minute its
        \\median moved most, {prev} then {cur}, with games still going at that minute.</p>
        \\
    , .{ .more = tpl.call(more, .{rows.items.len}), .prev = pd.prev_patch, .cur = pd.cur_patch });
}

fn byGold(_: void, x: MatchupMove, y: MatchupMove) bool {
    return goldDelta(x) > goldDelta(y);
}

fn goldDelta(m: MatchupMove) i32 {
    const g = m.gold orelse return 0;
    return @as(i32, g.cur) - g.prev;
}

fn goldCell(w: *Writer, gold: ?patchday.GoldMove) !void {
    const g = gold orelse return w.writeAll("about the same");
    try w.print("{f} then {f} at {d} min ({f} and {f} games)", .{
        Signed{ .v = g.prev }, Signed{ .v = g.cur }, g.minute, Thousands{ .n = g.prev_n }, Thousands{ .n = g.cur_n },
    });
}

const Signed = struct {
    v: i32,
    pub fn format(s: Signed, w: *Writer) Writer.Error!void {
        try w.print("{s}{d}", .{ if (s.v > 0) "+" else "", s.v });
    }
};

/// A champion page's line in role `r`: this patch against the previous one, the root
/// view's region
pub fn since(site: *const Site, w: *Writer, ch: Champ, r: core.Role, to_view: []const u8) !void {
    const pd = if (site.patchday) |*p| p else return;
    const o = pd.opts;
    const m = pd.champion(ch.id, r) orelse {
        if (early(pd)) try tpl.render(w,
            \\<p class="since muted">Patch {cur} against {prev}: too early to tell, too few games on {cur} so far. <a href="{href}">Patch changes</a></p>
            \\
        , .{ .cur = pd.cur_patch, .prev = pd.prev_patch, .href = try std.mem.concat(site.arena, u8, &.{ to_view, path }) });
        return;
    };
    const clear = m.win.clear(o.min_role_games, o.z);
    try tpl.renderPart(w, "<p class=\"since muted\">Patch {cur} against {prev}, {in}: {verdict}, {now} games won against {then}", .{
        .cur = pd.cur_patch,
        .prev = pd.prev_patch,
        .in = site.view.region.in(),
        .verdict = if (!clear) "no clear change" else if (m.win.z > 0) "won more often" else "won less often",
        .now = tpl.call(rateOf, .{m.win.cur}),
        .then = tpl.call(rateOf, .{m.win.prev}),
    });
    if (clear) try tpl.renderPart(w, " (a gap of {gap}, 99% range)", .{ .gap = tpl.call(gap, .{ m.win, o.z }) });
    if (m.ahead) |l| if (l.clear(o.min_role_games, o.z)) {
        try tpl.renderPart(w, ". Ahead in lane at {minute} min {dir} often: {now} games against {then}", .{
            .minute = core.curvesfile.lane_minute,
            .dir = if (l.z > 0) "more" else "less",
            .now = tpl.call(rateOf, .{l.cur}),
            .then = tpl.call(rateOf, .{l.prev}),
        });
    };
    try tpl.renderPart(w, ". <a href=\"{href}\">Patch changes</a></p>\n", .{ .href = try std.mem.concat(site.arena, u8, &.{ to_view, path }) });
}
