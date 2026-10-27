//! RankStrip: every champion one seat could have played as a dot on one axis, its team's
//! win chance with it; the played (or locked) one ringed, the model's pick starred, the
//! chosen one lit. A tap chooses a dot (the owner opens it in its CandidateList). The
//! ends carry the lowest and highest chance, nothing else: the list beside it names them.
//! Daily's seat panel, the draft tester's candidate panel
const tree = @import("tree.zig");
const champ = @import("champ.zig");
const phrase = @import("phrase.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "RankStrip";
pub const scope = .{".c-rank"};

pub const Dot = struct {
    champ: champ.Champ,
    /// The team's win chance with it, %
    win: f32,
    star: bool = false,
    ref: bool = false,
    chosen: bool = false,
    on: ?tree.Handler = null,
};

pub const Strip = struct {
    dots: []const Dot,
    /// What the dots are, for screen readers ("Every pick for red top")
    label: tree.Text,
    /// Dots are buttons (the owner sets each `on`; the gallery has none)
    pressable: bool = false,
};

pub fn view(h: *H, s: Strip) N {
    if (s.dots.len == 0) return .none;
    var lo: f32 = 100;
    var hi: f32 = 0;
    for (s.dots) |d| {
        lo = @min(lo, d.win);
        hi = @max(hi, d.win);
    }
    const span = @max(hi - lo, 1);
    var l = h.list();
    for (s.dots, 0..) |d, i| {
        const style = h.vars(.{ .x = 100 * (d.win - lo) / span });
        const label = W.dot.with(h, .{ .n = d.champ.name, .w = d.win });
        l.add(if (s.pressable) h.button(.{
            .key = i,
            .type = "button",
            .style = style,
            .aria_label = label,
            .aria_pressed = d.chosen,
            .data_star = d.star,
            .data_ref = d.ref,
            .on_click = d.on,
        }, .{}) else h.span(.{
            .key = i,
            .role = "img",
            .style = style,
            .aria_label = label,
            .data_star = d.star,
            .data_ref = d.ref,
        }, .{}));
    }
    return h.div(.{ .class = "c-rank", .role = "group", .aria_label = s.label }, .{
        h.div(.{ .class = "trk" }, .{l.done()}),
        h.div(.{ .class = "ends", .aria_hidden = true }, .{
            h.span(.{}, .{phrase.num(h, .rate, lo)}),
            h.span(.{}, .{phrase.num(h, .rate, hi)}),
        }),
    });
}

const W = struct {
    const dot = phrase.Phrase("{n:text} {w:rate}");
};

pub const css =
    \\@layer components {
    \\  .c-rank { display: grid; gap: 2px; min-width: 0; padding: 0 6px; }
    \\  .c-rank .trk { position: relative; height: 24px; }
    \\  .c-rank .trk::before { content: ""; position: absolute; left: 0; right: 0; top: 50%; height: 1px; background: var(--axis); }
    \\  .c-rank .trk > * { all: unset; position: absolute; top: 50%; left: calc(var(--x) * 1%); width: 8px; height: 8px;
    \\    margin: -4px 0 0 -4px; border-radius: 50%; background: var(--bar-hi); opacity: 0.5; }
    \\  .c-rank .trk > button { cursor: pointer; }
    \\  .c-rank .trk > button::after { content: ""; position: absolute; inset: -8px -3px; }
    \\  .c-rank .trk > button:hover, .c-rank .trk > [aria-pressed="true"] { opacity: 1;
    \\    box-shadow: 0 0 0 2px var(--panel), 0 0 0 3.5px var(--focus); }
    \\  .c-rank .trk > button:focus-visible { outline: 2px solid var(--focus); outline-offset: 2px; }
    \\  .c-rank .trk > [data-ref] { opacity: 1; background: var(--accent); box-shadow: 0 0 0 2px var(--panel), 0 0 0 3.5px var(--accent); }
    \\  .c-rank .trk > [data-star] { opacity: 1; background: var(--turn); z-index: 1; }
    \\  .c-rank .ends { display: flex; justify-content: space-between; font-size: var(--fs-xs); color: var(--faint);
    \\    font-variant-numeric: tabular-nums; margin: 0 -6px; }
    \\}
    \\
;

const demo = champ.demo;

const sample = [_]Dot{
    .{ .champ = demo("Gnar", "Gnar"), .win = 49.9, .star = true },
    .{ .champ = demo("Ambessa", "Ambessa"), .win = 49.4 },
    .{ .champ = demo("Jayce", "Jayce"), .win = 48.9, .ref = true },
    .{ .champ = demo("Renekton", "Renekton"), .win = 48.4 },
    .{ .champ = demo("Jax", "Jax"), .win = 48.1 },
    .{ .champ = demo("Aatrox", "Aatrox"), .win = 47.9 },
    .{ .champ = demo("Camille", "Camille"), .win = 47.6 },
    .{ .champ = demo("Fiora", "Fiora"), .win = 47.5 },
    .{ .champ = demo("Garen", "Garen"), .win = 47.2 },
    .{ .champ = demo("Darius", "Darius"), .win = 46.8 },
    .{ .champ = demo("Sion", "Sion"), .win = 46.1 },
    .{ .champ = demo("Teemo", "Teemo"), .win = 45.0 },
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("seat, read only", view(h, .{ .dots = &sample, .label = plain("Every pick for red top") }));
    const dots = h.mem.dupe(Dot, &sample) catch {
        h.oom = true;
        return;
    };
    dots[1].chosen = true;
    g.addFill("pressable, one chosen", view(h, .{ .dots = dots, .label = plain("Every pick for red top"), .pressable = true }));
}

test "dots placed from the lowest to the highest chance; buttons only when pressable" {
    const std = @import("std");
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const html = @import("html.zig");
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    var out: std.Io.Writer.Allocating = .init(a);
    try html.write(&t, view(&h, .{ .dots = &sample, .label = plain("x") }), &out.writer);
    var s = out.written();
    try std.testing.expect(std.mem.find(u8, s, "<button") == null);
    try std.testing.expectEqual(sample.len, std.mem.count(u8, s, "role=\"img\""));
    try std.testing.expect(std.mem.find(u8, s, "--x:100") != null);
    try std.testing.expect(std.mem.find(u8, s, "--x:0") != null);
    try std.testing.expectEqual(1, std.mem.count(u8, s, "data-star"));
    try std.testing.expectEqual(1, std.mem.count(u8, s, "data-ref"));
    var dots = sample;
    dots[2].chosen = true;
    out = .init(a);
    try html.write(&t, view(&h, .{ .dots = &dots, .label = plain("x"), .pressable = true }), &out.writer);
    s = out.written();
    try std.testing.expectEqual(sample.len, std.mem.count(u8, s, "<button"));
    try std.testing.expectEqual(1, std.mem.count(u8, s, "aria-pressed=\"true\""));
    try std.testing.expectEqual(.none, view(&h, .{ .dots = &.{}, .label = plain("x") }));
}
