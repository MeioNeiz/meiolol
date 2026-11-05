//! Pv: Meio's preview on public champion pages, for tester and admin logins only (app.md
//! "Private site"): Meio's estimate for the newest patch under the page's locks, before
//! it becomes the third period option (estimates.md E0) and the public pages show it.
//! ui-pv.wasm draws it under the head from ui.pvdata.Meio, one file per period. One
//! figure: Meio's number, its count as the games its range is worth (an estimate, not
//! games played), then a scale with Meio's 80% band and dot beside the two raw windows'
//! ticks, which say their names on hover only
const std = @import("std");
const tree = @import("tree.zig");
const badge = @import("badge.zig");
const tip = @import("tip.zig");
const phrase = @import("phrase.zig");
const rate = @import("rate.zig");
const pd = @import("pvdata.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;

pub const name = "Pv";
pub const scope = .{".c-pv"};
pub const sel = ".c-pv";

const W = struct {
    pub const tag = plain("Meio preview");
    pub const about = plain("Our estimate for the newest patch, beside the raw 30 days and patch rates. Admins only until it beats both");
    pub const said = plain("Meio");
    pub const days = Phrase("30 days {p:rate}, {n:count} games");
    pub const patch = Phrase("Newest patch {p:rate}, {n:count} games");
    pub const no_model = plain("no model loaded");
    pub const master = plain("raw only at Master+");
    pub const kind = plain("a lock it doesn't model");
    pub const deep = plain("stops at two locks");
};

/// A raw window's games and wins under the locks
pub const Raw = struct { games: u32, wins: u32 };

/// What the figure draws: Meio's number (null with `gap`'s reason) and the raw windows,
/// each null until its file is in or with no games
pub const Preview = struct {
    est: ?pd.Est,
    gap: pd.Gap = .none,
    days: ?Raw = null,
    patch: ?Raw = null,

    /// From the two periods' files (either may be missing); null when neither is in
    pub fn of(days: ?*const pd.Meio, patch: ?*const pd.Meio) ?Preview {
        const any = days orelse patch orelse return null;
        return .{ .est = any.stack, .gap = any.gap, .days = raw(days), .patch = raw(patch) };
    }

    fn raw(m: ?*const pd.Meio) ?Raw {
        const x = m orelse return null;
        return if (x.games == 0) null else .{ .games = x.games, .wins = x.wins };
    }
};

/// The games a binomial rate at `p` needs for an 80% range as narrow as Meio's
fn worth(e: pd.Est) u32 {
    const half: f64 = @max(0.0005, (e.hi - e.lo) / 2);
    const p: f64 = e.p;
    const n = p * (1 - p) * std.math.pow(f64, 1.2816 / half, 2);
    return if (n > 1e8) 100_000_000 else @intFromFloat(n + 0.5);
}

pub fn view(h: *H, v: Preview) N {
    const gap: ?tree.Text = switch (v.gap) {
        .none => null,
        .no_model => W.no_model,
        .master => W.master,
        .kind => W.kind,
        .deep => W.deep,
    };
    const tag = tip.view(h, W.about, .{badge.view(h, .accent, .{W.tag})}, .{ .below = true });
    const e = v.est orelse return h.div(.{ .class = "c-pv" }, .{ tag, h.small(.{}, .{gap orelse W.no_model}) });
    return h.div(.{ .class = "c-pv" }, .{
        tag,
        rate.view(h, .{ .pct = 100 * e.p, .games = worth(e), .half = 100 * (e.hi - e.lo) / 2 }, .{ .said = W.said.s, .worth = true }),
        scale(h, v),
    });
}

/// Meio's band and dot, the raw windows' ticks, 50 when near, on one axis fitted to them
/// and `min_span` wide at least, so half a point's gap looks small
fn scale(h: *H, v: Preview) N {
    var lo: f64 = 100;
    var hi: f64 = 0;
    const d = if (v.days) |r| pct(r) else null;
    const p = if (v.patch) |r| pct(r) else null;
    if (v.est) |e| {
        lo = 100 * e.lo;
        hi = 100 * e.hi;
    }
    for ([_]?f64{ d, p }) |x| if (x) |y| {
        lo = @min(lo, y);
        hi = @max(hi, y);
    };
    if (lo > hi) return h.span(.{}, .{});
    const pad = @max(1, (hi - lo) * 0.15, (min_span - (hi - lo)) / 2);
    lo -= pad;
    hi += pad;
    const fifty = lo - 2 < 50 and hi + 2 > 50;
    if (fifty) {
        lo = @min(lo, 49);
        hi = @max(hi, 51);
    }
    const at = struct {
        fn f(x: f64, a: f64, b: f64) f64 {
            return 100 * (x - a) / (b - a);
        }
    }.f;
    var marks = h.list();
    if (fifty) marks.add(h.span(.{ .class = "m", .style = h.vars(.{ .x = at(50, lo, hi) }) }, .{}));
    if (v.est) |e| {
        marks.add(h.span(.{ .class = "b", .style = h.vars(.{ .x = at(100 * e.lo, lo, hi), .w = at(100 * e.hi, lo, hi) - at(100 * e.lo, lo, hi) }) }, .{}));
    }
    if (v.est) |e| marks.add(h.span(.{ .class = "o", .style = h.vars(.{ .x = at(100 * e.p, lo, hi) }) }, .{}));
    if (v.days) |r| marks.add(tick(h, "t d", at(d.?, lo, hi), W.days.with(h, .{ .p = d.?, .n = r.games })));
    if (v.patch) |r| marks.add(tick(h, "t p", at(p.?, lo, hi), W.patch.with(h, .{ .p = p.?, .n = r.games })));
    return h.span(.{ .class = "ax" }, .{marks.done()});
}

/// A raw window's tick at `x` % along, its name and rate in a Tip
fn tick(h: *H, comptime class: []const u8, x: f64, said: tree.Text) N {
    return h.span(.{ .class = class, .style = h.vars(.{ .x = x }) }, .{tip.view(h, said, .{h.span(.{ .class = "k" }, .{})}, .{})});
}

const min_span = 6;

fn pct(r: Raw) f64 {
    return 100 * @as(f64, @floatFromInt(@min(r.wins, r.games))) / @as(f64, @floatFromInt(@max(r.games, 1)));
}

pub const css =
    \\@layer components {
    \\  .c-pv { display: flex; flex-wrap: wrap; align-items: center; justify-content: flex-end;
    \\    gap: var(--sp-2) var(--sp-3);
    \\    padding: 0 var(--card-px); margin-bottom: var(--sp-2); }
    \\  .c-pv > small { font-size: var(--fs-xs); color: var(--faint); }
    \\  .c-pv > .c-rate > .v { font-size: var(--fs-l); font-weight: var(--w-b); }
    \\  .c-pv .ax { position: relative; display: inline-block; width: 160px; height: 16px; }
    \\  .c-pv .ax::before { content: ""; position: absolute; left: 0; right: 0; top: 50%; border-top: 1px solid var(--line); }
    \\  .c-pv .ax > span { position: absolute; left: calc(var(--x) * 1%); top: 50%; translate: -50% -50%; }
    \\  .c-pv .ax > .m { height: 10px; border-left: 1px dashed var(--faint); translate: 0 -50%; }
    \\  .c-pv .ax > .b { width: calc(var(--w) * 1%); height: 8px; translate: 0 -50%; border-radius: 4px;
    \\    background: color-mix(in srgb, var(--accent) 30%, transparent); }
    \\  .c-pv .ax > .t { z-index: 1; }
    \\  .c-pv .ax > .t .k { display: block; width: 9px; height: 9px; border-radius: 50%;
    \\    border: 1.5px solid var(--muted); background: var(--bg); }
    \\  .c-pv .ax > .t.p .k { border-radius: 1px; rotate: 45deg; }
    \\  .c-pv .ax > .o { width: 10px; height: 10px; border-radius: 50%; background: var(--accent); }
    \\}
    \\
;

const demo_est: pd.Est = .{ .p = 0.522, .lo = 0.516, .hi = 0.528, .own = 972 };

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.add("below both raw windows (Ornn top, 149)", view(h, .{ .est = demo_est, .days = .{ .games = 26994, .wins = 14227 }, .patch = .{ .games = 972, .wins = 536 } }));
    g.add("under a lock, wide band, near 50", view(h, .{ .est = .{ .p = 0.497, .lo = 0.452, .hi = 0.541, .own = 4 }, .days = .{ .games = 290, .wins = 151 }, .patch = .{ .games = 40, .wins = 18 } }));
    g.add("the patch file not in yet", view(h, .{ .est = demo_est, .days = .{ .games = 26994, .wins = 14227 } }));
    g.add("Master+: no Meio, its reason, no scale", view(h, .{ .est = null, .gap = .master, .days = .{ .games = 812, .wins = 409 }, .patch = .{ .games = 70, .wins = 33 } }));
}

const testing = std.testing;

test "view: Meio's figure with its worth, the windows on hover and in sr text" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    const v: Preview = .{ .est = demo_est, .days = .{ .games = 26994, .wins = 14227 }, .patch = .{ .games = 972, .wins = 536 } };
    var out: std.Io.Writer.Allocating = .init(arena.allocator());
    try @import("html.zig").write(&t, view(&h, v), &out.writer);
    const html = out.written();
    try testing.expect(std.mem.find(u8, html, ">52.2%<") != null);
    try testing.expect(std.mem.find(u8, html, "worth 11,") != null);
    try testing.expect(std.mem.find(u8, html, "30 days 52.7%, 26,994 games") != null);
    try testing.expect(std.mem.find(u8, html, "Newest patch 55.1%, 972 games") != null);
    try testing.expectEqual(null, std.mem.find(u8, html, "own"));
}

test "view: no Meio number, the reason and no scale" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    var out: std.Io.Writer.Allocating = .init(arena.allocator());
    try @import("html.zig").write(&t, view(&h, .{ .est = null, .gap = .master, .days = .{ .games = 812, .wins = 409 } }), &out.writer);
    const html = out.written();
    try testing.expect(std.mem.find(u8, html, "<small>raw only at Master+</small>") != null);
    try testing.expectEqual(null, std.mem.find(u8, html, "class=\"ax\""));
    try testing.expectEqual(null, std.mem.find(u8, html, "c-rate"));
}

test "Preview.of: either period's file, raw windows without games dropped" {
    const m: pd.Meio = .{ .gap = .none, .any_slot = false, .games = 0, .wins = 0, .stack = demo_est, .gold = null, .keystones = &.{}, .items = &.{}, .opponents = &.{} };
    try testing.expectEqual(null, Preview.of(null, null));
    const v = Preview.of(null, &m).?;
    try testing.expectEqual(null, v.patch);
    try testing.expectEqual(0.522, v.est.?.p);
}
