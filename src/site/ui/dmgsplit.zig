//! DamageSplit: a champion's or a team's damage to champions as one bar, AD (physical,
//! true damage with it) from the left and AP the rest, each share at its end. Under 35%
//! AP reads AD, over 65% AP, else AD and AP (dailydata.dmgOf), said once for a screen
//! reader, an unknown share too. A share whose champions are unknown hatches after both;
//! all of it unknown, the bar is the hatch alone
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
    /// Shares of the damage, 0-1; AD is what they leave
    ap: f32,
    unknown: f32 = 0,
};

const W = struct {
    pub const ad = plain("AD");
    pub const ap = plain("AP");
    pub const said = phrase.Phrase("{k:text} damage: {ad:pct} AD, {ap:pct} AP");
    pub const said_part = phrase.Phrase("{k:text} damage: {ad:pct} AD, {ap:pct} AP, {u:pct} unknown");
    pub const not_known = plain("Damage not known yet");
    pub const kinds = [3][]const u8{ "AD", "AP", "AD and AP" };
};

/// A 0-1 share as a percent; NaN or out of range clamps
fn pct(x: f32) f32 {
    return if (x > 0) @min(100 * x, 100) else 0;
}

/// Whole percents that add up to 100: AD takes what AP and the unknown share leave
const Whole = struct {
    ad: u32,
    ap: u32,
    u: u32,

    fn of(x: Split) Whole {
        const u: u32 = @intFromFloat(@round(pct(x.unknown)));
        const ap: u32 = @min(@as(u32, @intFromFloat(@round(pct(x.ap)))), 100 - u);
        return .{ .ad = 100 - u - ap, .ap = ap, .u = u };
    }
};

pub fn view(h: *H, x: Split) N {
    const u = pct(x.unknown);
    const ap = @min(pct(x.ap), 100 - u);
    const ad = 100 - u - ap;
    const hatch: N = if (u > 0) h.el(.i, .{ .class = "uk", .style = h.vars(.{ .w = u }) }, .{}) else .none;
    if (ad + ap < 0.5) return h.div(.{ .class = "c-dmg", .role = "img", .aria_label = W.not_known }, .{
        h.span(.{ .class = "bar", .aria_hidden = true }, .{hatch}),
    });
    const n = Whole.of(x);
    const k = W.kinds[@backingInt(dmgOf(ap / (ad + ap)).?)];
    const said = if (n.u > 0) W.said_part.with(h, .{ .k = k, .ad = n.ad, .ap = n.ap, .u = n.u }) else W.said.with(h, .{ .k = k, .ad = n.ad, .ap = n.ap });
    return h.div(.{ .class = "c-dmg", .role = "img", .aria_label = said }, .{
        h.span(.{ .class = "bar", .aria_hidden = true }, .{
            h.el(.i, .{ .class = "ad", .style = h.vars(.{ .w = ad }) }, .{}),
            h.el(.i, .{ .class = "ap", .style = h.vars(.{ .w = ap }) }, .{}),
            hatch,
        }),
        h.span(.{ .class = "sh", .aria_hidden = true }, .{
            h.span(.{}, .{ W.ad, " ", h.b(.{}, .{phrase.num(h, .pct, n.ad)}) }),
            h.span(.{}, .{ W.ap, " ", h.b(.{}, .{phrase.num(h, .pct, n.ap)}) }),
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
    \\  .c-dmg > .sh { display: flex; justify-content: space-between; font-size: var(--fs-xs); color: var(--muted);
    \\    font-variant-numeric: tabular-nums; }
    \\  .c-dmg > .sh b { color: var(--text); }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("AD", view(h, .{ .ap = 0.12 }));
    g.addFill("AD and AP", view(h, .{ .ap = 0.48 }));
    g.addFill("AP", view(h, .{ .ap = 0.81 }));
    g.addFill("a share unknown", view(h, .{ .ap = 0.36, .unknown = 0.2 }));
    g.addFill("all unknown", view(h, .{ .ap = 0, .unknown = 1 }));
}

test "the kind and shares said once, adding up to 100; an unknown share hatches, leaves the kind to the known and is said" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    const ap = view(&h, .{ .ap = 0.81 });
    try testing.expectEqualStrings("AP damage: 19% AD, 81% AP", t.attr(ap, "aria-label").?);
    try testing.expectEqual(null, t.find(ap, "class", "uk"));
    const part = view(&h, .{ .ap = 0.36, .unknown = 0.2 });
    try testing.expectEqualStrings("AD and AP damage: 44% AD, 36% AP, 20% unknown", t.attr(part, "aria-label").?);
    try testing.expect(t.find(part, "class", "uk") != null);
    try testing.expectEqualStrings("AD damage: 100% AD, 0% AP", t.attr(view(&h, .{ .ap = std.math.nan(f32) }), "aria-label").?);
    // Rounded apart, 87.5 and 12.5 would read 88 and 13
    try testing.expectEqualStrings("AD damage: 87% AD, 13% AP", t.attr(view(&h, .{ .ap = 0.125 }), "aria-label").?);
    const none = view(&h, .{ .ap = 0, .unknown = 1 });
    try testing.expectEqualStrings("Damage not known yet", t.attr(none, "aria-label").?);
    try testing.expectEqual(null, t.find(none, "class", "sh"));
}
