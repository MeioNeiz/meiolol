//! Kda: kills / deaths / assists in tabular figures, the slashes faint; optionally the
//! ratio under it. l is a game header's
const tree = @import("tree.zig");
const Gallery = @import("gallery.zig").Gallery;
const phrase = @import("phrase.zig");
const H = tree.H;
const N = tree.N;

pub const name = "Kda";
pub const scope = .{".c-kda"};

pub const Kda = struct { k: u16, d: u16, a: u16 };

pub const Opts = struct {
    /// (k + a) / d under the figures
    ratio: bool = false,
    s: enum { m, l } = .m,
};

const W = struct {
    pub const ratio = phrase.Phrase("{r:dec} KDA");
    pub const perfect = phrase.plain("Perfect KDA");
    pub const read = phrase.Phrase("{k:int} kills, {d:int} deaths, {a:int} assists");
};

pub fn view(h: *H, x: Kda, o: Opts) N {
    const slash = struct {
        fn f(hh: *H) N {
            return hh.el(.i, .{ .aria_hidden = true }, .{"/"});
        }
    }.f;
    const r: f32 = @as(f32, @floatFromInt(@as(u32, x.k) + x.a)) / @as(f32, @floatFromInt(@max(x.d, 1)));
    return h.span(.{
        .class = "c-kda",
        .data_s = if (o.s == .m) null else o.s,
        .title = W.read.with(h, .{ .k = x.k, .d = x.d, .a = x.a }),
    }, .{
        x.k,
        slash(h),
        x.d,
        slash(h),
        x.a,
        if (o.ratio) h.small(.{}, .{if (x.d == 0) W.perfect else W.ratio.with(h, .{ .r = r })}) else null,
    });
}

pub const css =
    \\@layer components {
    \\  .c-kda { font-variant-numeric: tabular-nums; white-space: nowrap; font-weight: var(--w-m); }
    \\  .c-kda > i { font-style: normal; color: var(--faint); margin: 0 1px; font-weight: var(--w-r); }
    \\  .c-kda > small { display: block; font-size: var(--fs-xs); color: var(--faint); font-weight: var(--w-r); }
    \\  .c-kda[data-s="l"] { font-size: var(--fs-xl); font-weight: var(--w-b); }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.add("plain", view(h, .{ .k = 7, .d = 3, .a = 9 }, .{}));
    g.add("ratio", view(h, .{ .k = 14, .d = 8, .a = 14 }, .{ .ratio = true }));
    g.add("no deaths", view(h, .{ .k = 6, .d = 0, .a = 11 }, .{ .ratio = true }));
    g.add("a game's header", view(h, .{ .k = 14, .d = 8, .a = 14 }, .{ .s = .l }));
}
