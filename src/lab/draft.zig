//! `meiolol-lab draft`: a win model as a draft tester, and its export for the admin page's
//! draft board (docs/model.md "Draft model file"): the compiled-in candidate's, or with
//! --model additive the shrunk additive model (src/additive.zig, effects' "full", v2).
//! Fits once on every played game in the snapshot. Scores come from the exported
//! parameters through draftfile.zig's Scorer, the reference the page's JS must match.

const std = @import("std");
const api = @import("api");
const core = @import("core");
const cand = @import("cand");
const rows = @import("rows.zig");
const harness = @import("harness.zig");
const protocol = @import("protocol.zig");
const additive = @import("../additive.zig");
const addinputs = @import("addinputs.zig");
const df = @import("../draftfile.zig");

const Io = std.Io;
const n_role = df.n_role;
const default_min_games = df.default_min_games;
const Champions = df.Champions;
const Term = df.Term;
const Stat = df.Stat;
const TeamTerm = df.TeamTerm;
const Params = df.Params;
const PairGroup = df.PairGroup;
const PairCell = df.PairCell;
const Scorer = df.Scorer;
const Draft = df.Draft;
const Dev = df.Dev;
const Point = df.Point;
const sigmoid = @import("../logreg.zig").sigmoid;
const rank = df.rank;
const accuracyAuc = df.accuracyAuc;
const raw_len = df.raw_len;
const raw_magic = df.raw_magic;
const raw_dmg = df.raw_dmg;

pub const usage =
    \\  draft SNAP [DRAFT]              rank champions for an open slot with the compiled-in
    \\                                  candidate's win model (-Dcand); without DRAFT, reads
    \\                                  drafts line by line. DRAFT: --role mid [--side red]
    \\                                  [--ally top=Darius,jungle=Lee Sin] [--enemy mid=Ahri,
    \\                                  Jinx] [--ban Yasuo] [--top 10] [--min-games 100]
    \\  draft SNAP --export DIR [--temperature T]
    \\                                  write DIR/draft-model.json and DIR/draft-ref.json for
    \\                                  the admin draft board (docs/model.md); T scales every
    \\                                  logit (calibration, default_temperature)
    \\  draft SNAP --model additive [--pair-floor N] [--fit all|dev] ...
    \\                                  either of the above with the additive model (pairs
    \\                                  and damage mix; needs seat stats, ignores -Dcand);
    \\                                  pair cells on fewer than N fit games are left out
    \\                                  (default_pair_floor); --fit dev fits on dev's
    \\                                  visible games only, as netcheck's dev block
    \\                                  (the base a set net export was fitted on)
    \\
;

/// Shown chances are sigmoid(T * logit): win-ratings is over-confident on held-out games.
/// One temperature fitted on its preds on win-comp's 5 forward folds of snap-20261012T2055Z
/// (44,353 games): 0.80 +- 0.11 (netcheck f1 runs and effects eff-d agree; the top tenth
/// said 58.6% and won 55.8%). Refit when the shipped model or the snapshot changes
pub const default_temperature = 0.80;
/// The additive model's: fitted on effects' v2 "full" preds on the 5 forward folds of
/// snap-20261013T2253Z (run 20261014T041809Z-e53v2-V0, 134,375 games): 1.01 +- 0.03,
/// folds 0.96-1.10, dev-val 1.14 +- 0.05; the top tenth said 61.1% and won 61.2%
pub const default_temperature_additive = 1.01;
/// Pair cells on fewer fit games are left out of the export (0, the prior mean): heavily
/// shrunk, so they barely move a draft (the export prints by how much), and they are most
/// of the cells
pub const default_pair_floor = 20;

const ModelKind = enum { cand, additive };
const FitGames = enum { all, dev };

fn paramsOf(arena: std.mem.Allocator, e: anytype) !Params {
    const terms = try arena.alloc(Term, e.terms.len);
    for (terms, e.terms) |*t, x| {
        t.* = .{ .champion = x.champion, .role = x.role, .games = x.games, .b = x.b, .sd = x.sd, .u = x.u, .v = x.v, .s = x.s };
        if (@hasField(@TypeOf(x), "p")) t.p = x.p;
        if (@hasField(@TypeOf(x), "raw")) t.raw = x.raw;
    }
    var out: Params = .{ .kind = e.kind, .dim = e.dim, .intercept = e.intercept, .w = e.w, .z = e.z, .terms = terms };
    if (@hasField(@TypeOf(e), "comp")) if (e.comp) |c| {
        const stats = try arena.alloc(Stat, c.stats.len);
        for (stats, c.stats) |*st, x| st.* = .{ .name = x.name, .label = x.label };
        const team = try arena.alloc(TeamTerm, c.team.len);
        for (team, c.team) |*tt, x| {
            tt.* = .{ .kind = x.kind, .stat = x.stat, .centre = x.centre, .weight = x.weight };
            if (@hasField(@TypeOf(x), "sd")) tt.sd = x.sd;
        }
        out.comp = .{ .stats = stats, .S = c.S, .A = c.A, .S_sd = c.S_sd, .A_sd = c.A_sd, .team = team, .beta = c.beta };
    };
    // A candidate's own pair cells (win-draft: the shipped model's duos and matchups)
    if (@hasField(@TypeOf(e), "pairs")) if (e.pairs) |pr| {
        const groups = try arena.alloc(PairGroup, pr.groups.len);
        for (groups, pr.groups) |*g, x| g.* = .{ .name = x.name, .kind = x.kind, .r = x.r, .q = x.q, .sd = x.sd, .fitted = x.fitted, .shipped = x.shipped };
        const cells = try arena.alloc(PairCell, pr.cells.len);
        for (cells, pr.cells) |*c, x| c.* = .{ .group = x.group, .a = x.a, .b = x.b, .theta = x.theta, .games = x.games };
        out.pairs = .{ .min_games = pr.min_games, .groups = groups, .cells = cells };
    };
    return out;
}

pub fn main(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: Io, argv: []const []const u8) !u8 {
    if (argv.len < 1) {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    }
    const snap = argv[0];
    // --model, --pair-floor and --fit may sit anywhere after SNAP
    var model: ModelKind = .cand;
    var floor: u32 = default_pair_floor;
    var fit_games: FitGames = .all;
    var rest: std.ArrayList([]const u8) = .empty;
    var i: usize = 1;
    while (i < argv.len) : (i += 1) {
        const flag = argv[i];
        if (i + 1 < argv.len and std.mem.eql(u8, flag, "--model")) {
            i += 1;
            model = std.meta.stringToEnum(ModelKind, argv[i]) orelse {
                std.debug.print("draft: --model cand|additive\n", .{});
                return 2;
            };
        } else if (i + 1 < argv.len and std.mem.eql(u8, flag, "--fit")) {
            i += 1;
            fit_games = std.meta.stringToEnum(FitGames, argv[i]) orelse {
                std.debug.print("draft: --fit all|dev\n", .{});
                return 2;
            };
        } else if (i + 1 < argv.len and std.mem.eql(u8, flag, "--pair-floor")) {
            i += 1;
            floor = try std.fmt.parseInt(u32, argv[i], 10);
        } else try rest.append(arena, flag);
    }
    const args = rest.items;
    const export_mode = args.len >= 2 and std.mem.eql(u8, args[0], "--export");
    var temperature: f64 = if (model == .additive) default_temperature_additive else default_temperature;
    if (export_mode and args.len == 4 and std.mem.eql(u8, args[2], "--temperature")) {
        temperature = try std.fmt.parseFloat(f64, args[3]);
    } else if (export_mode and args.len != 2) {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    }
    var out_buf: [16 * 1024]u8 = undefined;
    var out_file = Io.File.stdout().writer(io, &out_buf);
    const w = &out_file.interface;
    defer w.flush() catch {};

    // Unused here, but the packed rows only load when they match
    var data = try rows.loadSnap(gpa, io, snap);
    defer data.deinit();
    const eu = harness.home_index;
    var champs = try loadChampions(gpa, arena, snap, &data);

    var cm: ?cand.Model = null;
    defer if (cm) |*m| cand.deinit(m, gpa);
    var af: ?AddFit = null;
    defer if (af) |*a| a.deinit(gpa);
    var params: Params = undefined;
    var training_games = data.games.len;
    switch (model) {
        .cand => if (comptime !@hasDecl(cand, "exportModel")) {
            std.debug.print("draft: the candidate has no exportModel (src/lab/cand/win-ratings has); or --model additive\n", .{});
            return 2;
        } else {
            cm = try fitAll(gpa, &data);
            params = try paramsOf(arena, try cand.exportModel(&cm.?, arena));
        },
        .additive => {
            const played = try arena.alloc(bool, data.games.len);
            const c = try harness.cuts(gpa, &data);
            for (data.games, played) |g, *x| x.* = switch (fit_games) {
                .all => harness.played(g),
                .dev => harness.visible(.dev, c, g),
            };
            af = try fitAdditive(gpa, arena, &data, try addinputs.inputs(arena, &data), played, addinputs.fullVariant(true, 1));
            params = try paramsOfAdditive(arena, &af.?.p, &af.?.f, &af.?.mix, floor);
            training_games = af.?.p.games.len;
        },
    }
    params.temperature = temperature;
    const sc = try Scorer.init(arena, params, eu, &champs);
    try w.print("win model ({s}) fitted on {d} games; --min-games guards against thin samples; chances at temperature {d}\n", .{ params.kind, training_games, params.temperature });

    if (export_mode) {
        // The scorer must agree with the model it came from on drafts it saw whole
        const worst = if (cm) |*m| try checkCand(m, &sc, &data, w) else try checkAdditive(arena, &af.?, &sc, &data, floor, w);
        if (worst > 1e-4) return error.ScorerDisagrees;
        try w.print("dev score (refits on dev's games)...\n", .{});
        try w.flush();
        const dev = if (cm != null) try devScore(gpa, &data) else try devAdditive(gpa, arena, &data, af.?.in);
        try w.print("dev: log loss {d:.5} (baseline {d:.5}), accuracy {d:.4}, AUC {d:.4} on {d} games\n", .{ dev.log_loss, dev.baseline_log_loss, dev.accuracy, dev.auc, dev.games });
        var newest: i64 = 0;
        var tests: std.ArrayList([2][n_role]u32) = .empty;
        for (data.games) |g| {
            newest = @max(newest, g.start);
            if (g.is_test and tests.items.len < 3) try tests.append(arena, g.teams);
        }
        try df.exportFiles(arena, io, &sc, &champs, .{
            .name = if (model == .additive) "additive v2: champion strength, ally pairs, matchups, damage mix" else try arena.print("{s} ({s})", .{ if (@hasDecl(cand, "name")) cand.name else "candidate", params.kind }),
            .run = std.fs.path.basename(args[1]),
            .snapshot = std.fs.path.basename(snap),
            .newest_start = newest,
            .training_games = training_games,
            .platform = protocol.home_platform,
            .dev = dev,
            .tests = tests.items,
        }, args[1], w);
        return 0;
    }
    if (args.len > 0) {
        try run(arena, &sc, &champs, args, w);
        return 0;
    }
    var in_buf: [4096]u8 = undefined;
    var in_file = Io.File.stdin().reader(io, &in_buf);
    while (true) {
        try w.writeAll("draft> ");
        try w.flush();
        const line = try in_file.interface.takeDelimiter('\n') orelse break;
        const line_args = try splitFlags(arena, line);
        if (line_args.len == 0) continue;
        run(arena, &sc, &champs, line_args, w) catch |err| try w.print("{t}\n", .{err});
    }
    return 0;
}

/// "--role mid --ally top=Lee Sin" -> ["--role", "mid", "--ally", "top=Lee Sin"]: values
/// may hold spaces, so split only before "--"
fn splitFlags(arena: std.mem.Allocator, line: []const u8) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    var it = std.mem.tokenizeSequence(u8, line, "--");
    while (it.next()) |part| {
        const p = std.mem.trim(u8, part, " \t\r");
        if (p.len == 0) continue;
        const sp = std.mem.findAny(u8, p, " \t") orelse p.len;
        try out.append(arena, try arena.print("--{s}", .{p[0..sp]}));
        if (sp < p.len) try out.append(arena, std.mem.trim(u8, p[sp..], " \t\"'"));
    }
    return out.items;
}

fn loadChampions(gpa: std.mem.Allocator, arena: std.mem.Allocator, snap: []const u8, d: *const rows.Data) !Champions {
    var c: Champions = .{ .names = try rows.loadNames(gpa, arena, snap) };
    try c.countShares(arena, d.games);
    for (d.rows) |r| {
        const e = try c.games.getOrPut(arena, Champions.key(r.champion, @backingInt(r.role)));
        if (!e.found_existing) e.value_ptr.* = 0;
        e.value_ptr.* += 1;
    }
    return c;
}

/// A tool, not an evaluation: every game that lasted 15:00, test games included
fn fitAll(gpa: std.mem.Allocator, d: *const rows.Data) !cand.Model {
    const players = try harness.gamePlayers(gpa, d);
    defer gpa.free(players);
    var train = try harness.buildTrainBy(gpa, d, players, harness.Played{}, false);
    defer train.deinit();
    return harness.fit(cand, gpa, &train.train, .{});
}

/// The additive model fitted on the games in `fit`, its damage mix from their rows
const AddFit = struct {
    in: addinputs.Inputs,
    mix: addinputs.Mix,
    p: additive.Problem,
    f: additive.Fit,

    fn deinit(a: *AddFit, gpa: std.mem.Allocator) void {
        a.mix.deinit(gpa);
        a.p.deinit(gpa);
        a.f.deinit(gpa);
    }

    /// Blue's logit for game gi on `platform`'s side term, the mix from every fit row
    fn logit(a: *const AddFit, d: *const rows.Data, gi: usize, platform: u8, f: *const additive.Fit) f64 {
        var g = addinputs.gameIn(d, gi, 0, a.mix.diff(d, a.in, gi, false));
        g.platform = platform;
        return additive.predict(&a.p, f, &g);
    }
};

/// As effects fits a block: fit games see their own rows left out of the mix
fn fitAdditive(gpa: std.mem.Allocator, arena: std.mem.Allocator, d: *const rows.Data, in: addinputs.Inputs, fit: []const bool, variant: additive.Variant) !AddFit {
    var mix = try addinputs.Mix.init(gpa, d, fit, in.win);
    errdefer mix.deinit(gpa);
    var games: std.ArrayList(additive.GameIn) = .empty;
    for (fit, 0..) |f, gi| if (f) try games.append(arena, addinputs.gameIn(d, gi, in.win[gi], mix.diff(d, in, gi, true)));
    var p = try additive.build(gpa, .logistic, variant, games.items);
    errdefer p.deinit(gpa);
    const f = try additive.fit(gpa, &p, .{}, null, null);
    return .{ .in = in, .mix = mix, .p = p, .f = f };
}

/// Rounding keeps the file small; the scorer and the export check use the rounded values
fn round5(x: f64) f64 {
    return @round(x * 1e5) / 1e5;
}

/// The additive model as Params: champion strength as terms (sd from the posterior
/// curvature), the damage mix as comp's one team term (raw holds each champion-role's mix
/// profile: magic share at raw_magic, damage per minute at raw_dmg), pair cells on
/// floor+ games. mix null: no comp (tests)
fn paramsOfAdditive(arena: std.mem.Allocator, p: *const additive.Problem, f: *const additive.Fit, mix: ?*const addinputs.Mix, floor: u32) !Params {
    const A = additive;
    const intercept = try arena.alloc(f32, A.n_platforms);
    for (intercept, f.theta[0..A.n_platforms]) |*x, y| x.* = @floatCast(y);
    var terms: std.ArrayList(Term) = .empty;
    for (p.param_start[A.g_main]..p.param_start[A.g_ally]) |j| {
        const cl = A.cellOf(p, j);
        const role = cl.group - A.g_main;
        var t: Term = .{ .champion = cl.a, .role = @intCast(role), .games = p.count[j], .b = @floatCast(f.theta[j]), .sd = @floatCast(1 / @sqrt(f.h[j])) };
        if (mix) |m| {
            const prof = m.profile(cl.a, role, null);
            const raw = try arena.alloc(f32, raw_len);
            @memset(raw, 0);
            raw[raw_magic] = @floatCast(prof[0]);
            raw[raw_dmg] = @floatCast(prof[1]);
            t.raw = raw;
        }
        try terms.append(arena, t);
    }
    var groups: std.ArrayList(PairGroup) = .empty;
    var cells: std.ArrayList(PairCell) = .empty;
    var nbuf: [64]u8 = undefined;
    for (A.g_ally..A.n_groups) |g| {
        const lo = p.param_start[g];
        const hi = p.param_start[g + 1];
        if (hi == lo) continue;
        const gr = A.groupRoles(g);
        const gi: u32 = @intCast(groups.items.len);
        var shipped: u32 = 0;
        for (lo..hi) |j| {
            if (p.count[j] < floor) continue;
            const cl = A.cellOf(p, j);
            try cells.append(arena, .{ .group = gi, .a = cl.a, .b = cl.b, .theta = round5(f.theta[j]), .games = p.count[j] });
            shipped += 1;
        }
        try groups.append(arena, .{
            .name = try arena.dupe(u8, A.groupName(&nbuf, g)),
            .kind = if (gr.ally) "ally" else "matchup",
            .r = @intCast(gr.r),
            .q = @intCast(gr.q),
            .sd = @floatCast(@sqrt(f.sigma2[g])),
            .fitted = @intCast(hi - lo),
            .shipped = shipped,
        });
    }
    var out: Params = .{ .kind = "additive", .dim = 0, .intercept = intercept, .w = @splat(0), .z = @splat(0), .terms = terms.items };
    out.pairs = .{ .min_games = floor, .groups = groups.items, .cells = cells.items };
    if (mix != null) {
        const j = A.n_platforms;
        const team = try arena.alloc(TeamTerm, 1);
        team[0] = .{ .kind = "mix", .stat = 0, .centre = 0.5, .weight = @floatCast(f.theta[j]), .sd = @floatCast(1 / @sqrt(f.h[j])) };
        out.comp = .{ .stats = &.{}, .S = &.{}, .A = &.{}, .S_sd = &.{}, .A_sd = &.{}, .team = team };
    }
    return out;
}

/// The fit as exported: pair cells below the floor 0, the rest rounded as in the file
fn shippedFit(arena: std.mem.Allocator, p: *const additive.Problem, f: *const additive.Fit, floor: u32) !additive.Fit {
    var out = f.*;
    out.theta = try arena.dupe(f64, f.theta);
    for (p.param_start[additive.g_ally]..p.n_params()) |j| {
        out.theta[j] = if (p.count[j] < floor) 0 else round5(f.theta[j]);
    }
    return out;
}

/// The scorer against the additive model it came from (as exported) on 500 test games,
/// and what the pair floor moves on every fit game
fn checkAdditive(arena: std.mem.Allocator, af: *const AddFit, sc: *const Scorer, d: *const rows.Data, floor: u32, w: *Io.Writer) !f64 {
    const fs = try shippedFit(arena, &af.p, &af.f, floor);
    var worst: f64 = 0;
    var checked: usize = 0;
    var moved: f64 = 0;
    var moved_max: f64 = 0;
    var n: usize = 0;
    for (d.games, 0..) |g, gi| {
        if (!harness.played(g)) continue;
        const shipped = af.logit(d, gi, sc.platform, &fs);
        const x = @abs(af.logit(d, gi, sc.platform, &af.f) - shipped);
        moved += x;
        moved_max = @max(moved_max, x);
        n += 1;
        if (!g.is_test or checked == 500) continue;
        checked += 1;
        worst = @max(worst, @abs(sc.blue(g.teams).p - sigmoid(sc.e.temperature * shipped)));
    }
    var fitted: usize = 0;
    var shipped: usize = 0;
    for (sc.e.pairs.?.groups) |g| {
        fitted += g.fitted;
        shipped += g.shipped;
    }
    try w.print("pair floor {d} games: {d} of {d} pair cells exported; blue's logit moves {d:.5} on average (max {d:.4}) on {d} played games\n", .{ floor, shipped, fitted, moved / @as(f64, @floatFromInt(@max(n, 1))), moved_max, n });
    try w.print("scorer vs the additive model on {d} test games: max |diff| {e}\n", .{ checked, worst });
    return worst;
}

/// The candidate's own predict through the same temperature, on 500 test games
fn checkCand(m: *const cand.Model, sc: *const Scorer, d: *const rows.Data, w: *Io.Writer) !f64 {
    var worst: f64 = 0;
    var checked: usize = 0;
    for (d.games) |g| {
        if (!g.is_test or checked == 500) continue;
        checked += 1;
        const q: api.Query = .{ .start = g.start, .patch = g.patch, .platform = sc.platform, .side = 0, .role = .top, .champion = g.teams[0][0], .rank = null, .teams = g.teams, .ranks = null, .exp = .{}, .exps = null };
        const raw: f64 = cand.predict(m, &q)[api.outcomeIndex(.win)];
        const want = sigmoid(sc.e.temperature * @log(raw / (1 - raw)));
        worst = @max(worst, @abs(sc.blue(g.teams).p - want));
    }
    try w.print("scorer vs candidate on {d} test games: max |diff| {e}\n", .{ checked, worst });
    return worst;
}

fn run(arena: std.mem.Allocator, sc: *const Scorer, champs: *const Champions, args: []const []const u8, w: *Io.Writer) !void {
    defer w.flush() catch {};
    const d = try parseDraft(arena, champs, args, w) orelse return;
    const r = try rank(arena, sc, champs, &d);
    if (r.options.len == 0) {
        try w.print("no free champion has {d}+ games in {s}\n", .{ d.min_games, roleLabel(d.role) });
        return;
    }
    try printDraft(champs, &d, w);
    try w.print("best {s} picks (your team's win chance and 95% interval; change vs an average pick, {d:.1}%):\n", .{ roleLabel(d.role), 100 * r.average });
    for (r.options[0..@min(d.top, r.options.len)], 1..) |o, i| {
        const pp = 100 * (o.win - r.average);
        try w.print("{d:>3}. {s:<16} {d:>5.1}%  ({d:.1}-{d:.1})  {s}{d:.1} pp  {d} games\n", .{
            i, champs.name(o.champion), 100 * o.win, 100 * o.lo, 100 * o.hi, if (pp >= 0) "+" else "", pp, o.games,
        });
    }
    try w.print("worst: ", .{});
    const tail = r.options[r.options.len - @min(3, r.options.len) ..];
    for (tail, 0..) |o, i| try w.print("{s}{s} {d:.1}%", .{ if (i > 0) ", " else "", champs.name(o.champion), 100 * o.win });
    try w.writeAll("\n\n");
}

fn roleLabel(r: usize) []const u8 {
    return @as(core.Role, @fromBackingInt(@as(u3, @intCast(r)))).label();
}

fn printDraft(champs: *const Champions, d: *const Draft, w: *Io.Writer) !void {
    try w.print("you: {s}, {s} side\n", .{ roleLabel(d.role), if (d.side == 0) "blue" else "red" });
    for ([_][]const u8{ "allies ", "enemies" }, d.teams) |label, t| {
        try w.print("  {s}", .{label});
        for (t, 0..) |c, r| try w.print("  {s}={s}", .{ roleLabel(r), if (c == 0) "-" else champs.name(c) });
        try w.writeAll("\n");
    }
}

fn parseDraft(arena: std.mem.Allocator, champs: *const Champions, args: []const []const u8, w: *Io.Writer) !?Draft {
    var d: Draft = .{ .role = n_role };
    var bans: std.ArrayList(u32) = .empty;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const flag = args[i];
        if (i + 1 >= args.len) {
            try w.print("{s} needs a value\n", .{flag});
            return null;
        }
        i += 1;
        const v = args[i];
        if (std.mem.eql(u8, flag, "--role")) {
            const r = core.Role.parse(v) orelse {
                try w.print("unknown role {s}\n", .{v});
                return null;
            };
            d.role = @backingInt(r);
        } else if (std.mem.eql(u8, flag, "--side")) {
            d.side = if (std.mem.eql(u8, v, "red")) 1 else 0;
        } else if (std.mem.eql(u8, flag, "--top")) {
            d.top = std.fmt.parseInt(usize, v, 10) catch 10;
        } else if (std.mem.eql(u8, flag, "--min-games")) {
            d.min_games = std.fmt.parseInt(u32, v, 10) catch default_min_games;
        } else if (std.mem.eql(u8, flag, "--ally") or std.mem.eql(u8, flag, "--enemy")) {
            const team: usize = if (std.mem.eql(u8, flag, "--ally")) 0 else 1;
            var it = std.mem.splitScalar(u8, v, ',');
            while (it.next()) |raw| {
                var item = std.mem.trim(u8, raw, " \t\"'");
                if (item.len == 0) continue;
                var role: ?usize = null;
                if (std.mem.findScalar(u8, item, '=')) |eq| {
                    const rn = std.mem.trim(u8, item[0..eq], " \t");
                    role = if (core.Role.parse(rn)) |r| @backingInt(r) else {
                        try w.print("unknown role {s}\n", .{rn});
                        return null;
                    };
                    item = std.mem.trim(u8, item[eq + 1 ..], " \t\"'");
                }
                const c = champs.find(item) orelse {
                    try w.print("no single champion matches \"{s}\"\n", .{item});
                    return null;
                };
                d.teams[team][role orelse mainRole(champs, &d, team, c)] = c;
            }
        } else if (std.mem.eql(u8, flag, "--ban")) {
            var it = std.mem.splitScalar(u8, v, ',');
            while (it.next()) |raw| {
                const item = std.mem.trim(u8, raw, " \t\"'");
                if (item.len == 0) continue;
                const c = champs.find(item) orelse {
                    try w.print("no single champion matches \"{s}\"\n", .{item});
                    return null;
                };
                try bans.append(arena, c);
            }
        } else {
            try w.print("unknown option {s}\n", .{flag});
            return null;
        }
    }
    d.bans = bans.items;
    if (d.role == n_role) {
        try w.writeAll("--role is required\n");
        return null;
    }
    if (d.teams[0][d.role] != 0) {
        try w.print("your slot ({s}) is already picked\n", .{roleLabel(d.role)});
        return null;
    }
    return d;
}

/// A pick without a role goes to the open slot where that champion is played most
fn mainRole(champs: *const Champions, d: *const Draft, team: usize, c: u32) usize {
    var best: usize = 0;
    var most: i64 = -1;
    for (0..n_role) |r| {
        if (d.teams[team][r] != 0 or (team == 0 and r == d.role)) continue;
        const g: i64 = champs.gamesIn(c, r);
        if (g > most) {
            most = g;
            best = r;
        }
    }
    return best;
}

// ---------- export (docs/model.md "Draft model file") ----------

/// The candidate refitted on dev's visible games, scored on dev-val (lab-agent.md
/// "Splits"): log loss per row, accuracy and AUC per game on blue's chance
fn devScore(gpa: std.mem.Allocator, d: *const rows.Data) !Dev {
    const players = try harness.gamePlayers(gpa, d);
    defer gpa.free(players);
    const c = try harness.cuts(gpa, d);
    var s = try harness.score(cand, gpa, d, players, c, .dev, .{});
    defer s.deinit(gpa);
    const k = api.outcomeIndex(.win);
    const la = try s.losses(gpa, d, k, null, .cand);
    defer gpa.free(la);
    const lb = try s.losses(gpa, d, k, null, .base);
    defer gpa.free(lb);
    const p = harness.paired(s.game, la, lb, null);

    var points: std.ArrayList(Point) = .empty;
    defer points.deinit(gpa);
    var last: ?u32 = null;
    for (s.row, s.game, s.cand) |ri, g, pred| {
        const r = d.rows[ri];
        if (r.side != 0 or last == g) continue;
        last = g;
        try points.append(gpa, .{ .p = pred[k], .y = d.games[g].winner == 0 });
    }
    const aa = accuracyAuc(points.items);
    return .{
        .what = "fitted on the games older than dev-val, scored on dev-val: the 10% of played games before the test cut, every platform (docs/lab-agent.md Splits); log loss per player row of the team's win (baseline: champion averages), accuracy and AUC per game on blue's chance",
        .games = points.items.len,
        .log_loss = p.a,
        .baseline_log_loss = p.b,
        .accuracy = aa[0],
        .auc = aa[1],
    };
}

/// The additive model refitted on dev's visible games, scored on dev-val per game; the
/// baseline is champion strength alone (no pairs, no mix)
fn devAdditive(gpa: std.mem.Allocator, arena: std.mem.Allocator, d: *const rows.Data, in: addinputs.Inputs) !Dev {
    const c = try harness.cuts(gpa, d);
    const fit = try arena.alloc(bool, d.games.len);
    for (d.games, fit) |g, *x| x.* = harness.visible(.dev, c, g);
    var full = try fitAdditive(gpa, arena, d, in, fit, addinputs.fullVariant(true, 1));
    defer full.deinit(gpa);
    var base = try fitAdditive(gpa, arena, d, in, fit, additive.Variant.mains());
    defer base.deinit(gpa);
    var points: std.ArrayList(Point) = .empty;
    var la: f64 = 0;
    var lb: f64 = 0;
    for (d.games, 0..) |g, gi| {
        if (!harness.scored(.dev, c, g)) continue;
        const y = g.winner == 0;
        const pa = sigmoid(full.logit(d, gi, g.platform, &full.f));
        const pb = sigmoid(base.logit(d, gi, g.platform, &base.f));
        la -= @log(if (y) pa else 1 - pa);
        lb -= @log(if (y) pb else 1 - pb);
        try points.append(arena, .{ .p = pa, .y = y });
    }
    const n: f64 = @floatFromInt(@max(points.items.len, 1));
    const aa = accuracyAuc(points.items);
    return .{
        .what = "fitted on the games older than dev-val, scored on dev-val: the 10% of played games before the test cut, every platform (docs/lab-agent.md Splits); log loss per game of blue's win (baseline: champion strength alone), accuracy and AUC per game on blue's chance",
        .games = points.items.len,
        .log_loss = la / n,
        .baseline_log_loss = lb / n,
        .accuracy = aa[0],
        .auc = aa[1],
    };
}

test "scorer: comp terms on team-summed profiles" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var champs: Champions = .{ .patch_total = 4 };
    try champs.patch_games.put(arena, Champions.key(1, 0), 2);
    try champs.patch_games.put(arena, Champions.key(2, 0), 2);
    // As a comp candidate exports them: p on its terms, comp beside them
    const CandTerm = struct { champion: u32, role: u8, games: u32, b: f32, sd: f32, u: []const f32 = &.{}, v: []const f32 = &.{}, s: []const f32 = &.{}, p: []const f32 };
    const zero: [4]f32 = @splat(0);
    var intercept: [256]f32 = @splat(0);
    intercept[6] = 0.04;
    const e = .{
        .kind = "comp",
        .dim = @as(u32, 0),
        .intercept = @as([]const f32, &intercept),
        .w = @as([25]f32, @splat(0)),
        .z = @as([25]f32, @splat(0)),
        .terms = &[_]CandTerm{
            .{ .champion = 1, .role = 0, .games = 400, .b = 0.2, .sd = 0.1, .p = &.{ 1, 0 } },
            .{ .champion = 2, .role = 0, .games = 400, .b = -0.1, .sd = 0.1, .p = &.{ 0, 1 } },
        },
        .comp = @as(?struct { stats: []const Stat, S: []const f32, A: []const f32, S_sd: []const f32, A_sd: []const f32, team: []const TeamTerm, beta: []const f32 }, .{
            .stats = &.{ .{ .name = "magic", .label = "magic damage" }, .{ .name = "armour", .label = "armour lean" } },
            .S = &.{ 0.5, 0.1, 0.1, -0.2 },
            .A = &.{ 0, 0.3, -0.3, 0 },
            .S_sd = &zero,
            .A_sd = &zero,
            .team = &.{},
            .beta = &.{},
        }),
    };
    const sc = try Scorer.init(arena, try paramsOf(arena, e), 6, &champs);
    var teams: [2][n_role]u32 = @splat(@splat(0));
    teams[0][0] = 1;
    teams[1][0] = 2;
    // P_b (1, 0), P_r (0, 1): S 0.5 - (-0.2), A 0.3; other roles have no terms, profile 0
    try std.testing.expectApproxEqAbs(1.0, sc.compOf(teams), 1e-6);
    try std.testing.expectApproxEqAbs(sigmoid(0.34 + 1.0), sc.blue(teams).p, 1e-6);
    // Red top empty: the role average, P_r (0.5, 0.5): S 0.5 - 0.125, A 0.15
    teams[1][0] = 0;
    try std.testing.expectApproxEqAbs(0.525, sc.compOf(teams), 1e-6);
    try std.testing.expectApproxEqAbs(sigmoid(0.04 + 0.2 - 0.05 + 0.525), sc.blue(teams).p, 1e-6);
    // Sides swapped: A antisymmetric and S's sign flips, so the comp part flips
    try std.testing.expectApproxEqAbs(-0.525, sc.compOf(.{ teams[1], teams[0] }), 1e-6);
}

test "scorer: additive pair cells and strength reproduce additive.predict" {
    const gpa = std.testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const A = additive;
    var rng: std.Random.DefaultPrng = .init(5);
    const rnd = rng.random();
    // 6 champions per role, ids shared across roles so mirrors and cross-role pairs occur
    const games = try arena.alloc(A.GameIn, 3000);
    for (games) |*g| {
        g.* = .{ .teams = undefined, .platform = 0, .y = @floatFromInt(rnd.uintLessThan(u8, 2)) };
        for (0..2) |side| for (0..n_role) |r| {
            g.teams[side][r] = 1 + rnd.uintLessThan(u32, 6);
        };
    }
    var p = try A.build(gpa, .logistic, addinputs.fullVariant(true, 0), games);
    defer p.deinit(gpa);
    var f = try A.fit(gpa, &p, .{ .outer = 2 }, null, null);
    defer f.deinit(gpa);
    // Random outcomes shrink every cell to ~0: give them sizes so a wrong sign shows
    for (A.n_platforms..p.n_params()) |j| f.theta[j] = rnd.floatNorm(f64) * 0.1;
    const champs: Champions = .{ .patch_total = 1 };
    const sc = try Scorer.init(arena, try paramsOfAdditive(arena, &p, &f, null, 0), 0, &champs);
    const fs = try shippedFit(arena, &p, &f, 0);
    for (games[0..200]) |*g| {
        const c = sc.blue(g.teams);
        try std.testing.expectApproxEqAbs(A.predict(&p, &fs, g), @log(c.p / (1 - c.p)), 1e-5);
    }
    // An empty slot touches no cell; an empty board has no pair part
    try std.testing.expectEqual(0, sc.pairLogit(@splat(@splat(0))));
    var t = games[0].teams;
    for (&t[1]) |*x| x.* = 0;
    var ally: f64 = 0;
    for (sc.e.pairs.?.groups, 0..) |g, gi| {
        if (std.mem.eql(u8, g.kind, "ally")) ally += sc.cell(gi, t[0][g.r], t[0][g.q]);
    }
    try std.testing.expectApproxEqAbs(ally, sc.pairLogit(t), 1e-12);
}

test "flags split before --, values keep spaces" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const got = try splitFlags(arena.allocator(), "--role mid --ally top=Darius,jungle=Lee Sin --side red");
    try std.testing.expectEqual(@as(usize, 6), got.len);
    try std.testing.expectEqualStrings("top=Darius,jungle=Lee Sin", got[3]);
    try std.testing.expectEqualStrings("red", got[5]);
}
