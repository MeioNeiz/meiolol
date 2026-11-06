//! DamageSplit: a champion's or a team's damage to champions as one bar, AD (physical,
//! true damage with it) from the left and AP the rest, each share at its end. Under 35%
//! AP reads AD, over 65% AP, else AD and AP (dailydata.dmgOf) unless the caller's tally
//! buckets it, said once for a screen reader, an unknown share too. A share whose
//! champions are unknown hatches between them, so each end's label stays on its own
//! part and the bar fills towards the middle as they come; all of it unknown, the bar
//! is the hatch alone. Without shares (the app's public edition) the ends and the label
//! carry no %
const std = @import("std");
const testing = std.testing;
const tree = @import("tree.zig");
const Gallery = @import("gallery.zig").Gallery;
const phrase = @import("phrase.zig");
const dailydata = @import("dailydata.zig");
const dmgOf = dailydata.dmgOf;

pub const Kind = dailydata.Dmg;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "DamageSplit";
pub const scope = .{".c-dmg"};

pub const Split = struct {
    /// Shares of the damage, 0-1; AD is what they leave
    ap: f32,
    unknown: f32 = 0,
    /// The kind from the caller's own buckets (compview: the team mix tally's), so the
    /// words match its other facts; null: dmgOf of the known share
    kind: ?Kind = null,
    /// False: no % on the ends nor in the label
    shares: bool = true,
    /// False: the caller names the bar (DraftBoard's middle column), no "Damage" before AD
    named: bool = true,
};

const W = struct {
    pub const ad = plain("AD");
    pub const ap = plain("AP");
    pub const said = phrase.Phrase("{k:text} damage: {ad:pct} AD, {ap:pct} AP");
    pub const said_part = phrase.Phrase("{k:text} damage: {ad:pct} AD, {ap:pct} AP, {u:pct} unknown");
    pub const said_kind = phrase.Phrase("{k:text} damage");
    pub const damage = plain("Damage");
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
    const k = W.kinds[@backingInt(x.kind orelse dmgOf(ap / (ad + ap)).?)];
    const said = if (!x.shares)
        W.said_kind.with(h, .{ .k = k })
    else if (n.u > 0)
        W.said_part.with(h, .{ .k = k, .ad = n.ad, .ap = n.ap, .u = n.u })
    else
        W.said.with(h, .{ .k = k, .ad = n.ad, .ap = n.ap });
    return h.div(.{ .class = "c-dmg", .role = "img", .aria_label = said }, .{
        h.span(.{ .class = "bar", .aria_hidden = true }, .{
            h.el(.i, .{ .class = "ad", .style = h.vars(.{ .w = ad }) }, .{}),
            hatch,
            h.el(.i, .{ .class = "ap", .style = h.vars(.{ .w = ap }) }, .{}),
        }),
        h.span(.{ .class = "sh", .aria_hidden = true }, .{
            h.span(.{}, .{ if (x.named) h.span(.{ .class = "k" }, .{W.damage}) else null, if (x.named) " " else null, W.ad, " ", if (x.shares) h.b(.{}, .{phrase.num(h, .pct, n.ad)}) else null }),
            h.span(.{}, .{ W.ap, " ", if (x.shares) h.b(.{}, .{phrase.num(h, .pct, n.ap)}) else null }),
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
    \\  .c-dmg > .sh .k { margin-right: .2em; }
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
    g.addFill("no shares, a tally's kind: 0.33 AP in a 30-70 bucket", view(h, .{ .ap = 0.33, .kind = .mixed, .shares = false }));
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
    // dmgOf would say AD; the caller's bucket wins, and without shares no % shows
    const tally = view(&h, .{ .ap = 0.33, .kind = .mixed, .shares = false });
    try testing.expectEqualStrings("AD and AP damage", t.attr(tally, "aria-label").?);
    var buf: [64]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try t.textOf(tally, &w);
    try testing.expectEqualStrings("Damage AD AP ", w.buffered());
    try testing.expectEqual(null, t.find(view(&h, .{ .ap = 0.4, .named = false }), "class", "k"));
}
