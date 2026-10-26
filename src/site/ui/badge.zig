//! Badge: a flat label (role, result, "few games", a patch note). Never looks pressable:
//! no fill or border, no hover. A patch note (`riot`) is ringed in its tone, buff or
//! nerf with an arrow as the second cue
const tree = @import("tree.zig");
const Gallery = @import("gallery.zig").Gallery;
const H = tree.H;
const N = tree.N;

pub const name = "Badge";
pub const scope = .{".c-badge"};

pub const Kind = enum { neutral, accent, us, them, few, patch, buff, nerf, turn };

pub fn view(h: *H, k: Kind, kids: anytype) N {
    return h.span(.{ .class = "c-badge", .data_k = if (k == .neutral) null else k }, kids);
}

pub const Tone = enum { buff, nerf, adjusted };

/// What Riot changed in a champion or item: its slots ("Q, W, stats") in `tone`
pub fn riot(h: *H, tone: Tone, slots: []const u8) N {
    return switch (tone) {
        .buff => view(h, .buff, .{ h.span(.{ .class = "ar", .aria_hidden = true }, .{"▲"}), slots }),
        .nerf => view(h, .nerf, .{ h.span(.{ .class = "ar", .aria_hidden = true }, .{"▼"}), slots }),
        .adjusted => view(h, .patch, .{slots}),
    };
}

pub const css =
    \\@layer components {
    \\  .c-badge { display: inline-flex; align-items: center; gap: 3px; padding: 1px 6px;
    \\    border-radius: var(--r-s); font-size: var(--fs-xs); font-weight: var(--w-m);
    \\    letter-spacing: 0.02em; background: var(--wash); color: var(--t2); white-space: nowrap; }
    \\  .c-badge[data-k="accent"] { background: var(--accent-bg); color: var(--accent); }
    \\  .c-badge[data-k="us"] { background: var(--us-bg); color: var(--us); }
    \\  .c-badge[data-k="them"] { background: var(--them-bg); color: var(--them); }
    \\  .c-badge[data-k="few"] { background: none; color: var(--faint); padding: 0; }
    \\  .c-badge[data-k="patch"] { background: none; color: var(--turn); box-shadow: inset 0 0 0 1px var(--turn-line); }
    \\  .c-badge[data-k="buff"] { background: none; color: var(--good); box-shadow: inset 0 0 0 1px var(--good-line); }
    \\  .c-badge[data-k="nerf"] { background: none; color: var(--bad); box-shadow: inset 0 0 0 1px var(--bad-line); }
    \\  .c-badge .ar { font-size: var(--fs-xs); }
    \\  .c-badge[data-k="turn"] { background: var(--panel-3); color: var(--turn); }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.add("neutral", view(h, .neutral, .{"Mid"}));
    g.add("accent", view(h, .accent, .{"New"}));
    g.add("us", view(h, .us, .{"WIN"}));
    g.add("them", view(h, .them, .{"LOSS"}));
    g.add("few", view(h, .few, .{"few games"}));
    g.add("patch note", riot(h, .adjusted, "Q, W"));
    g.add("patch buff", riot(h, .buff, "Q"));
    g.add("patch nerf", riot(h, .nerf, "W, stats"));
    g.add("moment", view(h, .turn, .{"★ Turn"}));
}
