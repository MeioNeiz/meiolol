//! `meiolol-lab exp`: one lab-agent run of the candidate compiled in (-Dcand, docs/
//! lab-agent.md). Runs in a deploy/lab-run.sh run dir, which gets summary.md and dev.tsv;
//! the snapshot's lab dir (LAB/<snapshot>/) gets runs.tsv, the ladder's looks.tsv and
//! best-<target>.tsv, and finals.tsv. Last stdout line: RESULT ..., what the agent reads

const std = @import("std");
const api = @import("api");
const cand = @import("cand");
const rows = @import("rows.zig");
const protocol = @import("protocol.zig");
const harness = @import("harness.zig");
const search = @import("search.zig");

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
    \\
;

const Args = struct {
    cmd: enum { run, final, screen, diagnose },
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
    var dev = try harness.score(cand, gpa, d, ranks, c, .dev, args.fraction);
    defer dev.deinit(gpa);
    const dev_target = try summary(gpa, io, d, &dev, args);
    try writePreds(gpa, io, d, &dev, "dev.tsv");

    var verdict: ?harness.Verdict = null;
    var looks: usize = 0;
    if (args.select) {
        const lock_path = try std.fs.path.join(arena, &.{ dir, "lock" });
        const lock = try Io.Dir.cwd().createFile(io, lock_path, .{ .truncate = false, .lock = .exclusive });
        defer lock.close(io);
        const looks_path = try std.fs.path.join(arena, &.{ dir, "looks.tsv" });
        looks = try countLines(gpa, io, looks_path);
        var sel = try harness.score(cand, gpa, d, ranks, c, .select, 1);
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

    try appendLine(io, try std.fs.path.join(arena, &.{ dir, "runs.tsv" }), "run\tcampaign\ttarget\tscope\tdev_n\tdev_diff\tdev_half\tselect\tlooks\thyp\tfraction\tdesc\n", try std.fmt.allocPrint(arena, "{s}\t{s}\t{t}\t{t}\t{d}\t{d:.5}\t{d:.5}\t{s}\t{d}\t{s}\t{d}\t{s}\n", .{
        args.run,     args.campaign,   args.target,     cand.scope,
        dev_target.n, dev_target.diff, dev_target.half, verdictName(verdict),
        looks,        args.hyp,        args.fraction,   args.desc,
    }));
    try w.print("RESULT run={s} target={t} dev={d:.5}±{d:.5} n={d} ({s}) select={s}", .{
        args.run,                                                         args.target,          dev_target.diff, dev_target.half, dev_target.n,
        if (dev_target.beats()) "beats baseline" else "not beyond noise", verdictName(verdict),
    });
    if (verdict) |v| if (v == .new_best) try w.print(" gain={d:.5}±{d:.5}", .{ v.new_best.diff, v.new_best.half });
    // Smallest gain this dev set would show 80% of the time: (1.96 + 0.84) / 1.96 half
    if (dev_target.half > 0 and std.math.isFinite(dev_target.half)) try w.print(" mde={d:.5}", .{dev_target.half * 1.43});
    try w.print(" looks={d}/{d}\n", .{ looks, harness.look_budget });
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
    var s = try harness.score(cand, gpa, d, ranks, c, .final, 1);
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

test {
    _ = search;
}
