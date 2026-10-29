//! AdminRuns: the Models tab's training runs, an island of its own below AdminLab
//! (ui-adminruns.wasm: ui-adminmodels.wasm is near its budget). It fetches
//! training/training.bin as AdminModels does and, for the run whose health shows, its
//! runs/<run>/metrics.bin and log.txt. A category: its runs as cards, the picked one's
//! effects, curves and log. All: the runs live now. Lab campaigns: the lab's runs. Win,
//! Draft and Neural nets show nothing here
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const card = @import("card.zig");
const badge = @import("badge.zig");
const chart = @import("chart.zig");
const Gallery = @import("gallery.zig").Gallery;
const md = @import("modelsdata.zig");
const ap = @import("adminpage.zig");
const am = @import("adminmodels.zig");
const al = @import("adminlab.zig");
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;
const Text = tree.Text;
const View = am.View;
const dec = am.dec;
const count = am.count;

pub const name = "AdminRuns";
pub const scope = .{".c-adruns"};
pub const sel = "[data-island=adminruns]";

/// Run cards shown; older ones are counted
const cards_max = 24;
/// Checks listed in their fold
const checks_max = 40;
/// Metrics table rows, newest first
const rows_max = 200;
/// The gpu-box not reached for this long: its runs may be out of date
const gpu_stale_s = 1800;

pub const Runs = struct {
    tab: ap.Tab = .overview,
    cat: View = .all,
    now: i64 = 0,
    /// The wasm's
    training: ?*const md.Training = null,
    failed: bool = false,
    /// The run picked, by name (the wasm keeps its own copy); none or gone: the newest in view
    run: []const u8 = "",
    /// The shown run's files once fetched: whose (the wasm's copy), curves, log tail
    files: []const u8 = "",
    metrics: ?*const md.Metrics = null,
    log: ?[]const u8 = null,
    files_failed: bool = false,
    /// This island's code, on its root for dom.lazyLoad
    js: []const u8 = "",
    wasm: []const u8 = "",

    /// AdminModels' keys: it owns the picker, this island follows
    pub const Url = struct { tab: ap.Tab = .overview, cat: View = .all };

    pub const Msg = union(enum) { pick: u16 };

    pub fn toUrl(m: *const Runs) Url {
        return .{ .tab = m.tab, .cat = m.cat };
    }

    pub fn fromUrl(m: *Runs, u: Url) void {
        m.tab = u.tab;
        m.cat = u.cat;
    }

    pub fn update(m: *Runs, msg: Msg, ev: *tree.Event) void {
        _ = ev;
        switch (msg) {
            .pick => |i| if (m.training) |t| if (i < t.runs.len) {
                m.run = t.runs[i].run;
            },
        }
    }

    pub fn shows(m: *const Runs) bool {
        return m.tab == .models and m.cat != .win and m.cat != .draft and m.cat != .nn;
    }

    /// The run whose health shows: the one picked if in view, else the newest model run
    pub fn shown(m: *const Runs) ?*const md.Run {
        const t = m.training orelse return null;
        var first: ?*const md.Run = null;
        for (t.runs) |*r| {
            if (!inView(m.cat, r) or isCheck(r)) continue;
            if (std.mem.eql(u8, r.run, m.run)) return r;
            if (first == null) first = r;
        }
        return first;
    }

    pub fn view(m: *Runs, h: *H) N {
        const on = m.shows();
        return h.div(.{ .class = "c-admodels c-adruns", .data_island = "adminruns", .data_js = m.js, .data_wasm = m.wasm, .hidden = !on }, .{
            if (on) body(m, h) else null,
        });
    }
};

fn inView(v: View, r: *const md.Run) bool {
    return switch (v) {
        .all => r.state == .running or r.state == .paused,
        .lab => r.lab,
        .win, .draft, .nn => false,
        else => r.cat == am.catOf(v),
    };
}

/// The lab's diagnose, screen and preds runs: folded under the model runs
fn isCheck(r: *const md.Run) bool {
    return if (r.res) |x| x.kind != .run else false;
}

const W = struct {
    pub const failed = plain("The lab view (training/training.bin) didn't load: reload the page to try again");
    pub const runs = plain("Runs");
    pub const runs_lead = plain("Newest first. Pick one to see its effects, curves and log.");
    pub const live = plain("Running now");
    pub const no_runs = plain("No model runs in this category yet.");
    pub const checks = Phrase("Checks and screens ({n:count}): where models are off, which inputs look useful");
    pub const older = Phrase("{n:count} older runs not shown.");
    pub const gpu_stale = Phrase("gpu-box last reached {t:text}: its runs may be out of date (the Mac reaches it on the home network only).");
    pub const runs_label = plain("Runs, newest first");
    pub const effects = Phrase("Effects measured by {r:text} ({n:count})");
    pub const started = Phrase("Started {t:text}");
    pub const at = Phrase(", at {c:text}");
    pub const dirty = Phrase(" + {d:text} changed");
    pub const loading = ap.W.loading;
    pub const files_failed = plain("Its log didn't load: reload the page to try again.");
    pub const no_metrics = plain("No metrics yet: a run reports by appending rows to metrics.tsv in its directory.");
    pub const table = Phrase("Metrics table ({n:count} rows, newest first)");
    pub const log = plain("Log (last 300 lines)");
    pub const empty_log = plain("(empty log)");

    pub const finished = plain("finished");
    pub const failed_code = Phrase("failed (exit {n:int})");
    pub const running = plain("running");
    pub const paused = plain("paused");
    pub const stopped = plain("stopped");
    pub const died = plain("died");
    pub const synthetic = plain("synthetic");
    pub const other = plain("other");
    pub const mac = plain("Mac");
    pub const gpu = plain("gpu-box");
};

fn body(m: *Runs, h: *H) N {
    if (m.failed and m.training == null) return h.p(.{ .class = "lead", .role = "status" }, .{W.failed});
    // AdminModels says it is loading
    const t = m.training orelse return .none;
    return switch (m.cat) {
        .all => if (m.shown() != null) runsBlock(m, h, t, W.live) else .none,
        else => runsBlock(m, h, t, W.runs),
    };
}

// ---------- Runs ----------

fn stateText(h: *H, r: *const md.Run) struct { Text, badge.Kind } {
    if (r.synthetic) return .{ W.synthetic, .few };
    return switch (r.state) {
        .finished => .{ W.finished, .us },
        .failed => .{ W.failed_code.with(h, .{ .n = r.code }), .them },
        .died => .{ W.died, .them },
        .running => .{ W.running, .accent },
        .paused => .{ W.paused, .few },
        .stopped => .{ W.stopped, .neutral },
        .other => .{ W.other, .neutral },
    };
}

fn stateBadge(h: *H, r: *const md.Run) N {
    const s = stateText(h, r);
    return badge.view(h, s[1], .{s[0]});
}

/// "Mac · Gold at 14 min · 28 Oct 13:00"
fn facts(h: *H, r: *const md.Run) []const u8 {
    var out: std.ArrayList(u8) = .empty;
    out.appendSlice(h.mem, if (r.host == .gpu_box) W.gpu.s else W.mac.s) catch {};
    if (r.target.len > 0) out.print(h.mem, " · {s}", .{am.outcomeLabel(r.target)}) catch {};
    if (r.started) |s| out.print(h.mem, " · {s}", .{ap.when(h, s).s}) catch {};
    return out.items;
}

/// What a run found, in a sentence a non-statistician can read
pub fn sentence(h: *H, r: *const md.Run) []const u8 {
    if (r.synthetic) return "Synthetic: random curves from a test script, not a model.";
    const what = if (r.target.len > 0) am.lowerFirst(h, am.outcomeLabel(r.target)) else "the outcome";
    if (r.result) |rt| if (rt.removed) |rm| {
        const unit = if (rt.unit.len > 0 and !std.mem.eql(u8, rt.unit, "-")) rt.unit else "";
        const miss = if (rt.err_base != null and rt.err_cand != null and unit.len > 0)
            h.fmt(" Typical miss {s} → {s} {s}.", .{ num(h, rt.err_base.?), num(h, rt.err_cand.?), unit })
        else
            "";
        const s = if (rm.mean - rm.ci > 0)
            h.fmt("Predicts {s} better than champion averages: {s}% (± {s}) of the error removed on practice games.{s}", .{ what, dec(h, rm.mean, 1), dec(h, rm.ci, 1), miss })
        else if (rm.mean + rm.ci < 0)
            h.fmt("Predicts {s} worse than champion averages ({s}% ± {s}).", .{ what, dec(h, rm.mean, 1), dec(h, rm.ci, 1) })
        else
            h.fmt("No measurable difference from champion averages for {s}.", .{what});
        return h.fmt("{s}{s}", .{ s, selectText(rt.select) });
    };
    const res = r.res orelse return r.last;
    switch (res.kind) {
        .run => if (res.dev) |d| {
            if (d.ci == 0) return h.fmt("Reference run for {s}: the baseline scored against itself.", .{what});
            // Squared error in the role's standard deviations: dev x 100 is about the % of
            // the outcome's spread
            const size = h.fmt("{s}% (± {s})", .{ dec(h, @abs(d.mean) * 100, 1), dec(h, d.ci * 100, 1) });
            const s = if (d.mean + d.ci < 0)
                h.fmt("Predicts {s} better than champion averages: error down {s} on practice games.", .{ what, size })
            else if (d.mean - d.ci > 0)
                h.fmt("Predicts {s} worse than champion averages: error up {s}.", .{ what, size })
            else
                h.fmt("No measurable difference from champion averages for {s}.", .{what});
            return h.fmt("{s}{s}", .{ s, selectText(res.select) });
        },
        .diagnose => if (res.bias) |b| return h.fmt("Check of where the model is off for {s}: overall bias {s}{s} standard deviations.", .{ what, if (b.mean < 0) "−" else "+", dec(h, @abs(b.mean), 3) }),
        .screen => if (res.features) |f| return h.fmt("Screened {s} candidate inputs for {s}: {s} clear of noise.", .{ count(h, f), what, count(h, res.clear orelse 0) }),
        .preds => if (res.rows) |n| return h.fmt("Wrote {s} predictions for comparison.", .{count(h, n)}),
        .other => {},
    }
    return r.last;
}

fn selectText(s: md.Select) []const u8 {
    return switch (s) {
        .none => "",
        .new_best => " Confirmed on the held-back selection games: the new best.",
        .no_change => " Not better on the held-back selection games.",
    };
}

/// A figure as a reader wants it: whole above 100, else three significant figures
pub fn num(h: *H, v: f32) []const u8 {
    const a = @abs(v);
    return if (a >= 100) count(h, @as(i64, @intFromFloat(@round(v)))) else if (a >= 10) dec(h, v, 1) else if (a >= 1) dec(h, v, 2) else dec(h, v, 3);
}

fn runsBlock(m: *Runs, h: *H, t: *const md.Training, title: Text) N {
    var checks = h.list();
    var n_checks: usize = 0;
    var cards = h.list();
    var n_runs: usize = 0;
    var gpu_runs = false;
    const pick = m.shown();
    for (t.runs, 0..) |*r, i| {
        if (!inView(m.cat, r)) continue;
        if (isCheck(r)) {
            n_checks += 1;
            if (n_checks <= checks_max) checks.add(h.li(.{ .key = i }, .{
                h.b(.{}, .{am.shortRun(r.run)}),
                h.fmt(" ({s}): ", .{facts(h, r)}),
                sentence(h, r),
            }));
            continue;
        }
        n_runs += 1;
        gpu_runs = gpu_runs or r.host == .gpu_box;
        if (n_runs > cards_max) continue;
        const on = if (pick) |p| p == r else false;
        cards.add(h.button(.{ .key = i, .type = "button", .class = "run", .role = "option", .aria_selected = on, .on_click = h.on(m, .{ .pick = @intCast(i) }) }, .{
            h.span(.{ .class = "top" }, .{ h.b(.{}, .{am.shortRun(r.run)}), stateBadge(h, r) }),
            h.span(.{ .class = "sub" }, .{facts(h, r)}),
            h.span(.{ .class = "finding" }, .{sentence(h, r)}),
        }));
    }
    const stale = if (t.gpu_seen) |g| gpu_runs and m.now - g > gpu_stale_s else false;
    return h.div(.{ .class = "tab" }, .{
        card.view(h, .{}, &.{
            card.head(h, title, if (n_runs > 0) Text{ .s = count(h, n_runs) } else null, &.{}),
            if (n_runs > 0) h.p(.{ .class = "lead" }, .{W.runs_lead}) else h.p(.{ .class = "lead" }, .{W.no_runs}),
            if (n_checks > 0) h.el(.details, .{}, .{
                h.el(.summary, .{}, .{W.checks.with(h, .{ .n = n_checks })}),
                h.ul(.{ .class = "readings" }, .{checks.done()}),
            }) else .none,
            if (stale) h.p(.{ .class = "warn", .role = "status" }, .{W.gpu_stale.with(h, .{ .t = ap.ago(h, m.now - t.gpu_seen.?).s })}) else .none,
            if (n_runs > 0) h.div(.{ .class = "runs", .role = "listbox", .aria_label = W.runs_label }, .{cards.done()}) else .none,
            if (n_runs > cards_max) h.p(.{ .class = "sub" }, .{W.older.with(h, .{ .n = n_runs - cards_max })}) else .none,
        }),
        if (pick) |r| effects(h, r) else null,
        if (pick) |r| detail(m, h, r) else null,
    });
}

fn effects(h: *H, r: *const md.Run) N {
    if (r.effects.len == 0) return .none;
    var l = h.list();
    for (r.effects) |e| l.add(am.effectForest(h, e));
    return h.el(.details, .{ .class = "c-card", .open = true }, .{
        h.el(.summary, .{}, .{W.effects.with(h, .{ .r = am.shortRun(r.run), .n = r.effects.len })}),
        h.div(.{ .class = "charts" }, .{l.done()}),
    });
}

/// The run's health: when and what it ran, its curves, the metrics behind them, its log
fn detail(m: *Runs, h: *H, r: *const md.Run) N {
    const mine = std.mem.eql(u8, m.files, r.run);
    const mt = if (mine) m.metrics else null;
    const log = if (mine) m.log else null;
    const commit = r.head.len > 0 and r.head[0] != '-';
    const dirty = commit and r.dirty.len > 0 and !std.mem.startsWith(u8, std.mem.trim(u8, r.dirty, " "), "0 files") and r.dirty[0] != '-';
    const rows = if (mt) |x| x.rows.len else 0;
    return card.view(h, .{}, &.{
        card.head(h, .{ .s = am.shortRun(r.run) }, null, &.{stateBadge(h, r)}),
        h.p(.{ .class = "sub" }, .{
            if (r.started) |s| W.started.with(h, .{ .t = ap.when(h, s).s }) else null,
            if (commit) W.at.with(h, .{ .c = r.head }) else null,
            if (dirty) W.dirty.with(h, .{ .d = std.mem.trim(u8, r.dirty, " ") }) else null,
        }),
        if (r.args.len > 0) h.div(.{ .class = "args" }, .{r.args}) else .none,
        if (!mine) h.p(.{ .class = "lead", .role = "status" }, .{W.loading}) else if (m.files_failed) h.p(.{ .class = "lead", .role = "status" }, .{W.files_failed}) else .none,
        if (mt) |x| curves(h, x) else if (mine) h.p(.{ .class = "lead" }, .{W.no_metrics}) else .none,
        if (mt) |x| if (rows > 0) metricsTable(h, x) else .none else .none,
        if (mine) h.el(.details, .{ .open = rows == 0 }, .{
            h.el(.summary, .{}, .{W.log}),
            h.div(.{ .class = "log" }, .{if (log) |l| (if (l.len > 0) Text{ .s = l } else W.empty_log) else W.empty_log}),
        }) else .none,
    });
}

/// Columns sharing the part after the last _ share a chart (train_loss, test_loss); a
/// prefix keeps its colour across charts
fn curves(h: *H, mt: *const md.Metrics) N {
    if (mt.cols.len < 2 or mt.rows.len == 0) return .none;
    const xs = h.mem.alloc(f32, mt.rows.len) catch return oom(h);
    for (xs, mt.rows) |*x, r| x.* = if (r.len > 0) r[0] else std.math.nan(f32);
    var prefixes: std.ArrayList([]const u8) = .empty;
    var groups: std.ArrayList([]const u8) = .empty;
    for (mt.cols[1..]) |c| {
        const g = suffix(c);
        if (indexOf(groups.items, g) == null) groups.append(h.mem, g) catch {};
        if (indexOf(prefixes.items, prefix(c)) == null) prefixes.append(h.mem, prefix(c)) catch {};
    }
    var charts = h.list();
    for (groups.items) |g| {
        var lines: std.ArrayList(Line) = .empty;
        var only: []const u8 = g;
        for (mt.cols[1..], 1..) |c, k| {
            if (!std.mem.eql(u8, suffix(c), g)) continue;
            const ys = h.mem.alloc(f32, mt.rows.len) catch return oom(h);
            for (ys, mt.rows) |*y, r| y.* = if (k < r.len) r[k] else std.math.nan(f32);
            lines.append(h.mem, .{ .name = c, .ys = ys, .s = @intCast(@min(indexOf(prefixes.items, prefix(c)).?, 5)) }) catch {};
            only = c;
        }
        charts.add(lineChart(h, .{ .s = if (lines.items.len == 1) only else g }, xs, lines.items, .{ .x_name = mt.cols[0] }));
    }
    return h.div(.{ .class = "charts" }, .{charts.done()});
}

fn suffix(c: []const u8) []const u8 {
    const i = std.mem.findScalarLast(u8, c, '_') orelse return c;
    return if (i > 0) c[i + 1 ..] else c;
}

fn prefix(c: []const u8) []const u8 {
    const i = std.mem.findScalarLast(u8, c, '_') orelse return c;
    return if (i > 0) c[0..i] else c;
}

pub fn indexOf(xs: []const []const u8, s: []const u8) ?usize {
    for (xs, 0..) |x, i| if (std.mem.eql(u8, x, s)) return i;
    return null;
}

pub fn oom(h: *H) N {
    h.oom = true;
    return .none;
}

fn metricsTable(h: *H, mt: *const md.Metrics) N {
    var head = h.list();
    for (mt.cols, 0..) |c, i| head.add(h.th(.{ .key = i, .class = "num", .data_answer = i + 1 == mt.cols.len }, .{c}));
    var rows = h.list();
    var i = mt.rows.len;
    var n: usize = 0;
    while (i > 0 and n < rows_max) : (n += 1) {
        i -= 1;
        var tds = h.list();
        for (0..mt.cols.len) |k| {
            const v: f32 = if (k < mt.rows[i].len) mt.rows[i][k] else std.math.nan(f32);
            tds.add(h.td(.{ .key = k, .class = "num" }, .{if (std.math.isNan(v)) "–" else num(h, v)}));
        }
        rows.add(h.tr(.{ .key = i }, .{tds.done()}));
    }
    return h.el(.details, .{}, .{
        h.el(.summary, .{}, .{W.table.with(h, .{ .n = mt.rows.len })}),
        h.div(.{ .class = "tw" }, .{h.table(.{}, .{ h.thead(.{}, .{h.tr(.{}, .{head.done()})}), h.tbody(.{}, .{rows.done()}) })}),
    });
}

// ---------- Line chart over a number axis ----------

pub const Line = struct { name: []const u8, ys: []const f32, s: u8 };
pub const XAxis = struct { x_name: []const u8 = "", share: bool = false };

pub fn finite(v: f32) bool {
    return !std.math.isNan(v) and !std.math.isInf(v);
}

/// Lines over real x values (steps, epochs, games), not evenly spaced points: chart.zig's
/// frame, each line in its colour, named under the plot
pub fn lineChart(h: *H, title: Text, xs: []const f32, lines: []const Line, o: XAxis) N {
    var x0: f32 = std.math.inf(f32);
    var x1: f32 = -std.math.inf(f32);
    for (xs) |x| if (finite(x)) {
        x0 = @min(x0, x);
        x1 = @max(x1, x);
    };
    var y0: f32 = std.math.inf(f32);
    var y1: f32 = -std.math.inf(f32);
    for (lines) |l| for (l.ys) |y| if (finite(y)) {
        y0 = @min(y0, y);
        y1 = @max(y1, y);
    };
    if (!(x1 >= x0) or !(y1 >= y0)) return .none;
    const ystep = chart.niceStep(if (y1 > y0) y1 - y0 else @max(@abs(y0), 1e-6), 4);
    const ylo = @floor(y0 / ystep) * ystep;
    const yhi = @max(@ceil(y1 / ystep) * ystep, ylo + ystep);
    const xs_ = chart.Scale{ .lo = x0, .hi = x1 };
    const ys_ = chart.Scale{ .lo = ylo, .hi = yhi };
    var yt: std.ArrayList(chart.Tick) = .empty;
    var v = ylo;
    var places: u4 = 0;
    while (places < 6 and ystep * std.math.pow(f32, 10, @floatFromInt(places)) < 0.999) places += 1;
    while (v <= yhi + ystep / 2) : (v += ystep) yt.append(h.mem, .{ .at = 100 - ys_.at(v), .label = .{ .s = fixedPlaces(h, v, places) } }) catch {};
    var xt: std.ArrayList(chart.Tick) = .empty;
    if (x1 > x0) {
        const xstep = chart.niceStep(x1 - x0, 4);
        var x = @ceil(x0 / xstep) * xstep;
        while (x <= x1) : (x += xstep) xt.append(h.mem, .{ .at = xs_.at(x), .label = .{ .s = if (o.share) h.fmt("{s}%", .{num(h, x)}) else num(h, x) } }) catch {};
    }
    var marks = h.list();
    var keys = h.list();
    for (lines, 0..) |l, k| {
        var d: std.ArrayList(u8) = .empty;
        var pen = false;
        for (xs, l.ys) |x, y| {
            if (!finite(x) or !finite(y)) {
                pen = false;
                continue;
            }
            d.print(h.mem, "{s}{s} {s}", .{ if (pen) "L" else "M", dec(h, xs_.at(x), 2), dec(h, 100 - ys_.at(y), 2) }) catch {};
            pen = true;
        }
        marks.add(h.path(.{ .key = k, .class = "ln", .data_s = l.s, .d = d.items }, .{}));
        keys.add(h.span(.{ .key = k, .data_s = l.s }, .{l.name}));
    }
    return card.view(h, .{}, &.{
        card.head(h, title, null, &.{}),
        chart.frame(h, .{ .label = title, .height = 160, .y = yt.items, .x = xt.items, .marks = marks.done() }),
        h.p(.{ .class = "keys" }, .{ keys.done(), if (o.x_name.len > 0) h.span(.{ .class = "xn" }, .{h.fmt("x: {s}", .{o.x_name})}) else null }),
    });
}

fn fixedPlaces(h: *H, v: f32, places: u4) []const u8 {
    return switch (places) {
        0 => dec(h, v, 0),
        1 => dec(h, v, 1),
        2 => dec(h, v, 2),
        3 => dec(h, v, 3),
        4 => dec(h, v, 4),
        else => dec(h, v, 5),
    };
}

pub const css =
    \\@layer components {
    \\  .c-adruns .runs { display: grid; gap: var(--sp-2); margin-top: var(--sp-2);
    \\    grid-template-columns: repeat(auto-fill, minmax(min(100%, 17rem), 1fr)); }
    \\  .c-adruns .run { display: grid; gap: var(--sp-1); align-content: start; text-align: start; padding: var(--sp-2) var(--sp-3);
    \\    border: 1px solid var(--line); border-radius: var(--r-m); background: none; color: var(--text); font: inherit; cursor: pointer; }
    \\  .c-adruns .run:hover { border-color: var(--line-2); }
    \\  .c-adruns .run[aria-selected="true"] { border-color: var(--accent); box-shadow: inset 0 0 0 1px var(--accent); }
    \\  .c-adruns .run .top { display: flex; justify-content: space-between; gap: var(--sp-2); overflow-wrap: anywhere; }
    \\  .c-adruns .run .finding { font-size: var(--fs-s); }
    \\  .c-adruns .warn { margin: var(--sp-2) 0 0; color: var(--bad); font-size: var(--fs-s); }
    \\  .c-adruns .args, .c-adruns .log { font-family: var(--mono, ui-monospace, monospace); font-size: var(--fs-xs);
    \\    overflow-wrap: anywhere; color: var(--muted); }
    \\  .c-adruns .log { white-space: pre-wrap; max-height: 28rem; overflow: auto; padding: var(--sp-2);
    \\    border: 1px solid var(--line); border-radius: var(--r-s); color: var(--text); }
    \\  .c-adruns .keys { display: flex; flex-wrap: wrap; gap: var(--sp-1) var(--sp-3); margin: var(--sp-2) 0 0; font-size: var(--fs-xs); color: var(--muted); }
    \\  .c-adruns .keys [data-s]::before { content: ""; display: inline-block; width: 0.8em; height: 2px; margin-inline-end: 0.3em;
    \\    vertical-align: middle; background: var(--s); }
    \\  .c-adruns [data-s="0"] { --s: var(--us); }
    \\  .c-adruns [data-s="1"] { --s: var(--drop); }
    \\  .c-adruns [data-s="2"] { --s: var(--gain); }
    \\  .c-adruns [data-s="3"] { --s: var(--accent); }
    \\  .c-adruns [data-s="4"] { --s: var(--turn); }
    \\  .c-adruns [data-s="5"] { --s: var(--them); }
    \\  .c-adruns .ln[data-s] { stroke: var(--s); }
    \\}
    \\
;

pub const Demo = struct {
    const now = ap.Demo.now;

    pub const training: md.Training = blk: {
        var t = am.Demo.training;
        t.campaigns = &al.Demo.campaigns;
        t.nn = &al.Demo.nn;
        var runs: [t.runs.len + 1]md.Run = undefined;
        @memcpy(runs[0..t.runs.len], t.runs);
        runs[t.runs.len] = .{ .run = "20261027T080000Z-gold14-screen", .state = .finished, .started = now - 120_000, .cat = .early, .target = "gold14", .lab = true, .res = .{ .kind = .screen, .features = 40, .clear = 3 } };
        const fixed = runs;
        t.runs = &fixed;
        break :blk t;
    };

    /// runs/<the early run>/metrics.bin
    pub const metrics: md.Metrics = .{
        .cols = &.{ "step", "train_loss", "test_loss" },
        .rows = &.{ &.{ 0, 0.71, 0.72 }, &.{ 100, 0.69, 0.70 }, &.{ 200, 0.684, 0.697 }, &.{ 400, 0.680, 0.696 } },
    };
    pub const log = "step 100 loss 0.69\nstep 200 loss 0.684\nRESULT run dev=-0.012±0.004\n";
    /// The run metrics and log are for (training.runs[2])
    pub const run = "20261027T101000Z-lanediff-a";

    fn island(v: View) Runs {
        return .{ .tab = .models, .cat = v, .now = now, .training = &training };
    }

    fn picked(v: View) Runs {
        var r = island(v);
        r.files = run;
        r.metrics = &metrics;
        r.log = log;
        return r;
    }
};

pub fn gallery(g: *Gallery) void {
    const a = g.h.mem;
    const states = [_][]const u8{ "all: a live run", "early: runs, one picked with curves", "lab runs, the gpu-box out of reach", "a run's files loading", "the lab view failed", "neural nets: hidden" };
    for (states, 0..) |caption, i| {
        const m = a.create(Runs) catch return;
        m.* = switch (i) {
            0 => Demo.island(.all),
            1 => Demo.picked(.early),
            2 => blk: {
                // The gpu-box not reached for 2 h: its runs may be out of date
                var x = Demo.island(.lab);
                x.now += 7_200;
                break :blk x;
            },
            3 => Demo.island(.early),
            4 => .{ .tab = .models, .cat = .items, .failed = true },
            else => .{ .tab = .models, .cat = .nn },
        };
        g.addFill(caption, m.view(g.h));
    }
}

const testing = std.testing;

fn render(a: std.mem.Allocator, m: *Runs) ![]const u8 {
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    const root = m.view(&h);
    try testing.expect(!h.oom);
    var out: std.Io.Writer.Allocating = .init(a);
    try @import("html.zig").write(&t, root, &out.writer);
    return out.written();
}

fn expectHas(s: []const u8, wants: []const []const u8) !void {
    for (wants) |w| if (std.mem.find(u8, s, w) == null) {
        std.debug.print("missing {s} in {s}\n", .{ w, s });
        return error.TestExpectedEqual;
    };
}

test "admin runs: a category's runs, the newest picked, its curves and log" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var m = Demo.picked(.early);
    try testing.expectEqualStrings(Demo.run, m.shown().?.run);
    const s = try render(a, &m);
    try expectHas(s, &.{
        "lanediff-a",
        "Predicts lane gold lead at 14 min better than champion averages: 1.2% (± 0.4) of the error removed on practice games. Typical miss 812 → 806 gold.",
        "Reference run for gold at 14 min: the baseline scored against itself.",
        "Checks and screens (1)",
        "Screened 40 candidate inputs for gold at 14 min: 3 clear of noise.",
        "aria-selected=\"true\"",
        "train_loss",
        "Metrics table (4 rows, newest first)",
        "RESULT run",
    });
    // One chart: train_loss and test_loss share "loss"
    try testing.expectEqual(1, std.mem.count(u8, s, "class=\"c-chart"));
    // Another run picked: its files are not these
    var ev: tree.Event = .{ .kind = .click, .text = "" };
    m.update(.{ .pick = 3 }, &ev);
    try testing.expectEqualStrings("20261026T090000Z-gold14-a-ref", m.shown().?.run);
    try expectHas(try render(a, &m), &.{"Loading"});
    // Win shows nothing here
    m.fromUrl(.{ .tab = .models, .cat = .win });
    try testing.expect(!m.shows());
}

test "admin runs: All's live runs, the lab's runs, none for the nets" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var m = Demo.island(.all);
    try expectHas(try render(a, &m), &.{ "Running now", "<b>items</b>" });
    m.cat = .lab;
    try expectHas(try render(a, &m), &.{ "Runs</h", "gold14-screen" });
    m.cat = .nn;
    try testing.expect(!m.shows());
}

test "admin runs: sentences for each kind of result" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    const base: md.Run = .{ .run = "x", .state = .finished, .target = "deaths15" };
    var r = base;
    r.res = .{ .kind = .run, .dev = .{ .mean = 0.02, .ci = 0.01 }, .select = .no_change };
    try testing.expectEqualStrings("Predicts deaths before 15 min worse than champion averages: error up 2.0% (± 1.0). Not better on the held-back selection games.", sentence(&h, &r));
    r.res = .{ .kind = .diagnose, .bias = .{ .mean = -0.012, .ci = 0.01 } };
    try testing.expectEqualStrings("Check of where the model is off for deaths before 15 min: overall bias −0.012 standard deviations.", sentence(&h, &r));
    r.res = .{ .kind = .preds, .rows = 12_000 };
    try testing.expectEqualStrings("Wrote 12,000 predictions for comparison.", sentence(&h, &r));
    r = base;
    r.last = "epoch 3";
    try testing.expectEqualStrings("epoch 3", sentence(&h, &r));
}
