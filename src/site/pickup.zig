//! How hard each champion is to pick up (src/learning.zig): new players' win rate against
//! practised players', a dumbbell row per champion, the biggest gap first. One page per
//! view and role; lean on purpose (pool.md, review v9: designed properly later)

const std = @import("std");
const core = @import("core");
const ui = @import("ui");
const root = @import("root.zig");
const html = @import("html.zig");
const tpl = html.tpl;
const champion = @import("champion.zig");
const matchup = @import("matchup.zig");
const learning = @import("../learning.zig");
const pool = @import("../pool.zig");

const Writer = std.Io.Writer;
const Site = root.Site;
const Role = core.Role;
const H = ui.H;
const N = ui.N;
const plain = ui.plain;
const Phrase = ui.Phrase;

/// /pickup, then /pickup/<role>
pub fn paths(site: *const Site, list: *std.ArrayList(ui.urls.Page)) !void {
    try list.append(site.arena, .{ .pickup = null });
    for (Role.all) |r| try list.append(site.arena, .{ .pickup = champion.uiRole(r) });
}

const W = struct {
    const title = "How hard to pick up";
    const all = plain("All");
    const roles = plain("Role");
    const names = [2][]const u8{ "New", "Practised" };
    const fig = plain("Gap");
    const gap = Phrase("{v:points}");
    const harder = plain("Harder");
    const easier = plain("Easier");
    const none = plain("More data needed: no champion has 200+ games each from new and practised players yet.");
    const note = Phrase("New: under 30k mastery points on the champion; practised: 100k+. {n:count} ranked solo games. Practised players are better players too, so every champion has a gap ({m:dec} points on average): harder or easier only when a gap is clearly bigger or smaller than that.");
};

pub fn writePage(site: *const Site, w: *Writer, r: ?Role) !void {
    const a = site.arena;
    const pg = try site.page(
        "How hard each champion is to pick up | meiolol",
        "Win rate of players new to each champion against practised ones: the gap shows which champions take longest to learn.",
        .{ .pickup = if (r) |x| champion.uiRole(x) else null },
        .pool,
    );
    try html.head(w, pg);
    // Every region's games, by the view's period (load.zig)
    try tpl.render(w, "<h1>{title} {chip}</h1>\n", .{
        .title = W.title,
        .chip = site.chip(site.regionDim(.all), site.periodDim(site.view.period), .plat),
    });
    var tree: ui.Tree = .{};
    var h: H = .init(a, &tree);
    tree.root = try view(site, &h, r);
    if (h.oom) return error.OutOfMemory;
    try ui.html.write(&tree, tree.root, w);
    try html.foot(w, pg);
}

fn view(site: *const Site, h: *H, r: ?Role) !N {
    const a = site.arena;
    const l = &site.learning;
    var segs: [1 + Role.all.len]ui.segmented.Item = undefined;
    segs[0] = .{ .label = W.all, .selected = r == null, .href = try site.href(.{ .pickup = null }) };
    for (Role.all, segs[1..]) |x, *s| s.* = .{
        .label = champion.uiRole(x).label(),
        .selected = r == x,
        .href = try site.href(.{ .pickup = champion.uiRole(x) }),
    };
    var rows: std.ArrayList(Row) = .empty;
    for (try order(a, l, &site.stats, r)) |c| {
        const ch = matchup.champ(site, c.id) orelse continue;
        try rows.append(a, .{
            .champ = .{ .name = ch.name, .src = try site.icon(ch) },
            .href = try site.champHref(ch),
            .gap = c.gap.?,
        });
    }
    return h.div(.{ .class = "c-pickup" }, .{
        ui.segmented.view(h, .{ .s = .s, .label = W.roles }, &segs),
        try body(h, rows.items),
        h.p(.{ .class = "muted" }, .{W.note.with(h, .{ .n = l.games, .m = @as(f32, @floatCast(l.mean_pp)) })}),
    });
}

/// Champions with a gap (on a role's page, those playing it), the biggest gap pulled
/// toward the average first
fn order(a: std.mem.Allocator, l: *const learning.Learning, st: *const core.Stats, r: ?Role) ![]learning.Champion {
    var list: std.ArrayList(learning.Champion) = .empty;
    for (l.champions) |c| {
        if (c.gap == null) continue;
        if (r) |x| {
            const i = st.index(c.id) orelse continue;
            if (!pool.playsRole(st, i, x, .{})) continue;
        }
        try list.append(a, c);
    }
    std.mem.sort(learning.Champion, list.items, {}, struct {
        fn f(_: void, x: learning.Champion, y: learning.Champion) bool {
            return x.gap.?.pulled > y.gap.?.pulled;
        }
    }.f);
    return list.items;
}

const Row = struct { champ: ui.champ.Champ, href: []const u8, gap: learning.Gap };

fn body(h: *H, rows: []const Row) !N {
    if (rows.len == 0) return h.p(.{ .class = "note" }, .{W.none});
    var lo: f32 = 100;
    var hi: f32 = 0;
    const bells = try h.mem.alloc(ui.versus.Bell, rows.len);
    for (bells, rows) |*b, x| {
        const g = x.gap;
        const new: f32 = @floatCast(100 * g.new.winRate());
        const old: f32 = @floatCast(100 * g.practised.winRate());
        lo = @min(lo, new, old);
        hi = @max(hi, new, old);
        b.* = .{
            .head = h.a(.{ .href = x.href }, .{ ui.champ.view(h, x.champ, .{ .named = false }), x.champ.name }),
            .a = new,
            .b = old,
            .fig = W.gap.with(h, .{ .v = @as(f32, @floatCast(g.pp)) }),
            .tag = switch (g.kind) {
                .harder => ui.badge.view(h, .neutral, .{W.harder}),
                .easier => ui.badge.view(h, .neutral, .{W.easier}),
                .usual => null,
            },
        };
    }
    const axis = axisOf(lo, hi);
    return ui.versus.dumbbell(h, .{
        .names = W.names,
        .fig = W.fig,
        .lo = @floatFromInt(axis.lo),
        .hi = @floatFromInt(axis.hi),
        .ticks = axis.ticks(),
    }, bells);
}

const Axis = struct {
    lo: u8,
    hi: u8,
    buf: [21]u8 = undefined,
    n: usize = 0,

    fn ticks(x: *const Axis) []const u8 {
        return x.buf[0..x.n];
    }
};

/// Whole fives around the rates, a tick on each
fn axisOf(lo: f32, hi: f32) Axis {
    const from: u8 = @intFromFloat(@floor(std.math.clamp(lo, 0, 95) / 5) * 5);
    const to: u8 = @intFromFloat(@ceil(std.math.clamp(hi, @as(f32, @floatFromInt(from)) + 5, 100) / 5) * 5);
    var x: Axis = .{ .lo = from, .hi = to };
    var t = from;
    while (t <= to) : (t += 5) {
        x.buf[x.n] = t;
        x.n += 1;
    }
    return x;
}

test "axis: whole fives around the rates" {
    const x = axisOf(41.2, 52.9);
    try std.testing.expectEqual(40, x.lo);
    try std.testing.expectEqual(55, x.hi);
    try std.testing.expectEqualSlices(u8, &.{ 40, 45, 50, 55 }, x.ticks());
    const flat = axisOf(50, 50);
    try std.testing.expectEqualSlices(u8, &.{ 50, 55 }, flat.ticks());
    try std.testing.expectEqual(21, axisOf(-3, 140).n);
}

fn testGap(new: u32, practised: u32, pulled: f64, kind: learning.Kind) ?learning.Gap {
    return .{
        .new = .{ .games = 1000, .wins = new },
        .practised = .{ .games = 1000, .wins = practised },
        .pp = @as(f64, @floatFromInt(practised - new)) / 10,
        .se = 1,
        .pulled = pulled,
        .kind = kind,
    };
}

test "rows: biggest pulled gap first, a role's page its players only, badges and axis" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    // pool's fixture: champions 1 to 6, all top; 99 is in no stats
    const st = (try pool.testPool(a)).st;
    const l: learning.Learning = .{ .champions = &.{
        .{ .id = 1, .bins = @splat(.{}), .gap = testGap(412, 522, 9, .harder) },
        .{ .id = 2, .bins = @splat(.{}), .gap = testGap(430, 529, 9.5, .usual) },
        .{ .id = 3, .bins = @splat(.{}), .gap = testGap(508, 521, 1, .easier) },
        .{ .id = 4, .bins = @splat(.{}), .gap = null },
        .{ .id = 99, .bins = @splat(.{}), .gap = testGap(450, 500, 5, .usual) },
    } };
    const ids = struct {
        fn f(al: std.mem.Allocator, cs: []const learning.Champion) ![]u32 {
            const out = try al.alloc(u32, cs.len);
            for (out, cs) |*o, c| o.* = c.id;
            return out;
        }
    }.f;
    try std.testing.expectEqualSlices(u32, &.{ 2, 1, 99, 3 }, try ids(a, try order(a, &l, &st, null)));
    try std.testing.expectEqualSlices(u32, &.{ 2, 1, 3 }, try ids(a, try order(a, &l, &st, .top)));
    try std.testing.expectEqual(0, (try order(a, &l, &st, .jungle)).len);

    var rows: std.ArrayList(Row) = .empty;
    for (try order(a, &l, &st, .top)) |c| try rows.append(a, .{
        .champ = .{ .name = try a.print("C{d}", .{c.id}), .src = "" },
        .href = try a.print("champion/c{d}.html", .{c.id}),
        .gap = c.gap.?,
    });
    var tree: ui.Tree = .{};
    var h: H = .init(a, &tree);
    const n = try body(&h, rows.items);
    var out: std.Io.Writer.Allocating = .init(a);
    try ui.html.write(&tree, n, &out.writer);
    const s = out.written();
    try std.testing.expectEqual(1, std.mem.count(u8, s, ">Harder<"));
    try std.testing.expectEqual(1, std.mem.count(u8, s, ">Easier<"));
    // Rates 41.2 to 52.9: whole fives 40 to 55
    try std.testing.expect(std.mem.find(u8, s, ">40%<") != null);
    try std.testing.expect(std.mem.find(u8, s, ">55%<") != null);
    const first = std.mem.find(u8, s, "href=\"champion/c2.html\"").?;
    try std.testing.expect(first < std.mem.find(u8, s, "href=\"champion/c1.html\"").?);

    var empty: ui.Tree = .{};
    var he: H = .init(a, &empty);
    const none = try body(&he, &.{});
    out.clearRetainingCapacity();
    try ui.html.write(&empty, none, &out.writer);
    try std.testing.expect(std.mem.find(u8, out.written(), "More data needed") != null);
}
