//! GuessSlider: a guess on a number line. No value until touched (the dashed track is
//! the hint, no thumb), so the owner's Lock in stays off until the first move; a press
//! or drag, arrows, Page keys, Home and End set it, Enter commits. Once revealed the
//! real value joins it as a second marker with the gap between, and it takes no input.
//! The owner keeps a Guess and forwards its events (`event`), as chart.Press. `row`: the
//! asked row of PuzzleCard's RateRows, on the rows' axis: the fill grows from `from` and
//! the figures sit in the row's value cell, not over the marks
const std = @import("std");
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const Gallery = @import("gallery.zig").Gallery;
const phrase = @import("phrase.zig");
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "GuessSlider";
pub const scope = .{".c-guess"};

const W = struct {
    pub const label = plain("Your guess");
    pub const unset = plain("Not set");
    pub const you = plain("You ");
    pub const gold = plain(" gold");
    pub const off = plain(" off");
};

pub const Unit = enum { rate, gold };

pub const Guess = struct {
    lo: f32,
    hi: f32,
    step: f32 = 0.5,
    unit: Unit = .rate,
    /// Where the fill starts (a RateRows track's 50%)
    from: ?f32 = null,
    value: ?f32 = null,
    /// The measured value, once revealed
    real: ?f32 = null,
    dragging: bool = false,

    pub const Out = enum { none, moved, commit };

    /// A pointer or key event on the slider: what it did to the guess
    pub fn event(g: *Guess, ev: *tree.Event) Out {
        if (g.real != null) return .none;
        switch (ev.kind) {
            .pointerdown => {
                g.dragging = true;
                ev.capture = true;
                return g.set(g.at(ev));
            },
            .pointermove => return if (g.dragging) g.set(g.at(ev)) else .none,
            .pointerup, .pointercancel => g.dragging = false,
            .keydown => {
                const k = ev.text;
                if (eql(k, "Enter")) {
                    if (g.value == null) return .none;
                    ev.handled = true;
                    return .commit;
                }
                const v = g.value orelse g.from orelse (g.lo + g.hi) / 2;
                const to: f32 = if (eql(k, "ArrowRight") or eql(k, "ArrowUp"))
                    v + g.step
                else if (eql(k, "ArrowLeft") or eql(k, "ArrowDown"))
                    v - g.step
                else if (eql(k, "PageUp"))
                    v + 10 * g.step
                else if (eql(k, "PageDown"))
                    v - 10 * g.step
                else if (eql(k, "Home"))
                    g.lo
                else if (eql(k, "End"))
                    g.hi
                else
                    return .none;
                ev.handled = true;
                return g.set(to);
            },
            else => {},
        }
        return .none;
    }

    fn at(g: *const Guess, ev: *const tree.Event) f32 {
        const w = if (ev.w > 0) ev.w else 1;
        return g.lo + (g.hi - g.lo) * std.math.clamp(ev.x / w, 0, 1);
    }

    fn set(g: *Guess, v: f32) Out {
        const s = std.math.clamp(@round(v / g.step) * g.step, g.lo, g.hi);
        if (g.value == s) return .none;
        g.value = s;
        return .moved;
    }

    /// How far the guess was from the real value
    pub fn off(g: *const Guess) ?f32 {
        const v = g.value orelse return null;
        return @abs(v - (g.real orelse return null));
    }

    /// 3 within `tol`, 2 within 2.5 tol, 1 within 5 tol
    pub fn stars(g: *const Guess, tol: f32) u2 {
        const d = g.off() orelse return 0;
        return if (d <= tol) 3 else if (d <= 2.5 * tol) 2 else if (d <= 5 * tol) 1 else 0;
    }

    /// `v` along the track, percent
    pub fn pos(g: *const Guess, v: f32) f32 {
        return 100 * std.math.clamp((v - g.lo) / (g.hi - g.lo), 0, 1);
    }
};

fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

/// "55%", "51.7%", "300 gold"
pub fn text(h: *H, u: Unit, v: f32) tree.Text {
    var out: std.Io.Writer.Allocating = .init(h.mem);
    const w = &out.writer;
    write(w, u, v) catch {
        h.oom = true;
    };
    return .{ .s = out.written() };
}

/// The gap once revealed: "3.3 off" (points), "150 gold off"
pub fn offText(h: *H, g: *const Guess) ?tree.Text {
    const d = g.off() orelse return null;
    var out: std.Io.Writer.Allocating = .init(h.mem);
    const w = &out.writer;
    (if (g.unit == .rate) fmt.fixed(w, d, 1, true) else write(w, .gold, d)) catch {
        h.oom = true;
    };
    w.writeAll(W.off.s) catch {
        h.oom = true;
    };
    return .{ .s = out.written() };
}

fn write(w: *std.Io.Writer, u: Unit, v: f32) !void {
    switch (u) {
        .rate => {
            try fmt.fixed(w, v, 1, true);
            try w.writeByte('%');
        },
        .gold => {
            try fmt.write(w, .count, @as(u64, @intFromFloat(@round(@max(v, 0)))));
            try w.writeAll(W.gold.s);
        },
    }
}

pub const Opts = struct {
    /// The owner's handler for the slider's events; none: drawn only (gallery, no script)
    on: ?tree.Handler = null,
    label: tree.Text = W.label,
    /// Axis figures under the track (not in a row)
    ticks: []const f32 = &.{},
    row: bool = false,
    /// data-ref, to focus it after a patch
    ref: ?[]const u8 = null,
};

pub fn view(h: *H, g: *const Guess, o: Opts) N {
    const done = g.real != null;
    const live = !done and o.on != null;
    const on = if (live) o.on else null;
    var ticks = h.list();
    if (!o.row) for (o.ticks) |t| {
        const p = g.pos(t);
        ticks.add(h.span(.{
            .style = h.vars(.{ .x = p }),
            .data_e = if (p <= 0) "s" else if (p >= 100) "e" else null,
        }, .{text(h, g.unit, t)}));
    };
    const you = if (g.value) |v| g.pos(v) else null;
    const real = if (g.real) |v| g.pos(v) else null;
    return h.div(.{
        .class = "c-guess",
        .data_v = if (o.row) "row" else null,
        .data_done = done,
        .data_set = g.value != null,
        .tabindex = if (live) @as(?u8, 0) else null,
        .role = "slider",
        .aria_label = o.label,
        .aria_valuemin = g.lo,
        .aria_valuemax = g.hi,
        .aria_valuenow = g.value,
        .aria_valuetext = if (g.value) |v| text(h, g.unit, v) else W.unset,
        .aria_readonly = done,
        .data_ref = o.ref,
        .on_pointerdown = on,
        .on_pointermove = on,
        .on_pointerup = on,
        .on_pointercancel = on,
        .on_keydown = on,
    }, .{
        h.el(.i, .{ .class = "track" }, .{}),
        if (o.row and !done and you != null and g.from != null) span(h, "fill", g.pos(g.from.?), you.?) else null,
        if (real) |r| span(h, "gap", r, you orelse r) else null,
        if (you) |x| mark(h, "you", x, real, if (o.row) null else if (done) .{ W.you, text(h, g.unit, g.value.?) } else .{ plain(""), text(h, g.unit, g.value.?) }) else null,
        if (real) |r| mark(h, "real", r, you, if (o.row) null else .{ plain(""), text(h, g.unit, g.real.?) }) else null,
        if (ticks.done().len > 0) h.div(.{ .class = "ticks", .aria_hidden = true }, .{ticks.done()}) else null,
    });
}

fn span(h: *H, comptime class: []const u8, a: f32, b: f32) N {
    return h.el(.i, .{ .class = class, .style = h.vars(.{ .a = @min(a, b), .b = @max(a, b) }) }, .{});
}

/// A marker at x; its figure leans off the track's ends first, then away from the other
/// marker
fn mark(h: *H, comptime k: []const u8, x: f32, other: ?f32, label: ?[2]tree.Text) N {
    const end: ?[]const u8 = if (x < 12) "r" else if (x > 88) "l" else null;
    const side: ?[]const u8 = end orelse if (other) |o| (if (x < o) "l" else "r") else null;
    return h.span(.{ .class = "mark", .data_k = k, .data_side = side, .style = h.vars(.{ .x = x }) }, .{
        if (label) |l| h.span(.{}, .{ l[0], l[1] }) else null,
    });
}

pub const css =
    \\@layer components {
    \\  .c-guess { --top: 26px; position: relative; height: 64px; touch-action: none; cursor: pointer; user-select: none;
    \\    -webkit-user-select: none; border-radius: var(--r-s); }
    \\  .c-guess:focus-visible { outline: 2px solid var(--focus); outline-offset: 2px; }
    \\  .c-guess[data-done] { cursor: default; touch-action: auto; }
    \\  .c-guess > .track { position: absolute; inset-inline: 0; top: calc(var(--top) + 10px); height: 4px; border-radius: 2px;
    \\    background: repeating-linear-gradient(90deg, var(--line-2) 0 6px, transparent 6px 10px); }
    \\  .c-guess[data-done] > .track { background: var(--bar-track); }
    \\  .c-guess > .fill, .c-guess > .gap { position: absolute; left: calc(var(--a) * 1%); width: calc((var(--b) - var(--a)) * 1%); }
    \\  .c-guess > .fill { top: calc(var(--top) + 1px); height: 22px; border-radius: 4px; box-shadow: inset 0 0 0 1px var(--sel-line);
    \\    background: repeating-linear-gradient(135deg, var(--accent-bg) 0 5px, transparent 5px 10px); }
    \\  .c-guess > .gap { top: calc(var(--top) + 8px); height: 8px; background: var(--accent-bg); }
    \\  .c-guess > .mark { position: absolute; top: var(--top); left: calc(var(--x) * 1%); width: 4px; height: 24px; margin-left: -2px;
    \\    border-radius: 2px; background: var(--accent); }
    \\  .c-guess > .mark[data-k="real"] { background: var(--text); }
    \\  .c-guess > .mark > span { position: absolute; bottom: calc(100% + 4px); left: 50%; transform: translateX(-50%);
    \\    font-size: var(--fs-s); font-weight: var(--w-b); white-space: nowrap; color: var(--accent);
    \\    font-variant-numeric: tabular-nums; }
    \\  .c-guess > .mark[data-k="real"] > span { color: var(--text); }
    \\  .c-guess > .mark[data-side="l"] > span { transform: translateX(calc(-100% + 2px)); }
    \\  .c-guess > .mark[data-side="r"] > span { transform: translateX(-2px); }
    \\  .c-guess > .ticks { position: absolute; inset-inline: 0; top: calc(var(--top) + 22px); height: 16px;
    \\    font-size: var(--fs-xs); color: var(--faint); font-variant-numeric: tabular-nums; }
    \\  .c-guess > .ticks > span { position: absolute; left: calc(var(--x) * 1%); transform: translateX(-50%); white-space: nowrap; }
    \\  .c-guess > .ticks > span[data-e="s"] { transform: none; }
    \\  .c-guess > .ticks > span[data-e="e"] { transform: translateX(-100%); }
    \\  .c-guess[data-v="row"] { --top: 10px; height: 52px; }
    \\  .c-guess[data-v="row"] > .track { top: 25px; height: 2px; }
    \\  .c-guess[data-v="row"] > .mark { height: 32px; }
    \\  .c-guess[data-v="row"] > .gap { top: 22px; }
    \\  .c-guess[data-v="row"] > .fill { top: 15px; }
    \\}
    \\
;

fn demo(value: ?f32, real: ?f32) Guess {
    return .{ .lo = 40, .hi = 65, .value = value, .real = real };
}

const demo_ticks = [_]f32{ 40, 45, 50, 55, 60, 65 };

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const states = [_]struct { []const u8, Guess }{
        .{ "untouched", demo(null, null) },
        .{ "moved", demo(55, null) },
        .{ "revealed, 3.3 off", demo(55, 51.7) },
        .{ "revealed, guess at the end", demo(40, 51.7) },
        .{ "gold", .{ .lo = 0, .hi = 1000, .step = 25, .unit = .gold, .value = 450, .real = 300 } },
        .{ "gold, guess at the top", .{ .lo = 0, .hi = 1000, .step = 25, .unit = .gold, .value = 1000, .real = 300 } },
    };
    for (states) |s| {
        const x = h.mem.create(Guess) catch {
            h.oom = true;
            return;
        };
        x.* = s[1];
        const ticks: []const f32 = if (x.unit == .gold) &.{ 0, 500, 1000 } else &demo_ticks;
        g.addFill(s[0], view(h, x, .{ .ticks = ticks }));
    }
    const row = [_]struct { []const u8, Guess }{
        .{ "row: untouched", .{ .lo = 40, .hi = 60, .from = 50 } },
        .{ "row: moved", .{ .lo = 40, .hi = 60, .from = 50, .value = 55 } },
    };
    for (row) |s| {
        const x = h.mem.create(Guess) catch {
            h.oom = true;
            return;
        };
        x.* = s[1];
        g.addFill(s[0], view(h, x, .{ .row = true }));
    }
}

const testing = std.testing;

test "no value until touched; press, drag, keys snap to the step; Enter commits once set" {
    var g: Guess = .{ .lo = 40, .hi = 65 };
    var ev: tree.Event = .{ .kind = .keydown, .text = "Enter" };
    try testing.expectEqual(Guess.Out.none, g.event(&ev));
    ev = .{ .kind = .pointermove, .x = 100, .w = 200 };
    try testing.expectEqual(Guess.Out.none, g.event(&ev));
    try testing.expectEqual(@as(?f32, null), g.value);
    // 61 px of 200: 47.625, to the half point
    ev = .{ .kind = .pointerdown, .x = 61, .w = 200 };
    try testing.expectEqual(Guess.Out.moved, g.event(&ev));
    try testing.expect(ev.capture);
    try testing.expectEqual(@as(?f32, 47.5), g.value);
    ev = .{ .kind = .pointermove, .x = 400, .w = 200 };
    _ = g.event(&ev);
    try testing.expectEqual(@as(?f32, 65), g.value);
    ev = .{ .kind = .pointerup, .x = 400, .w = 200 };
    _ = g.event(&ev);
    ev = .{ .kind = .pointermove, .x = 0, .w = 200 };
    try testing.expectEqual(Guess.Out.none, g.event(&ev));
    ev = .{ .kind = .keydown, .text = "ArrowLeft" };
    try testing.expectEqual(Guess.Out.moved, g.event(&ev));
    try testing.expect(ev.handled);
    try testing.expectEqual(@as(?f32, 64.5), g.value);
    ev = .{ .kind = .keydown, .text = "PageDown" };
    _ = g.event(&ev);
    try testing.expectEqual(@as(?f32, 59.5), g.value);
    ev = .{ .kind = .keydown, .text = "a" };
    try testing.expectEqual(Guess.Out.none, g.event(&ev));
    try testing.expect(!ev.handled);
    ev = .{ .kind = .keydown, .text = "Enter" };
    try testing.expectEqual(Guess.Out.commit, g.event(&ev));
    g.real = 51.7;
    try testing.expectApproxEqAbs(@as(f32, 7.8), g.off().?, 0.001);
    try testing.expectEqual(@as(u2, 0), g.stars(1));
    try testing.expectEqual(@as(u2, 1), g.stars(2));
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    try testing.expectEqualStrings("7.8 off", offText(&h, &g).?.s);
    ev = .{ .kind = .keydown, .text = "Home" };
    try testing.expectEqual(Guess.Out.none, g.event(&ev));
}

test "a first arrow starts from the fill's start" {
    var g: Guess = .{ .lo = 40, .hi = 60, .from = 50 };
    var ev: tree.Event = .{ .kind = .keydown, .text = "ArrowUp" };
    _ = g.event(&ev);
    try testing.expectEqual(@as(?f32, 50.5), g.value);
}

test "markup: unset has no aria-valuenow and no marks; revealed takes no input; a figure at an end leans in" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const T = struct {
        g: Guess,
        pub const Msg = enum { ev };
        pub fn update(_: *@This(), _: Msg, _: *tree.Event) void {}
    };
    var x: T = .{ .g = .{ .lo = 40, .hi = 65 } };
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    const html = @import("html.zig");
    var out: std.Io.Writer.Allocating = .init(a);
    try html.write(&t, view(&h, &x.g, .{ .on = h.on(&x, .ev), .ticks = &demo_ticks }), &out.writer);
    var s = out.written();
    try testing.expect(std.mem.indexOf(u8, s, "aria-valuenow") == null);
    try testing.expect(std.mem.indexOf(u8, s, "aria-valuetext=\"Not set\"") != null);
    try testing.expect(std.mem.indexOf(u8, s, "tabindex=\"0\"") != null);
    try testing.expect(std.mem.indexOf(u8, s, "class=\"mark\"") == null);
    x.g.value = 55;
    x.g.real = 51.7;
    out = .init(a);
    try html.write(&t, view(&h, &x.g, .{ .on = h.on(&x, .ev) }), &out.writer);
    s = out.written();
    try testing.expect(std.mem.indexOf(u8, s, "tabindex") == null);
    try testing.expect(std.mem.indexOf(u8, s, "You 55%") != null);
    try testing.expect(std.mem.indexOf(u8, s, "51.7%") != null);
    try testing.expect(std.mem.indexOf(u8, s, "aria-valuetext=\"55%\"") != null);
    try testing.expect(std.mem.indexOf(u8, s, "data-k=\"you\" data-side=\"r\"") != null);
    x.g.value = 65;
    out = .init(a);
    try html.write(&t, view(&h, &x.g, .{ .on = h.on(&x, .ev) }), &out.writer);
    try testing.expect(std.mem.indexOf(u8, out.written(), "data-k=\"you\" data-side=\"l\"") != null);
}
