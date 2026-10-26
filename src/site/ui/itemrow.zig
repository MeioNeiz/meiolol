//! ItemRow: one player's purchases by shop visit, each visit its items over the minute,
//! arrows between (dpm.lol and deeplol builds; game-detail.md "Build"). Wraps
const tree = @import("tree.zig");
const art = @import("art.zig");
const phrase = @import("phrase.zig");
const Gallery = @import("gallery.zig").Gallery;
const H = tree.H;
const N = tree.N;

pub const name = "ItemRow";
pub const scope = .{".c-itemrow"};

pub const Back = struct {
    /// Seconds
    t: u16,
    items: []const art.Art,
};

const W = struct {
    pub const min = phrase.Phrase("{m:int} min");
};

pub fn view(h: *H, backs: []const Back) N {
    var l = h.list();
    for (backs, 0..) |b, i| {
        if (i > 0) l.add(h.span(.{ .class = "ar", .aria_hidden = true }, .{"›"}));
        var its = h.list();
        for (b.items) |it| its.add(art.view(h, it, .{ .px = .@"28" }));
        l.add(h.div(.{ .class = "bk" }, .{
            h.span(.{ .class = "its" }, .{its.done()}),
            h.span(.{ .class = "t" }, .{W.min.with(h, .{ .m = (b.t + 30) / 60 })}),
        }));
    }
    return h.div(.{ .class = "c-itemrow" }, .{l.done()});
}

pub const css =
    \\@layer components {
    \\  .c-itemrow { display: flex; flex-wrap: wrap; align-items: flex-start; gap: var(--sp-3) var(--sp-1); min-width: 0; }
    \\  .c-itemrow > .bk { display: flex; flex-direction: column; align-items: center; gap: 4px; }
    \\  .c-itemrow .its { display: flex; gap: 2px; }
    \\  .c-itemrow .t { font-size: var(--fs-xs); color: var(--faint); font-variant-numeric: tabular-nums; white-space: nowrap; }
    \\  .c-itemrow > .ar { align-self: center; margin-top: -16px; color: var(--faint); font-size: var(--fs-s); }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const dmp = art.item("3742", "Dead Man's Plate");
    const ghost = art.item("3142", "Youmuu's Ghostblade");
    const dd = art.item("6333", "Death's Dance");
    g.add("three backs", view(g.h, &.{
        .{ .t = 0, .items = &.{ghost} },
        .{ .t = 610, .items = &.{ dmp, dd } },
        .{ .t = 1300, .items = &.{dd} },
    }));
}
