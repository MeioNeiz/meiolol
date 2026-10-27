//! Pool on the site: pool.html (the ui.poolpage island, ui-pool.wasm) and its files,
//! one per main and view (data/pool/<slug>.bin). Several options with their numbers and
//! n, never "the best pick" (docs/concept.md).

const std = @import("std");
const root = @import("root.zig");
const html = @import("html.zig");
const tpl = html.tpl;
const pool = @import("../pool.zig");
const champion = @import("champion.zig");
const core = @import("core");
const ui = @import("ui");
const pd = ui.pooldata;
const page_ui = ui.poolpage;
const assets = @import("assets.zig");

const Writer = std.Io.Writer;
const Site = root.Site;

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

comptime {
    const o: pool.Options = .{};
    std.debug.assert(pd.min_games == o.min_pair_games);
    std.debug.assert(pd.min_pp == tenths(o.min_lane_pp));
}

fn tenths(pp: f64) i16 {
    return std.math.lossyCast(i16, @round(10 * pp));
}

fn id16(id: u32) error{BadId}!u16 {
    return std.math.cast(u16, id) orelse error.BadId;
}

pub const path = "pool.html";

/// The island, empty (the picker), with every champion and the mains with a file in its
/// data-bin; the lanes' scope under it
pub fn writePage(site: *const Site, w: *Writer, p: *const pool.Pool) !void {
    const a = site.arena;
    const pg = try site.page(
        "Champion pool | meiolol",
        "Pick your champions: the lanes your main struggles in, which champions cover them, what to play when it is banned and what its players also play.",
        path,
        .pool,
    );
    try html.head(w, pg);
    const d = try a.create(page_ui.Data);
    d.* = try pageData(site, p);
    var page: page_ui.Page = try .init(a, d);
    page.bin = try bin(a, d.*);
    var t: ui.Tree = .{};
    var h: ui.H = .init(a, &t);
    t.root = page.view(&h);
    if (h.oom) return error.OutOfMemory;
    try ui.html.write(&t, t.root, w);
    const to_root = try site.toRoot(path);
    try tpl.render(w,
        \\
        \\<p class="muted">{chip} Lanes: points of win chance beyond what the two champions'
        \\own win rates predict, from {games} games. A main is a player's most played champion,
        \\from {source}. <a href="{up}method.html">Method</a>.</p>
        \\<script src="{js}" data-wasm="{wasm}" defer></script>
        \\
    , .{
        .chip = site.chip(site.regionDim(site.view.region), site.periodDim(site.view.period), .plat),
        .games = pd.min_games,
        .source = sourceText(p),
        .up = site.view.up(),
        .js = html.Link{ .root = to_root, .up = site.view.up(), .path = assets.pool_js.path },
        .wasm = assets.pool_wasm.path,
    });
    try html.foot(w, pg);
}

/// Champions with a file (dataFiles' rule), most players first as pool.mains are
fn pageData(site: *const Site, p: *const pool.Pool) !page_ui.Data {
    const a = site.arena;
    const champs = try a.alloc(page_ui.Champ, site.champs.len);
    for (champs, site.champs) |*c, ch| c.* = .{ .id = try id16(ch.id), .name = ch.name, .key = ch.key, .slug = ch.slug };
    var mains: std.ArrayList(page_ui.Main) = .empty;
    for (p.mains) |m| {
        const r = m.role orelse continue;
        if (m.cols.len == 0) continue;
        const c = for (site.champs, 0..) |ch, i| {
            if (ch.id == m.id) break i;
        } else continue;
        try mains.append(a, .{ .c = @intCast(c), .role = champion.uiRole(r), .players = m.players });
    }
    return .{ .ddragon = site.ddragon_version, .champs = champs, .mains = mains.items };
}

/// `v` as ui.data, base64: the island root's data-bin
fn bin(a: std.mem.Allocator, v: page_ui.Data) ![]const u8 {
    var raw: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, page_ui.Data, v, &raw);
    const e = std.base64.standard.Encoder;
    const out = try a.alloc(u8, e.calcSize(raw.items.len));
    return e.encode(out, raw.items);
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
