//! DotPlot: one axis centred on a reference (the champion's own rate in the role, 0 for vs
//! usual and gold), each dot a champion's icon in its bin, a bin's icons stacked so height
//! is only a count, the most played nearest the axis (champion.md, Jacob v7: matchups
//! option C). The centre line carries no label; "harder" and "easier" sit at the ends.
//! Pure CSS layout: bins are grid columns, icons wrap upward, their size follows the
//! container, so nothing is measured. A tap or ← → chooses a dot; the page shows its
//! figures (`chosen`). A mouse hover shows name, rate and games (Jacob v9: no more)
const std = @import("std");
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const phrase = @import("phrase.zig");
const champ = @import("champ.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "DotPlot";
pub const scope = .{".c-dots"};

pub const Dot = struct {
    champ: champ.Champ,
    /// From the centre, in the measure's units (win rate minus his own, gold at 14)
    x: f32,
    games: u32,
    /// The figure read out with the name ("49.9%")
    fig: tree.Text,
    thin: bool = false,
};

pub const Measure = struct {
    /// One bin's width: 1 point of win rate, 0.5 of vs usual, 100 gold
    bin: f32 = 1,
    /// The axis reaches at least this far each side (the scale's first cut), so a tame set
    /// doesn't look extreme
    reach: f32 = 2,
    /// What the dots are against, for screen readers ("Matchups")
    label: tree.Text,
    /// The ends: worse for the champion on the left
    lo: tree.Text = W.harder,
    hi: tree.Text = W.easier,
};

const W = struct {
    pub const harder = plain("harder");
    pub const easier = plain("easier");
    pub const dot = phrase.Phrase("{n:text} {v:text}");
    pub const games = phrase.Phrase("{n:count} games");
};

/// Bins each side of the centre: at least 4, the farthest dot with enough games inside
pub fn bins(dots: []const Dot, m: Measure) u16 {
    var far = m.reach;
    for (dots) |d| if (!d.thin) {
        far = @max(far, @abs(d.x));
    };
    return @intFromFloat(@max(4, @ceil(far / m.bin - 0.5)));
}

pub const DotPlot = struct {
    dots: []const Dot,
    m: Measure,
    /// The chosen dot; null: the most played
    sel: ?u16 = null,

    const D = @This();

    pub const Msg = union(enum) { pick: u16, key };

    /// The dot the page shows figures for
    pub fn chosen(d: *const D) ?u16 {
        if (d.sel) |s| if (s < d.dots.len) return s;
        var best: ?u16 = null;
        for (d.dots, 0..) |x, i| {
            if (best == null or x.games > d.dots[best.?].games) best = @intCast(i);
        }
        return best;
    }

    fn binOf(d: *const D, i: usize, nb: u16) i32 {
        const n: f32 = @floatFromInt(nb);
        return @intFromFloat(std.math.clamp(@round(d.dots[i].x / d.m.bin), -n, n));
    }

    /// Dots left to right into `o`: by bin, then the most played first (nearest the axis)
    fn order(d: *const D, o: []u16, nb: u16) void {
        for (o, 0..) |*x, i| x.* = @intCast(i);
        const Ctx = struct {
            d: *const D,
            nb: u16,
            fn less(c: @This(), a: u16, b: u16) bool {
                const ba = c.d.binOf(a, c.nb);
                const bb = c.d.binOf(b, c.nb);
                if (ba != bb) return ba < bb;
                return c.d.dots[a].games > c.d.dots[b].games;
            }
        };
        std.mem.sort(u16, o, Ctx{ .d = d, .nb = nb }, Ctx.less);
    }

    pub fn update(d: *D, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .pick => |i| d.sel = i,
            .key => {
                const step: i32 = if (std.mem.eql(u8, ev.text, "ArrowRight")) 1 else if (std.mem.eql(u8, ev.text, "ArrowLeft")) -1 else return;
                var buf: [256]u16 = undefined;
                const o = buf[0..@min(d.dots.len, buf.len)];
                d.order(o, bins(d.dots, d.m));
                const at = std.mem.findScalar(u16, o, d.chosen() orelse return) orelse return;
                const next = std.math.clamp(@as(i32, @intCast(at)) + step, 0, @as(i32, @intCast(o.len)) - 1);
                d.sel = o[@intCast(next)];
                ev.handled = true;
                ev.after = .{ .op = .focus, .ref = "dot" };
            },
        }
    }

    pub fn view(d: *D, h: *H) N {
        const nb = bins(d.dots, d.m);
        const n = 2 * nb + 1;
        const nf: f32 = @floatFromInt(n);
        const o = h.mem.alloc(u16, d.dots.len) catch {
            h.oom = true;
            return .none;
        };
        d.order(o, nb);
        const ch = d.chosen();
        var cols = h.list();
        var i: usize = 0;
        while (i < o.len) {
            const b = d.binOf(o[i], nb);
            var kids = h.list();
            while (i < o.len and d.binOf(o[i], nb) == b) : (i += 1) {
                const k = o[i];
                const x = d.dots[k];
                const on = ch == k;
                // The tip beside the button, not in it: its words aren't the button's label
                kids.add(h.span(.{ .key = k, .class = "d" }, .{
                    h.button(.{
                        .class = "m",
                        .type = "button",
                        .tabindex = if (on) @as(i8, 0) else -1,
                        .data_thin = x.thin,
                        .data_ref = if (on) "dot" else null,
                        .aria_pressed = on,
                        .aria_label = W.dot.with(h, .{ .n = x.champ.name, .v = x.fig.s }),
                        .on_click = h.on(d, .{ .pick = k }),
                    }, .{h.img(.{ .src = x.champ.src, .alt = "" })}),
                    h.span(.{ .class = "tt", .aria_hidden = true }, .{ h.b(.{}, .{x.champ.name}), " ", x.fig, " · ", W.games.with(h, .{ .n = x.games }) }),
                }));
            }
            // A tip opens toward the middle, so it never leaves the chart
            cols.add(h.div(.{ .class = "bin", .data_side = if (b < 0) "lo" else if (b > 0) "hi" else null, .style = h.vars(.{ .c = b + @as(i32, nb) + 1 }) }, .{kids.done()}));
        }
        var xs = h.list();
        const tstep: i32 = @intCast((nb + 3) / 4);
        var b: i32 = -@as(i32, nb) + 1;
        while (b < nb) : (b += 1) {
            if (b == 0 or @rem(b, tstep) != 0) continue;
            const v = @as(f32, @floatFromInt(b)) * d.m.bin;
            const at = (@as(f32, @floatFromInt(b + @as(i32, nb))) + 0.5) / nf * 100;
            xs.add(h.span(.{ .class = "xt", .style = h.vars(.{ .x = at }) }, .{tick(h, v)}));
        }
        return h.el(.figure, .{
            .class = "c-dots",
            .role = "group",
            .aria_label = d.m.label,
            .style = h.vars(.{ .n = n, .nb = nb }),
            .on_keydown = h.on(d, .key),
        }, .{
            h.div(.{ .class = "cols" }, .{ h.el(.i, .{ .class = "ctr" }, .{}), cols.done() }),
            h.div(.{ .class = "xax", .aria_hidden = true }, .{
                xs.done(),
                h.span(.{ .class = "end" }, .{d.m.lo}),
                h.span(.{ .class = "end", .data_at = "hi" }, .{d.m.hi}),
            }),
        });
    }
};

/// "+2" for whole units, "+1.5" between, "+300" for gold
fn tick(h: *H, v: f32) tree.Text {
    if (v == @round(v)) return phrase.num(h, .signed, @as(i32, @intFromFloat(v)));
    return phrase.num(h, .points, v);
}

pub const css =
    \\@layer components {
    \\  .c-dots { container-type: inline-size; margin: 0; font-size: var(--fs-xs); color: var(--faint);
    \\    font-variant-numeric: tabular-nums;
    \\    --sz: clamp(12px, 100cqw / var(--n) - 3px, 28px); }
    \\  .c-dots > .cols { position: relative; display: grid; grid-template-columns: repeat(var(--n), minmax(0, 1fr));
    \\    align-items: end; min-height: 64px; padding: 12px 0 2px; border-bottom: 1px solid var(--axis); }
    \\  .c-dots .ctr { position: absolute; top: 0; bottom: -6px; left: calc((var(--nb) + 0.5) / var(--n) * 100%);
    \\    width: 1px; background: var(--axis); }
    \\  .c-dots .bin { grid-row: 1; grid-column: var(--c); display: flex; flex-wrap: wrap-reverse; justify-content: center;
    \\    gap: 3px; padding: 0 1px; }
    \\  .c-dots .d { position: relative; flex: none; }
    \\  .c-dots .m { all: unset; position: relative; z-index: 1; display: block; width: var(--sz); height: var(--sz);
    \\    border-radius: calc(var(--sz) / 6); cursor: pointer; transition: transform var(--dur) var(--ease); }
    \\  .c-dots .m img { display: block; width: 100%; height: 100%; border-radius: inherit; }
    \\  .c-dots .m[data-thin] { opacity: 0.4; }
    \\  .c-dots .m:hover { z-index: 2; opacity: 1; transform: scale(1.3); box-shadow: 0 0 0 2px var(--panel), 0 0 0 3.5px var(--text); }
    \\  .c-dots .m[aria-pressed="true"] { z-index: 2; opacity: 1; box-shadow: 0 0 0 2px var(--panel), 0 0 0 3.5px var(--accent); }
    \\  .c-dots .tt { display: none; position: absolute; z-index: 3; bottom: calc(100% + 6px); left: 50%; transform: translateX(-50%);
    \\    padding: 2px var(--sp-2); border-radius: var(--r-m); background: var(--panel-3); border: 1px solid var(--line-2);
    \\    box-shadow: var(--shadow-pop); color: var(--t2); font-size: var(--fs-s); white-space: nowrap; pointer-events: none; }
    \\  .c-dots .tt b { color: var(--text); font-weight: var(--w-b); }
    \\  .c-dots .bin[data-side="lo"] .tt { left: 0; transform: none; }
    \\  .c-dots .bin[data-side="hi"] .tt { left: auto; right: 0; transform: none; }
    \\  @media (hover: hover) { .c-dots .d:hover > .tt { display: block; } }
    \\  .c-dots .m:focus-visible { outline: 2px solid var(--focus); outline-offset: 3px; }
    \\  .c-dots > .xax { position: relative; height: 22px; }
    \\  .c-dots .xt { position: absolute; top: 6px; left: calc(var(--x) * 1%); transform: translateX(-50%); white-space: nowrap; }
    \\  .c-dots .xt::before { content: ""; position: absolute; left: 50%; top: -9px; width: 1px; height: 7px; background: var(--grid); }
    \\  .c-dots .end { position: absolute; top: 6px; left: 0; }
    \\  .c-dots .end[data-at="hi"] { left: auto; right: 0; }
    \\  @container (max-width: 520px) {
    \\    .c-dots { --sz: clamp(10px, 100cqw / var(--n) - 2px, 24px); }
    \\    .c-dots .bin { gap: 2px; }
    \\    .c-dots .end { display: none; }
    \\  }
    \\}
    \\
;

/// Darius top's opponents on 16.21 (his own rate 49.3%), from the round 4 mock
pub const demo_dots = blk: {
    const rows = [_]struct { []const u8, []const u8, f32, u32 }{
        .{ "DrMundo", "Dr. Mundo", 43.2, 859 },   .{ "Akali", "Akali", 43.5, 393 },
        .{ "Volibear", "Volibear", 45.9, 939 },   .{ "Urgot", "Urgot", 45.4, 538 },
        .{ "Riven", "Riven", 45.1, 344 },         .{ "Teemo", "Teemo", 47.1, 930 },
        .{ "Sett", "Sett", 47.4, 1621 },          .{ "Renekton", "Renekton", 47.4, 816 },
        .{ "Yorick", "Yorick", 47.1, 501 },       .{ "Kayle", "Kayle", 47.4, 460 },
        .{ "Malphite", "Malphite", 48.0, 932 },   .{ "Jax", "Jax", 48.0, 922 },
        .{ "Ornn", "Ornn", 47.8, 571 },           .{ "Kennen", "Kennen", 47.9, 338 },
        .{ "Pantheon", "Pantheon", 48.7, 573 },   .{ "Chogath", "Cho'Gath", 48.9, 485 },
        .{ "Gragas", "Gragas", 49.3, 381 },       .{ "Illaoi", "Illaoi", 49.5, 479 },
        .{ "Gangplank", "Gangplank", 49.6, 807 }, .{ "Singed", "Singed", 49.7, 348 },
        .{ "Camille", "Camille", 49.8, 609 },     .{ "TahmKench", "Tahm Kench", 50.0, 440 },
        .{ "Aatrox", "Aatrox", 49.9, 747 },       .{ "Jayce", "Jayce", 50.1, 447 },
        .{ "Garen", "Garen", 49.9, 1788 },        .{ "Tryndamere", "Tryndamere", 50.2, 484 },
        .{ "Irelia", "Irelia", 50.4, 530 },       .{ "Mordekaiser", "Mordekaiser", 50.2, 1077 },
        .{ "Ambessa", "Ambessa", 50.9, 446 },     .{ "Gnar", "Gnar", 51.0, 480 },
        .{ "Nasus", "Nasus", 50.9, 593 },         .{ "Shen", "Shen", 51.5, 608 },
        .{ "Gwen", "Gwen", 52.4, 368 },           .{ "Sion", "Sion", 52.1, 599 },
        .{ "Olaf", "Olaf", 52.7, 452 },           .{ "Yone", "Yone", 51.8, 1259 },
        .{ "Fiora", "Fiora", 53.3, 798 },         .{ "Yasuo", "Yasuo", 56.5, 451 },
        .{ "KSante", "K'Sante", 60.3, 353 },
    };
    @setEvalBranchQuota(200_000);
    var out: [rows.len]Dot = undefined;
    for (rows, &out) |r, *d| d.* = .{
        .champ = champ.demo(r[0], r[1]),
        .x = r[2] - 49.3,
        .games = r[3],
        .fig = plain(std.fmt.comptimePrint("{d:.1}%", .{r[2]})),
        .thin = r[3] < 400,
    };
    break :blk out;
};

const demo_label = plain("Matchups");

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const states = [_]struct { []const u8, DotPlot }{
        .{ "win rate against, the most met chosen", .{ .dots = &demo_dots, .m = .{ .label = demo_label } } },
        .{ "a hard one chosen", .{ .dots = &demo_dots, .m = .{ .label = demo_label }, .sel = 0 } },
        .{ "few dots", .{ .dots = demo_dots[20..26], .m = .{ .label = demo_label } } },
    };
    for (states) |s| {
        const d = h.mem.create(DotPlot) catch {
            h.oom = true;
            return;
        };
        d.* = s[1];
        g.addFill(s[0], d.view(h));
    }
}

const testing = std.testing;

test "bins reach the farthest well-played dot, at least 4 and the scale's cut" {
    try testing.expectEqual(@as(u16, 7), bins(&demo_dots, .{ .label = demo_label }));
    try testing.expectEqual(@as(u16, 4), bins(demo_dots[20..26], .{ .label = demo_label }));
    try testing.expectEqual(@as(u16, 6), bins(demo_dots[20..26], .{ .label = demo_label, .reach = 6 }));
}

test "the most played is chosen first; arrows walk bins left to right" {
    var d: DotPlot = .{ .dots = &demo_dots, .m = .{ .label = demo_label } };
    try testing.expectEqual(@as(?u16, 24), d.chosen());
    var ev: tree.Event = .{ .kind = .keydown, .text = "ArrowRight" };
    d.update(.key, &ev);
    // Garen (+0.6) sits in bin +1 with Tryndamere, Irelia, Mordekaiser...: the next most played is Mordekaiser
    try testing.expectEqual(@as(?u16, 27), d.chosen());
    try testing.expect(ev.handled);
    d.sel = 0;
    ev = .{ .kind = .keydown, .text = "ArrowLeft" };
    d.update(.key, &ev);
    try testing.expectEqual(@as(?u16, 0), d.chosen());
}
