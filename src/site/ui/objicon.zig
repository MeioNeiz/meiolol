//! ObjectiveIcon: a tower, inhibitor or epic monster as a small glyph (a CSS mask, like
//! RoleIcon), in the taking team's colour. Named for screen readers unless the row
//! around it says what it is
const tree = @import("tree.zig");
const gamedata = @import("gamedata.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const H = tree.H;
const N = tree.N;

pub const name = "ObjectiveIcon";
pub const scope = .{".c-obj"};

pub const Kind = gamedata.ObjKind;

pub fn label(k: Kind) tree.Text {
    return switch (k) {
        .tower => plain("Tower"),
        .inhibitor => plain("Inhibitor"),
        .dragon => plain("Dragon"),
        .elder => plain("Elder dragon"),
        .grubs => plain("Voidgrubs"),
        .herald => plain("Rift Herald"),
        .baron => plain("Baron"),
        .atakhan => plain("Atakhan"),
    };
}

pub const Opts = struct {
    /// Coloured by the taking team; null is plain ink
    ours: ?bool = null,
    /// 10, 14 or 18 px
    s: enum { s, m, l } = .m,
    /// Shown dimmed (filtered out)
    dim: bool = false,
    named: bool = true,
};

pub fn view(h: *H, k: Kind, o: Opts) N {
    return h.span(.{
        .class = "c-obj",
        .data_k = k,
        .data_s = if (o.s == .m) null else o.s,
        .data_side = if (o.ours) |u| (if (u) "us" else "them") else null,
        .data_dim = o.dim,
        .role = if (o.named) "img" else null,
        .aria_label = if (o.named) label(k) else null,
        .aria_hidden = if (o.named) null else true,
    }, .{});
}

fn svg(comptime d: []const u8) []const u8 {
    return "url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Cpath fill-rule='evenodd' d='" ++ d ++ "'/%3E%3C/svg%3E\")";
}

pub const css =
    \\@layer components {
    \\  .c-obj { display: inline-block; flex: none; width: 14px; height: 14px; vertical-align: middle;
    \\    color: var(--muted); background: currentColor; mask: var(--oi) center / contain no-repeat; }
    \\  .c-obj[data-s="s"] { width: 10px; height: 10px; }
    \\  .c-obj[data-s="l"] { width: 18px; height: 18px; }
    \\  .c-obj[data-side="us"] { color: var(--us-hot); }
    \\  .c-obj[data-side="them"] { color: var(--them-hot); }
    \\  .c-obj[data-dim] { opacity: .3; }
    \\  .c-obj[data-k="tower"] { --oi:
++ " " ++ svg("M5 1h6v2.5H10V12h2v3H4v-3h2V3.5H5z") ++ "; }\n" ++
    \\  .c-obj[data-k="inhibitor"] { --oi:
++ " " ++ svg("M8 1a7 7 0 1 0 0 14A7 7 0 0 0 8 1zm0 3.5a3.5 3.5 0 1 1 0 7 3.5 3.5 0 0 1 0-7z") ++ "; }\n" ++
    \\  .c-obj[data-k="dragon"] { --oi:
++ " " ++ svg("M8 1l6 7-6 7-6-7z") ++ "; }\n" ++
    \\  .c-obj[data-k="elder"] { --oi:
++ " " ++ svg("M8 1l6 7-6 7-6-7zm0 4.2L5.6 8 8 10.8 10.4 8z") ++ "; }\n" ++
    \\  .c-obj[data-k="grubs"] { --oi:
++ " " ++ svg("M8 1.5a2.6 2.6 0 1 1 0 5.2 2.6 2.6 0 0 1 0-5.2zM3.6 9a2.6 2.6 0 1 1 0 5.2 2.6 2.6 0 0 1 0-5.2zm8.8 0a2.6 2.6 0 1 1 0 5.2 2.6 2.6 0 0 1 0-5.2z") ++ "; }\n" ++
    \\  .c-obj[data-k="herald"] { --oi:
++ " " ++ svg("M.5 8C2.8 3.4 13.2 3.4 15.5 8c-2.3 4.6-12.7 4.6-15 0zM8 5.4a2.6 2.6 0 1 0 0 5.2 2.6 2.6 0 0 0 0-5.2z") ++ "; }\n" ++
    \\  .c-obj[data-k="baron"] { --oi:
++ " " ++ svg("M1.5 13L2.5 4l3.2 3.4L8 2.5l2.3 4.9L13.5 4l1 9z") ++ "; }\n" ++
    \\  .c-obj[data-k="atakhan"] { --oi:
++ " " ++ svg("M8 .8l1.9 5h5.3l-4.3 3.1 1.7 5.3L8 11l-4.6 3.2 1.7-5.3L.8 5.8h5.3z") ++ "; }\n" ++
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    var l = h.list();
    inline for (@typeInfo(Kind).@"enum".field_names, 0..) |f, i| l.add(h.span(.{ .key = i }, .{view(h, @field(Kind, f), .{})}));
    g.add("each kind", h.span(.{}, .{l.done()}));
    g.add("by side, sizes", h.span(.{}, .{
        view(h, .dragon, .{ .ours = true, .s = .s }),
        view(h, .baron, .{ .ours = false }),
        view(h, .tower, .{ .ours = true, .s = .l }),
        view(h, .grubs, .{ .ours = false, .dim = true }),
    }));
}
