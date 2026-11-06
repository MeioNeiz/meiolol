//! HardAgainst: the lane opponents a champion loses to most, up to three portraits in a
//! row, each a link to that matchup's page. Who they are is the server's rule
//! (site/champion.zig hardAgainst: under 50% only, as the faces show no rate). A
//! /champions column; the champion head next
const tree = @import("tree.zig");
const Gallery = @import("gallery.zig").Gallery;
const champ = @import("champ.zig");
const H = tree.H;
const N = tree.N;

pub const name = "HardAgainst";
pub const scope = .{".c-hard"};

pub const Face = struct {
    champ: champ.Champ,
    /// The matchup page
    href: []const u8,
};

/// Each portrait is its link's name (the opponent's); none: nothing
pub fn view(h: *H, faces: []const Face) N {
    if (faces.len == 0) return .none;
    var l = h.list();
    for (faces, 0..) |f, i| l.add(h.a(.{ .key = i, .href = f.href }, .{champ.view(h, f.champ, .{})}));
    return h.span(.{ .class = "c-hard" }, .{l.done()});
}

pub const css =
    \\@layer components {
    \\  .c-hard { display: inline-flex; gap: var(--sp-1); }
    \\  .c-hard > a { display: flex; border-radius: var(--r-s); }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const faces = [_]Face{
        .{ .champ = champ.demo("Fiora", "Fiora"), .href = "#fiora" },
        .{ .champ = champ.demo("Mordekaiser", "Mordekaiser"), .href = "#mordekaiser" },
        .{ .champ = champ.demo("Darius", "Darius"), .href = "#darius" },
    };
    g.add("three, hardest first", view(h, &faces));
    g.add("fewer sure ones: fewer faces", view(h, faces[0..1]));
}
