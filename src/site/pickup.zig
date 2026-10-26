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

const Writer = std.Io.Writer;
const Site = root.Site;
const Role = core.Role;
const H = ui.H;
const N = ui.N;
const plain = ui.plain;
const Phrase = ui.Phrase;

pub const path = "pickup.html";

/// pickup.html, then pickup/<role>.html
pub fn paths(site: *const Site, list: *std.ArrayList([]const u8)) !void {
    try list.append(site.arena, path);
    for (Role.all) |r| try list.append(site.arena, try site.arena.print("pickup/{s}.html", .{r.label()}));
}

/// A champion is on a role's page when it has this share of its games there
const role_share = 0.1;

const W = struct {
    const title = plain("How hard to pick up");
    const all = plain("All");
    const roles = plain("Role");
    const names = [2][]const u8{ "New", "Practised" };
    const fig = plain("Gap");
    const gap = Phrase("{v:points}");
    const harder = plain("Harder");
    const easier = plain("Easier");
    const none = plain("More data needed: no champion has 200+ games each from new and practised players yet.");
    const note = Phrase("New: under 30k mastery points on the champion; practised: 100k+. {n:count} ranked solo games, every region. Practised players are better players too, so every champion has a gap ({m:dec} points on average): harder or easier only when a gap is clearly bigger or smaller than that.");
};

pub fn writePage(site: *const Site, w: *Writer, r: ?Role) !void {
    const a = site.arena;
    const here = if (r) |x| try a.print("pickup/{s}.html", .{x.label()}) else path;
    const pg = try site.page(
        "How hard each champion is to pick up | meiolol",
        "Win rate of players new to each champion against practised ones: the gap shows which champions take longest to learn.",
        here,
        .pool,
    );
    try html.head(w, pg);
    const to_root = try site.toRoot(here);
    const to_site = try site.toShared(here);
    var tree: ui.Tree = .{};
    var h: H = .init(a, &tree);
    tree.root = try view(site, &h, r, to_root, to_site);
    if (h.oom) return error.OutOfMemory;
    try ui.html.write(&tree, tree.root, w);
    try html.foot(w, pg);
}

fn view(site: *const Site, h: *H, r: ?Role, to_root: []const u8, to_site: []const u8) !N {
    const a = site.arena;
    const l = &site.learning;
    var segs: [1 + Role.all.len]ui.segmented.Item = undefined;
    segs[0] = .{ .label = W.all, .selected = r == null, .href = try a.print("{s}{s}", .{ to_root, path }) };
    for (Role.all, segs[1..]) |x, *s| s.* = .{
        .label = champion.uiRole(x).label(),
        .selected = r == x,
        .href = try a.print("{s}pickup/{s}.html", .{ to_root, x.label() }),
    };

    var list: std.ArrayList(learning.Champion) = .empty;
    for (l.champions) |c| {
        if (c.gap == null) continue;
        if (r) |x| if (!plays(&site.stats, c.id, x)) continue;
        try list.append(a, c);
    }
    std.mem.sort(learning.Champion, list.items, {}, struct {
        fn f(_: void, x: learning.Champion, y: learning.Champion) bool {
            return x.gap.?.pulled > y.gap.?.pulled;
        }
    }.f);

    const body: N = if (list.items.len == 0) h.p(.{ .class = "note" }, .{W.none}) else body: {
        var lo: f32 = 100;
        var hi: f32 = 0;
        const bells = try a.alloc(ui.versus.Bell, list.items.len);
        for (bells, list.items) |*b, c| {
            const g = c.gap.?;
            const ch = matchup.champ(site, c.id).?;
            const new: f32 = @floatCast(100 * g.new.winRate());
            const old: f32 = @floatCast(100 * g.practised.winRate());
            lo = @min(lo, new, old);
            hi = @max(hi, new, old);
            b.* = .{
                .head = h.a(.{ .href = try site.champHref(ch, to_site) }, .{
                    ui.champ.view(h, .{ .name = ch.name, .src = try site.icon(ch) }, .{ .named = false }),
                    ch.name,
                }),
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
        break :body ui.versus.dumbbell(h, .{
            .names = W.names,
            .fig = W.fig,
            .lo = @floatFromInt(axis.lo),
            .hi = @floatFromInt(axis.hi),
            .ticks = axis.ticks(),
        }, bells);
    };
    return h.div(.{ .class = "c-pickup" }, .{
        h.el(.h1, .{}, .{W.title}),
        ui.segmented.view(h, .{ .s = .s, .label = W.roles }, &segs),
        body,
        h.p(.{ .class = "muted" }, .{W.note.with(h, .{ .n = l.games, .m = @as(f32, @floatCast(l.mean_pp)) })}),
    });
}

fn plays(st: *const core.Stats, id: u32, r: Role) bool {
    const c = st.index(id) orelse return false;
    const g: f64 = @floatFromInt(st.champRole(r, c).games);
    return g > 0 and g >= role_share * @as(f64, @floatFromInt(st.champGames(c)));
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
