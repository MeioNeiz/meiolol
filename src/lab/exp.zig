//! `meiolol-lab exp`: one lab-agent run of the candidate compiled in (-Dcand, docs/
//! lab-agent.md). Runs in a deploy/lab-run.sh run dir, which gets summary.md, dev.tsv,
//! result.tsv (the run's runs.tsv row) and the candidate's effects-<name>.tsv tables;
//! the snapshot's lab dir (LAB/<snapshot>/) gets runs.tsv, the ladder's looks.tsv and
//! best-<target>.tsv, and finals.tsv. Last stdout line: RESULT ..., what the agent reads

const std = @import("std");
const api = @import("api");
const cand = @import("cand");
const rows = @import("rows.zig");
const protocol = @import("protocol.zig");
const harness = @import("harness.zig");
const search = @import("search.zig");
const store = @import("store");

const Io = std.Io;

pub const usage =
    \\  exp run SNAP CAMPAIGN TARGET [--select] [--fraction F] [--hyp ID] [--desc TEXT]
    \\          [--lab DIR] [--run ID]  score the compiled-in candidate on dev (and spend a
    \\                                  selection look with --select); TARGET is one of
    \\                                  win gold14 lanediff14 cs10 deaths15 first_item;
    \\                                  --fraction fits dev on a nested share of games
    \\  exp screen|diagnose SNAP CAMPAIGN TARGET
    \\                                  dev only: the candidate's features one by one, or
    \\                                  its residuals by covariate (lab/search.zig)
    \\  exp final SNAP CAMPAIGN TARGET [--lab DIR] [--run ID]
    \\                                  test score, once per campaign: humans only
    \\  exp preds SNAP CAMPAIGN TARGET  the candidate's test-row predictions, no outcomes
    \\                                  or scores (preds.tsv), to check a port against
    \\                                  its original's prediction file
    \\
;

const Args = struct {
    cmd: enum { run, final, screen, diagnose, preds },
    snap: []const u8,
    campaign: []const u8,
    target: api.Outcome,
    select: bool = false,
    desc: []const u8 = "",
    /// Share of dev's training games (learning curves); dev only
    fraction: f64 = 1,
    /// The campaign's hypotheses.tsv id this run tests
    hyp: []const u8 = "-",
    lab: []const u8,
    run: []const u8,
};

pub fn main(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: Io, home: ?[]const u8, argv: []const []const u8) !u8 {
    const args = parse(arena, io, home, argv) catch |err| {
        std.debug.print("exp: {t}\nusage:\n{s}", .{ err, usage });
        return 2;
    };
    var legendaries = try rows.loadLegendaries(gpa, io, args.snap);
    defer legendaries.deinit(gpa);
    var data = try rows.load(gpa, args.snap, &legendaries);
    defer data.deinit();
    const ranks = try harness.gameRanks(gpa, &data);
    defer gpa.free(ranks);
    const ids = protocol.platformIds();
    const eu: u8 = for (ids, 0..) |id, i| {
        if (std.mem.eql(u8, id, protocol.test_platform)) break @intCast(i);
    } else return error.TestPlatformNotScanned;
    const c = try harness.cuts(gpa, &data, eu);

    const dir = try std.fs.path.join(arena, &.{ args.lab, std.fs.path.basename(args.snap) });
    try Io.Dir.cwd().createDirPath(io, dir);

    var buf: [4096]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &buf);
    const w = &stdout.interface;
    switch (args.cmd) {
        .run => try run(gpa, arena, io, &data, ranks, c, args, dir, w),
        .final => try final(gpa, arena, io, &data, ranks, c, args, dir, w),
        .screen => try search.screen(cand, gpa, &data, ranks, c, api.outcomeIndex(args.target), w),
        .diagnose => try search.diagnose(cand, gpa, &data, ranks, c, api.outcomeIndex(args.target), w),
        .preds => try testPreds(gpa, io, &data, ranks, c, w),
    }
    try w.flush();
    return 0;
}

fn parse(arena: std.mem.Allocator, io: Io, home: ?[]const u8, argv: []const []const u8) !Args {
    if (argv.len < 4) return error.MissingArguments;
    var a: Args = .{
        .cmd = std.meta.stringToEnum(@FieldType(Args, "cmd"), argv[0]) orelse return error.UnknownCommand,
        .snap = argv[1],
        .campaign = argv[2],
        .target = std.meta.stringToEnum(api.Outcome, argv[3]) orelse return error.UnknownTarget,
        .lab = if (home) |h| try std.fs.path.join(arena, &.{ h, "ml/lab" }) else "lab",
        .run = "",
    };
    var i: usize = 4;
    while (i < argv.len) : (i += 1) {
        const o = argv[i];
        if (std.mem.eql(u8, o, "--select")) {
            a.select = true;
            continue;
        }
        if (i + 1 >= argv.len) return error.MissingValue;
        i += 1;
        if (std.mem.eql(u8, o, "--desc")) a.desc = argv[i] //
        else if (std.mem.eql(u8, o, "--lab")) a.lab = argv[i] //
        else if (std.mem.eql(u8, o, "--run")) a.run = argv[i] //
        else if (std.mem.eql(u8, o, "--hyp")) a.hyp = argv[i] //
        else if (std.mem.eql(u8, o, "--fraction")) a.fraction = try std.fmt.parseFloat(f64, argv[i]) //
        else return error.UnknownOption;
    }
    if (a.cmd != .run and (a.select or a.fraction != 1)) return error.UnknownOption;
    if (!(a.fraction > 0 and a.fraction <= 1)) return error.BadFraction;
    // A look on a model fitted to part of train would waste the budget
    if (a.select and a.fraction != 1) return error.FractionWithSelect;
    // The run dir's name (deploy/lab-run.sh: <stamp>-<name>)
    if (a.run.len == 0) a.run = std.fs.path.basename(try std.process.currentPathAlloc(io, arena));
    const desc = try arena.dupe(u8, a.desc);
    std.mem.replaceScalar(u8, desc, '\t', ' ');
    std.mem.replaceScalar(u8, desc, '\n', ' ');
    a.desc = desc;
    return a;
}

fn run(
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    io: Io,
    d: *const rows.Data,
    ranks: []const [2][5]?u8,
    c: harness.Cuts,
    args: Args,
    dir: []const u8,
    w: *Io.Writer,
) !void {
    const k = api.outcomeIndex(args.target);
    var dev = try harness.score(cand, gpa, d, ranks, c, .dev, .{
        .fraction = args.fraction,
        .effects_for = args.target,
        .effects_arena = arena,
    });
    defer dev.deinit(gpa);
    const dev_target = try summary(gpa, io, d, &dev, args);
    try writePreds(gpa, io, d, &dev, "dev.tsv");
    const h = try human(gpa, d, &dev, k, dev_target);
    const effect_files = try writeEffects(gpa, arena, io, args.snap, dev.effects);

    var verdict: ?harness.Verdict = null;
    var looks: usize = 0;
    if (args.select) {
        const lock_path = try std.fs.path.join(arena, &.{ dir, "lock" });
        const lock = try Io.Dir.cwd().createFile(io, lock_path, .{ .truncate = false, .lock = .exclusive });
        defer lock.close(io);
        const looks_path = try std.fs.path.join(arena, &.{ dir, "looks.tsv" });
        looks = try countLines(gpa, io, looks_path);
        var sel = try harness.score(cand, gpa, d, ranks, c, .select, .{});
        defer sel.deinit(gpa);
        const best_path = try std.fs.path.join(arena, &.{ dir, try std.fmt.allocPrint(arena, "best-{t}.tsv", .{args.target}) });
        const best_preds = try readBest(gpa, io, best_path, sel.row.len);
        defer if (best_preds) |b| gpa.free(b);
        const la = try sel.losses(gpa, d, k, null, .cand);
        defer gpa.free(la);
        const lb = try sel.losses(gpa, d, k, best_preds, .base);
        defer gpa.free(lb);
        verdict = harness.ladder(sel.game, la, lb, looks);
        if (verdict.? != .budget_spent) {
            looks += 1;
            try appendLine(io, looks_path, "run\tcampaign\ttarget\tverdict\tdiff\thalf\n", try std.fmt.allocPrint(arena, "{s}\t{s}\t{t}\t{s}\t{d:.5}\t{d:.5}\n", .{
                args.run,
                args.campaign,
                args.target,
                verdictName(verdict),
                if (verdict.? == .new_best) verdict.?.new_best.diff else std.math.nan(f64),
                if (verdict.? == .new_best) verdict.?.new_best.half else std.math.nan(f64),
            }));
        }
        if (verdict.? == .new_best) try writeBest(io, best_path, args.run, sel.cand, k);
    }

    const header = "run\tcampaign\ttarget\tscope\tdev_n\tdev_diff\tdev_half\tselect\tlooks\thyp\tfraction\tdesc" ++
        "\tcategory\tremoved_pct\tremoved_half\terr_base\terr_cand\tunit\teffects\n";
    const line = try std.fmt.allocPrint(arena, "{s}\t{s}\t{t}\t{t}\t{d}\t{d:.5}\t{d:.5}\t{s}\t{d}\t{s}\t{d}\t{s}\t{s}\t{d:.3}\t{d:.3}\t{s}\t{s}\t{s}\t{s}\n", .{
        args.run,                                    args.campaign,     args.target,                                     cand.scope,
        dev_target.n,                                dev_target.diff,   dev_target.half,                                 verdictName(verdict),
        looks,                                       args.hyp,          args.fraction,                                   args.desc,
        category(args.target),                       h.removed_pct,     h.removed_half,                                  try errText(arena, args.target, h.err_base),
        try errText(arena, args.target, h.err_cand), unit(args.target), if (effect_files.len > 0) effect_files else "-",
    });
    try appendLine(io, try std.fs.path.join(arena, &.{ dir, "runs.tsv" }), header, line);
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = "result.tsv", .data = try std.mem.concat(arena, u8, &.{ header, line }) });
    try w.print("RESULT run={s} target={t} dev={d:.5}±{d:.5} n={d} ({s}) select={s}", .{
        args.run,                                                         args.target,          dev_target.diff, dev_target.half, dev_target.n,
        if (dev_target.beats()) "beats baseline" else "not beyond noise", verdictName(verdict),
    });
    // Human units for the run's finding (docs/lab-brief.md "Findings")
    try w.print(" removed={d:.2}%±{d:.2}", .{ h.removed_pct, h.removed_half });
    try w.print(" {s}={s}->{s} {s}", .{
        if (args.target == .win) "accuracy" else "error",
        try errText(arena, args.target, h.err_base),
        try errText(arena, args.target, h.err_cand),
        unit(args.target),
    });
    try w.print(" effects={s}", .{if (effect_files.len > 0) effect_files else "none"});
    if (verdict) |v| if (v == .new_best) try w.print(" gain={d:.5}±{d:.5}", .{ v.new_best.diff, v.new_best.half });
    // Smallest gain this dev set would show 80% of the time: (1.96 + 0.84) / 1.96 half
    if (dev_target.half > 1e-9 and std.math.isFinite(dev_target.half)) try w.print(" mde={d:.5}", .{dev_target.half * 1.43});
    try w.print(" looks={d}/{d}\n", .{ looks, harness.look_budget });
}

/// The admin page groups runs by model category
fn category(o: api.Outcome) []const u8 {
    return switch (o) {
        .win => "win",
        .gold14, .lanediff14, .cs10, .deaths15 => "early",
        .first_item => "items",
    };
}

fn unit(o: api.Outcome) []const u8 {
    return switch (o) {
        .win => "% right",
        .gold14, .lanediff14 => "gold",
        .cs10 => "CS",
        .deaths15 => "deaths",
        .first_item => "min",
    };
}

fn errText(arena: std.mem.Allocator, o: api.Outcome, x: f64) ![]const u8 {
    if (std.math.isNan(x)) return "-";
    return switch (o) {
        .gold14, .lanediff14 => std.fmt.allocPrint(arena, "{d:.0}", .{x}),
        .win => std.fmt.allocPrint(arena, "{d:.1}", .{x}),
        else => std.fmt.allocPrint(arena, "{d:.2}", .{x}),
    };
}

const Human = struct {
    /// Share of the baseline's dev loss the candidate removes, with its 95% half-width;
    /// positive = better
    removed_pct: f64,
    removed_half: f64,
    /// Root mean squared error in the outcome's own units (gold, CS, ...); for win the
    /// share of rows whose team the prediction calls right (a coin flip is 50%)
    err_base: f64,
    err_cand: f64,
};

fn human(gpa: std.mem.Allocator, d: *const rows.Data, s: *const harness.Scores, k: usize, p: harness.Paired) !Human {
    var h: Human = .{
        .removed_pct = -100 * p.diff / p.b,
        .removed_half = 100 * p.half / p.b,
        .err_base = std.math.nan(f64),
        .err_cand = std.math.nan(f64),
    };
    if (k == api.outcomeIndex(.win)) {
        var right: [2]f64 = @splat(0);
        var n: f64 = 0;
        for (s.row, s.cand, s.base) |ri, pc, pb| {
            const y = d.rows[ri].y[k];
            if (std.math.isNan(y)) continue;
            for ([2]f64{ pc[k], pb[k] }, &right) |q, *r| r.* += called(q, y);
            n += 1;
        }
        if (n > 0) {
            h.err_cand = 100 * right[0] / n;
            h.err_base = 100 * right[1] / n;
        }
        return h;
    }
    const la = try s.losses(gpa, d, k, null, .cand);
    defer gpa.free(la);
    const lb = try s.losses(gpa, d, k, null, .base);
    defer gpa.free(lb);
    // Losses are squared errors in role sd: scale back per row
    var sa: f64 = 0;
    var sb: f64 = 0;
    var n: f64 = 0;
    for (la, lb, s.row) |a, b, ri| {
        if (std.math.isNan(a) or std.math.isNan(b)) continue;
        const sd = s.sd[@backingInt(d.rows[ri].role)][k];
        sa += a * sd * sd;
        sb += b * sd * sd;
        n += 1;
    }
    if (n > 0) {
        h.err_cand = @sqrt(sa / n);
        h.err_base = @sqrt(sb / n);
    }
    return h;
}

/// 1 when the win prediction picks the row's result, 0 when it picks the other, half
/// for a coin flip
fn called(p: f64, y: f32) f64 {
    if (p == 0.5) return 0.5;
    return @floatFromInt(@intFromBool((p > 0.5) == (y > 0.5)));
}

/// Writes each table as effects-<name>.tsv: "# title | unit | what higher means", then
/// label, effect, ci (95% half-width), n. Returns the file names, comma separated
fn writeEffects(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: Io, snap: []const u8, tables: []const api.Effects) ![]const u8 {
    if (tables.len == 0) return "";
    const names = try championNames(gpa, arena, snap);
    var files: std.ArrayList(u8) = .empty;
    for (tables) |t| {
        if (t.name.len == 0) return error.BadEffectsName;
        for (t.name) |ch| if (!(std.ascii.isLower(ch) or std.ascii.isDigit(ch) or ch == '_' or ch == '-')) return error.BadEffectsName;
        var aw: Io.Writer.Allocating = .init(arena);
        const w = &aw.writer;
        try w.print("# {s} | {s} | {s}\nlabel\teffect\tci\tn\n", .{
            try clean(arena, &names, t.title), try clean(arena, &names, t.unit), try clean(arena, &names, t.higher),
        });
        for (t.rows) |r| try w.print("{s}\t{d:.4}\t{d:.4}\t{d}\n", .{ try clean(arena, &names, r.label), r.effect, r.ci, r.n });
        const file = try std.fmt.allocPrint(arena, "effects-{s}.tsv", .{t.name});
        try Io.Dir.cwd().writeFile(io, .{ .sub_path = file, .data = aw.written() });
        if (files.items.len > 0) try files.append(arena, ',');
        try files.appendSlice(arena, file);
    }
    return files.items;
}

/// Champion names by id (the snapshot's Data Dragon table), for effect labels
fn championNames(gpa: std.mem.Allocator, arena: std.mem.Allocator, snap: []const u8) !std.AutoHashMapUnmanaged(u32, []const u8) {
    const db = try store.schema.openReadOnly(gpa, snap);
    defer db.close();
    var out: std.AutoHashMapUnmanaged(u32, []const u8) = .empty;
    var q = try db.prepare("SELECT id, name FROM champions");
    defer q.deinit();
    try q.bind(.{});
    while (try q.step()) try out.put(arena, @intCast(q.int(0)), try arena.dupe(u8, q.bytes(1)));
    return out;
}

/// One TSV field: "#<champion id>" becomes the champion's name; tabs, newlines and "|"
/// (the title line's separator) become spaces
fn clean(arena: std.mem.Allocator, names: *const std.AutoHashMapUnmanaged(u32, []const u8), text: []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    var i: usize = 0;
    while (i < text.len) {
        if (text[i] == '#') {
            var j = i + 1;
            while (j < text.len and std.ascii.isDigit(text[j])) j += 1;
            const id = std.fmt.parseInt(u32, text[i + 1 .. j], 10) catch null;
            if (id) |x| if (names.get(x)) |name| {
                try out.appendSlice(arena, name);
                i = j;
                continue;
            };
        }
        try out.append(arena, switch (text[i]) {
            '\t', '\n', '\r', '|' => ' ',
            else => text[i],
        });
        i += 1;
    }
    return out.items;
}

fn verdictName(v: ?harness.Verdict) []const u8 {
    const x = v orelse return "-";
    return switch (x) {
        .new_best => "new-best",
        .no_change => "no-change",
        .budget_spent => "budget-spent",
    };
}

/// summary.md: dev per outcome, then the target sliced by role, patch and rank tier
fn summary(gpa: std.mem.Allocator, io: Io, d: *const rows.Data, s: *const harness.Scores, args: Args) !harness.Paired {
    var aw: Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();
    const w = &aw.writer;
    try w.print("# {s} ({s}), target {t}, scope {t}\n\n{s}\n\n", .{ args.run, args.campaign, args.target, cand.scope, args.desc });
    try w.writeAll("Dev: candidate vs champion-role baseline, mean loss per row (log loss for win, " ++
        "squared error in role sd for the rest), 95% interval clustered by game. " ++
        "Negative diff = candidate better.\n\n");
    try w.writeAll("| outcome | rows | no opinion | baseline | candidate | diff |\n|---|---|---|---|---|---|\n");
    var target: harness.Paired = .{};
    for (0..api.outcome_count) |k| {
        const la = try s.losses(gpa, d, k, null, .cand);
        defer gpa.free(la);
        const lb = try s.losses(gpa, d, k, null, .base);
        defer gpa.free(lb);
        const p = harness.paired(s.game, la, lb, null);
        if (k == api.outcomeIndex(args.target)) target = p;
        try w.print("| {t} | {d} | {d} | {d:.5} | {d:.5} | {d:.5} ± {d:.5} |\n", .{
            api.outcomeAt(k), p.n, s.no_opinion[k], p.b, p.a, p.diff, p.half,
        });
    }

    const k = api.outcomeIndex(args.target);
    const la = try s.losses(gpa, d, k, null, .cand);
    defer gpa.free(la);
    const lb = try s.losses(gpa, d, k, null, .base);
    defer gpa.free(lb);
    const keep = try gpa.alloc(bool, s.row.len);
    defer gpa.free(keep);

    try w.print("\n## {t} by role\n\n| role | rows | diff |\n|---|---|---|\n", .{args.target});
    for (std.enums.values(api.Role)) |ro| {
        for (keep, s.row) |*kp, ri| kp.* = @backingInt(d.rows[ri].role) == @backingInt(ro);
        try sliceRow(w, @tagName(ro), harness.paired(s.game, la, lb, keep));
    }

    try w.print("\n## {t} by patch\n\n| patch | rows | diff |\n|---|---|---|\n", .{args.target});
    var patches: std.ArrayList(u32) = .empty;
    defer patches.deinit(gpa);
    for (s.row) |ri| {
        const p = d.games[d.rows[ri].game].patch;
        if (std.mem.indexOfScalar(u32, patches.items, p) == null) try patches.append(gpa, p);
    }
    std.mem.sort(u32, patches.items, {}, std.sort.asc(u32));
    for (patches.items) |p| {
        for (keep, s.row) |*kp, ri| kp.* = d.games[d.rows[ri].game].patch == p;
        var name: [16]u8 = undefined;
        try sliceRow(w, try std.fmt.bufPrint(&name, "{d}.{d}", .{ p / 1000, p % 1000 }), harness.paired(s.game, la, lb, keep));
    }

    try w.print("\n## {t} by rank tier\n\n| tier | rows | diff |\n|---|---|---|\n", .{args.target});
    const tiers = [_][]const u8{ "iron", "bronze", "silver", "gold", "platinum", "emerald", "diamond", "master", "grandmaster", "challenger" };
    for (0..tiers.len + 1) |t| {
        for (keep, s.row) |*kp, ri| kp.* = if (d.rows[ri].rank) |r| r / 4 == t else t == tiers.len;
        try sliceRow(w, if (t < tiers.len) tiers[t] else "unranked", harness.paired(s.game, la, lb, keep));
    }
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = "summary.md", .data = aw.written() });
    return target;
}

fn sliceRow(w: *Io.Writer, name: []const u8, p: harness.Paired) !void {
    if (p.n == 0) return;
    try w.print("| {s} | {d} | {d:.5} ± {d:.5} |\n", .{ name, p.n, p.diff, p.half });
}

/// The shared prediction file format (docs/model.md): match_id, slot, outcome, y, pred
fn writePreds(gpa: std.mem.Allocator, io: Io, d: *const rows.Data, s: *const harness.Scores, path: []const u8) !void {
    _ = gpa;
    var file = try Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    var buf: [64 * 1024]u8 = undefined;
    var fw = file.writer(io, &buf);
    const w = &fw.interface;
    try w.writeAll("match_id\tslot\toutcome\ty\tpred\n");
    for (s.row, s.cand) |ri, pred| {
        const r = d.rows[ri];
        for (pred, r.y, 0..) |p, y, k| {
            if (std.math.isNan(y)) continue;
            try w.print("{s}\t{d}\t{t}\t{d}\t{d:.4}\n", .{
                d.games[r.game].match_id, r.slot, api.outcomeAt(k), y, p,
            });
        }
    }
    try w.flush();
}

fn testPreds(gpa: std.mem.Allocator, io: Io, d: *const rows.Data, ranks: []const [2][5]?u8, c: harness.Cuts, w: *Io.Writer) !void {
    var s = try harness.score(cand, gpa, d, ranks, c, .final, .{});
    defer s.deinit(gpa);
    var file = try Io.Dir.cwd().createFile(io, "preds.tsv", .{});
    defer file.close(io);
    var buf: [64 * 1024]u8 = undefined;
    var fw = file.writer(io, &buf);
    try fw.interface.writeAll("match_id\tslot\toutcome\tpred\n");
    for (s.row, s.cand) |ri, pred| {
        const r = d.rows[ri];
        for (pred, 0..) |p, k| try fw.interface.print("{s}\t{d}\t{t}\t{d:.4}\n", .{
            d.games[r.game].match_id, r.slot, api.outcomeAt(k), p,
        });
    }
    try fw.interface.flush();
    try w.print("RESULT preds rows={d} file=preds.tsv\n", .{s.row.len});
}

fn countLines(gpa: std.mem.Allocator, io: Io, path: []const u8) !usize {
    const text = Io.Dir.cwd().readFileAlloc(io, path, gpa, .limited(16 << 20)) catch |err| switch (err) {
        error.FileNotFound => return 0,
        else => return err,
    };
    defer gpa.free(text);
    const n = std.mem.count(u8, text, "\n");
    return if (n > 0) n - 1 else 0;
}

fn appendLine(io: Io, path: []const u8, header: []const u8, line: []const u8) !void {
    var file = try Io.Dir.cwd().createFile(io, path, .{ .truncate = false });
    defer file.close(io);
    const len = try file.length(io);
    var buf: [1024]u8 = undefined;
    var fw = file.writer(io, &buf);
    try fw.seekTo(len);
    if (len == 0) try fw.interface.writeAll(header);
    try fw.interface.writeAll(line);
    try fw.interface.flush();
}

/// best-<target>.tsv: "run\t<id>" then one prediction per selection row; null until a
/// candidate beats the baseline
fn readBest(gpa: std.mem.Allocator, io: Io, path: []const u8, n: usize) !?[]f64 {
    const text = Io.Dir.cwd().readFileAlloc(io, path, gpa, .limited(64 << 20)) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer gpa.free(text);
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    _ = lines.next();
    const out = try gpa.alloc(f64, n);
    errdefer gpa.free(out);
    var i: usize = 0;
    while (lines.next()) |line| : (i += 1) {
        if (i >= n) return error.SelectionRowsChanged;
        out[i] = try std.fmt.parseFloat(f64, line);
    }
    if (i != n) return error.SelectionRowsChanged;
    return out;
}

fn writeBest(io: Io, path: []const u8, run_id: []const u8, preds: []const [api.outcome_count]f64, k: usize) !void {
    var file = try Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    var buf: [64 * 1024]u8 = undefined;
    var fw = file.writer(io, &buf);
    try fw.interface.print("run\t{s}\n", .{run_id});
    for (preds) |p| try fw.interface.print("{d}\n", .{p[k]});
    try fw.interface.flush();
}

fn final(
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    io: Io,
    d: *const rows.Data,
    ranks: []const [2][5]?u8,
    c: harness.Cuts,
    args: Args,
    dir: []const u8,
    w: *Io.Writer,
) !void {
    var s = try harness.score(cand, gpa, d, ranks, c, .final, .{});
    defer s.deinit(gpa);
    try w.print("# Final: {s} ({s}), test set, scope {t}\n\n| outcome | rows | baseline | candidate | diff |\n|---|---|---|---|---|\n", .{ args.run, args.campaign, cand.scope });
    const finals = try std.fs.path.join(arena, &.{ dir, "finals.tsv" });
    for (0..api.outcome_count) |k| {
        const la = try s.losses(gpa, d, k, null, .cand);
        defer gpa.free(la);
        const lb = try s.losses(gpa, d, k, null, .base);
        defer gpa.free(lb);
        const p = harness.paired(s.game, la, lb, null);
        const o = api.outcomeAt(k);
        try w.print("| {t} | {d} | {d:.5} | {d:.5} | {d:.5} ± {d:.5} |\n", .{ o, p.n, p.b, p.a, p.diff, p.half });
        try appendLine(io, finals, "run\tcampaign\ttarget\toutcome\tn\tdiff\thalf\n", try std.fmt.allocPrint(arena, "{s}\t{s}\t{t}\t{t}\t{d}\t{d:.5}\t{d:.5}\n", .{
            args.run, args.campaign, args.target, o, p.n, p.diff, p.half,
        }));
    }
}

test "effect labels: champion ids become names, separators become spaces" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var names: std.AutoHashMapUnmanaged(u32, []const u8) = .empty;
    try names.put(arena, 266, "Aatrox");
    try std.testing.expectEqualStrings("Aatrox vs #9 (top) a b", try clean(arena, &names, "#266 vs #9 (top) a|b"));
    try std.testing.expectEqualStrings("# 1", try clean(arena, &names, "#\t1"));
}

test {
    _ = search;
}
