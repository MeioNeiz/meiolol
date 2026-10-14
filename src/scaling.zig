//! `meiolol scaling`: which champions win more than the game state says, and when?
//! Rows: every player at minute 0 (the draft) and 10/15/20/25/30 of games reaching
//! 15:00 and still going then. A logistic baseline per minute gives the win chance from
//! the team gold and XP lead (objectives.zig's lead features); on top of it, in log-odds,
//! the champion in its role (by minute: the scaling curve) and the champion's slope on
//! the team gold lead (converts a lead, or comes back from behind), each shrunk toward 0
//! by a method-of-moments prior per role (as items.zig, on IRLS weights). Descriptive:
//! a champion's players and teams differ in ways the state misses. Use-time: lessons and
//! aggregate facts ("from 2k behind at 15, X comes back more often than Y").
//! Split as docs/model.md "Shared protocol, 2026-10-12".

const std = @import("std");
const store = @import("store");
const core = @import("core");
const stats = @import("stats.zig");
const eval = @import("eval.zig");
const analysis = @import("analysis.zig");
const logreg = @import("logreg.zig");
const objectives = @import("objectives.zig");
const Date = @import("date.zig").Date;
const Role = core.Role;
const Io = std.Io;

pub const Options = struct {
    test_share: f64 = eval.test_share,
    /// Region model only; the global model is never scored on a region
    test_platform: ?[]const u8 = null,
    passes: u32 = 8,
    /// One TSV per model of every test row's prediction
    preds_dir: ?[]const u8 = null,
    /// TSV of every champion-role's effect and lead slope by minute
    table: ?[]const u8 = null,
    state: State = .lead,
    slope: Slope = .team,
};

/// What the baseline knows, own side minus the enemy's
pub const State = enum {
    /// team gold (with objectives' curve term) and XP
    lead,
    /// gold by role (who holds it), the team gold curve term, XP
    roles,
    /// objectives.zig's lead and objectives held (winchance's state)
    objectives,

    fn dims(s: State) usize {
        return switch (s) {
            .lead => objectives.lead.len,
            .roles => Role.count + 2,
            .objectives => objectives.lead.len + objectives.held.len,
        };
    }
};

/// The champion x lead term's lead
pub const Slope = enum {
    team,
    /// the player's own gold minus their lane opponent's: is gold on this champion worth
    /// more than on others in the role?
    own,
};

const minute_ms = 60_000;
/// 0: the draft, no state
const minutes = [_]u8{0} ++ objectives.minutes;
const n_min = minutes.len;
/// Champion-roles shown in the markdown need this many train games
const shown_games = 500;

/// One player at one minute
const Row = struct {
    game: u32,
    /// participant id - 1
    slot: u8,
    role: u8,
    champ: u16,
    /// own side's team gold lead and own gold minus the lane opponent's, thousands
    gold: f32,
    own: f32,
    /// the baseline's features, own side's (State.dims of them)
    x: [max_x]f32,
    won: bool,
};
const max_x = objectives.lead.len + objectives.held.len;

const Game = struct {
    match_id: []const u8,
    /// [side][role]: participant id - 1
    slot: [2][Role.count]u8,
    /// blue minus red (null: ended by then)
    states: [n_min]?Snap,
};

const Snap = struct {
    obj: objectives.State,
    /// gold by role, thousands
    roles: [Role.count]f32,
};

const Map = std.AutoHashMapUnmanaged(u64, Game);

fn load(
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    db: store.Db,
    chosen: []const []const u8,
    platforms: []const []const u8,
) !Map {
    var games: analysis.TimelineGames = try .init(gpa, db, chosen, platforms);
    defer games.deinit();
    var map: Map = .empty;
    errdefer map.deinit(gpa);
    while (try games.next()) |game| {
        const t = game.t;
        if (t.participants != 10 or t.frames.len < 16 or t.frames[15].t_ms < 15 * minute_ms) continue;
        const pid = try games.pids(game) orelse continue;
        var g: Game = .{ .match_id = undefined, .slot = undefined, .states = undefined };
        for (0..2) |side| for (0..Role.count) |ri| {
            g.slot[side][ri] = pid[side][ri] - 1;
        };
        for (minutes, &g.states) |m, *snap| {
            if (m == 0) {
                snap.* = .{ .obj = @splat(0), .roles = @splat(0) };
                continue;
            }
            const s = objectives.stateAt(t, m) orelse {
                snap.* = null;
                continue;
            };
            var roles: [Role.count]f32 = undefined;
            for (&roles, pid[0], pid[1]) |*r, blue, red| {
                const f = t.frames[m];
                r.* = @as(f32, @floatFromInt(f.get(blue, .total_gold) - f.get(red, .total_gold))) / 1000;
            }
            snap.* = .{ .obj = s, .roles = roles };
        }
        g.match_id = try arena.dupe(u8, game.match_id);
        try map.put(gpa, stats.matchKey(game.match_id), g);
    }
    return map;
}

/// The baseline's features from blue's state, for a side (sign -1: red; every feature
/// is blue minus red, the curve term too)
fn features(state: State, snap: Snap, sign: f32) [max_x]f32 {
    var x: [max_x]f32 = @splat(0);
    switch (state) {
        .lead, .objectives => {
            const feats = if (state == .lead) objectives.lead else objectives.lead ++ objectives.held;
            for (feats, x[0..feats.len]) |f, *v| v.* = sign * snap.obj[@backingInt(f)];
        },
        .roles => {
            for (snap.roles, x[0..Role.count]) |g, *v| v.* = sign * g;
            x[Role.count] = sign * snap.obj[@backingInt(objectives.Feat.gold_curve)];
            x[Role.count + 1] = sign * snap.obj[@backingInt(objectives.Feat.xp)];
        },
    }
    return x;
}

fn featureName(w: *Io.Writer, state: State, i: usize) !void {
    switch (state) {
        .lead => try w.print("{t}", .{objectives.lead[i]}),
        .objectives => try w.print("{t}", .{(objectives.lead ++ objectives.held)[i]}),
        .roles => if (i < Role.count)
            try w.print("{t} gold", .{@as(Role, @fromBackingInt(@intCast(i)))})
        else
            try w.writeAll(if (i == Role.count) "gold_curve" else "xp"),
    }
}

/// Win chance from the state alone; minute 0 has only the intercept
fn baseRow(state: State, r: Row) logreg.Row {
    var b: logreg.Row = .{ .y = @floatFromInt(@intFromBool(r.won)) };
    b.add(0, 1);
    for (r.x[0..state.dims()], 1..) |v, i| b.add(@intCast(i), v);
    return b;
}

/// The baseline's log-odds per 1000 team gold lead (spread evenly over roles in .roles)
fn goldWeight(state: State, wt: []const f64) f64 {
    return switch (state) {
        .lead, .objectives => wt[1],
        .roles => blk: {
            var sum: f64 = 0;
            for (wt[1..][0..Role.count]) |v| sum += v;
            break :blk sum / Role.count;
        },
    };
}

/// Shrunk log-odds effects per champion-role cell, times x (x = 1: a shift; x = gold
/// lead: a slope per 1000), fitted by Newton steps on the working residual of the whole
/// model (IRLS: weight p(1-p)), with a method-of-moments prior on their spread per role
const Term = struct {
    b: []f64,
    /// sum of p(1-p) x^2 per cell: the information behind each effect
    sxx: []f64,
    n: []f64,
    /// [role]: spread of true effects (0: off)
    tau: [Role.count]f64 = @splat(0),

    fn init(gpa: std.mem.Allocator, cells: usize) !Term {
        const t: Term = .{
            .b = try gpa.alloc(f64, cells),
            .sxx = try gpa.alloc(f64, cells),
            .n = try gpa.alloc(f64, cells),
        };
        @memset(t.b, 0);
        return t;
    }

    fn deinit(t: Term, gpa: std.mem.Allocator) void {
        gpa.free(t.b);
        gpa.free(t.sxx);
        gpa.free(t.n);
    }

    /// Posterior sd of a cell's effect (0 when the term is off for its role)
    fn sd(t: Term, cell: usize, champs: usize) f64 {
        const tau = t.tau[cell / champs];
        if (tau == 0) return 0;
        return 1 / @sqrt(t.sxx[cell] + 1 / (tau * tau));
    }
};

const Cov = enum { one, team, own };

fn covariate(cov: Cov, r: Row) f64 {
    return switch (cov) {
        .one => 1,
        .team => r.gold,
        .own => r.own,
    };
}

fn cellOf(champs: usize, r: Row) usize {
    return @as(usize, r.role) * champs + r.champ;
}

/// One backfitting step for `t`; `eta` is each row's log-odds from the whole model
/// (updated in place)
fn update(gpa: std.mem.Allocator, t: *Term, cov: Cov, champs: usize, rows: []const Row, eta: []f64) !void {
    const sxr = try gpa.alloc(f64, t.b.len);
    defer gpa.free(sxr);
    @memset(sxr, 0);
    @memset(t.sxx, 0);
    @memset(t.n, 0);
    for (rows, eta) |r, e| {
        const c = cellOf(champs, r);
        const x = covariate(cov, r);
        const p = logreg.sigmoid(e);
        const wx2 = p * (1 - p) * x * x;
        // sum w x z for the working response z = (y - p) / w + b x
        sxr[c] += x * (@as(f64, @floatFromInt(@intFromBool(r.won))) - p) + t.b[c] * wx2;
        t.sxx[c] += wx2;
        t.n[c] += 1;
    }
    const old = try gpa.dupe(f64, t.b);
    defer gpa.free(old);
    for (0..Role.count) |ri| {
        const lo = ri * champs;
        const cell_xr = sxr[lo..][0..champs];
        const cell_xx = t.sxx[lo..][0..champs];
        // Working response on the log-odds scale: unit residual variance
        const prior: analysis.Prior = .estimate(cell_xr, cell_xx, t.n[lo..][0..champs], 1);
        t.tau[ri] = @sqrt(prior.tau2);
        for (t.b[lo..][0..champs], cell_xr, cell_xx) |*b, xr, xx| b.* = prior.effect(xr, xx);
    }
    for (rows, eta) |r, *e| {
        const c = cellOf(champs, r);
        e.* += (t.b[c] - old[c]) * covariate(cov, r);
    }
}

/// spreadBounds for a fitted term, on its working response at the final `eta`
fn slopeBounds(gpa: std.mem.Allocator, t: *const Term, cov: Cov, champs: usize, rows: []const Row, eta: []const f64, n_games: usize) ![Role.count]?f64 {
    const parts = try gpa.alloc(analysis.Part, rows.len);
    defer gpa.free(parts);
    for (parts, rows, eta) |*part, r, e| {
        const c = cellOf(champs, r);
        const x = covariate(cov, r);
        const p = logreg.sigmoid(e);
        const wx2 = p * (1 - p) * x * x;
        part.* = .{
            .game = r.game,
            .cell = @intCast(c),
            .xr = x * (@as(f64, @floatFromInt(@intFromBool(r.won))) - p) + t.b[c] * wx2,
            .xx = wx2,
        };
    }
    return analysis.spreadBounds(gpa, parts, n_games, champs, true, 1);
}

const Model = struct { label: []const u8, file: []const u8 };

const models = [_]Model{
    .{ .label = "state", .file = "3c-scale-state" },
    .{ .label = "champion, one effect for minutes 10-30", .file = "3c-scale-pooled" },
    .{ .label = "champion by minute", .file = "3c-scale-champ" },
    .{ .label = "champion x gold lead", .file = "3c-scale-slope" },
};
const pooled_model = 1;

/// Gain columns: model, against model
const gains = [_][2]usize{ .{ 1, 0 }, .{ 2, 0 }, .{ 2, 1 }, .{ 3, 2 } };

/// One minute's rows, baseline and fits
const Minute = struct {
    train: std.ArrayList(Row) = .empty,
    tests: std.ArrayList(Row) = .empty,
    /// baseline log-odds per row
    base_train: []f64 = &.{},
    base_test: []f64 = &.{},
    /// the baseline's log-odds per 1000 team gold lead, at an even game
    gold_w: f64 = 0,
    /// the baseline's weights on the state's features
    base_w: [max_x]f64 = @splat(0),
    champ: ?Term = null,
    slope: ?Term = null,
    /// [role]: upper 95% bound on the slope's spread (analysis.spreadBounds)
    slope_bound: [Role.count]?f64 = @splat(null),
};

pub fn run(
    gpa: std.mem.Allocator,
    io: Io,
    db: store.Db,
    patches: []const []const u8,
    platforms: []const []const u8,
    opts: Options,
    w: *Io.Writer,
) !void {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var split = try analysis.heldOut(gpa, db, patches, platforms, opts.test_share, opts.test_platform);
    defer split.deinit();

    var map = try load(gpa, arena, db, patches, platforms);
    defer map.deinit(gpa);

    var champ_index: analysis.DenseIndex = .{};
    defer champ_index.deinit(gpa);
    var test_ids: std.ArrayList([]const u8) = .empty;
    defer test_ids.deinit(gpa);
    var at: [n_min]Minute = @splat(.{});
    defer for (&at) |*m| {
        m.train.deinit(gpa);
        m.tests.deinit(gpa);
        if (m.champ) |t| t.deinit(gpa);
        if (m.slope) |t| t.deinit(gpa);
    };
    var n_games: [2]u32 = @splat(0);
    for (split.parts(), [_]bool{ false, true }) |part, is_test| for (part) |g| {
        const gm = map.get(g.id) orelse continue;
        if (is_test) try test_ids.append(gpa, gm.match_id);
        const game = n_games[@intFromBool(is_test)];
        n_games[@intFromBool(is_test)] += 1;
        for (0..2) |side| for (0..Role.count) |ri| {
            const champ = try champ_index.get(gpa, g.teams[side][ri]);
            const sign: f32 = if (side == 0) 1 else -1;
            for (gm.states, &at) |st, *m| {
                const snap = st orelse continue;
                try (if (is_test) &m.tests else &m.train).append(gpa, .{
                    .game = game,
                    .slot = gm.slot[side][ri],
                    .role = @intCast(ri),
                    .champ = champ,
                    .gold = sign * snap.obj[@backingInt(objectives.Feat.gold)],
                    .own = sign * snap.roles[ri],
                    .x = features(opts.state, snap, sign),
                    .won = g.winner == side,
                });
            }
        };
    };
    if (at[0].train.items.len == 0 or at[0].tests.items.len == 0) return error.TooFewGames;
    const champs = champ_index.ids.items.len;
    const cells = Role.count * champs;
    const slope_cov: Cov = switch (opts.slope) {
        .team => .team,
        .own => .own,
    };

    try w.print("# meiolol scaling\n\nTrain: {d} games reaching 15:00, every scanned platform, " ++
        "started before {f} ({d}). Test: {d} {s} games from then. Ten rows per game and " ++
        "minute while it is still going; minute 0 is the draft (no state). State: {t}; " ++
        "slope on the {t} gold lead.\n", .{
        n_games[0], Date.fromMs(split.cutoff), split.cutoff, n_games[1], opts.test_platform orelse "every platform's", opts.state, opts.slope,
    });

    for (&at) |*m| {
        const rows = try gpa.alloc(logreg.Row, m.train.items.len);
        defer gpa.free(rows);
        for (rows, m.train.items) |*b, x| b.* = baseRow(opts.state, x);
        // Minute 0: the state's features are all 0, so they stay 0
        const wt = try logreg.fit(gpa, 1 + opts.state.dims(), rows, 1);
        defer gpa.free(wt);
        m.gold_w = goldWeight(opts.state, wt);
        @memcpy(m.base_w[0..opts.state.dims()], wt[1..]);
        m.base_train = try arena.alloc(f64, m.train.items.len);
        for (m.base_train, rows) |*e, b| e.* = b.dot(wt);
        m.base_test = try arena.alloc(f64, m.tests.items.len);
        for (m.base_test, m.tests.items) |*e, x| e.* = baseRow(opts.state, x).dot(wt);
    }

    var pooled = try Term.init(gpa, cells);
    defer pooled.deinit(gpa);
    {
        var rows: std.ArrayList(Row) = .empty;
        defer rows.deinit(gpa);
        var eta: std.ArrayList(f64) = .empty;
        defer eta.deinit(gpa);
        for (at[1..]) |m| {
            try rows.appendSlice(gpa, m.train.items);
            try eta.appendSlice(gpa, m.base_train);
        }
        for (0..opts.passes) |_| try update(gpa, &pooled, .one, champs, rows.items, eta.items);
    }

    for (&at, minutes) |*m, minute| {
        const eta = try gpa.dupe(f64, m.base_train);
        defer gpa.free(eta);
        var champ = try Term.init(gpa, cells);
        errdefer champ.deinit(gpa);
        var slope = try Term.init(gpa, cells);
        errdefer slope.deinit(gpa);
        for (0..opts.passes) |_| {
            try update(gpa, &champ, .one, champs, m.train.items, eta);
            try update(gpa, &slope, slope_cov, champs, m.train.items, eta);
        }
        m.champ = champ;
        m.slope = slope;
        if (minute > 0) m.slope_bound = try slopeBounds(gpa, &slope, slope_cov, champs, m.train.items, eta, n_games[0]);
    }

    var names: [models.len][]const u8 = undefined;
    for (&names, models) |*n, m| {
        // Variants other than the first run's get their own files
        n.* = if (opts.state == .lead and opts.slope == .team)
            m.file
        else
            try std.fmt.allocPrint(arena, "{s}-{t}-{t}", .{ m.file, opts.state, opts.slope });
    }
    const preds: analysis.Preds = try .init(arena, io, opts.preds_dir, &names, "match_id\tslot\tminute\ty\tpred\n");
    defer preds.close(io);

    try w.writeAll("\nTest log loss of the player's win, nats per row; gain = drop in it, ± 95% " ++
        "clustered by game. State: the baseline (minute 0: the train win rate); its win " ++
        "pp per 1000 team gold lead in an even game in brackets.\n\n" ++
        "| minute | train rows | test rows | state |");
    for (gains) |g| try w.print(" {s} vs {s} |", .{ models[g[0]].label, models[g[1]].label });
    try w.writeAll("\n| --- | --- | --- | --- |");
    for (gains) |_| try w.writeAll(" --- |");
    try w.writeAll("\n");
    for (at, minutes) |m, minute| {
        var loss: [models.len][]f64 = undefined;
        for (&loss) |*l| l.* = try arena.alloc(f64, m.tests.items.len);
        for (m.tests.items, m.base_test, 0..) |r, e0, i| {
            const c = cellOf(champs, r);
            const y: f64 = @floatFromInt(@intFromBool(r.won));
            const eta = [models.len]f64{
                e0,
                e0 + if (minute == 0) 0 else pooled.b[c],
                e0 + m.champ.?.b[c],
                e0 + m.champ.?.b[c] + m.slope.?.b[c] * covariate(slope_cov, r),
            };
            for (loss, eta, 0..) |l, e, k| {
                const x = logreg.sigmoid(e);
                l[i] = analysis.logLoss(x, y);
                if (preds.on()) try preds.at(k).print("{s}\t{d}\t{d}\t{d}\t{d:.4}\n", .{
                    test_ids.items[r.game], r.slot, minute, y, std.math.clamp(x, 1e-4, 1 - 1e-4),
                });
            }
        }
        try w.print("| {d} | {d} | {d} | {d:.4} [{d:.1}] |", .{
            minute, m.train.items.len, m.tests.items.len, analysis.mean(loss[0]), 25 * m.gold_w,
        });
        for (gains) |pair| {
            if (minute == 0 and (pair[0] == pooled_model or pair[1] == pooled_model)) {
                try w.writeAll(" - |");
                continue;
            }
            const g = analysis.pairedGain(m.tests.items, loss[pair[1]], loss[pair[0]]);
            try w.print(" {d:.5} ± {d:.5} |", .{ g.mean, g.half_width });
        }
        try w.writeAll("\n");
    }
    try w.writeAll("\nChampion by minute vs one effect for minutes 10-30 measures the scaling " ++
        "curve: whether a champion's value beyond the state changes with the minute.\n");

    try w.writeAll("\nBaseline: win pp per unit of each state feature in an even game (log-odds " ++
        "x 25; gold and XP in thousands)\n\n| feature |");
    for (minutes[1..]) |minute| try w.print(" {d} min |", .{minute});
    try w.writeAll("\n| --- |");
    for (minutes[1..]) |_| try w.writeAll(" --- |");
    try w.writeAll("\n");
    for (0..opts.state.dims()) |i| {
        try w.writeAll("| ");
        try featureName(w, opts.state, i);
        try w.writeAll(" |");
        for (at[1..]) |m| try w.print(" {d:.2} |", .{25 * m.base_w[i]});
        try w.writeAll("\n");
    }

    try w.print("\nSpread of true effects (sd across champions in the role): champion " ++
        "given the state, win pp in an even game (log-odds x 25); [its slope on the {t} " ++
        "gold lead, pp per 1000]\n\n| role |", .{opts.slope});
    for (minutes) |minute| try w.print(" {d} min |", .{minute});
    try w.writeAll("\n| --- |");
    for (minutes) |_| try w.writeAll(" --- |");
    try w.writeAll("\n");
    for (Role.all, 0..) |role, ri| {
        try w.print("| {t} |", .{role});
        for (at, minutes) |m, minute| {
            try w.print(" {d:.1}", .{25 * m.champ.?.tau[ri]});
            if (minute > 0) try w.print(" [{d:.2}]", .{25 * m.slope.?.tau[ri]});
            try w.writeAll(" |");
        }
        try w.writeAll("\n");
    }

    try w.print("\nUpper 95% bound on the slope's spread, pp per 1000 ({d} resamples of " ++
        "train games, analysis.spreadBounds; the estimate above is cut at 0, this is not)" ++
        "\n\n| role |", .{analysis.bound_reps});
    for (minutes[1..]) |minute| try w.print(" {d} min |", .{minute});
    try w.writeAll("\n| --- |");
    for (minutes[1..]) |_| try w.writeAll(" --- |");
    try w.writeAll("\n");
    for (Role.all, 0..) |role, ri| {
        try w.print("| {t} |", .{role});
        for (at[1..]) |m| if (m.slope_bound[ri]) |b| try w.print(" {d:.2} |", .{25 * b}) else try w.writeAll(" - |");
        try w.writeAll("\n");
    }

    var name = try db.prepare("SELECT name FROM champions WHERE id = ?");
    defer name.deinit();
    const champ_names = try arena.alloc([]const u8, champs);
    for (champ_names, champ_index.ids.items) |*n, id| {
        try name.bind(.{@as(i64, id)});
        n.* = if (try name.step()) try arena.dupe(u8, name.bytes(0)) else try std.fmt.allocPrint(arena, "#{d}", .{id});
    }

    if (opts.table) |path| {
        const cwd = Io.Dir.cwd();
        const f = try cwd.createFile(io, path, .{});
        defer f.close(io);
        var buf: [16 * 1024]u8 = undefined;
        var fw = f.writer(io, &buf);
        try fw.interface.writeAll("champion\trole\tminute\ttrain_rows\teffect\teffect_sd\tslope\tslope_sd\n");
        for (0..cells) |c| for (at, minutes) |m, minute| {
            const n = m.champ.?.n[c];
            if (n == 0) continue;
            try fw.interface.print("{s}\t{t}\t{d}\t{d}\t{d:.4}\t{d:.4}\t{d:.4}\t{d:.4}\n", .{
                champ_names[c % champs], @as(Role, @fromBackingInt(@intCast(c / champs))), minute,         n,
                m.champ.?.b[c],          m.champ.?.sd(c, champs),                          m.slope.?.b[c], m.slope.?.sd(c, champs),
            });
        };
        try fw.interface.flush();
    }

    try lessons(w, arena, &at, champs, champ_names);
    try preds.flush();
}

/// Index of a minute in `minutes`
fn mi(minute: u8) usize {
    return std.mem.indexOfScalar(u8, &minutes, minute).?;
}

const Shown = struct { cell: usize, key: f64, sd: f64 };

fn byKey(_: void, a: Shown, b: Shown) bool {
    return a.key > b.key;
}

/// Per role: the champions that gain most from minute 10 to 25, and the ones that win
/// most beyond the state at 15 and 25, also as the gold lead worth the same
fn lessons(w: *Io.Writer, arena: std.mem.Allocator, at: *const [n_min]Minute, champs: usize, names: []const []const u8) !void {
    const m10 = at[mi(10)].champ.?;
    const draft = at[0].champ.?;
    try w.print("\nPer role, champions with {d}+ train games. Effects in win pp in an even game " ++
        "(log-odds x 25) beyond the state then, against an average champion in the role, ± 95%. " ++
        "Scaling: effect at 25 minus at 10. At 15 / 25: the effect then, and [the team gold " ++
        "lead worth the same then, in an even game].\n", .{shown_games});
    for (Role.all, 0..) |role, ri| {
        var list: std.ArrayList(Shown) = .empty;
        for (0..champs) |ci| {
            const c = ri * champs + ci;
            if (draft.n[c] < shown_games) continue;
            try list.append(arena, .{ .cell = c, .key = 0, .sd = 0 });
        }
        if (list.items.len == 0) continue;
        try w.print("\n#### {t}\n\n| list | champion | draft | 10 min | 15 min | 20 min | 25 min | 30 min | " ++
            "key ± 95% | games |\n| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |\n", .{role});
        const Kind = enum { scaling, at_15, at_25 };
        for ([_]Kind{ .scaling, .at_15, .at_25 }) |kind| {
            const then: ?Minute = switch (kind) {
                .scaling => null,
                .at_15 => at[mi(15)],
                .at_25 => at[mi(25)],
            };
            for (list.items) |*s| {
                const c = s.cell;
                const m = (then orelse at[mi(25)]).champ.?;
                s.key = m.b[c] - if (then == null) m10.b[c] else 0;
                s.sd = if (then == null) std.math.hypot(m.sd(c, champs), m10.sd(c, champs)) else m.sd(c, champs);
            }
            std.mem.sort(Shown, list.items, {}, byKey);
            const k = @min(5, list.items.len / 2);
            for ([_][]const Shown{ list.items[0..k], list.items[list.items.len - k ..] }, [_][]const u8{ "most", "least" }) |part, which| {
                for (part) |s| {
                    try w.print("| {t}, {s} | {s} |", .{ kind, which, names[s.cell % champs] });
                    for (at) |m| try w.print(" {d:.1} |", .{25 * m.champ.?.b[s.cell]});
                    try w.print(" {d:.1} ± {d:.1}", .{ 25 * s.key, 25 * 1.96 * s.sd });
                    if (then) |m| try w.print(" [{d:.0}]", .{1000 * s.key / m.gold_w});
                    try w.print(" | {d:.0} |\n", .{draft.n[s.cell]});
                }
            }
        }
    }
}

const testing = std.testing;

test "shrunk effects recover a champion's shift and slope" {
    const gpa = testing.allocator;
    const champs = 30;
    var rows: std.ArrayList(Row) = .empty;
    defer rows.deinit(gpa);
    var prng: std.Random.DefaultPrng = .init(1);
    const rand = prng.random();
    for (0..150_000) |i| {
        const champ: u16 = @intCast(i % champs);
        const gold: f32 = @floatCast(rand.floatNorm(f64) * 3);
        // Log-odds: champions 0-14 shift by +-0.3; 0-9 also gain or lose 0.1 per 1000 gold
        const shift: f64 = if (champ < 15) (if (champ % 2 == 0) 0.3 else -0.3) else 0;
        const slope: f64 = if (champ < 10) (if (champ % 3 == 1) 0.1 else -0.1) else 0;
        const won = rand.float(f64) < logreg.sigmoid(shift + slope * gold);
        try rows.append(gpa, .{ .game = @intCast(i), .slot = 0, .role = 0, .champ = champ, .gold = gold, .own = 0, .x = @splat(0), .won = won });
    }
    const eta = try gpa.alloc(f64, rows.items.len);
    defer gpa.free(eta);
    @memset(eta, 0);
    var champ = try Term.init(gpa, Role.count * champs);
    defer champ.deinit(gpa);
    var slope = try Term.init(gpa, Role.count * champs);
    defer slope.deinit(gpa);
    for (0..8) |_| {
        try update(gpa, &champ, .one, champs, rows.items, eta);
        try update(gpa, &slope, .team, champs, rows.items, eta);
    }
    // Sampling sd: about 0.04 for a shift, 0.015 for a slope
    try testing.expectApproxEqAbs(0.3, champ.b[0], 0.1);
    try testing.expectApproxEqAbs(-0.3, champ.b[1], 0.1);
    try testing.expectApproxEqAbs(0, champ.b[20], 0.1);
    try testing.expectApproxEqAbs(0.1, slope.b[1], 0.035);
    try testing.expectApproxEqAbs(-0.1, slope.b[2], 0.035);
    try testing.expectApproxEqAbs(0, slope.b[20], 0.035);
    // Half the champions at +-0.3: sd 0.21
    try testing.expect(champ.tau[0] > 0.17 and champ.tau[0] < 0.25);
    try testing.expect(champ.sd(0, champs) > 0.02 and champ.sd(0, champs) < 0.06);
    // No other role has rows: off
    try testing.expectEqual(0, champ.tau[1]);
}
