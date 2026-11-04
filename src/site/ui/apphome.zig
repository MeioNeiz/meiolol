//! AppHome: the desktop app's tiles before champ select (docs/plan/ui/app-whole.md slice
//! 4), each a TodayCard into one of the site's features with a line of data from the
//! app's own stats: your mastery top's best role now (Champion pool), each role's best
//! now (Rankings); then Patch changes and the Draft tester (private edition). Static
//! HTML beside the lobby's form panel (src/shell/home.zig builds it)
const std = @import("std");
const tree = @import("tree.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const today = @import("today.zig");
const phrase = @import("phrase.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "AppHome";
pub const scope = .{".c-apphome"};

pub const Pick = struct {
    champ: champ.Champ,
    role: role.Role,
    /// Win rate in that role, percent
    win: f64,
};

pub const Home = struct {
    /// Where and when the stats are from, as the board says it ("EUW, last 30 days")
    scope: []const u8 = "",
    /// The mastery top's best role each, in mastery order
    pool: []const Pick = &.{},
    /// Each role's best now, in role order
    best: []const Pick = &.{},
    private: bool = false,
};

const W = struct {
    const pool = plain("Your champions now");
    const pool_go = plain("Champion pool");
    const pool_none = plain("Your mastery top shows here once the League client has it.");
    const best = plain("Best per role");
    const best_go = plain("Rankings");
    const patch = plain("Patch changes");
    const patch_what = plain("What rose and fell");
    const patch_go = plain("Open");
    const tester = plain("Draft tester");
    const tester_what = plain("Any draft, both teams");
    const tester_go = plain("Open");
};

/// `site`: the address the links start with ("https://meio.lol")
pub fn view(h: *H, site: []const u8, d: Home) N {
    const from: ?tree.Text = if (d.scope.len > 0) .{ .s = d.scope } else null;
    return h.section(.{ .class = "c-apphome" }, .{
        today.view(h, .{ .title = W.pool, .action = W.pool_go, .href = link(h, site, "/pool") }, null, if (d.pool.len > 0)
            picks(h, d.pool, false)
        else
            h.p(.{ .class = "none" }, .{W.pool_none})),
        if (d.best.len > 0) today.view(h, .{ .title = W.best, .count = from, .action = W.best_go, .href = link(h, site, "/rankings") }, null, picks(h, d.best, true)) else null,
        today.view(h, .{ .title = W.patch, .count = W.patch_what, .action = W.patch_go, .href = link(h, site, "/patch") }, null, .none),
        if (d.private) today.view(h, .{ .title = W.tester, .count = W.tester_what, .action = W.tester_go, .href = link(h, site, "/private/tester") }, null, .none) else null,
    });
}

/// `by_role`: the role leads each row (Best per role), else the champion does
fn picks(h: *H, rows: []const Pick, by_role: bool) N {
    var list = h.list();
    for (rows, 0..) |p, i| list.add(h.li(.{ .key = i }, .{
        if (by_role) role.view(h, p.role, .{ .s = .s }) else null,
        champ.view(h, p.champ, .{ .px = .@"32", .named = false }),
        h.span(.{ .class = "who" }, .{p.champ.name}),
        if (by_role) null else role.view(h, p.role, .{ .s = .s }),
        h.span(.{ .class = "win" }, .{phrase.Phrase("{w:rate}").with(h, .{ .w = p.win })}),
    }));
    return h.ul(.{ .class = "c-apphome", .data_v = "list" }, .{list.done()});
}

fn link(h: *H, site: []const u8, path: []const u8) []const u8 {
    return std.mem.concat(h.mem, u8, &.{ site, path }) catch {
        h.oom = true;
        return path;
    };
}

pub const css =
    \\@layer components {
    \\  .c-apphome { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); align-content: start;
    \\    gap: var(--sp-3); min-width: 0; }
    \\  .c-apphome[data-v="list"] { display: flex; flex-direction: column; gap: 4px; margin: 0; padding: var(--sp-2) var(--sp-3); list-style: none; }
    \\  .c-apphome[data-v="list"] li { display: flex; align-items: center; gap: var(--sp-2); min-width: 0; }
    \\  .c-apphome[data-v="list"] .who { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: var(--fs-s); }
    \\  .c-apphome[data-v="list"] .c-role { color: var(--t2); }
    \\  .c-apphome[data-v="list"] .win { font-size: var(--fs-s); font-weight: var(--w-m); font-variant-numeric: tabular-nums; }
    \\  .c-apphome .none { margin: 0; padding: var(--sp-2) var(--sp-3); font-size: var(--fs-s); color: var(--t2); }
    \\}
    \\
;

const demo = champ.demo;

pub const sample: Home = .{
    .scope = "EUW, last 30 days",
    .pool = &.{
        .{ .champ = demo("Ahri", "Ahri"), .role = .mid, .win = 51.2 },
        .{ .champ = demo("Orianna", "Orianna"), .role = .mid, .win = 49.8 },
        .{ .champ = demo("Syndra", "Syndra"), .role = .mid, .win = 52.4 },
    },
    .best = &.{
        .{ .champ = demo("Darius", "Darius"), .role = .top, .win = 53.1 },
        .{ .champ = demo("Vi", "Vi"), .role = .jungle, .win = 52.6 },
        .{ .champ = demo("Syndra", "Syndra"), .role = .mid, .win = 52.4 },
        .{ .champ = demo("Jinx", "Jinx"), .role = .bot, .win = 52.0 },
        .{ .champ = demo("Thresh", "Thresh"), .role = .support, .win = 52.9 },
    },
    .private = true,
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("private, mastery top", view(h, "https://meio.lol", sample));
    g.addFill("public, no mastery yet", view(h, "https://meio.lol", .{ .scope = sample.scope, .best = sample.best }));
}

const testing = std.testing;

test "tiles link into the site; draft tester private only; empty pool says why" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const full = try render(a, sample);
    try testing.expectEqual(4, std.mem.count(u8, full, "class=\"c-today\""));
    for ([_][]const u8{ "/pool\"", "/rankings\"", "/patch\"", "/private/tester\"" }) |p|
        try testing.expect(std.mem.find(u8, full, p) != null);
    try testing.expect(std.mem.find(u8, full, "52.4%") != null);
    try testing.expect(std.mem.find(u8, full, "EUW, last 30 days") != null);
    const public = try render(a, .{ .best = sample.best });
    try testing.expectEqual(3, std.mem.count(u8, public, "class=\"c-today\""));
    try testing.expect(std.mem.find(u8, public, "tester") == null);
    try testing.expect(std.mem.find(u8, public, "Your mastery top shows here") != null);
}

fn render(a: std.mem.Allocator, d: Home) ![]const u8 {
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    const root = view(&h, "https://meio.lol", d);
    try testing.expect(!h.oom);
    var out: std.Io.Writer.Allocating = .init(a);
    try @import("html.zig").write(&t, root, &out.writer);
    return out.written();
}
