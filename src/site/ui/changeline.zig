//! ChangeLine: what Riot changed, one line each: the slot's key (Q, P; · for stats and
//! items), what it is, the old value struck, then the new one in the tone's colour with
//! an arrow as the second cue. A text hunk keeps a few words either side. Lines with
//! no number to show say so instead
const std = @import("std");
const tree = @import("tree.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const H = tree.H;
const N = tree.N;

pub const name = "ChangeLine";
pub const scope = .{".c-chg"};

pub const Dir = enum { buff, nerf, adjusted, text, blanked };

pub const Line = struct {
    /// "Q", "P"; "" draws ·
    key: []const u8 = "",
    /// "Decimate cooldown", "Health"; "" for a text hunk
    label: []const u8 = "",
    /// A text hunk's words before and after the change
    before: []const u8 = "",
    old: []const u8 = "",
    new: []const u8 = "",
    after: []const u8 = "",
    dir: Dir,
};

const W = struct {
    const text = plain("wording changed");
    const blanked = plain("new numbers not in Riot's data");
};

pub fn view(h: *H, lines: []const Line) N {
    var l = h.list();
    for (lines) |x| l.add(line(h, x));
    return h.ul(.{ .class = "c-chg" }, .{l.done()});
}

fn line(h: *H, x: Line) N {
    const key = h.span(.{ .class = "k" }, .{if (x.key.len > 0) x.key else "·"});
    const label = if (x.label.len > 0) h.span(.{ .class = "f" }, .{x.label}) else null;
    return switch (x.dir) {
        .text => h.li(.{ .data_v = x.dir }, .{ key, label, h.span(.{ .class = "x" }, .{W.text}) }),
        .blanked => h.li(.{ .data_v = x.dir }, .{ key, label, h.span(.{ .class = "x" }, .{W.blanked}) }),
        .buff, .nerf, .adjusted => h.li(.{ .data_v = if (x.dir == .adjusted) null else x.dir }, .{
            key,
            label,
            if (x.before.len > 0) h.span(.{ .class = "c" }, .{x.before}) else null,
            h.el(.s, .{}, .{x.old}),
            h.span(.{ .class = "to", .aria_hidden = true }, .{"→"}),
            h.b(.{}, .{
                x.new,
                switch (x.dir) {
                    .buff => h.span(.{ .class = "ar", .aria_hidden = true }, .{"▲"}),
                    .nerf => h.span(.{ .class = "ar", .aria_hidden = true }, .{"▼"}),
                    else => null,
                },
            }),
            if (x.after.len > 0) h.span(.{ .class = "c" }, .{x.after}) else null,
        }),
    };
}

pub const css =
    \\@layer components {
    \\  .c-chg { list-style: none; margin: 0; padding: 0; display: grid; gap: 4px; font-size: var(--fs-s); }
    \\  .c-chg li { position: relative; display: flex; flex-wrap: wrap; align-items: baseline; gap: 2px 6px;
    \\    min-width: 0; padding-left: 28px; min-height: 18px; }
    \\  .c-chg .k { position: absolute; left: 0; top: 0; display: inline-grid; place-items: center; min-width: 22px; height: 18px; padding: 0 4px;
    \\    border-radius: var(--r-s); background: var(--panel-3); font-size: var(--fs-xs); font-weight: var(--w-b); color: var(--t2); }
    \\  .c-chg .f { color: var(--t2); }
    \\  .c-chg .c, .c-chg .x { color: var(--faint); }
    \\  .c-chg s { color: var(--faint); overflow-wrap: anywhere; }
    \\  .c-chg .to { color: var(--faint); }
    \\  .c-chg b { font-weight: var(--w-m); overflow-wrap: anywhere; }
    \\  .c-chg li[data-v="buff"] b { color: var(--good); }
    \\  .c-chg li[data-v="nerf"] b { color: var(--bad); }
    \\  .c-chg .ar { margin-left: 2px; font-size: var(--fs-xs); }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.add("champion", view(h, &.{
        .{ .key = "Q", .label = "Decimate cooldown", .old = "9/8/7/6/5", .new = "9/7.75/6.5/5.25/4", .dir = .buff },
        .{ .label = "Health", .old = "630", .new = "610", .dir = .nerf },
        .{ .key = "P", .before = "Bleeds for", .old = "5", .new = "4", .after = "seconds.", .dir = .adjusted },
        .{ .key = "W", .label = "Iron Will", .dir = .text },
        .{ .key = "E", .label = "Audacious Charge", .dir = .blanked },
    }));
    g.add("item", view(h, &.{
        .{ .label = "Gold", .old = "1000", .new = "1100", .dir = .nerf },
        .{ .before = "Attack Damage", .old = "22", .new = "18", .after = "Lethality 15", .dir = .nerf },
    }));
}

test "tone and arrow by direction; text and blanked say so" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    const n = view(&h, &.{
        .{ .key = "Q", .old = "9", .new = "8", .dir = .buff },
        .{ .old = "630", .new = "610", .dir = .nerf },
        .{ .old = "1", .new = "2", .dir = .adjusted },
        .{ .key = "E", .dir = .blanked },
    });
    var out: std.Io.Writer.Allocating = .init(arena.allocator());
    try @import("html.zig").write(&t, n, &out.writer);
    const s = out.written();
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, s, "data-v=\"buff\""));
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, s, "\u{25B2}"));
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, s, "\u{25BC}"));
    try std.testing.expectEqual(@as(usize, 2), std.mem.count(u8, s, "class=\"ar\""));
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, s, "data-v=\"blanked\""));
    try std.testing.expect(std.mem.indexOf(u8, s, ">\u{00B7}<") != null);
}
