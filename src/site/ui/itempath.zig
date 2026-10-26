//! ItemPath: the first finished items in the order bought, as icons with arrows, then the
//! median minute of each. In a list of paths, items a path shares with the most played
//! one in the same place are dimmed, so the eye goes to where it branches
const std = @import("std");
const tree = @import("tree.zig");
const art = @import("art.zig");
const phrase = @import("phrase.zig");
const Gallery = @import("gallery.zig").Gallery;
const H = tree.H;
const N = tree.N;

pub const name = "ItemPath";
pub const scope = .{".c-path"};

pub const Opts = struct {
    /// Median minute each item was bought, 0 when unknown; empty for none
    minutes: []const f32 = &.{},
    /// The most played path: items in the same place dim in this one
    top: ?[]const art.Art = null,
};

const W = struct {
    pub const min = phrase.plain("min");
};

pub fn view(h: *H, items: []const art.Art, o: Opts) N {
    var kids = h.list();
    for (items, 0..) |it, i| {
        if (i > 0) kids.add(h.span(.{ .class = "ar", .aria_hidden = true }, .{"›"}));
        const same = if (o.top) |t| i < t.len and std.mem.eql(u8, t[i].src, it.src) else false;
        kids.add(h.span(.{ .class = "it", .data_state = if (same) "same" else null }, .{art.view(h, it, .{})}));
    }
    var known = false;
    for (o.minutes) |m| known = known or m > 0;
    if (known) {
        var w: std.Io.Writer.Allocating = .init(h.mem);
        for (o.minutes, 0..) |m, i| {
            if (i > 0) w.writer.writeAll(" · ") catch {};
            if (m > 0) w.writer.print("{d}", .{@as(u32, @intFromFloat(@round(m)))}) catch {} else w.writer.writeAll("-") catch {};
        }
        kids.add(h.span(.{ .class = "min" }, .{ w.written(), " ", W.min }));
    }
    return h.span(.{ .class = "c-path" }, .{kids.done()});
}

pub const css =
    \\@layer components {
    \\  .c-path { display: inline-flex; align-items: center; gap: 3px; min-width: 0; }
    \\  .c-path > .ar { color: var(--faint); font-size: var(--fs-s); }
    \\  .c-path > .it { display: inline-flex; }
    \\  .c-path > .it[data-state="same"] { opacity: 0.4; }
    \\  .c-path > .min { margin-left: var(--sp-2); font-size: var(--fs-xs); color: var(--faint); white-space: nowrap;
    \\    font-variant-numeric: tabular-nums; }
    \\  @container (max-width: 300px) { .c-path > .min { display: none; } }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const top = [_]art.Art{ art.item("3142", "Youmuu's Ghostblade"), art.item("3742", "Dead Man's Plate"), art.item("6333", "Death's Dance") };
    const second = [_]art.Art{ art.item("3142", "Youmuu's Ghostblade"), art.item("3742", "Dead Man's Plate"), art.item("4401", "Force of Nature") };
    g.add("most played, minutes", view(h, &top, .{ .minutes = &.{ 12, 20, 26 } }));
    g.add("a branch: shared items dim", view(h, &second, .{ .minutes = &.{ 12, 20, 25 }, .top = &top }));
    g.add("no minutes", view(h, top[0..2], .{}));
}
