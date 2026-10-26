//! Pool on the site: the pool.html skeleton that static/pool.js fills from
//! data/pool.json (src/pool.zig), and the "also play" section of each champion page.
//! Several options with their numbers and n, never "the best pick" (docs/concept.md).

const std = @import("std");
const root = @import("root.zig");
const html = @import("html.zig");
const tpl = html.tpl;
const pool = @import("../pool.zig");
const learning = @import("../learning.zig");
const learning_page = @import("learning.zig");
const scope = @import("scope.zig");
const champion = @import("champion.zig");
const core = @import("core");
const ui = @import("ui");
const pd = ui.pooldata;

const Writer = std.Io.Writer;
const Site = root.Site;

/// A pool's period as a scope chip: games over every patch, or lifetime mastery
pub fn periodDim(p: *const pool.Pool) scope.Dim {
    return switch (p.source) {
        .games => .every_patch,
        .mastery => .{ .key = "every", .text = "All time" },
    };
}

pub fn sourceText(p: *const pool.Pool) []const u8 {
    return switch (p.source) {
        .games => "their ranked solo games in our sample, every patch",
        .mastery => "their champion mastery, all time",
    };
}

/// One file per main with lists (from Options.min_players) and a role, in the view's
/// directory: data/pool/<slug>.bin
pub fn dataFiles(site: *const Site, files: anytype) !void {
    const a = site.arena;
    for (site.champs) |ch| {
        const m = for (site.pool.mains) |m| {
            if (m.id == ch.id) break m;
        } else continue;
        const f = try fileData(a, &site.stats, m, .{}) orelse continue;
        var out: std.ArrayList(u8) = .empty;
        try ui.data.encode(a, pd.File, f, &out);
        try files.append(a, .{ .path = try a.print("data/pool/{s}.bin", .{ch.slug}), .data = out.items });
    }
}

pub fn fileData(a: std.mem.Allocator, st: *const core.Stats, m: pool.Main, opts: pool.Options) !?pd.File {
    const r = m.role orelse return null;
    if (m.cols.len == 0) return null;
    const cells = try a.alloc(pd.Cell, m.cols.len * (m.hard.len + m.good.len));
    for (cells, try pool.grid(a, st, m, opts)) |*c, l| c.* = .{ .pp = tenths(l.pp), .games = l.games };
    const cols = try a.alloc(pd.Col, m.cols.len);
    for (cols, m.cols) |*c, x| c.* = .{ .id = try id16(x.id), .together = x.together };
    const also = try a.alloc(pd.Also, m.also.len);
    for (also, m.also) |*o, x| o.* = .{
        .id = try id16(x.id),
        .together = x.together,
        .lift = std.math.lossyCast(u16, @round(100 * x.lift)),
    };
    return .{
        .id = try id16(m.id),
        .role = champion.uiRole(r),
        .players = m.players,
        .one_tricks = m.one_tricks,
        .hard = try lanes(a, m.hard),
        .good = try lanes(a, m.good),
        .cols = cols,
        .cells = cells,
        .also = also,
    };
}

fn lanes(a: std.mem.Allocator, from: []const pool.Lane) ![]const pd.Lane {
    const out = try a.alloc(pd.Lane, from.len);
    for (out, from) |*o, l| o.* = .{ .id = try id16(l.id), .pp = tenths(l.pp), .games = l.games };
    return out;
}

fn tenths(pp: f64) i16 {
    return std.math.lossyCast(i16, @round(10 * pp));
}

fn id16(id: u32) error{BadId}!u16 {
    return std.math.cast(u16, id) orelse error.BadId;
}

/// With the learning-curve table under the picker (site/learning.zig)
pub fn writePage(site: *const Site, w: *Writer, p: *const pool.Pool, l: *const learning.Learning) !void {
    const pg = try site.page(
        "Champion pool | meiolol",
        "Pick the champions you main: what their players also play, how hard each champion is to pick up, and which do well where your main struggles.",
        "pool.html",
        .pool,
    );
    try html.head(w, pg);
    try tpl.render(w,
        \\<h1>Champion pool</h1>
        \\<p class="lead">Looking for a second champion? Pick the one you main, or up to
        \\three: see what else their players play and which do
        \\well where your main struggles or when it is banned. Several options with the
        \\numbers behind each; the choice is yours. <a href="pickup.html">How hard every
        \\champion is to pick up</a>.</p>
        \\<p id="status" class="note">Loading…</p>
        \\<form id="pool" class="pool-form" autocomplete="off" onsubmit="return false">
        \\<datalist id="champions"></datalist>
        \\<label><span>Main</span><input data-main list="champions" placeholder="Champion"></label>
        \\<label><span>Also</span><input data-main list="champions" placeholder="Champion (optional)"></label>
        \\<label><span>Also</span><input data-main list="champions" placeholder="Champion (optional)"></label>
        \\</form>
        \\<div id="results" data-to-site="{up}" data-query="{query}"></div>
        \\<p class="muted">{chip} A player's main is their most played champion, from {source}
        \\({players} players {in} so far); they play another when it has at least a tenth of their
        \\main's games or points. "59% (28%)": 59% of the main's players play it, 28% of other players do.
        \\Listed are those played most beyond their usual share (small groups count for less),
        \\from {min} players per main. Lane numbers are points of win chance beyond what the two
        \\champions' own win rates predict, {in} {when}, shown from 1 point either way (most
        \\matchups are closer to even).
        \\<a href="{up}method.html">Method</a>.</p>
        \\<script src="pool.js" defer></script>
        \\
    , .{
        .chip = site.chip(site.regionDim(site.view.region), periodDim(p), .plat),
        .up = site.view.up(),
        .query = site.view.query(),
        .source = sourceText(p),
        .players = root.Thousands{ .n = p.players },
        .min = p.min_players,
        .in = site.view.region.in(),
        .when = site.when,
    });
    try learning_page.table(site, w, l);
    try html.foot(w, pg);
}

test "pool file: a main's lanes and grid, through ui.data, as the page reads them" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const fx = try pool.testPool(a);
    try std.testing.expectEqual(null, try fileData(a, &fx.st, fx.pool.mains[2], pool.test_options));

    const f = (try fileData(a, &fx.st, fx.pool.mains[1], pool.test_options)).?;
    var bytes: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, pd.File, f, &bytes);
    const back = try ui.data.decode(a, pd.File, bytes.items);
    try std.testing.expectEqual(1, back.id);
    try std.testing.expectEqual(.top, back.role);
    try std.testing.expectEqual(4, back.hard[0].id);
    try std.testing.expect(back.hard[0].pp <= -pd.min_pp);
    try std.testing.expectEqual(5, back.good[0].id);
    try std.testing.expectEqual(back.cols.len * back.lanes(), back.cells.len);
    try std.testing.expectEqual(back.hard[0].pp, back.cells[0].pp);
    // 2 beats the main's hard lane, so the pool {1, 2} covers it and 2 is the first option
    try std.testing.expectEqual(0, back.covered(&.{1}));
    try std.testing.expectEqual(1, back.covered(&.{ 1, 2 }));
    var buf: [5]pd.File.Option = undefined;
    try std.testing.expectEqual(2, back.cols[back.options(&.{1}, .hard, &buf)[0].col].id);
}
