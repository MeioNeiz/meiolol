//! GameBuild: the desktop app's in-game panel under the island (private edition): my
//! champion-role's usual boots and core items with those I own ticked and the next one
//! marked, the ability for my next point and the usual max order, then the usual
//! levelling path as a skill grid, a tip or two from the comp, and the power spike sheet:
//! level 6, first item and the stronger half of the game against my lane opponent, in a
//! <details> only the player opens (never pushed: docs/plan/app.md "Policy line").
//! Static HTML (src/shell/screens.zig builds it from ingame.InGame): a buy or a level
//! reloads the page, and the shell's bridge.js keeps the sheet as the player left it
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
    /// 0 without a usual build
    games: u32 = 0,
    tips: []const []const u8 = &.{},
    spikes: ?Spikes = null,
};

pub const Timing = struct {
    /// Median seconds, mine then theirs; 0 unknown
    at: [2]u16 = .{ 0, 0 },
    /// 0 me, 1 them: clearly sooner; null about the same
    sooner: ?u1 = null,

    fn known(t: Timing) bool {
        return t.at[0] != 0 and t.at[1] != 0;
    }
};

pub const Lean = enum { none, early, late };

pub const Spikes = struct {
    /// My lane opponent's name
    opponent: []const u8,
    level6: Timing = .{},
    first_item: Timing = .{},
    /// The matchup's games behind the timings
    games: u32 = 0,
    /// Mine then theirs
    lean: [2]Lean = .{ .none, .none },
};

pub fn view(h: *H, b: Build) N {
    return h.section(.{ .class = "c-gamebuild" }, .{
        if (b.games > 0) h.h3(.{}, .{ W.title, h.small(.{}, .{W.games.with(h, .{ .n = b.games })}) }) else null,
        if (b.items.len > 0) items(h, b) else null,
        if (b.skill != 0 or b.order.len == 3) skills(h, b) else null,
        if (b.path.len > 0) skillgrid.order(h, b.path) else null,
        if (b.tips.len > 0) tips(h, b.tips) else null,
        if (b.spikes) |sp| sheet(h, sp) else null,
    });
}

fn tips(h: *H, lines: []const []const u8) N {
    var list = h.list();
    for (lines, 0..) |t, i| list.add(h.li(.{ .key = i }, .{t}));
    return h.ul(.{ .class = "tips" }, .{list.done()});
}

fn sheet(h: *H, sp: Spikes) N {
    var rows = h.list();
    if (sp.level6.known()) rows.add(timingRow(h, 0, W.level6, sp.level6));
    if (sp.first_item.known()) rows.add(timingRow(h, 1, W.first_item, sp.first_item));
    if (sp.lean[0] != .none or sp.lean[1] != .none) rows.add(h.tr(.{ .key = 2 }, .{
        h.th(.{ .scope = "row" }, .{W.strongest}),
        h.td(.{}, .{leanWord(sp.lean[0])}),
        h.td(.{}, .{leanWord(sp.lean[1])}),
    }));
    return h.el(.details, .{ .class = "spikes", .data_keep = "spikes" }, .{
        h.el(.summary, .{}, .{ W.spikes, h.b(.{}, .{sp.opponent}) }),
        h.table(.{}, .{
            h.thead(.{}, .{h.tr(.{}, .{
                h.td(.{}, .{}),
                h.th(.{ .scope = "col", .data_answer = true }, .{W.you}),
                h.th(.{ .scope = "col" }, .{sp.opponent}),
            })}),
            h.tbody(.{}, .{rows.done()}),
        }),
        if (sp.games > 0) h.p(.{ .class = "src" }, .{W.median.with(h, .{ .n = sp.games })}) else null,
    });
}

fn timingRow(h: *H, key: u32, what: tree.Text, t: Timing) N {
    var cells: [2]N = undefined;
    for (&cells, t.at, 0..) |*c, at, i| c.* = h.td(.{
        .data_state = @as(?[:0]const u8, if (t.sooner != null and t.sooner.? == i) "sooner" else null),
    }, .{phrase.num(h, .time, at)});
    return h.tr(.{ .key = key }, .{ h.th(.{ .scope = "row" }, .{what}), cells[0], cells[1] });
}

fn leanWord(l: Lean) tree.Text {
    return switch (l) {
        .none => W.no_lean,
        .early => W.early,
        .late => W.late,
    };
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
    const spikes = plain("Power spikes against ");
    const you = plain("You");
    const level6 = plain("Level 6");
    const first_item = plain("First item");
    const strongest = plain("Strongest");
    const early = plain("early game");
    const late = plain("late game");
    const no_lean = plain("no lean");
    const median = phrase.Phrase("Median of {n:count} games of this lane");
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
    \\  .c-gamebuild .tips { flex-direction: column; gap: var(--sp-1); font-size: var(--fs-s); }
    \\  .c-gamebuild .tips li::before { content: "›"; margin-right: var(--sp-2); color: var(--accent); }
    \\  .c-gamebuild .spikes { border-top: 1px solid var(--line); padding-top: var(--sp-2); font-size: var(--fs-s); }
    \\  .c-gamebuild .spikes summary { cursor: pointer; color: var(--t2); }
    \\  .c-gamebuild .spikes table { margin-top: var(--sp-2); border-collapse: collapse; font-variant-numeric: tabular-nums; }
    \\  .c-gamebuild .spikes th, .c-gamebuild .spikes td { padding: 2px var(--sp-3) 2px 0; text-align: left; font-weight: normal; }
    \\  .c-gamebuild .spikes th { color: var(--t2); }
    \\  .c-gamebuild .spikes [data-state="sooner"] { font-weight: var(--w-b); color: var(--good); }
    \\  .c-gamebuild .spikes .src { margin-top: var(--sp-1); font-size: var(--fs-xs); color: var(--faint); }
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
    .tips = &.{ "They're all AD: armour goes a long way", "You scale better: after 20 min is yours" },
    .spikes = .{
        .opponent = "Zed",
        .level6 = .{ .at = .{ 418, 452 }, .sooner = 0 },
        .first_item = .{ .at = .{ 655, 610 }, .sooner = 1 },
        .games = 3_120,
        .lean = .{ .late, .early },
    },
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
    g.add("no usual build: a tip, leans only", view(h, .{
        .tips = sample.tips[0..1],
        .spikes = .{ .opponent = "Zed", .lean = .{ .none, .early } },
    }));
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
    try testing.expect(std.mem.find(u8, full, "class=\"tips\"") != null);
    // The sheet stays closed: the player opens it
    try testing.expect(std.mem.find(u8, full, "<details class=\"spikes\" data-keep=\"spikes\"><summary>") != null);
    try testing.expect(std.mem.find(u8, full, "<td data-state=\"sooner\">6:58</td><td>7:32</td>") != null);
    try testing.expect(std.mem.find(u8, full, "<td>10:55</td><td data-state=\"sooner\">10:10</td>") != null);
    try testing.expect(std.mem.find(u8, full, "<td>late game</td><td>early game</td>") != null);
    const bare = try render(a, .{ .items = sample.items, .next = 2, .games = 140 });
    try testing.expect(std.mem.find(u8, bare, "c-skills") == null);
    try testing.expect(std.mem.find(u8, bare, "class=\"k\"") == null);
    try testing.expect(std.mem.find(u8, bare, "<details") == null);
    const lean_only = try render(a, .{ .spikes = .{ .opponent = "Zed", .lean = .{ .none, .early } } });
    try testing.expect(std.mem.find(u8, lean_only, "<h3") == null);
    try testing.expect(std.mem.find(u8, lean_only, "Level 6") == null);
    try testing.expect(std.mem.find(u8, lean_only, "Median") == null);
    try testing.expect(std.mem.find(u8, lean_only, "<td>no lean</td><td>early game</td>") != null);
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
