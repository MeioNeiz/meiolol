//! DayHead: a day group's head in the Your games list (your-games.md "Games"): "Today",
//! "Yesterday" or "Thu 22 Oct", the day's W-L in result colours and the time played
//! (deeplol's session line)
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const yl = @import("yourlist.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "DayHead";
pub const scope = .{".c-dayhead"};

const W = struct {
    pub const today = plain("Today");
    pub const yesterday = plain("Yesterday");
    pub const date = phrase.Phrase("{wd:text} {d:int} {m:text}");
    pub const played = phrase.Phrase("{h:int}h {m:int}m");
    pub const record = phrase.Phrase("{w:int} wins, {l:int} losses");
};

const weekdays = [_][]const u8{ "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" };
const months = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };

/// `today` the viewer's (yourlist.dayOf of now)
pub fn label(h: *H, day: i32, today: i32) tree.Text {
    if (day == today) return W.today;
    if (day == today - 1) return W.yesterday;
    const c = yl.civil(day);
    return W.date.with(h, .{ .wd = weekdays[c.weekday], .d = c.day, .m = months[c.month - 1] });
}

pub fn view(h: *H, d: yl.Day, today: i32) N {
    return h.div(.{ .class = "c-dayhead" }, .{
        h.el(.h3, .{}, .{label(h, d.day, today)}),
        h.span(.{ .class = "wl", .title = W.record.with(h, .{ .w = d.t.wins, .l = d.t.losses() }) }, .{
            h.b(.{ .class = "w" }, .{d.t.wins}),
            "–",
            h.b(.{ .class = "l" }, .{d.t.losses()}),
        }),
        h.span(.{ .class = "pl" }, .{W.played.with(h, .{ .h = d.played / 3600, .m = d.played / 60 % 60 })}),
    });
}

pub const css =
    \\@layer components {
    \\  .c-dayhead { display: flex; align-items: baseline; gap: var(--sp-3); padding: var(--sp-2) var(--sp-3) 6px;
    \\    border-bottom: 1px solid var(--line); }
    \\  .c-dayhead > h3 { margin: 0; font-size: var(--fs-s); font-weight: var(--w-b); color: var(--t2); }
    \\  .c-dayhead > .wl { font-size: var(--fs-s); font-variant-numeric: tabular-nums; color: var(--faint); }
    \\  .c-dayhead .w { color: var(--us); }
    \\  .c-dayhead .l { color: var(--them); }
    \\  .c-dayhead > .pl { margin-left: auto; font-size: var(--fs-xs); color: var(--faint); font-variant-numeric: tabular-nums; }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    // 22 Oct 2026, a Thursday
    const day = 20748;
    g.addFill("yesterday: 3-0, 1h 36m", view(h, .{ .day = day, .games = &.{}, .t = .{ .games = 3, .wins = 3 }, .played = 5760 }, day + 1));
    g.addFill("an older day: 2-3", view(h, .{ .day = day, .games = &.{}, .t = .{ .games = 5, .wins = 2 }, .played = 9420 }, day + 4));
}

const testing = std.testing;

test "today, yesterday, then the date" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    try testing.expectEqualStrings("Today", label(&h, 20748, 20748).s);
    try testing.expectEqualStrings("Yesterday", label(&h, 20747, 20748).s);
    try testing.expectEqualStrings("Thu 22 Oct", label(&h, 20748, 20750).s);
}
