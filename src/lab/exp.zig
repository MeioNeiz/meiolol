//! `meiolol-lab exp`: one lab-agent run of the candidate compiled in (-Dcand, docs/
//! lab-agent.md). Runs in a deploy/lab-run.sh run dir, which gets summary.md, dev.tsv,
//! result.tsv (the run's runs.tsv row) and the candidate's effects-<name>.tsv tables;
//! the snapshot's lab dir (LAB/<snapshot>/) gets runs.tsv and finals.tsv. Last stdout
//! line: RESULT ..., what the agent reads

const std = @import("std");
const api = @import("api");
const nn = @import("nn");
const cand = @import("cand");
const rows = @import("rows.zig");
const test_looks = @import("looks.zig");
const protocol = @import("protocol.zig");
const harness = @import("harness.zig");
const search = @import("search.zig");
const store = @import("store");
const tsvlog = @import("../tsvlog.zig");

const Io = std.Io;

pub const usage =
    \\  exp run SNAP CAMPAIGN TARGET [--fraction F] [--hyp ID] [--desc TEXT]
    \\          [--lab DIR] [--run ID]  score the compiled-in candidate on dev (no selection
    \\                                  window since the one global cut); TARGET is one of
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
    if (harness.afterGameRank(cand) and (args.cmd == .final or args.cmd == .preds)) {
        std.debug.print("exp: an after_game_rank candidate is a dev-only leak diagnostic: " ++
            "no final or preds (src/lab/api.zig)\n", .{});
        return 2;
    }
    var legendaries = try rows.loadLegendaries(gpa, io, args.snap);
    defer legendaries.deinit(gpa);
    var data = try rows.load(gpa, args.snap, &legendaries);
    defer data.deinit();
    const players = try harness.gamePlayers(gpa, &data);
    defer gpa.free(players);
    const c = try harness.cuts(gpa, &data);

    const dir = try std.fs.path.join(arena, &.{ args.lab, std.fs.path.basename(args.snap) });
    try Io.Dir.cwd().createDirPath(io, dir);

    var buf: [4096]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &buf);
    const w = &stdout.interface;
    if (args.cmd == .final) _ = try test_looks.record(gpa, io, Io.Dir.cwd(), args.snap, "exp", argv, w);
    switch (args.cmd) {
        .run => try run(gpa, arena, io, &data, players, c, args, dir, w),
        .final => try final(gpa, arena, io, &data, players, c, args, dir, w),
        .screen => try search.screen(cand, gpa, &data, players, c, api.outcomeIndex(args.target), w),
        .diagnose => try search.diagnose(cand, gpa, &data, players, c, api.outcomeIndex(args.target), w),
        .preds => try testPreds(gpa, io, &data, players, c, w),
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
        if (std.mem.eql(u8, o, "--select")) return error.NoSelectionWindow;
        if (i + 1 >= argv.len) return error.MissingValue;
        i += 1;
        if (std.mem.eql(u8, o, "--desc")) a.desc = argv[i] //
        else if (std.mem.eql(u8, o, "--lab")) a.lab = argv[i] //
        else if (std.mem.eql(u8, o, "--run")) a.run = argv[i] //
        else if (std.mem.eql(u8, o, "--hyp")) a.hyp = argv[i] //
        else if (std.mem.eql(u8, o, "--fraction")) a.fraction = try std.fmt.parseFloat(f64, argv[i]) //
        else return error.UnknownOption;
    }
    if (a.cmd != .run and a.fraction != 1) return error.UnknownOption;
    if (!(a.fraction > 0 and a.fraction <= 1)) return error.BadFraction;
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
    players: []const harness.Players,
    c: harness.Cuts,
    args: Args,
    dir: []const u8,
    w: *Io.Writer,
) !void {
    const k = api.outcomeIndex(args.target);
    var dev = try harness.score(cand, gpa, d, players, c, .dev, .{
        .fraction = args.fraction,
        .effects_for = args.target,
        .effects_arena = arena,
    });
    defer dev.deinit(gpa);
    const dev_target = try summary(gpa, io, d, &dev, args);
    try writePreds(io, d, &dev, "dev.tsv");
    const h = try human(gpa, d, &dev, k, dev_target);
    const effect_files = try writeEffects(gpa, arena, io, args.snap, dev.effects);

    // No selection window since the one global cut (2253Z): no ladder looks
    const header = "run\tcampaign\ttarget\tscope\tdev_n\tdev_diff\tdev_half\tselect\tlooks\thyp\tfraction\tdesc" ++
        "\tcategory\tremoved_pct\tremoved_half\terr_base\terr_cand\tunit\teffects\n";
    const line = try arena.print("{s}\t{s}\t{t}\t{t}\t{d}\t{d:.5}\t{d:.5}\t{s}\t{d}\t{s}\t{d}\t{s}\t{s}\t{d:.3}\t{d:.3}\t{s}\t{s}\t{s}\t{s}\n", .{
        args.run,                                    args.campaign,     args.target,                                     cand.scope,
        dev_target.n,                                dev_target.diff,   dev_target.half,                                 "-",
        0,                                           args.hyp,          args.fraction,                                   args.desc,
        category(args.target),                       h.removed_pct,     h.removed_half,                                  try errText(arena, args.target, h.err_base),
        try errText(arena, args.target, h.err_cand), unit(args.target), if (effect_files.len > 0) effect_files else "-",
    });
    try tsvlog.appendRaw(io, Io.Dir.cwd(), try std.fs.path.join(arena, &.{ dir, "runs.tsv" }), header, line);
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = "result.tsv", .data = try std.mem.concat(arena, u8, &.{ header, line }) });
    try w.print("RESULT run={s} scope={t} target={t} dev={d:.5}±{d:.5} n={d} ({s}) select={s}", .{
        args.run,                                                         cand.scope, args.target, dev_target.diff, dev_target.half, dev_target.n,
        if (dev_target.beats()) "beats baseline" else "not beyond noise", "-",
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
    // Smallest gain this dev set would show 80% of the time: (1.96 + 0.84) / 1.96 half
    if (dev_target.half > 1e-9 and std.math.isFinite(dev_target.half)) try w.print(" mde={d:.5}", .{dev_target.half * 1.43});
    try w.print(" looks=0/{d}\n", .{harness.look_budget});
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
        .gold14, .lanediff14 => arena.print("{d:.0}", .{x}),
        .win => arena.print("{d:.1}", .{x}),
        else => arena.print("{d:.2}", .{x}),
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
        const file = try arena.print("effects-{s}.tsv", .{t.name});
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
        if (std.mem.findScalar(u32, patches.items, p) == null) try patches.append(gpa, p);
    }
    std.mem.sort(u32, patches.items, {}, std.sort.asc(u32));
    for (patches.items) |p| {
        for (keep, s.row) |*kp, ri| kp.* = d.games[d.rows[ri].game].patch == p;
        var name: [16]u8 = undefined;
        try sliceRow(w, try std.mem.print(&name, "{d}.{d}", .{ p / 1000, p % 1000 }), harness.paired(s.game, la, lb, keep));
    }

    try w.print("\n## {t} by rank tier (after-game rank, report only)\n\n| tier | rows | diff |\n|---|---|---|\n", .{args.target});
    const tiers = [_][]const u8{ "iron", "bronze", "silver", "gold", "platinum", "emerald", "diamond", "master", "grandmaster", "challenger" };
    for (0..tiers.len + 1) |t| {
        for (keep, s.row) |*kp, ri| kp.* = if (d.rows[ri].rank_after) |r| r / 4 == t else t == tiers.len;
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
fn writePreds(io: Io, d: *const rows.Data, s: *const harness.Scores, path: []const u8) !void {
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

fn testPreds(gpa: std.mem.Allocator, io: Io, d: *const rows.Data, players: []const harness.Players, c: harness.Cuts, w: *Io.Writer) !void {
    var s = try harness.score(cand, gpa, d, players, c, .final, .{});
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

fn final(
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    io: Io,
    d: *const rows.Data,
    players: []const harness.Players,
    c: harness.Cuts,
    args: Args,
    dir: []const u8,
    w: *Io.Writer,
) !void {
    var s = try harness.score(cand, gpa, d, players, c, .final, .{});
    defer s.deinit(gpa);
    // The test minus the games an earlier snapshot's looks saw, from the same predictions
    var exclude = try test_looks.Exclude.load(gpa, io, Io.Dir.cwd(), args.snap);
    defer if (exclude) |*e| e.deinit(gpa);
    const keep = try gpa.alloc(bool, s.game.len);
    defer gpa.free(keep);
    for (keep, s.game) |*kp, g| kp.* = if (exclude) |*e| !e.has(d.games[g].match_id) else true;
    const finals = try std.fs.path.join(arena, &.{ dir, "finals.tsv" });
    for ([_]?[]const bool{ null, if (exclude != null) keep else null }, 0..) |mask, pass| {
        if (pass == 1 and mask == null) {
            try w.print("\nno {s}: the test number above is the only one\n", .{test_looks.exclude_name});
            continue;
        }
        const set = if (pass == 0) "test" else "test minus " ++ test_looks.exclude_name;
        try w.print("{s}# Final: {s} ({s}), {s}, scope {t}\n\n| outcome | rows | baseline | candidate | diff |\n|---|---|---|---|---|\n", .{ if (pass == 0) "" else "\n", args.run, args.campaign, set, cand.scope });
        for (0..api.outcome_count) |k| {
            const la = try s.losses(gpa, d, k, null, .cand);
            defer gpa.free(la);
            const lb = try s.losses(gpa, d, k, null, .base);
            defer gpa.free(lb);
            const p = harness.paired(s.game, la, lb, mask);
            const o = api.outcomeAt(k);
            try w.print("| {t} | {d} | {d:.5} | {d:.5} | {d:.5} ± {d:.5} |\n", .{ o, p.n, p.b, p.a, p.diff, p.half });
            try tsvlog.appendRaw(io, Io.Dir.cwd(), finals, "run\tcampaign\ttarget\toutcome\tset\tn\tdiff\thalf\n", try arena.print("{s}\t{s}\t{t}\t{t}\t{s}\t{d}\t{d:.5}\t{d:.5}\n", .{
                args.run, args.campaign, args.target, o, if (pass == 0) "test" else "test-excl", p.n, p.diff, p.half,
            }));
        }
    }
    const kw = api.outcomeIndex(.win);
    const ys = try gpa.alloc(f32, s.row.len);
    defer gpa.free(ys);
    const pc = try gpa.alloc(f64, s.row.len);
    defer gpa.free(pc);
    const pb = try gpa.alloc(f64, s.row.len);
    defer gpa.free(pb);
    for (ys, pc, pb, s.row, s.cand, s.base) |*y, *c1, *b1, ri, sc, sb| {
        y.* = d.rows[ri].y[kw];
        c1.* = sc[kw];
        b1.* = sb[kw];
    }
    try w.print("\nwin AUC per row: baseline {d:.4}, candidate {d:.4}\n", .{ try auc(gpa, ys, pb), try auc(gpa, ys, pc) });
    try writeTestRows(gpa, io, d, &s, "test.tsv");
}

/// Rank AUC of predictions p for 0/1 outcomes y (NaN rows skipped), ties averaged
/// nn.auc over the rows with a win label (y NaN: none)
fn auc(gpa: std.mem.Allocator, y: []const f32, p: []const f64) !f64 {
    var ys: std.ArrayList(f64) = .empty;
    defer ys.deinit(gpa);
    var ps: std.ArrayList(f64) = .empty;
    defer ps.deinit(gpa);
    for (y, p) |yy, pp| if (!std.math.isNan(yy)) {
        try ys.append(gpa, yy);
        try ps.append(gpa, pp);
    };
    return nn.auc(f64, gpa, ys.items, ps.items);
}

/// The final's per-row test file: writePreds' columns (meiolol-lab pairs reads them) with
/// 6-digit predictions, plus the row's loss (log loss for win, squared error in role sds
/// for the rest) and the baseline's
fn writeTestRows(gpa: std.mem.Allocator, io: Io, d: *const rows.Data, s: *const harness.Scores, path: []const u8) !void {
    var file = try Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    var buf: [64 * 1024]u8 = undefined;
    var fw = file.writer(io, &buf);
    const w = &fw.interface;
    try w.writeAll("match_id\tslot\toutcome\ty\tpred\tloss\tbase_pred\tbase_loss\n");
    for (0..api.outcome_count) |k| {
        const la = try s.losses(gpa, d, k, null, .cand);
        defer gpa.free(la);
        const lb = try s.losses(gpa, d, k, null, .base);
        defer gpa.free(lb);
        for (s.row, s.cand, s.base, la, lb) |ri, pc, pb, a, b| {
            const r = d.rows[ri];
            if (std.math.isNan(r.y[k])) continue;
            try w.print("{s}\t{d}\t{t}\t{d}\t{d:.6}\t{d:.6}\t{d:.6}\t{d:.6}\n", .{
                d.games[r.game].match_id, r.slot, api.outcomeAt(k), r.y[k], pc[k], a, pb[k], b,
            });
        }
    }
    try w.flush();
}

test "auc: ranks with ties averaged, NaN outcomes skipped" {
    const gpa = std.testing.allocator;
    try std.testing.expectEqual(@as(f64, 1), try auc(gpa, &.{ 0, 0, 1, 1 }, &.{ 0.1, 0.2, 0.3, 0.4 }));
    try std.testing.expectEqual(@as(f64, 0), try auc(gpa, &.{ 1, 0 }, &.{ 0.1, 0.2 }));
    try std.testing.expectEqual(@as(f64, 0.5), try auc(gpa, &.{ 0, 1, std.math.nan(f32) }, &.{ 0.5, 0.5, 0.9 }));
    try std.testing.expectEqual(@as(f64, 0.875), try auc(gpa, &.{ 0, 1, 0, 1 }, &.{ 0.1, 0.2, 0.2, 0.3 }));
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
