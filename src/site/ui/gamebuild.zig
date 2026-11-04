//! GameBuild: the desktop app's in-game panel under the island (private edition): my
//! champion-role's usual boots and core items with those I own ticked and the next one
//! marked, the ability for my next point and the usual max order, then the usual
//! levelling path as a skill grid. Static HTML (src/shell/screens.zig builds it from
//! ingame.Plan): a buy or a level reloads the page
const std = @import("std");
const tree = @import("tree.zig");
const art = @import("art.zig");
const skillgrid = @import("skillgrid.zig");
const phrase = @import("phrase.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "GameBuild";
pub const scope = .{".c-gamebuild"};

pub const Item = struct { art: art.Art, owned: bool };

pub const Build = struct {
    /// Boots, then the core items in buying order
    items: []const Item = &.{},
    /// `items` index of the first not owned; null all owned
    next: ?u8 = null,
    /// The basics by max order, "QEW"; "" unknown
    order: []const u8 = "",
    /// The usual ability at each level, up to 18; "" unknown
    path: []const u8 = "",
    /// The ability for my next point; 0 none
    skill: u8 = 0,
    /// A point to spend now; else `skill` is for the next level
    unspent: bool = false,
    games: u32 = 0,
};

pub fn view(h: *H, b: Build) N {
    return h.section(.{ .class = "c-gamebuild" }, .{
        h.h3(.{}, .{ W.title, h.small(.{}, .{W.games.with(h, .{ .n = b.games })}) }),
        if (b.items.len > 0) items(h, b) else null,
        if (b.skill != 0 or b.order.len == 3) skills(h, b) else null,
        if (b.path.len > 0) skillgrid.order(h, b.path) else null,
    });
}

fn items(h: *H, b: Build) N {
    var list = h.list();
    for (b.items, 0..) |it, i| {
        const next = b.next != null and b.next.? == i;
        list.add(h.li(.{
            .key = i,
            .title = it.art.name,
            .data_state = @as(?[:0]const u8, if (it.owned) "owned" else if (next) "next" else null),
        }, .{art.view(h, it.art, .{ .px = .@"36" })}));
    }
    const upcoming: ?[]const u8 = if (b.next) |n| b.items[n].art.name else null;
    return h.div(.{ .class = "items" }, .{
        h.ul(.{}, .{list.done()}),
        if (upcoming) |n| h.p(.{ .class = "nx" }, .{ W.next, h.b(.{}, .{n}) }) else h.p(.{ .class = "nx" }, .{W.done}),
    });
}

fn skills(h: *H, b: Build) N {
    return h.p(.{ .class = "lv" }, .{
        if (b.skill != 0) h.span(.{ .data_state = if (b.unspent) "now" else null }, .{
            if (b.unspent) W.level_up else W.next_level,
            h.b(.{ .class = "k" }, .{h.fmt("{c}", .{b.skill})}),
        }) else null,
        if (b.order.len == 3) h.span(.{ .class = "max" }, .{ W.max, h.fmt("{c} › {c} › {c}", .{ b.order[0], b.order[1], b.order[2] }) }) else null,
    });
}

const W = struct {
    const title = plain("Usual build ");
    const games = phrase.Phrase("from {n:count} games");
    const next = plain("Next: ");
    const done = plain("Core build done");
    const level_up = plain("Level up ");
    const next_level = plain("Next level ");
    const max = plain("Max ");
};

pub const css =
    \\@layer components {
    \\  .c-gamebuild { display: flex; flex-direction: column; gap: var(--sp-2); min-width: 0; max-width: 420px; }
    \\  .c-gamebuild h3 { margin: var(--sp-2) 0 0; font-size: var(--fs-s); font-weight: var(--w-m); color: var(--t2); }
    \\  .c-gamebuild h3 small { font-size: var(--fs-xs); font-weight: normal; color: var(--faint); font-variant-numeric: tabular-nums; }
    \\  .c-gamebuild .items { display: flex; flex-direction: column; gap: var(--sp-1); }
    \\  .c-gamebuild ul { list-style: none; margin: 0; padding: 0; display: flex; flex-wrap: wrap; gap: var(--sp-2); }
    \\  .c-gamebuild li { position: relative; display: flex; border-radius: var(--r-s); }
    \\  .c-gamebuild li[data-state="owned"] .c-art { opacity: 0.45; }
    \\  .c-gamebuild li[data-state="owned"]::after { content: "✓"; position: absolute; right: -4px; bottom: -4px;
    \\    width: 16px; height: 16px; border-radius: 50%; display: grid; place-items: center;
    \\    font-size: var(--fs-xs); font-weight: var(--w-b); line-height: 1; background: var(--good); color: var(--bg); }
    \\  .c-gamebuild li[data-state="next"] { outline: 2px solid var(--accent); outline-offset: 2px; }
    \\  .c-gamebuild p { margin: 0; font-size: var(--fs-s); }
    \\  .c-gamebuild .lv { display: flex; flex-wrap: wrap; gap: var(--sp-3); align-items: baseline; }
    \\  .c-gamebuild .lv [data-state="now"] { font-weight: var(--w-b); }
    \\  .c-gamebuild .k { display: inline-block; min-width: 1.6em; padding: 1px 4px; border-radius: var(--r-s);
    \\    background: var(--panel-2); font-weight: var(--w-b); text-align: center; }
    \\  .c-gamebuild .lv [data-state="now"] .k { background: var(--accent); color: var(--bg); }
    \\  .c-gamebuild .max { color: var(--t2); }
    \\}
    \\
;

pub const sample: Build = .{
    .items = &.{
        .{ .art = art.item("3020", "Sorcerer's Shoes"), .owned = true },
        .{ .art = art.item("6655", "Luden's Companion"), .owned = true },
        .{ .art = art.item("4645", "Shadowflame"), .owned = false },
        .{ .art = art.item("3089", "Rabadon's Deathcap"), .owned = false },
    },
    .next = 2,
    .order = "QWE",
    .path = "QWEQQRQWQWRWWEEREE",
    .skill = 'Q',
    .unspent = true,
    .games = 12_400,
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.add("two items owned, a point to spend", view(h, sample));
    var later = sample;
    later.unspent = false;
    later.skill = 'W';
    later.next = null;
    later.items = &.{
        .{ .art = sample.items[0].art, .owned = true }, .{ .art = sample.items[1].art, .owned = true },
        .{ .art = sample.items[2].art, .owned = true }, .{ .art = sample.items[3].art, .owned = true },
    };
    g.add("core done, next level's ability", view(h, later));
    g.add("no levelling path known", view(h, .{ .items = sample.items, .next = 2, .games = 140 }));
}

const testing = std.testing;

test "items owned and next, the point to spend, the path" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const full = try render(a, sample);
    try testing.expectEqual(2, std.mem.count(u8, full, "data-state=\"owned\""));
    try testing.expectEqual(1, std.mem.count(u8, full, "data-state=\"next\""));
    try testing.expect(std.mem.find(u8, full, "Next: <b>Shadowflame</b>") != null);
    try testing.expect(std.mem.find(u8, full, "Level up <b class=\"k\">Q</b>") != null);
    try testing.expect(std.mem.find(u8, full, "Max Q › W › E") != null);
    try testing.expect(std.mem.find(u8, full, "c-skills") != null);
    const bare = try render(a, .{ .items = sample.items, .next = 2, .games = 140 });
    try testing.expect(std.mem.find(u8, bare, "c-skills") == null);
    try testing.expect(std.mem.find(u8, bare, "class=\"k\"") == null);
}

fn render(a: std.mem.Allocator, b: Build) ![]const u8 {
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    const root = view(&h, b);
    try testing.expect(!h.oom);
    var out: std.Io.Writer.Allocating = .init(a);
    try @import("html.zig").write(&t, root, &out.writer);
    return out.written();
}
