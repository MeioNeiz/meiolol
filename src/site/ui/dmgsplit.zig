//! DamageSplit: a champion's or a team's damage to champions as one bar, AD (physical,
//! true damage with it) from the left and AP the rest, each share at its end. Under 35%
//! AP reads AD, over 65% AP, else AD and AP (dailydata.dmgOf), said once for a screen
//! reader. A share whose champions are unknown hatches after both
const std = @import("std");
const testing = std.testing;
const tree = @import("tree.zig");
const Gallery = @import("gallery.zig").Gallery;
const phrase = @import("phrase.zig");
const dmgOf = @import("dailydata.zig").dmgOf;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "DamageSplit";
pub const scope = .{".c-dmg"};

pub const Split = struct {
    /// Shares of the damage, 0-1; `unknown` is the rest's, else AD is 1 - ap
    ap: f32,
    unknown: f32 = 0,
};

const W = struct {
    pub const ad = plain("AD");
    pub const ap = plain("AP");
    pub const said = phrase.Phrase("{k:text} damage: {ad:pct} AD, {ap:pct} AP");
    pub const kinds = [3][]const u8{ "AD", "AP", "AD and AP" };
};

/// A 0-1 share as a percent; NaN or out of range clamps
fn pct(x: f32) f32 {
    return if (x > 0) @min(100 * x, 100) else 0;
}

fn whole(x: f32) u32 {
    return @intFromFloat(@round(pct(x)));
}

pub fn view(h: *H, x: Split) N {
    const ad = @max(0, 1 - pct(x.ap) / 100 - pct(x.unknown) / 100);
    const k = W.kinds[@backingInt(dmgOf(pct(x.ap) / 100 / @max(1 - pct(x.unknown) / 100, 0.01)).?)];
    return h.div(.{ .class = "c-dmg", .role = "img", .aria_label = W.said.with(h, .{ .k = k, .ad = whole(ad), .ap = whole(x.ap) }) }, .{
        h.span(.{ .class = "bar", .aria_hidden = true }, .{
            h.el(.i, .{ .class = "ad", .style = h.vars(.{ .w = pct(ad) }) }, .{}),
            h.el(.i, .{ .class = "ap", .style = h.vars(.{ .w = pct(x.ap) }) }, .{}),
            if (x.unknown > 0) h.el(.i, .{ .class = "uk", .style = h.vars(.{ .w = pct(x.unknown) }) }, .{}) else null,
        }),
        h.span(.{ .class = "ends", .aria_hidden = true }, .{
            h.span(.{}, .{ W.ad, " ", h.b(.{}, .{phrase.num(h, .pct, whole(ad))}) }),
            h.span(.{}, .{ W.ap, " ", h.b(.{}, .{phrase.num(h, .pct, whole(x.ap))}) }),
        }),
    });
}

pub const css =
    \\@layer components {
    \\  .c-dmg { display: grid; gap: 4px; min-width: 0; }
    \\  .c-dmg > .bar { display: flex; height: 10px; border-radius: 3px; overflow: hidden; background: var(--bar-track); }
    \\  .c-dmg > .bar > i { display: block; height: 100%; width: calc(var(--w) * 1%); }
    \\  .c-dmg .ad { background: var(--bar-hi); }
    \\  .c-dmg .ap { background: var(--bar-lo); }
    \\  .c-dmg .uk { background: repeating-linear-gradient(135deg, var(--accent-bg) 0 4px, transparent 4px 8px);
    \\    box-shadow: inset 0 0 0 1px var(--sel-line); }
    \\  .c-dmg > .ends { display: flex; justify-content: space-between; font-size: var(--fs-xs); color: var(--muted);
    \\    font-variant-numeric: tabular-nums; }
    \\  .c-dmg > .ends b { color: var(--text); }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("AD", view(h, .{ .ap = 0.12 }));
    g.addFill("AD and AP", view(h, .{ .ap = 0.48 }));
    g.addFill("AP", view(h, .{ .ap = 0.81 }));
    g.addFill("a share unknown", view(h, .{ .ap = 0.36, .unknown = 0.2 }));
}

test "the kind and both shares said once; an unknown share hatches and leaves the kind to the known" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    const ap = view(&h, .{ .ap = 0.81 });
    try testing.expectEqualStrings("AP damage: 19% AD, 81% AP", t.attr(ap, "aria-label").?);
    try testing.expectEqual(null, t.find(ap, "class", "uk"));
    const part = view(&h, .{ .ap = 0.36, .unknown = 0.2 });
    try testing.expectEqualStrings("AD and AP damage: 44% AD, 36% AP", t.attr(part, "aria-label").?);
    try testing.expect(t.find(part, "class", "uk") != null);
    try testing.expectEqualStrings("AD damage: 100% AD, 0% AP", t.attr(view(&h, .{ .ap = std.math.nan(f32) }), "aria-label").?);
}
