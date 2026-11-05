//! ItemPath: the first finished items in the order bought, as icons with arrows, each
//! item's median minute under it ("min" once, after the last). In a list of paths, items
//! a path shares with the most played one in the same place are dimmed, so the eye goes
//! to where it branches
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
    px: art.Px = .@"22",
};

const W = struct {
    pub const min = phrase.plain("min");
    pub const none = phrase.plain("-");
};

pub fn view(h: *H, items: []const art.Art, o: Opts) N {
    var known = false;
    for (o.minutes) |m| known = known or m > 0;
    var kids = h.list();
    for (items, 0..) |it, i| {
        if (i > 0) kids.add(h.span(.{ .class = "ar", .aria_hidden = true }, .{"›"}));
        const same = if (o.top) |t| i < t.len and std.mem.eql(u8, t[i].src, it.src) else false;
        const m: f32 = if (known and i < o.minutes.len) o.minutes[i] else 0;
        const minute: ?N = if (!known) null else h.small(.{}, .{
            if (m > 0) phrase.num(h, .int, @as(u32, @intFromFloat(@round(m)))) else W.none,
            if (i + 1 == items.len) h.span(.{}, .{ " ", W.min }) else null,
        });
        kids.add(h.span(.{ .class = "it", .data_state = if (same) "same" else null }, .{ art.view(h, it, .{ .px = o.px }), minute }));
    }
    return h.span(.{ .class = "c-path", .data_min = known }, .{kids.done()});
}

pub const css =
    \\@layer components {
    \\  .c-path { display: inline-flex; align-items: center; gap: 3px; min-width: 0; }
    \\  .c-path > .ar { color: var(--faint); font-size: var(--fs-s); }
    \\  .c-path > .it { position: relative; display: inline-flex; }
    \\  .c-path > .it[data-state="same"] > .c-art { opacity: 0.4; }
    \\  .c-path > .it > small { position: absolute; top: 100%; left: 0; font-size: var(--fs-xs); line-height: 1.3;
    \\    color: var(--faint); white-space: nowrap; font-variant-numeric: tabular-nums; }
    \\  .c-path[data-min] { padding-bottom: 14px; }
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
    g.add("the build panel's: 32 px, one minute unknown", view(h, &top, .{ .minutes = &.{ 11, 0, 27 }, .px = .@"32" }));
}
