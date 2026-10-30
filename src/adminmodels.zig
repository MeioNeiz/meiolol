//! The admin Models tab's files (ui/modelsdata.zig): models.bin from the box's eval
//! (generate() in admin.zig, each web round), and training.bin plus runs/<run>/metrics.bin
//! from the lab view deploy/lab-push.sh stages on the Mac (`meiolol admin --training DIR`).
//! Ports the old JS admin page's parsing (winReadings, runInfo, labResult, learnedByCat,
//! loadNn)
const std = @import("std");
const store = @import("store");
const date = @import("date.zig");
const ui = @import("ui");
const ad = ui.admindata;
const md = ui.modelsdata;
const prose = ui.prose;
const Io = std.Io;
const Allocator = std.mem.Allocator;

pub fn models(a: Allocator, now: i64, eval: []const ad.EvalRow, report_md: ?[]const u8, history: []const ad.HistoryRow) !md.Models {
    const report = try prose.parse(a, report_md orelse "");
    return .{
        .now = now,
        .eval = eval,
        .win = try win(a, report, report_md orelse ""),
        .report = report,
        .matches_per_day = perDay(history),
    };
}

/// Least squares slope of stored matches over the newest week, a day
fn perDay(history: []const ad.HistoryRow) ?f32 {
    if (history.len < 2) return null;
    const end = history[history.len - 1].time;
    var n: f64 = 0;
    var sx: f64 = 0;
    var sy: f64 = 0;
    var first: ?i64 = null;
    for (history) |r| if (r.time >= end - 7 * 86400) if (r.matches) |m| {
        if (first == null) first = r.time;
        n += 1;
        sx += @floatFromInt(r.time - end);
        sy += @floatFromInt(m);
    };
    if (n < 2 or end - first.? < 86400 / 5) return null;
    const mx = sx / n;
    const my = sy / n;
    var sxy: f64 = 0;
    var sxx: f64 = 0;
    for (history) |r| if (r.time >= end - 7 * 86400) if (r.matches) |m| {
        const dx = @as(f64, @floatFromInt(r.time - end)) - mx;
        sxy += dx * (@as(f64, @floatFromInt(m)) - my);
        sxx += dx * dx;
    };
    if (sxx == 0) return null;
    return @floatCast(sxy / sxx * 86400);
}

/// A line's text, its runs joined
fn plain(a: Allocator, l: prose.Line) ![]const u8 {
    if (l.len == 1) return l[0].s;
    var w: std.ArrayList(u8) = .empty;
    for (l) |r| try w.appendSlice(a, r.s);
    return w.items;
}

/// A pipe table with its cells as text
const Table = struct {
    head: []const []const u8,
    rows: []const []const []const u8,

    fn col(t: Table, name: []const u8) ?usize {
        for (t.head, 0..) |h, i| if (std.mem.eql(u8, h, name)) return i;
        return null;
    }

    /// The first column whose name holds `part`
    fn colWith(t: Table, part: []const u8) ?usize {
        for (t.head, 0..) |h, i| if (std.mem.find(u8, h, part) != null) return i;
        return null;
    }
};

fn at(row: []const []const u8, i: ?usize) []const u8 {
    const k = i orelse return "";
    return if (k < row.len) row[k] else "";
}

fn tableOf(a: Allocator, t: prose.Table) !Table {
    const head = try a.alloc([]const u8, t.head.len);
    for (t.head, head) |c, *h| h.* = try plain(a, c);
    const rows = try a.alloc([]const []const u8, t.rows.len);
    for (t.rows, rows) |r, *o| {
        const cells = try a.alloc([]const u8, r.len);
        for (r, cells) |c, *x| x.* = try plain(a, c);
        o.* = cells;
    }
    return .{ .head = head, .rows = rows };
}

/// The tables under the heading whose text starts with `title`, up to the next heading at
/// its level or above
fn tablesUnder(a: Allocator, d: prose.Doc, title: []const u8) ![]const Table {
    var out: std.ArrayList(Table) = .empty;
    var level: ?u8 = null;
    for (d.blocks) |b| switch (b) {
        .heading => |h| {
            if (level) |l| if (h.level <= l) break;
            if (std.mem.startsWith(u8, try plain(a, h.line), title)) level = h.level;
        },
        .table => |t| if (level != null) try out.append(a, try tableOf(a, t)),
        else => {},
    };
    return out.items;
}

/// The heading text starting with `title` (model.md's carry a date)
fn headingWith(a: Allocator, d: prose.Doc, title: []const u8) !?[]const u8 {
    for (d.blocks) |b| if (b == .heading) {
        const t = try plain(a, b.heading.line);
        if (std.mem.startsWith(u8, t, title)) return t;
    };
    return null;
}

/// The number a cell starts with: "55.7%", "0.6826", "3594195 (5 not candidates)"
fn num(s: []const u8) ?f32 {
    const t = std.mem.trim(u8, s, " ");
    var end: usize = 0;
    while (end < t.len and (std.ascii.isDigit(t[end]) or t[end] == '.' or t[end] == ',' or (end == 0 and (t[end] == '-' or t[end] == '+')))) end += 1;
    var buf: [32]u8 = undefined;
    var n: usize = 0;
    for (t[0..end]) |c| if (c != ',' and c != '+' and n < buf.len) {
        buf[n] = c;
        n += 1;
    };
    return std.fmt.parseFloat(f32, buf[0..n]) catch null;
}

/// "+0.0105 ± 0.0004", "-0.00310±0.00172"
fn pm(s: []const u8) ?md.Pm {
    const i = std.mem.find(u8, s, "±") orelse return null;
    return .{ .mean = num(s[0..i]) orelse return null, .ci = num(s[i + "±".len ..]) orelse return null };
}

fn win(a: Allocator, d: prose.Doc, src: []const u8) !?md.Win {
    const full = try tablesUnder(a, d, "Full draft, held-out games");
    if (full.len == 0 or full[0].head.len < 2) return null;
    const t = full[0];
    const ll = t.col("log loss");
    const acc = t.col("accuracy");
    const auc = t.col("AUC");
    const vs = t.head.len - 1;
    var ms: std.ArrayList(md.Model) = .empty;
    for (t.rows) |r| try ms.append(a, .{
        .label = at(r, 0),
        .ll = num(at(r, ll)) orelse continue,
        .acc = (num(at(r, acc)) orelse continue) / 100,
        .auc = num(at(r, auc)),
        .d = pm(at(r, vs)),
    });
    var w: md.Win = .{ .games = gamesIn(t.head[0]) orelse 0, .models = ms.items };
    for (ms.items, 0..) |m, i| {
        const k: u16 = @intCast(i);
        if (std.mem.find(u8, m.label, "base only") != null) w.base = k;
        if (std.mem.startsWith(u8, m.label, "current")) w.current = k;
    }
    w.shipped = w.current orelse best(ms.items, w, false);
    w.experiment = best(ms.items, w, true);
    if (w.experiment) |e| if (w.shipped == null or ms.items[e].ll >= ms.items[w.shipped.?].ll) {
        w.experiment = null;
    };
    for (full[1..]) |c| if (c.head.len > 0 and std.mem.eql(u8, c.head[0], "decile")) {
        var ds: std.ArrayList(md.Decile) = .empty;
        for (c.rows) |r| try ds.append(a, .{
            .predicted = num(at(r, c.col("mean predicted"))) orelse continue,
            .won = num(at(r, c.col("blue won"))) orelse continue,
            .games = @intFromFloat(num(at(r, c.col("games"))) orelse continue),
        });
        w.deciles = ds.items;
        break;
    };
    if ((try tablesUnder(a, d, "Pick metric")).len > 0) {
        const p = (try tablesUnder(a, d, "Pick metric"))[0];
        for (p.rows) |r| if (std.mem.startsWith(u8, at(r, 0), "current")) {
            const cell = at(r, p.colWith("top 10%"));
            const of = std.mem.find(u8, cell, "% of ") orelse break;
            w.picks = .{ .p = (num(cell[0..of]) orelse break) / 100, .n = @intFromFloat(num(cell[of + 5 ..]) orelse break) };
            break;
        };
    }
    w.curve = try curve(a, try tablesUnder(a, d, "Learning curve"));
    const exp = try tablesUnder(a, d, "Player experience");
    if (exp.len > 0) for (exp[0].rows) |r| {
        const e = exp[0];
        if (!std.mem.eql(u8, at(r, e.col("source")), "history") or std.mem.find(u8, at(r, e.col("players")), "user") == null) continue;
        var bins: std.ArrayList(f32) = .empty;
        var it = std.mem.tokenizeScalar(u8, at(r, e.col("effect per bin (pp)")), ' ');
        while (it.next()) |x| try bins.append(a, num(x) orelse continue);
        if (pm(at(r, e.col("difference")))) |x| w.experience = .{ .d = x, .bins = bins.items };
        break;
    };
    const gold = try tablesUnder(a, d, "Lane gold at 14 minutes");
    if (gold.len > 0) {
        const g = gold[0];
        var stacked: ?md.Model = null;
        var eb: ?md.Model = null;
        for (g.rows) |r| {
            const m: md.Model = .{ .label = at(r, 0), .ll = num(at(r, g.col("log loss"))) orelse continue, .acc = (num(at(r, g.col("accuracy"))) orelse continue) / 100 };
            if (std.mem.find(u8, m.label, "lane gold (stacked)") != null) stacked = m;
            if (std.mem.find(u8, m.label, "empirical") != null) eb = m;
        }
        if (stacked != null and eb != null) w.gold = .{ stacked.?, eb.? };
    }
    if (std.mem.find(u8, src, "Term weights")) |i| {
        const rest = src[i..];
        const colon = std.mem.findScalar(u8, rest, ':') orelse rest.len;
        const end = std.mem.findScalar(u8, rest, '\n') orelse rest.len;
        if (colon < end) {
            var it = std.mem.splitScalar(u8, rest[colon + 1 .. end], ',');
            while (it.next()) |pair| {
                var words = std.mem.tokenizeScalar(u8, pair, ' ');
                const k = words.next() orelse continue;
                const v = num(words.next() orelse continue) orelse continue;
                if (std.mem.eql(u8, k, "lane")) w.lane_weight = v;
                if (std.mem.eql(u8, k, "duo")) w.duo_weight = v;
            }
        }
    }
    return w;
}

/// "model (359420 games)"
fn gamesIn(head: []const u8) ?u32 {
    const i = std.mem.findScalar(u8, head, '(') orelse return null;
    return @intFromFloat(num(head[i + 1 ..]) orelse return null);
}

/// Lowest log loss among real models (no coin flip, blue side); `tried`: also not the
/// shipped one, the base or a previous model
fn best(ms: []const md.Model, w: md.Win, tried: bool) ?u16 {
    var out: ?u16 = null;
    for (ms, 0..) |m, i| {
        const k: u16 = @intCast(i);
        if (std.mem.find(u8, m.label, "coin") != null or std.mem.find(u8, m.label, "blue side") != null) continue;
        if (tried and (k == w.shipped or k == w.base or std.mem.startsWith(u8, m.label, "previous"))) continue;
        if (out == null or m.ll < ms[out.?].ll) out = k;
    }
    return out;
}

fn curve(a: Allocator, ts: []const Table) !?md.Curve {
    if (ts.len == 0 or ts[0].rows.len < 3) return null;
    const t = ts[0];
    var cols: std.ArrayList([]const u8) = .empty;
    var idx: std.ArrayList(usize) = .empty;
    for (t.head, 0..) |h, i| if (!std.mem.eql(u8, h, "train games") and std.mem.find(u8, h, "AUC") == null) {
        try cols.append(a, h);
        try idx.append(a, i);
    };
    var games: std.ArrayList(u32) = .empty;
    var ll: std.ArrayList([]const ?f32) = .empty;
    for (t.rows) |r| {
        try games.append(a, @intFromFloat(num(at(r, t.col("train games"))) orelse continue));
        const row = try a.alloc(?f32, idx.items.len);
        for (idx.items, row) |i, *x| x.* = num(at(r, i));
        try ll.append(a, row);
    }
    var c: md.Curve = .{ .cols = cols.items, .games = games.items, .ll = ll.items };
    // Slope of base only against log2 games over the largest four sizes
    const base = for (cols.items, 0..) |h, i| {
        if (std.mem.eql(u8, h, "base only")) break i;
    } else return c;
    const from = games.items.len -| 4;
    var n: f32 = 0;
    var sx: f32 = 0;
    var sy: f32 = 0;
    for (games.items[from..], ll.items[from..]) |g, row| if (row[base]) |y| {
        n += 1;
        sx += std.math.log2(@as(f32, @floatFromInt(g)));
        sy += y;
    };
    if (n < 2) return c;
    var sxy: f32 = 0;
    var sxx: f32 = 0;
    for (games.items[from..], ll.items[from..]) |g, row| if (row[base]) |y| {
        const dx = std.math.log2(@as(f32, @floatFromInt(g))) - sx / n;
        sxy += dx * (y - sy / n);
        sxx += dx * dx;
    };
    if (sxx > 0) c.per_doubling = -sxy / sxx;
    c.last = ll.items[ll.items.len - 1][base] orelse 0;
    return c;
}

// ---------- the lab view (training.bin) ----------

/// `meiolol admin --training DIR`: DIR as lab-push.sh stage() leaves it
/// No clock in its bytes: lab-push uploads the view whenever a file in it changed
pub fn training(gpa: Allocator, io: Io, dir_path: []const u8) !void {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    var dir = try Io.Dir.cwd().openDir(io, dir_path, .{});
    defer dir.close(io);
    const l: Lab = .{ .a = a, .io = io, .dir = dir };
    const t = try l.view();
    var bin: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, md.Training, t, &bin);
    try writeGz(gpa, io, dir, "training.bin", bin.items);
    for (t.runs) |r| if (r.metrics) {
        const m = try metrics(a, (try l.read(try runPath(a, r.run, "metrics.tsv"))).?);
        bin.clearRetainingCapacity();
        try ui.data.encode(a, md.Metrics, m, &bin);
        try writeGz(gpa, io, dir, try runPath(a, r.run, "metrics.bin"), bin.items);
    };
}

fn writeGz(gpa: Allocator, io: Io, dir: Io.Dir, path: []const u8, data: []const u8) !void {
    try dir.writeFile(io, .{ .sub_path = path, .data = data });
    const gz = try store.raw.compress(gpa, data);
    defer gpa.free(gz);
    var buf: [256]u8 = undefined;
    try dir.writeFile(io, .{ .sub_path = try std.fmt.bufPrint(&buf, "{s}.gz", .{path}), .data = gz });
}

fn runPath(a: Allocator, run: []const u8, file: []const u8) ![]const u8 {
    return std.fs.path.join(a, &.{ "runs", run, file });
}

/// TSV by header name
const Tsv = struct {
    head: []const []const u8,
    rows: []const []const []const u8,

    fn parse(a: Allocator, text: []const u8) !Tsv {
        var lines = std.mem.splitScalar(u8, text, '\n');
        const head = try cells(a, lines.first());
        var rows: std.ArrayList([]const []const u8) = .empty;
        while (lines.next()) |l| if (std.mem.trim(u8, l, " \r").len > 0) try rows.append(a, try cells(a, l));
        return .{ .head = head, .rows = rows.items };
    }

    fn cells(a: Allocator, line: []const u8) ![]const []const u8 {
        var out: std.ArrayList([]const u8) = .empty;
        var it = std.mem.splitScalar(u8, std.mem.trimEnd(u8, line, "\r"), '\t');
        while (it.next()) |c| try out.append(a, c);
        return out.items;
    }

    fn get(t: Tsv, row: []const []const u8, name: []const u8) []const u8 {
        for (t.head, 0..) |h, i| if (std.mem.eql(u8, h, name)) return if (i < row.len) row[i] else "";
        return "";
    }
};

const Lab = struct {
    a: Allocator,
    io: Io,
    dir: Io.Dir,

    /// null when missing
    fn read(l: Lab, path: []const u8) !?[]const u8 {
        return l.dir.readFileAlloc(l.io, path, l.a, .limited(16 << 20)) catch |e| switch (e) {
            error.FileNotFound => null,
            else => e,
        };
    }

    fn view(l: Lab) !md.Training {
        const a = l.a;
        const learned = try learnedOf(a, try l.read("learned.md") orelse "");
        var runs: std.ArrayList(md.Run) = .empty;
        const rt = try Tsv.parse(a, try l.read("runs.tsv") orelse "");
        var i = rt.rows.len;
        while (i > 0) {
            i -= 1;
            try runs.append(a, try l.run(rt, rt.rows[i]));
        }
        var gpu_seen: ?i64 = null;
        const hosts = try Tsv.parse(a, try l.read("hosts.tsv") orelse "");
        for (hosts.rows) |r| if (std.mem.eql(u8, hosts.get(r, "host"), "gpu-box")) {
            gpu_seen = std.fmt.parseInt(i64, hosts.get(r, "seen"), 10) catch null;
        };
        return .{
            .gpu_seen = gpu_seen,
            .runs = runs.items,
            .learned = learned,
            .campaigns = try l.campaigns(runs.items),
            .team = try teamEffects(a, try prose.parse(a, try l.read("model.md") orelse "")),
            .nn = try l.nn(learned),
        };
    }

    fn run(l: Lab, t: Tsv, row: []const []const u8) !md.Run {
        const a = l.a;
        const name = t.get(row, "run");
        const state = t.get(row, "state");
        const args = t.get(row, "args");
        var r: md.Run = .{
            .run = name,
            .state = .other,
            .started = iso(t.get(row, "started")),
            .ended = iso(t.get(row, "ended")),
            .args = args,
            .head = t.get(row, "head"),
            .dirty = t.get(row, "dirty"),
            .last = t.get(row, "last"),
            .host = if (std.mem.eql(u8, t.get(row, "host"), "gpu-box")) .gpu_box else .mac,
        };
        if (std.mem.startsWith(u8, state, "exit ")) {
            r.code = std.fmt.parseInt(i32, state[5..], 10) catch -1;
            r.state = if (r.code == 0) .finished else .failed;
        } else r.state = std.meta.stringToEnum(md.State, state) orelse .other;

        var words: std.ArrayList([]const u8) = .empty;
        var it = std.mem.tokenizeAny(u8, args, " \t");
        while (it.next()) |w| try words.append(a, w);
        const w = words.items;
        const lab = w.len > 4 and std.mem.eql(u8, w[0], "exp");
        r.lab = lab;
        r.synthetic = w.len > 0 and std.mem.eql(u8, w[0], "train-demo");
        var target: []const u8 = "";
        var campaign: []const u8 = if (lab) w[3] else "";
        if (lab) target = w[4];
        if (labResult(r.last)) |res| {
            r.res = res.res;
            if (res.target.len > 0) target = res.target;
        }
        if (target.len == 0) for (w) |x| if (outcome(x)) {
            target = x;
            break;
        };

        const res_tsv = try Tsv.parse(a, try l.read(try runPath(a, name, "result.tsv")) orelse "");
        const fin_tsv = try Tsv.parse(a, try l.read(try runPath(a, name, "findings.tsv")) orelse "");
        var category: []const u8 = "";
        var effect_names: std.ArrayList([]const u8) = .empty;
        if (res_tsv.rows.len > 0) {
            const x = res_tsv.rows[0];
            const g = struct {
                fn f(s: []const u8) ?f32 {
                    return if (s.len == 0) null else std.fmt.parseFloat(f32, s) catch null;
                }
            }.f;
            const unit = res_tsv.get(x, "unit");
            r.result = .{
                .removed = if (g(res_tsv.get(x, "removed_pct"))) |p| (if (g(res_tsv.get(x, "removed_half"))) |h| md.Pm{ .mean = p, .ci = h } else null) else null,
                .err_base = g(res_tsv.get(x, "err_base")),
                .err_cand = g(res_tsv.get(x, "err_cand")),
                .unit = if (std.mem.eql(u8, unit, "-")) "" else unit,
                .select = selectOf(res_tsv.get(x, "select")),
            };
            category = res_tsv.get(x, "category");
            if (target.len == 0) target = res_tsv.get(x, "target");
            if (campaign.len == 0) campaign = res_tsv.get(x, "campaign");
            var es = std.mem.splitScalar(u8, res_tsv.get(x, "effects"), ',');
            while (es.next()) |e| try addName(a, &effect_names, e);
        }
        for (fin_tsv.rows) |x| try addName(a, &effect_names, fin_tsv.get(x, "effect_file"));
        var effects: std.ArrayList(md.Effect) = .empty;
        for (effect_names.items) |e| if (try l.read(try runPath(a, name, e))) |text| {
            try effects.append(a, try effectOf(a, e, text));
        };
        var findings: std.ArrayList(md.Finding) = .empty;
        for (fin_tsv.rows) |x| {
            const text = fin_tsv.get(x, "finding");
            if (text.len == 0) continue;
            const file = std.fs.path.basename(fin_tsv.get(x, "effect_file"));
            var effect: ?u16 = null;
            for (effects.items, 0..) |e, k| if (std.mem.eql(u8, e.name, file)) {
                effect = @intCast(k);
            };
            try findings.append(a, .{ .campaign = fin_tsv.get(x, "campaign"), .text = text, .effect = effect });
        }
        r.findings = findings.items;
        r.effects = effects.items;
        r.target = target;
        r.campaign = campaign;
        r.cat = if (std.mem.eql(u8, target, "win")) .win else if (outcome(target)) .early else null;
        if (r.cat == null) {
            const first = if (w.len > 0) w[0] else "";
            for ([_][]const u8{ "enemy", "outcomes", "fm", "pairs", "team" }) |p| if (std.mem.startsWith(u8, first, p)) {
                r.cat = .early;
            };
        }
        if (r.cat == null) {
            for ([_]struct { []const u8, md.Cat }{ .{ "item", .items }, .{ "objective", .objectives }, .{ "playstyle", .playstyle } }) |p| if (r.cat == null and std.mem.find(u8, args, p[0]) != null) {
                r.cat = p[1];
            };
        }
        if (std.meta.stringToEnum(md.Cat, category)) |c| r.cat = c;
        r.metrics = try l.read(try runPath(a, name, "metrics.tsv")) != null;
        return r;
    }

    fn campaigns(l: Lab, runs: []const md.Run) ![]const md.Campaign {
        const a = l.a;
        var out: std.ArrayList(md.Campaign) = .empty;
        var names = std.mem.tokenizeAny(u8, try l.read("campaigns.txt") orelse "", "\r\n");
        while (names.next()) |name| {
            const hyp = try Tsv.parse(a, try l.read(try std.fs.path.join(a, &.{ "campaigns", name, "hypotheses.tsv" })) orelse "");
            var ids: std.StringArrayHashMapUnmanaged(void) = .empty;
            var new_best: u32 = 0;
            for (runs) |r| if (std.mem.eql(u8, r.campaign, name)) {
                try ids.put(a, r.run, {});
                if (r.res) |x| new_best += @intFromBool(x.select == .new_best);
            };
            var hyps: std.ArrayList(md.Hyp) = .empty;
            for (hyp.rows) |x| {
                const text = hyp.get(x, "hypothesis");
                const word = hyp.get(x, "status");
                var lower: [16]u8 = undefined;
                const status: md.HypStatus = if (std.ascii.startsWithIgnoreCase(text, "reference")) .reference else if (word.len <= lower.len)
                    std.meta.stringToEnum(md.HypStatus, std.ascii.lowerString(&lower, word)) orelse .other
                else
                    .other;
                try hyps.append(a, .{ .id = hyp.get(x, "id"), .status = status, .word = word, .text = text });
                var rs = std.mem.splitScalar(u8, hyp.get(x, "runs"), ',');
                while (rs.next()) |id| {
                    const t = std.mem.trim(u8, id, " ");
                    if (t.len > 0 and !std.mem.eql(u8, t, "-")) try ids.put(a, t, {});
                }
            }
            const digest = try l.read(try std.fs.path.join(a, &.{ "campaigns", name, "digest.md" }));
            try out.append(a, .{
                .name = name,
                .runs = @intCast(ids.count()),
                .new_best = new_best,
                .hyps = hyps.items,
                .digest = if (digest != null and hasBody(digest.?)) try prose.parse(a, digest.?) else null,
            });
        }
        return out.items;
    }

    fn nn(l: Lab, learned: []const md.Learned) ![]const md.NnFile {
        const a = l.a;
        var out: std.ArrayList(md.NnFile) = .empty;
        var names = std.mem.tokenizeAny(u8, try l.read("nn.txt") orelse "", "\r\n");
        while (names.next()) |file| {
            const text = try l.read(try std.fs.path.join(a, &.{ "nn", file })) orelse continue;
            var title: []const u8 = "";
            var body: std.ArrayList(u8) = .empty;
            var lines = std.mem.splitScalar(u8, text, '\n');
            while (lines.next()) |line| {
                if (std.mem.startsWith(u8, line, "#")) {
                    const t = std.mem.trim(u8, line[1..], " \r");
                    if (std.mem.startsWith(u8, t, "title:")) title = std.mem.trim(u8, t[6..], " ");
                    continue;
                }
                try body.appendSlice(a, line);
                try body.append(a, '\n');
            }
            const t = try Tsv.parse(a, body.items);
            var rows: std.ArrayList(md.NnRow) = .empty;
            for (t.rows) |x| {
                const model = t.get(x, "model");
                const diff = opt(f32, t.get(x, "diff")) orelse continue;
                if (model.len == 0) continue;
                const key = std.mem.trim(u8, t.get(x, "learned"), " ");
                var ls: std.ArrayList(u16) = .empty;
                if (key.len > 0) for (learned, 0..) |item, k| if (std.mem.startsWith(u8, try plain(a, item.line), key)) try ls.append(a, @intCast(k));
                try rows.append(a, .{
                    .model = model,
                    .vs = t.get(x, "vs"),
                    .block = t.get(x, "block"),
                    .diff = diff,
                    .ci = opt(f32, t.get(x, "ci")),
                    .seeds = opt(u32, t.get(x, "seeds")),
                    .seed_lo = opt(f32, t.get(x, "seed_lo")),
                    .seed_hi = opt(f32, t.get(x, "seed_hi")),
                    .games = opt(u64, t.get(x, "games")),
                    .fit_games = t.get(x, "fit_games"),
                    .source = t.get(x, "source"),
                    .note = t.get(x, "note"),
                    .learned = ls.items,
                });
            }
            const key = if (std.mem.endsWith(u8, file, ".tsv")) file[0 .. file.len - 4] else file;
            try out.append(a, .{ .key = key, .title = if (title.len > 0) title else key, .rows = rows.items });
        }
        return out.items;
    }
};

fn opt(comptime T: type, s: []const u8) ?T {
    const t = std.mem.trim(u8, s, " ");
    if (t.len == 0) return null;
    return switch (@typeInfo(T)) {
        .float => std.fmt.parseFloat(T, t) catch null,
        else => std.fmt.parseInt(T, t, 10) catch null,
    };
}

/// A digest with more than headings and its "What worked" line
fn hasBody(text: []const u8) bool {
    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |l| {
        const t = std.mem.trim(u8, l, " \r");
        if (t.len > 0 and t[0] != '#' and !std.mem.startsWith(u8, t, "What worked")) return true;
    }
    return false;
}

fn addName(a: Allocator, names: *std.ArrayList([]const u8), raw: []const u8) !void {
    const n = std.fs.path.basename(std.mem.trim(u8, raw, " "));
    if (n.len == 0 or std.mem.eql(u8, n, "-")) return;
    for (names.items) |x| if (std.mem.eql(u8, x, n)) return;
    try names.append(a, n);
}

/// The lab's targets besides win (CAT_OF_TARGET: all early game)
fn outcome(s: []const u8) bool {
    for ([_][]const u8{ "win", "gold14", "lanediff14", "cs10", "deaths15", "first_item" }) |o| if (std.mem.eql(u8, s, o)) return true;
    return false;
}

fn selectOf(s: []const u8) md.Select {
    if (std.mem.eql(u8, s, "new-best")) return .new_best;
    if (std.mem.eql(u8, s, "no-change")) return .no_change;
    return .none;
}

/// "2026-10-18T09:09:54Z"
fn iso(s: []const u8) ?i64 {
    if (s.len < 19 or s[10] != 'T') return null;
    const d = date.Date.parse(s[0..10]) orelse return null;
    const hh = std.fmt.parseInt(i64, s[11..13], 10) catch return null;
    const mm = std.fmt.parseInt(i64, s[14..16], 10) catch return null;
    const ss = std.fmt.parseInt(i64, s[17..19], 10) catch return null;
    return d.toDay() * 86400 + hh * 3600 + mm * 60 + ss;
}

/// meiolol-lab's RESULT line: "run=NAME target=win dev=-0.00310±0.00172 ... (beats
/// baseline) select=-"; kind is its first word
fn labResult(last: []const u8) ?struct { res: md.LabResult, target: []const u8 } {
    var end: usize = 0;
    while (end < last.len and (std.ascii.isAlphanumeric(last[end]) or last[end] == '_')) end += 1;
    if (end == 0 or end == last.len or (last[end] != ' ' and last[end] != '=')) return null;
    var r: md.LabResult = .{ .kind = std.meta.stringToEnum(md.Kind, last[0..end]) orelse .other };
    var target: []const u8 = "";
    var it = std.mem.tokenizeScalar(u8, last, ' ');
    while (it.next()) |w| {
        const eq = std.mem.findScalar(u8, w, '=') orelse continue;
        const k = w[0..eq];
        const v = w[eq + 1 ..];
        if (std.mem.eql(u8, k, "dev")) r.dev = pm(v);
        if (std.mem.eql(u8, k, "bias")) r.bias = pm(v);
        if (std.mem.eql(u8, k, "select")) r.select = selectOf(v);
        if (std.mem.eql(u8, k, "features")) r.features = opt(u32, v);
        if (std.mem.eql(u8, k, "clear")) r.clear = opt(u32, v);
        if (std.mem.eql(u8, k, "rows")) r.rows = opt(u64, v);
        if (std.mem.eql(u8, k, "target")) target = v;
    }
    return .{ .res = r, .target = target };
}

fn effectOf(a: Allocator, name: []const u8, text: []const u8) !md.Effect {
    var e: md.Effect = .{ .name = name, .title = name, .unit = "", .higher = "", .rows = &.{} };
    var body = text;
    if (std.mem.startsWith(u8, text, "#")) {
        const nl = std.mem.findScalar(u8, text, '\n') orelse text.len;
        var parts = std.mem.splitScalar(u8, text[1..nl], '|');
        const t = std.mem.trim(u8, parts.next() orelse "", " \r");
        if (t.len > 0) e.title = t;
        e.unit = std.mem.trim(u8, parts.next() orelse "", " \r");
        if (std.mem.eql(u8, e.unit, "-")) e.unit = "";
        e.higher = std.mem.trim(u8, parts.next() orelse "", " \r");
        body = text[@min(nl + 1, text.len)..];
    }
    const t = try Tsv.parse(a, body);
    var rows: std.ArrayList(md.EffectRow) = .empty;
    for (t.rows) |x| try rows.append(a, .{
        .label = t.get(x, "label"),
        .value = opt(f32, t.get(x, "effect")) orelse continue,
        .ci = opt(f32, t.get(x, "ci")) orelse 0,
        .n = opt(u32, t.get(x, "n")),
    });
    e.rows = rows.items;
    return e;
}

/// learned.md's items under a category heading, in the doc's order
fn learnedOf(a: Allocator, text: []const u8) ![]const md.Learned {
    const d = try prose.parse(a, text);
    var out: std.ArrayList(md.Learned) = .empty;
    var cat: ?md.Cat = null;
    for (d.blocks) |b| switch (b) {
        .heading => |h| if (h.level <= 2) {
            cat = catOf(try plain(a, h.line));
        },
        .list => |items| if (cat) |c| for (items) |it| {
            try out.append(a, .{ .cat = c, .line = it.line, .short = try firstSentence(a, it.line) });
        },
        else => {},
    };
    return out.items;
}

fn catOf(heading: []const u8) ?md.Cat {
    for ([_]struct { []const u8, md.Cat }{
        .{ "win", .win },
        .{ "early game", .early },
        .{ "items", .items },
        .{ "objectives", .objectives },
        .{ "playstyle", .playstyle },
        .{ "player", .player },
        .{ "data quality", .data },
    }) |p| if (std.ascii.eqlIgnoreCase(std.mem.trim(u8, heading, " "), p[0])) return p[1];
    return null;
}

/// Up to the ". " before the evidence (Evidence, Sure, Site, Use, Models), ending in "."
fn firstSentence(a: Allocator, l: prose.Line) !prose.Line {
    const text = try plain(a, l);
    var cut: ?usize = null;
    var i: usize = 0;
    while (std.mem.findPos(u8, text, i, ". ")) |k| : (i = k + 2) {
        for ([_][]const u8{ "Evidence", "Sure", "Site", "Use", "Models" }) |w| if (std.mem.startsWith(u8, text[k + 2 ..], w)) {
            cut = k + 1;
        };
        if (cut != null) break;
    }
    const n = cut orelse return l;
    var out: std.ArrayList(prose.Run) = .empty;
    var pos: usize = 0;
    for (l) |r| {
        if (pos >= n) break;
        const take = @min(r.s.len, n - pos);
        try out.append(a, .{ .kind = r.kind, .s = r.s[0..take] });
        pos += r.s.len;
    }
    return out.items;
}

fn teamEffects(a: Allocator, d: prose.Doc) !?md.TeamEffects {
    const title = try headingWith(a, d, "Team effects on early outcomes") orelse return null;
    const ts = try tablesUnder(a, d, title);
    const t = for (ts) |t| {
        if (t.head.len > 1 and std.mem.eql(u8, t.head[0], "step")) break t;
    } else return null;
    var steps: std.ArrayList([]const u8) = .empty;
    var cells: std.ArrayList([]const ?md.Pm) = .empty;
    var total: []const ?md.Pm = &.{};
    for (t.rows) |r| {
        const row = try a.alloc(?md.Pm, t.head.len - 1);
        for (row, 1..) |*c, i| c.* = pm(at(r, i));
        const step = at(r, 0);
        if (std.mem.startsWith(u8, step, "total")) {
            total = row;
            continue;
        }
        try steps.append(a, if (std.mem.startsWith(u8, step, "+ ")) step[2..] else step);
        try cells.append(a, row);
    }
    return .{ .title = title, .outcomes = t.head[1..], .steps = steps.items, .cells = cells.items, .total = total };
}

fn metrics(a: Allocator, text: []const u8) !md.Metrics {
    const t = try Tsv.parse(a, text);
    var rows: std.ArrayList([]const f32) = .empty;
    for (t.rows) |x| {
        const row = try a.alloc(f32, t.head.len);
        for (row, 0..) |*v, i| v.* = opt(f32, if (i < x.len) x[i] else "") orelse std.math.nan(f32);
        if (std.math.isNan(row[0])) continue;
        try rows.append(a, row);
    }
    return .{ .cols = t.head, .rows = rows.items };
}

const testing = std.testing;

const report_fixture =
    \\# meiolol eval
    \\
    \\## Tuning (5-fold inside train)
    \\
    \\Best: base 50, pairs 3200 (out-of-fold 0.6852). Term weights on those out-of-fold drafts (in-sample 0.6849): intercept 0.034, base 0.988, duo 0.797, lane 1.643, matchup 0.988
    \\
    \\## Full draft, held-out games
    \\
    \\| model (359,420 games) | log loss | Brier | AUC | accuracy | log loss vs current model (additive v2) |
    \\| --- | --- | --- | --- | --- | --- |
    \\| coin flip (50%) | 0.6931 | 0.2500 | 0.500 | 50.0% | +0.0105 ± 0.0004 |
    \\| champion base only | 0.6882 | 0.2475 | 0.556 | 53.9% | +0.0056 ± 0.0003 |
    \\| current model (additive v2) | 0.6826 | 0.2448 | 0.582 | 55.7% | - |
    \\| previous model (1000/1000) | 0.6814 | 0.2462 | 0.572 | 55.0% | -0.0012 ± 0.0002 |
    \\| tuned + term weights | 0.6820 | 0.2456 | 0.574 | 55.9% | -0.0006 ± 0.0002 |
    \\
    \\| decile | games | mean predicted | blue won |
    \\| --- | --- | --- | --- |
    \\| 1 | 35942 | 38.7% | 38.5% |
    \\| 2 | 35942 | 60.7% | 61.6% |
    \\
    \\## Pick metric
    \\
    \\| model | picks ranked | win rate, picks in model's top 10% |
    \\| --- | --- | --- |
    \\| current model (additive v2) | 3594195 (5 not candidates) | 53.4% of 824045 |
    \\
    \\## Learning curve
    \\
    \\| train games | base only | empirical Bayes | AUC (EB) |
    \\| --- | --- | --- | --- |
    \\| 1000 | 0.6950 | 0.6931 | 0.509 |
    \\| 2000 | 0.6940 | 0.6931 | 0.509 |
    \\| 4000 | 0.6930 | 0.6920 | 0.509 |
    \\| 8000 | 0.6920 | 0.6910 | 0.509 |
    \\
    \\## Player experience
    \\
    \\| source | players | difference | effect per bin (pp) |
    \\| --- | --- | --- | --- |
    \\| history | all known | -0.0003 ± 0.0002 | 0.5 2.6 |
    \\| history | user only | -0.0002 ± 0.0001 | 0.9 3.1 |
    \\
    \\## Lane gold at 14 minutes
    \\
    \\| model (218731 games) | log loss | accuracy |
    \\| --- | --- | --- |
    \\| empirical-Bayes priors | 0.6843 | 55.2% |
    \\| EB + lane gold (stacked) | 0.6855 | 54.8% |
;

test "models.bin: the eval report's numbers for the Win view" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const hist = [_]ad.HistoryRow{ .{ .time = 0, .matches = 100 }, .{ .time = 43200, .matches = 150 }, .{ .time = 86400, .matches = 200 } };
    const m = try models(a, 86400, &.{}, report_fixture, &hist);
    try testing.expectApproxEqAbs(@as(f32, 100), m.matches_per_day.?, 1e-3);
    const w = m.win.?;
    try testing.expectEqual(359420, w.games);
    try testing.expectEqual(5, w.models.len);
    try testing.expectEqual(@as(?u16, 2), w.current);
    try testing.expectEqual(@as(?u16, 2), w.shipped);
    try testing.expectEqual(@as(?u16, 1), w.base);
    // previous models never count as the experiment, however good
    try testing.expectEqual(@as(?u16, 4), w.experiment);
    try testing.expectApproxEqAbs(@as(f32, 0.557), w.models[2].acc, 1e-6);
    try testing.expectEqual(@as(?md.Pm, null), w.models[2].d);
    try testing.expectApproxEqAbs(@as(f32, -0.0006), w.models[4].d.?.mean, 1e-7);
    try testing.expectEqual(2, w.deciles.len);
    try testing.expectEqual(35942, w.deciles[1].games);
    try testing.expectApproxEqAbs(@as(f32, 0.534), w.picks.?.p, 1e-6);
    try testing.expectEqual(824045, w.picks.?.n);
    const c = w.curve.?;
    try testing.expectEqual(2, c.cols.len);
    try testing.expectEqual(8000, c.games[3]);
    try testing.expectApproxEqAbs(@as(f32, 0.001), c.per_doubling.?, 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 0.692), c.last, 1e-6);
    try testing.expectApproxEqAbs(@as(f32, -0.0002), w.experience.?.d.mean, 1e-7);
    try testing.expectEqual(2, w.experience.?.bins.len);
    try testing.expectApproxEqAbs(@as(f32, 0.548), w.gold.?[0].acc, 1e-6);
    try testing.expectApproxEqAbs(@as(f32, 1.643), w.lane_weight.?, 1e-6);
    try testing.expectApproxEqAbs(@as(f32, 0.797), w.duo_weight.?, 1e-6);
    // No report yet: no Win, an empty doc
    const none = try models(a, 0, &.{}, null, &.{});
    try testing.expectEqual(null, none.win);
    try testing.expectEqual(null, none.matches_per_day);
}

test "lab result lines and learned items" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const r = labResult("run=20261024T001511Z-golden scope=champ_select target=win dev=-0.00310±0.00172 n=85000 (beats baseline) select=new-best").?;
    try testing.expectEqual(md.Kind.run, r.res.kind);
    try testing.expectEqualStrings("win", r.target);
    try testing.expectApproxEqAbs(@as(f32, 0.00172), r.res.dev.?.ci, 1e-7);
    try testing.expectEqual(md.Select.new_best, r.res.select);
    try testing.expectEqual(md.Kind.screen, labResult("screen target=gold14 features=40 clear=3").?.res.kind);
    try testing.expectEqual(null, labResult("done"));
    try testing.expectEqual(1793224539, iso("2026-10-28T21:55:39Z").?);

    const ls = try learnedOf(a,
        \\# What we have learnt
        \\
        \\- An intro item, under no category
        \\
        \\## Win
        \\
        \\- A counter is about the **two champions**. Sure: beats it. Site: live
        \\  for the helper.
        \\- Duos add little. Evidence: docs/model.md
        \\
        \\## Early game
        \\
        \\- Lane gold is mostly the champions
    );
    try testing.expectEqual(3, ls.len);
    try testing.expectEqual(md.Cat.win, ls[0].cat);
    try testing.expectEqualStrings("A counter is about the two champions. Sure: beats it. Site: live for the helper.", try plain(a, ls[0].line));
    try testing.expectEqualStrings("A counter is about the two champions.", try plain(a, ls[0].short));
    try testing.expectEqual(.bold, ls[0].short[1].kind);
    try testing.expectEqualStrings("two champions", ls[0].short[1].s);
    try testing.expectEqualStrings("Duos add little.", try plain(a, ls[1].short));
    try testing.expectEqual(md.Cat.early, ls[2].cat);
    try testing.expectEqualStrings("Lane gold is mostly the champions", try plain(a, ls[2].short));
}

test "training.bin from a staged lab view" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const files = [_][2][]const u8{
        .{ "runs.tsv", "run\tstate\tstarted\tended\targs\thead\tdirty\tlast\thost\tfindings\n" ++
            "20261012T2222Z-gold14-a-ref\texit 0\t2026-10-12T22:22:00Z\t\texp run SNAP gold14-a gold14\tabc\t0 files\trun=x target=gold14 dev=0.00000±0.00000 (reference)\tmac\t\n" ++
            "20261024T001511Z-golden\texit 1\t2026-10-24T00:15:11Z\t\texp run SNAP golden win\tdef\t0 files\trun=y target=win dev=-0.00310±0.00172 select=new-best\tgpu-box\tresult.tsv\n" ++
            "20261025T000000Z-items\trunning\t2026-10-25T00:00:00Z\t\titem-paths SNAP\tdef\t0 files\tstep 3\tmac\t\n" },
        .{ "runs/20261024T001511Z-golden/result.tsv", "run\tcampaign\ttarget\tselect\tcategory\tremoved_pct\tremoved_half\terr_base\terr_cand\tunit\teffects\n" ++
            "20261024T001511Z-golden\tgolden\twin\t-\twin\t0.447\t0.249\t51.2\t53.7\t% right\teffects-comp.tsv\n" },
        .{ "runs/20261024T001511Z-golden/findings.tsv", "campaign\tfinding\teffect_file\ngolden\tComps matter a little\truns/x/effects-comp.tsv\n" },
        .{ "runs/20261024T001511Z-golden/effects-comp.tsv", "# Comp terms | log loss | more wins\nlabel\teffect\tci\tn\nengage\t0.01\t0.005\t900\nbad\tx\t1\t1\n" },
        .{ "runs/20261025T000000Z-items/metrics.tsv", "step\ttrain_loss\ttest_loss\n1\t0.7\t0.71\n2\t0.69\t\nx\t1\t1\n" },
        .{ "hosts.tsv", "host\tseen\ngpu-box\t1793224200\n" },
        .{ "learned.md", "## Win\n\n- A neural network now predicts the winner. Evidence: nets\n" },
        .{ "model.md", "## Results\n\n### Team effects on early outcomes, 2026-10-12 (3c)\n\n| step | gold14 | cs10 |\n| --- | --- | --- |\n| champion | 1.0 ± 0.2 | 2.0 ± 0.1 |\n| + lane opponent | 0.1 ± 0.2 | - |\n| total | 1.1 ± 0.3 | 2.0 ± 0.1 |\n" },
        .{ "campaigns.txt", "gold14-a\n" },
        .{ "campaigns/gold14-a/hypotheses.tsv", "id\tstatus\truns\thypothesis\nH0\tconfirmed\t20261012T2222Z-gold14-a-ref\treference: unchanged\nH1\tParked\tr1, r2\tpatch term\n" },
        .{ "campaigns/gold14-a/digest.md", "# gold14-a digest\n\nWhat worked\n" },
        .{ "nn.txt", "nets.tsv\n" },
        .{ "nn/nets.tsv", "# title: Do nets beat today's model?\nmodel\tvs\tblock\tdiff\tci\tseeds\tlearned\nset net\twin-draft\tfolds\t-0.00078\t0.00012\t3\tA neural network now\nbroken\twin-draft\tfolds\t\t\t\t\n" },
    };
    for (files) |f| {
        if (std.fs.path.dirname(f[0])) |d| try tmp.dir.createDirPath(io, d);
        try tmp.dir.writeFile(io, .{ .sub_path = f[0], .data = f[1] });
    }
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = buf[0..try tmp.dir.realPath(io, &buf)];
    try training(testing.allocator, io, path);

    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const bin = try tmp.dir.readFileAlloc(io, "training.bin", a, .limited(1 << 20));
    const t = try ui.data.decode(a, md.Training, bin);
    // Same files, same bytes: lab-push uploads only on a change
    try training(testing.allocator, io, path);
    try testing.expectEqualSlices(u8, bin, try tmp.dir.readFileAlloc(io, "training.bin", a, .limited(1 << 20)));
    try testing.expectEqual(@as(?i64, 1793224200), t.gpu_seen);
    try testing.expectEqual(3, t.runs.len);
    // Newest first
    const items = t.runs[0];
    try testing.expectEqual(md.State.running, items.state);
    try testing.expectEqual(@as(?md.Cat, .items), items.cat);
    try testing.expect(items.metrics);
    const golden = t.runs[1];
    try testing.expectEqual(md.State.failed, golden.state);
    try testing.expectEqual(1, golden.code);
    try testing.expectEqual(md.Host.gpu_box, golden.host);
    try testing.expectEqual(@as(?md.Cat, .win), golden.cat);
    try testing.expect(golden.lab);
    try testing.expectEqualStrings("golden", golden.campaign);
    try testing.expectEqual(md.Select.new_best, golden.res.?.select);
    try testing.expectApproxEqAbs(@as(f32, 0.447), golden.result.?.removed.?.mean, 1e-6);
    try testing.expectEqualStrings("% right", golden.result.?.unit);
    try testing.expectEqual(1, golden.effects.len);
    try testing.expectEqualStrings("Comp terms", golden.effects[0].title);
    try testing.expectEqualStrings("more wins", golden.effects[0].higher);
    try testing.expectEqual(1, golden.effects[0].rows.len);
    try testing.expectEqual(@as(?u16, 0), golden.findings[0].effect);
    const ref = t.runs[2];
    try testing.expectEqual(@as(?md.Cat, .early), ref.cat);
    try testing.expectEqualStrings("gold14", ref.target);
    try testing.expectEqual(@as(f32, 0), ref.res.?.dev.?.ci);
    try testing.expectEqual(iso("2026-10-12T22:22:00Z"), ref.started);

    try testing.expectEqual(1, t.learned.len);
    try testing.expectEqual(1, t.campaigns.len);
    const c = t.campaigns[0];
    // ref (tagged and named) plus r1 and r2
    try testing.expectEqual(3, c.runs);
    try testing.expectEqual(md.HypStatus.reference, c.hyps[0].status);
    try testing.expectEqual(md.HypStatus.parked, c.hyps[1].status);
    try testing.expectEqual(null, c.digest);
    const te = t.team.?;
    try testing.expectEqual(2, te.outcomes.len);
    try testing.expectEqualStrings("lane opponent", te.steps[1]);
    try testing.expectEqual(null, te.cells[1][1]);
    try testing.expectApproxEqAbs(@as(f32, 1.1), te.total[0].?.mean, 1e-6);
    try testing.expectEqual(1, t.nn.len);
    try testing.expectEqualStrings("nets", t.nn[0].key);
    try testing.expectEqualStrings("Do nets beat today's model?", t.nn[0].title);
    try testing.expectEqual(1, t.nn[0].rows.len);
    try testing.expectEqualSlices(u16, &.{0}, t.nn[0].rows[0].learned);

    const mb = try tmp.dir.readFileAlloc(io, "runs/20261025T000000Z-items/metrics.bin", a, .limited(1 << 20));
    const m = try ui.data.decode(a, md.Metrics, mb);
    try testing.expectEqual(3, m.cols.len);
    try testing.expectEqual(2, m.rows.len);
    try testing.expect(std.math.isNan(m.rows[1][2]));
}
