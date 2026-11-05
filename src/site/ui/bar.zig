//! Bar: a magnitude without good or bad (pick, ban, games), a neutral ink bar beside its
//! figure. Bars in one column share a scale: `of` is the column's largest. `track`: a
//! position along a full-width line (a place among champions, a rate on 0-100), a mark
//! at it and an optional reference tick, no good or bad colour
const tree = @import("tree.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const champ = @import("champ.zig");
const H = tree.H;
const N = tree.N;

pub const name = "Bar";
pub const scope = .{ ".c-bar", ".c-track" };

/// `x` of `of` as the bar's length, `text` the figure beside it
pub fn view(h: *H, x: f64, of: f64, text: tree.Text) N {
    const w = if (of > 0) @max(0, @min(100, 100 * x / of)) else 0;
    return h.span(.{ .class = "c-bar" }, .{
        h.span(.{ .aria_hidden = true }, .{h.el(.i, .{ .style = h.vars(.{ .w = w }) }, .{})}),
        text,
    });
}

pub const Track = struct {
    /// 0 at the left end, 1 at the right
    at: f64,
    /// A reference tick (the role's middle, its average), same scale
    ref: ?f64 = null,
    /// Centred on `at`, at most 20 px (a portrait); none: a dot
    mark: N = .none,
    /// After the line, in a column of its own
    text: ?tree.Text = null,
};

/// Fills its container's width
pub fn track(h: *H, t: Track) N {
    const at = 100 * @max(0, @min(1, t.at));
    const style = if (t.ref) |r| h.vars(.{ .at = at, .ref = 100 * @max(0, @min(1, r)) }) else h.vars(.{ .at = at });
    return h.span(.{ .class = "c-track", .style = style }, .{
        h.span(.{ .aria_hidden = true }, .{ if (t.ref != null) h.el(.i, .{}, .{}) else null, h.b(.{}, .{t.mark}) }),
        if (t.text) |x| h.small(.{}, .{x}) else null,
    });
}

pub const css =
    \\@layer components {
    \\  .c-bar { display: inline-flex; align-items: center; gap: 6px; font-variant-numeric: tabular-nums; }
    \\  .c-bar > span { position: relative; width: var(--bw, 48px); height: 4px; border-radius: 2px;
    \\    background: var(--bar-track); overflow: hidden; flex: none; }
    \\  .c-bar > span > i { position: absolute; inset: 0 auto 0 0; width: calc(var(--w) * 1%); border-radius: 2px;
    \\    background: linear-gradient(90deg, var(--bar-lo), var(--bar-hi)); }
    \\  /* The line sits 10px in from each end, so a 20px mark at either end stays inside */
    \\  .c-track { display: flex; align-items: center; gap: var(--sp-2); min-width: 0; }
    \\  .c-track > span { position: relative; flex: 1; height: 20px; margin: 0 10px; }
    \\  .c-track > span::before { content: ""; position: absolute; inset: 9px 0 auto; height: 2px; border-radius: 1px;
    \\    background: var(--bar-track); }
    \\  .c-track > span > i { position: absolute; left: calc(var(--ref) * 1%); top: 4px; width: 2px; height: 12px;
    \\    margin-left: -1px; background: var(--muted); }
    \\  .c-track > span > b { position: absolute; left: calc(var(--at) * 1%); top: 50%; transform: translate(-50%, -50%);
    \\    display: flex; }
    \\  .c-track > span > b:empty { width: 10px; height: 10px; border-radius: 50%; background: var(--text); }
    \\  .c-track > small { flex: none; min-width: 3.5em; font-size: var(--fs-s); color: var(--muted);
    \\    font-variant-numeric: tabular-nums; }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.add("share", view(h, 56, 100, plain("56%")));
    g.add("games, the column's most", view(h, 44935, 44935, plain("44,935")));
    g.add("ban", view(h, 4.1, 100, plain("4.1%")));
    const ornn = champ.view(h, champ.demo("Ornn", "Ornn"), .{ .px = .@"20", .named = false });
    g.add("track: a place, portrait at 1st, the middle ticked", track(h, .{ .at = 1, .ref = 0.5, .mark = ornn, .text = plain("1st") }));
    g.add("track: the middle", track(h, .{ .at = 0.5, .ref = 0.5, .mark = ornn, .text = plain("30th") }));
    g.add("track: last", track(h, .{ .at = 0, .ref = 0.5, .mark = ornn, .text = plain("60th") }));
    g.add("track: a rate, a dot, the average ticked", track(h, .{ .at = 0.733, .ref = 0.684, .text = plain("73.3%") }));
}
