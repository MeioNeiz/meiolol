//! `meiolol-lab champcomp SNAP`: which champions do better or worse into which enemy comps,
//! and beside which allies (docs/model.md "Champions into comps"). Built with
//! -Dcand=src/lab/cand/win-ratings: its predictions are the offset, as comps'.
//!
//! Traits of a set of seats, from comps' champion-role profiles (fit games only, z within
//! role): AP share of damage, melee count, CC, engage, dive, tank, sustain, early power.
//! A team sees the enemy's five and its own five (team terms, fitted once over teams); a
//! seat sees the enemy's five and its four allies (16 features, standardised on the fit
//! units, centred on its champion-role's mean). Every seat of a team shares the enemy's
//! traits, so only a champion's difference from its role's average is identifiable per
//! seat: per champion-role with min_cell_games fit games, one logistic step from the
//! offset (ratings plus team terms) gives raw slopes with model-based se (the sandwich's
//! small-cell bias inflated the spread: planted data with no spread came out worse than
//! ratings); per role and feature the precision-weighted mean comes off, and the
//! deviations are shrunk to 0 by empirical Bayes (spread by DerSimonian-Laird, 0 unless
//! its Q test passes at 1%). Two
//! passes: the second's offset adds the other nine seats' deviation terms.
//!
//! Folds as comps' (harness.Cuts.bounds): fold k fits on dev games before its block and
//! scores the block; dev-val fits on every dev game. The fit games' ratings offset is
//! in-sample (ratings fitted on the same games), the scored games' out of sample. Log loss
//! per game against ratings alone, paired. Reported effects: the dev-val fit. Replication:
//! deviations clear in fold 3's fit (games before bounds[2]) against raw deviations on the
//! newer dev games. Controls: --permute-profiles SEED (profiles shuffled among a role's
//! champions), --shuffle-traits SEED (each unit's features from another unit of its role).
//! Writes champcomp.tsv, roles.tsv, team.tsv, profiles.tsv, examples.tsv,
//! effects-champcomp-*.tsv and findings.tsv in the working directory; last stdout line
//! RESULT

const std = @import("std");
const api = @import("api");
const cand = @import("cand");
const store = @import("store");
const rows = @import("rows.zig");
const harness = @import("harness.zig");
const compstats = @import("compstats.zig");
const comps = @import("comps.zig");
const synth = @import("synth.zig");

const Io = std.Io;
const Allocator = std.mem.Allocator;
const vi = comps.vi;

pub const usage =
    \\  champcomp SNAP [--permute-profiles SEED] [--shuffle-traits SEED]
    \\                                  champions into comps, dev only, built with
    \\                                  -Dcand=src/lab/cand/win-ratings (or win-comp, an
    \\                                  offset with the damage mix, or win-draft, the
    \\                                  shipped model): per champion-role,
    \\                                  win against the enemy team's and its allies'
    \\                                  traits beyond ratings and its role's average,
    \\                                  shrunk, on comps' folds and dev-val
    \\                                  (lab/champcomp.zig); SNAP may be plant:SPEC:PATH
    \\                                  (champ_melee, cell)
    \\
;

pub const Trait = enum { ap_share, melee, cc, engage, dive, tank, sustain, early };
pub const nt = @typeInfo(Trait).@"enum".field_names.len;
const trait_names = @typeInfo(Trait).@"enum".field_names;
/// Features: the enemy team's traits, then the allies' (a team's own five for team terms)
pub const nf = 2 * nt;

const trait_words = [nt][]const u8{
    "AP share of damage",
    "melee champions",
    "crowd control",
    "engage",
    "dive",
    "tankiness",
    "sustain",
    "early power",
};

const role_names = [_][]const u8{ "top", "jungle", "middle", "bottom", "support" };

/// Champion-roles with fewer fit games than this get no terms of their own
const min_cell_games = 300;
/// Base attack range under this is melee
pub const melee_range = 300;
/// A clear effect: posterior |mean| / sd at or above this (two-sided 1%)
const clear_z = 2.58;
const passes = 2;
const pp_per_logit = synth.pp_per_logit;
const nan = std.math.nan(f64);

/// One seat's part in a set's traits
pub const Seat = struct {
    magic: f64,
    dmg: f64,
    /// Sums of role z per trait; ap_share unused
    v: [nt]f64,
};

pub fn seatOf(p: *const comps.Profiles, champion: u32, role: usize) Seat {
    const raw = p.raw_of(champion, role);
    const z = p.z(role, raw);
    var s: Seat = .{
        .magic = raw[vi(.magic_dpm)],
        .dmg = raw[vi(.phys_dpm)] + raw[vi(.magic_dpm)] + raw[vi(.true_dpm)],
        .v = @splat(0),
    };
    s.v[@backingInt(Trait.melee)] = @floatFromInt(@intFromBool(raw[vi(.range)] < melee_range));
    s.v[@backingInt(Trait.cc)] = z[vi(.cc_pm)] + z[vi(.immob_pm)];
    s.v[@backingInt(Trait.engage)] = z[vi(.immob_kills)] + z[vi(.knock_kills)];
    s.v[@backingInt(Trait.dive)] = z[vi(.dive_kills)] + z[vi(.outnumbered)];
    s.v[@backingInt(Trait.tank)] = z[vi(.tank_share)] + z[vi(.taken_pm)];
    s.v[@backingInt(Trait.sustain)] = z[vi(.selfheal_pm)] + z[vi(.ally_pm)];
    s.v[@backingInt(Trait.early)] = (z[vi(.gold14)] + z[vi(.early_td)] + z[vi(.lanediff14)]) / 3;
    return s;
}

/// A set's traits (any number of seats): AP share of the set's damage, sums otherwise
pub fn traitsOf(seats: []const Seat) [nt]f64 {
    var t: [nt]f64 = @splat(0);
    var magic: f64 = 0;
    var dmg: f64 = 0;
    for (seats) |s| {
        magic += s.magic;
        dmg += s.dmg;
        for (&t, s.v) |*a, b| a.* += b;
    }
    t[@backingInt(Trait.ap_share)] = if (dmg > 0) magic / dmg else 0.5;
    return t;
}

/// A seat's 16 raw features in its game: enemy team, then its four allies
fn seatFeatures(seats: *const [2][5]Seat, side: usize, role: usize) [nf]f64 {
    var out: [nf]f64 = undefined;
    var allies: [4]Seat = undefined;
    var n: usize = 0;
    for (seats[side], 0..) |s, r| if (r != role) {
        allies[n] = s;
        n += 1;
    };
    @memcpy(out[0..nt], &traitsOf(&seats[1 - side]));
    @memcpy(out[nt..], &traitsOf(&allies));
    return out;
}

/// A team's 16 raw features: enemy team, then its own five
fn teamFeatures(seats: *const [2][5]Seat, side: usize) [nf]f64 {
    var out: [nf]f64 = undefined;
    @memcpy(out[0..nt], &traitsOf(&seats[1 - side]));
    @memcpy(out[nt..], &traitsOf(&seats[side]));
    return out;
}

/// A seat (ten per game, blue's five then red's, by role) or a team (two per game)
pub const Unit = struct {
    game: u32,
    /// comps.cellKey; 0 for a team
    cell: u64,
    /// Its team won
    y: f32,
    /// Ratings' logit for its team
    off: f32,
    x: [nf]f32,
};

/// Seats and teams of a set of games, in step
const Units = struct {
    seats: std.ArrayList(Unit) = .empty,
    teams: std.ArrayList(Unit) = .empty,

    fn deinit(u: *Units, gpa: Allocator) void {
        u.seats.deinit(gpa);
        u.teams.deinit(gpa);
    }
};

fn logit(p: f64) f64 {
    const q = std.math.clamp(p, 1e-6, 1 - 1e-6);
    return @log(q / (1 - q));
}

fn sigmoid(z: f64) f64 {
    return 1 / (1 + @exp(-z));
}

/// Ratings' chance for blue in every game with start < hi (not test, played), fitted on
/// the dev games before `before`; NaN elsewhere. As compcheck.offset: the same seeds, the
/// same query
fn ratingsBlue(gpa: Allocator, d: *const rows.Data, players: []const harness.Players, c: harness.Cuts, before: i64, hi: i64) ![]f64 {
    const k = api.outcomeIndex(.win);
    var fit_cuts = c;
    fit_cuts.dev = before;
    var v = try harness.buildTrain(gpa, d, players, .dev, fit_cuts, 1, false);
    defer v.deinit();
    const n_seeds: u64 = if (@hasDecl(cand, "seeded") and cand.seeded) 3 else 1;
    const sum = try gpa.alloc(f64, d.games.len);
    defer gpa.free(sum);
    const cnt = try gpa.alloc(f64, d.games.len);
    defer gpa.free(cnt);
    @memset(sum, 0);
    @memset(cnt, 0);
    for (1..n_seeds + 1) |seed| {
        var m = try harness.fit(cand, gpa, &v.train, .{ .seed = seed });
        defer cand.deinit(&m, gpa);
        for (d.rows) |r| {
            const g = d.games[r.game];
            if (!included(g, hi)) continue;
            const q = harness.query(cand.scope, g, players[r.game], r, false);
            const p = cand.predict(&m, &q)[k];
            sum[r.game] += if (r.side == 0) p else 1 - p;
            cnt[r.game] += 1;
        }
    }
    const out = try gpa.alloc(f64, d.games.len);
    for (out, sum, cnt) |*o, s, n| o.* = if (n > 0) s / n else nan;
    return out;
}

fn included(g: rows.Game, hi: i64) bool {
    return !g.is_test and harness.played(g) and g.start < hi;
}

fn toF32(x: [nf]f64) [nf]f32 {
    var out: [nf]f32 = undefined;
    for (&out, x) |*a, b| a.* = @floatCast(b);
    return out;
}

/// Units of the given games, raw features (not yet standardised)
fn unitsOf(gpa: Allocator, d: *const rows.Data, p: *const comps.Profiles, games: []const u32, blue: []const f64, out: *Units) !void {
    for (games) |gi| {
        const g = d.games[gi];
        var seats: [2][5]Seat = undefined;
        for (g.teams, 0..) |t, s| for (t, 0..) |ch, r| {
            seats[s][r] = seatOf(p, ch, r);
        };
        const lb = logit(blue[gi]);
        for (0..2) |s| {
            const y: f32 = if (g.winner == s) 1 else 0;
            const off: f32 = @floatCast(if (s == 0) lb else -lb);
            try out.teams.append(gpa, .{ .game = gi, .cell = 0, .y = y, .off = off, .x = toF32(teamFeatures(&seats, s)) });
            for (0..5) |r| try out.seats.append(gpa, .{
                .game = gi,
                .cell = comps.cellKey(g.teams[s][r], r),
                .y = y,
                .off = off,
                .x = toF32(seatFeatures(&seats, s, r)),
            });
        }
    }
}

pub const Scale = struct { mean: [nf]f64, sd: [nf]f64 };

fn scaleOf(units: []const Unit) Scale {
    var s: Scale = .{ .mean = @splat(0), .sd = @splat(0) };
    var sq: [nf]f64 = @splat(0);
    for (units) |u| for (u.x, &s.mean, &sq) |x, *m, *q| {
        m.* += x;
        q.* += @as(f64, x) * x;
    };
    const n: f64 = @floatFromInt(@max(units.len, 1));
    for (&s.mean, &s.sd, sq) |*m, *sd, q| {
        m.* /= n;
        sd.* = @sqrt(@max(q / n - m.* * m.*, 0));
        if (sd.* == 0) sd.* = 1;
    }
    return s;
}

fn standardise(units: []Unit, s: Scale) void {
    for (units) |*u| for (&u.x, s.mean, s.sd) |*x, m, sd| {
        x.* = @floatCast((x.* - m) / sd);
    };
}

/// Each seat's features from another seat of the same role, each team's from another
/// team (a control)
fn shuffleTraits(gpa: Allocator, u: *Units, seed: u64) !void {
    var rng: std.Random.DefaultPrng = .init(seed);
    for (0..6) |group| {
        var idx: std.ArrayList(u32) = .empty;
        defer idx.deinit(gpa);
        const list = if (group == 5) u.teams.items else u.seats.items;
        for (list, 0..) |x, i| if (group == 5 or (x.cell & 7) == group) try idx.append(gpa, @intCast(i));
        const xs = try gpa.alloc([nf]f32, idx.items.len);
        defer gpa.free(xs);
        for (xs, idx.items) |*x, i| x.* = list[i].x;
        rng.random().shuffle([nf]f32, xs);
        for (xs, idx.items) |x, i| list[i].x = x;
    }
}

/// One raw fit (a champion-role's seats, or every team)
pub const Est = struct {
    n: u32 = 0,
    mean_x: [nf]f64 = @splat(0),
    beta: [nf]f64 = @splat(nan),
    se: [nf]f64 = @splat(nan),

    fn ok(e: Est) bool {
        return e.n >= min_cell_games and !std.math.isNan(e.beta[0]);
    }
};

/// One logistic step from the offset on centred features: beta = A^-1 g with A = sum w x
/// x', g = sum x (y - p), se from A^-1. extra adds to each unit's offset
pub fn fitCell(gpa: Allocator, units: []const Unit, idx: []const u32, extra: ?[]const f64) !Est {
    var e: Est = .{ .n = @intCast(idx.len) };
    if (idx.len < nf + 2) return e;
    for (idx) |i| for (&e.mean_x, units[i].x) |*m, x| {
        m.* += x;
    };
    for (&e.mean_x) |*m| m.* /= @floatFromInt(idx.len);
    var a: [nf * nf]f64 = @splat(0);
    var g: [nf]f64 = @splat(0);
    for (idx) |i| {
        const u = units[i];
        const off = @as(f64, u.off) + if (extra) |x| x[i] else 0;
        const p = sigmoid(off);
        const w = p * (1 - p);
        const r = u.y - p;
        var x: [nf]f64 = undefined;
        for (&x, u.x, e.mean_x) |*xc, v, m| xc.* = v - m;
        for (0..nf) |j| {
            g[j] += x[j] * r;
            for (0..nf) |l| a[j * nf + l] += w * x[j] * x[l];
        }
    }
    var trace: f64 = 0;
    for (0..nf) |j| trace += a[j * nf + j];
    for (0..nf) |j| a[j * nf + j] += 1e-9 * trace / nf;
    const inv = comps.invert(gpa, &a, nf) catch |err| switch (err) {
        error.SingularMatrix => return e,
        else => return err,
    };
    defer gpa.free(inv);
    for (0..nf) |j| {
        var s: f64 = 0;
        for (0..nf) |l| s += inv[j * nf + l] * g[l];
        e.beta[j] = s;
        e.se[j] = @sqrt(@max(inv[j * nf + j], 0));
    }
    return e;
}

/// Per role and feature: precision-weighted mean of the cells' raw slopes and its se,
/// and the deviations' true spread by DerSimonian-Laird: (Q - (k - 1)) / (sum w - sum w^2
/// / sum w), Q = sum w (beta - mean)^2, w = 1 / se^2, at least 0; 0 unless Q passes its
/// chi-squared test at 1%
pub const RoleFit = struct {
    m: [5][nf]f64 = @splat(@splat(0)),
    m_se: [5][nf]f64 = @splat(@splat(0)),
    tau2: [5][nf]f64 = @splat(@splat(0)),
    cells: [5]u32 = @splat(0),
};

pub fn roleFit(cells: []const u64, ests: []const Est) RoleFit {
    var rf: RoleFit = .{};
    var wsum: [5][nf]f64 = @splat(@splat(0));
    for (cells, ests) |c, e| {
        if (!e.ok()) continue;
        const role: usize = @intCast(c & 7);
        rf.cells[role] += 1;
        for (0..nf) |f| {
            const w = 1 / (e.se[f] * e.se[f]);
            rf.m[role][f] += w * e.beta[f];
            wsum[role][f] += w;
        }
    }
    for (0..5) |role| for (0..nf) |f| {
        if (wsum[role][f] == 0) continue;
        rf.m[role][f] /= wsum[role][f];
        rf.m_se[role][f] = 1 / @sqrt(wsum[role][f]);
    };
    var q: [5][nf]f64 = @splat(@splat(0));
    var w2sum: [5][nf]f64 = @splat(@splat(0));
    for (cells, ests) |c, e| {
        if (!e.ok()) continue;
        const role: usize = @intCast(c & 7);
        for (0..nf) |f| {
            const w = 1 / (e.se[f] * e.se[f]);
            const dlt = e.beta[f] - rf.m[role][f];
            q[role][f] += w * dlt * dlt;
            w2sum[role][f] += w * w;
        }
    }
    for (0..5) |role| for (0..nf) |f| {
        const k: f64 = @floatFromInt(rf.cells[role]);
        if (k < 2) continue;
        // No spread unless Q shows one: a positive estimate by chance let noise through
        // on planted data with none (champion terms 0.00017 nats/game worse)
        if (q[role][f] <= chi2Quantile(k - 1, heterogeneity_z)) continue;
        const denom = wsum[role][f] - w2sum[role][f] / wsum[role][f];
        rf.tau2[role][f] = @max((q[role][f] - (k - 1)) / denom, 0);
    };
    return rf;
}

/// One-sided normal quantile of the heterogeneity test (1%)
const heterogeneity_z = 2.326;

/// Chi-squared quantile with df degrees of freedom at normal quantile z (Wilson-Hilferty)
fn chi2Quantile(df: f64, z: f64) f64 {
    const a = 2 / (9 * df);
    const t = 1 - a + z * @sqrt(a);
    return df * t * t * t;
}

/// Posterior deviation of one cell and feature from its role's mean (logit per sd), sd
pub const Post = struct { mean: f64 = 0, sd: f64 = 0 };

pub fn posterior(rf: *const RoleFit, role: usize, e: Est, f: usize) Post {
    if (!e.ok()) return .{};
    const t2 = rf.tau2[role][f];
    const s2 = e.se[f] * e.se[f] + rf.m_se[role][f] * rf.m_se[role][f];
    if (t2 + s2 == 0) return .{};
    const b = t2 / (t2 + s2);
    return .{ .mean = b * (e.beta[f] - rf.m[role][f]), .sd = @sqrt(b * s2) };
}

/// A fitted model: team terms, and per cell the posterior deviations and centres
pub const Model = struct {
    team: Est,
    cells: []u64,
    ests: []Est,
    rf: RoleFit,
    post: [][nf]Post,
    index: std.AutoHashMapUnmanaged(u64, u32) = .empty,

    pub fn deinit(m: *Model, gpa: Allocator) void {
        gpa.free(m.cells);
        gpa.free(m.ests);
        gpa.free(m.post);
        m.index.deinit(gpa);
    }

    /// A team's team term on its logit
    pub fn teamTerm(m: *const Model, x: []const f32) f64 {
        if (std.math.isNan(m.team.beta[0])) return 0;
        var t: f64 = 0;
        for (0..nf) |f| t += m.team.beta[f] * (x[f] - m.team.mean_x[f]);
        return t;
    }

    /// A seat's own term (its champion-role's deviations) on its team's logit, and its
    /// parts by feature
    pub fn seatTerm(m: *const Model, cell: u64, x: []const f32, parts: ?*[nf]f64) f64 {
        if (parts) |p| p.* = @splat(0);
        const ci = m.index.get(cell) orelse return 0;
        if (!m.ests[ci].ok()) return 0;
        var t: f64 = 0;
        for (0..nf) |f| {
            const v = m.post[ci][f].mean * (x[f] - m.ests[ci].mean_x[f]);
            if (parts) |p| p[f] = v;
            t += v;
        }
        return t;
    }
};

const Groups = struct {
    cells: []u64,
    starts: []u32,
    order: []u32,

    fn deinit(g: *Groups, gpa: Allocator) void {
        gpa.free(g.cells);
        gpa.free(g.starts);
        gpa.free(g.order);
    }

    fn of(g: *const Groups, i: usize) []const u32 {
        return g.order[g.starts[i]..g.starts[i + 1]];
    }
};

/// Cells and their units, sorted by cell
fn groupByCell(gpa: Allocator, units: []const Unit) !Groups {
    const order = try gpa.alloc(u32, units.len);
    errdefer gpa.free(order);
    for (order, 0..) |*o, i| o.* = @intCast(i);
    std.mem.sort(u32, order, units, struct {
        fn lt(us: []const Unit, a: u32, b: u32) bool {
            return if (us[a].cell != us[b].cell) us[a].cell < us[b].cell else a < b;
        }
    }.lt);
    var cells: std.ArrayList(u64) = .empty;
    errdefer cells.deinit(gpa);
    var starts: std.ArrayList(u32) = .empty;
    errdefer starts.deinit(gpa);
    for (order, 0..) |o, i| if (i == 0 or units[o].cell != units[order[i - 1]].cell) {
        try cells.append(gpa, units[o].cell);
        try starts.append(gpa, @intCast(i));
    };
    try starts.append(gpa, @intCast(order.len));
    return .{ .cells = try cells.toOwnedSlice(gpa), .starts = try starts.toOwnedSlice(gpa), .order = order };
}

/// Team terms over every team, then two passes of per-cell fits and deviation shrinkage
/// on the seats (ten a game, in step with the teams, two a game)
pub fn fitModel(gpa: Allocator, u: *const Units) !Model {
    const seats = u.seats.items;
    const teams = u.teams.items;
    std.debug.assert(seats.len == 5 * teams.len);
    const all = try gpa.alloc(u32, teams.len);
    defer gpa.free(all);
    for (all, 0..) |*a, i| a.* = @intCast(i);
    var grp = try groupByCell(gpa, seats);
    defer gpa.free(grp.starts);
    defer gpa.free(grp.order);
    var m: Model = .{
        .team = try fitCell(gpa, teams, all, null),
        .cells = grp.cells,
        .ests = try gpa.alloc(Est, grp.cells.len),
        .rf = .{},
        .post = try gpa.alloc([nf]Post, grp.cells.len),
    };
    errdefer m.deinit(gpa);
    for (m.cells, 0..) |c, i| try m.index.put(gpa, c, @intCast(i));
    const extra = try gpa.alloc(f64, seats.len);
    defer gpa.free(extra);
    for (0..passes) |pass| {
        for (extra, 0..) |*e, i| e.* = m.teamTerm(&teams[i / 5].x);
        if (pass > 0) addOtherSeats(&m, seats, extra);
        for (m.ests, 0..) |*e, ci| e.* = try fitCell(gpa, seats, grp.of(ci), extra);
        m.rf = roleFit(m.cells, m.ests);
        for (m.cells, m.ests, m.post) |c, e, *p| {
            for (0..nf) |f| p[f] = posterior(&m.rf, @intCast(c & 7), e, f);
        }
    }
    return m;
}

/// Adds to each seat's offset the other nine seats' terms (allies add, enemies take)
fn addOtherSeats(m: *const Model, seats: []const Unit, out: []f64) void {
    var i: usize = 0;
    while (i + 10 <= seats.len) : (i += 10) {
        var t: [10]f64 = undefined;
        var team: [2]f64 = .{ 0, 0 };
        for (0..10) |j| {
            t[j] = m.seatTerm(seats[i + j].cell, &seats[i + j].x, null);
            team[j / 5] += t[j];
        }
        for (0..10) |j| {
            const s = j / 5;
            out[i + j] += (team[s] - t[j]) - team[1 - s];
        }
    }
}

/// Blue's logit beyond ratings for game k of a set: team terms and seat terms
fn blueExtra(m: *const Model, u: *const Units, k: usize, team_only: bool) f64 {
    var z = m.teamTerm(&u.teams.items[2 * k].x) - m.teamTerm(&u.teams.items[2 * k + 1].x);
    if (team_only) return z;
    for (0..10) |j| {
        const s = u.seats.items[10 * k + j];
        const t = m.seatTerm(s.cell, &s.x, null);
        z += if (j < 5) t else -t;
    }
    return z;
}

const Scores = struct {
    base: std.ArrayList(f64) = .empty,
    team: std.ArrayList(f64) = .empty,
    full: std.ArrayList(f64) = .empty,

    fn deinit(s: *Scores, gpa: Allocator) void {
        s.base.deinit(gpa);
        s.team.deinit(gpa);
        s.full.deinit(gpa);
    }
};

/// Per scored game: log loss of ratings, ratings plus team terms, and the whole model
fn scoreGames(gpa: Allocator, m: *const Model, u: *const Units, out: *Scores) !void {
    for (0..u.teams.items.len / 2) |k| {
        const z0: f64 = u.teams.items[2 * k].off;
        const y: f64 = u.teams.items[2 * k].y;
        try out.base.append(gpa, logLoss(y, sigmoid(z0)));
        try out.team.append(gpa, logLoss(y, sigmoid(z0 + blueExtra(m, u, k, true))));
        try out.full.append(gpa, logLoss(y, sigmoid(z0 + blueExtra(m, u, k, false))));
    }
}

fn logLoss(y: f64, p: f64) f64 {
    const q = std.math.clamp(p, 1e-12, 1 - 1e-12);
    return -(y * @log(q) + (1 - y) * @log(1 - q));
}

const Gain = struct { mean: f64 = 0, half: f64 = 0, n: usize = 0 };

/// Mean of with - base per game, 95% half-width (games independent)
fn gainOf(base: []const f64, with: []const f64) Gain {
    const n: f64 = @floatFromInt(@max(base.len, 1));
    var s: f64 = 0;
    var q: f64 = 0;
    for (base, with) |a, b| {
        s += b - a;
        q += (b - a) * (b - a);
    }
    const mean = s / n;
    const v = @max(q / n - mean * mean, 0) / @max(n - 1, 1);
    return .{ .mean = mean, .half = 1.96 * @sqrt(v), .n = base.len };
}

fn zOf(p: Post) f64 {
    return if (p.sd > 0) p.mean / p.sd else 0;
}

/// A cell's raw deviation from its role's mean over its se (the mean's se included)
fn rawZ(m: *const Model, ci: usize, f: usize) f64 {
    const e = m.ests[ci];
    const role: usize = @intCast(m.cells[ci] & 7);
    const se = @sqrt(e.se[f] * e.se[f] + m.rf.m_se[role][f] * m.rf.m_se[role][f]);
    return (e.beta[f] - m.rf.m[role][f]) / se;
}

const Clear = struct {
    /// Posterior deviation clear (|z| >= clear_z)
    clear: usize = 0,
    /// Raw deviations passing Benjamini-Hochberg at bh_q over every test
    bh: usize = 0,
    bh_p: f64 = 0,
    tests: usize = 0,
};

const bh_q = 0.05;

/// Clear deviations of a model (cells with min_cell_games fit games)
fn countClear(gpa: Allocator, m: *const Model) !Clear {
    var c: Clear = .{};
    var ps: std.ArrayList(f64) = .empty;
    defer ps.deinit(gpa);
    for (m.ests, m.post, 0..) |e, p, ci| {
        if (!e.ok()) continue;
        for (0..nf) |f| {
            c.tests += 1;
            if (@abs(zOf(p[f])) >= clear_z) c.clear += 1;
            try ps.append(gpa, comps.pOf(rawZ(m, ci, f)));
        }
    }
    c.bh_p = try comps.bhThreshold(gpa, ps.items, bh_q);
    for (ps.items) |p| c.bh += @intFromBool(c.bh_p > 0 and p <= c.bh_p);
    return c;
}

fn bhPass(m: *const Model, cc: Clear, ci: usize, f: usize) bool {
    return cc.bh_p > 0 and comps.pOf(rawZ(m, ci, f)) <= cc.bh_p;
}

fn featureName(buf: []u8, f: usize) []const u8 {
    return std.fmt.bufPrint(buf, "{s}:{s}", .{ if (f < nt) "enemy" else "ally", trait_names[f % nt] }) catch "?";
}

fn loadNames(gpa: Allocator, arena: Allocator, snap: []const u8) !std.AutoHashMapUnmanaged(u32, []const u8) {
    var names: std.AutoHashMapUnmanaged(u32, []const u8) = .empty;
    const db = try store.schema.openReadOnly(gpa, snap);
    defer db.close();
    var q = try db.prepare("SELECT id, name FROM champions");
    defer q.deinit();
    try q.bind(.{});
    while (try q.step()) try names.put(arena, @intCast(q.int(0)), try arena.dupe(u8, q.bytes(1)));
    return names;
}

const Window = struct {
    label: []const u8,
    /// Fit on dev games before this
    before: i64,
    /// Scored games: [lo, hi)
    lo: i64,
    hi: i64,
};

const Replication = struct {
    clear: usize = 0,
    agree: usize = 0,
    z_sum: f64 = 0,
    /// The same for Benjamini-Hochberg passes
    bh: usize = 0,
    bh_agree: usize = 0,
    games: usize = 0,
};

pub fn main(gpa: Allocator, arena: Allocator, io: Io, argv: []const []const u8) !u8 {
    if (argv.len < 1) {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    }
    // win-comp (ratings plus the damage mix): does a champion's ally AP share effect go
    // beyond the team's mix?
    // win-draft (the shipped model, score.zig): do comps add beyond the site's own pairs
    // and matchups?
    const offsets = [_][]const u8{ "win-ratings", "win-comp", "win-draft" };
    const known = @hasDecl(cand, "name") and for (offsets) |o| {
        if (std.mem.eql(u8, cand.name, o)) break true;
    } else false;
    if (!known) {
        std.debug.print("champcomp: build with -Dcand=src/lab/cand/win-ratings (its predictions are the offset), win-comp or win-draft\n", .{});
        return 2;
    }
    const snap = argv[0];
    var permute: u64 = 0;
    var shuffle: u64 = 0;
    var i: usize = 1;
    while (i < argv.len) : (i += 1) {
        const a = argv[i];
        if (std.mem.eql(u8, a, "--permute-profiles") and i + 1 < argv.len) {
            i += 1;
            permute = try std.fmt.parseInt(u64, argv[i], 10);
        } else if (std.mem.eql(u8, a, "--shuffle-traits") and i + 1 < argv.len) {
            i += 1;
            shuffle = try std.fmt.parseInt(u64, argv[i], 10);
        } else {
            std.debug.print("usage:\n{s}", .{usage});
            return 2;
        }
    }
    const data_path = if (try synth.parseArg(snap)) |pa| pa.path else snap;

    var buf: [4096]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &buf);
    const w = &stdout.interface;

    var legendaries = try rows.loadLegendaries(gpa, io, snap);
    defer legendaries.deinit(gpa);
    var data = try rows.load(gpa, snap, &legendaries);
    defer data.deinit();
    const d = &data;
    const players = try harness.gamePlayers(gpa, d);
    defer gpa.free(players);
    const c = try harness.cuts(gpa, d);
    const names = try loadNames(gpa, arena, data_path);

    const extra = try gpa.alloc(?compstats.Seat, d.rows.len);
    defer gpa.free(extra);
    const team_obj = try gpa.alloc(?[2]compstats.Team, d.games.len);
    defer gpa.free(team_obj);
    const placed = try comps.loadExtra(gpa, io, d, data_path, extra, team_obj);
    var with_stats: usize = 0;
    for (d.rows) |r| with_stats += @intFromBool(!std.math.isNan(r.stats[0]));
    try w.print("# champcomp, offset {s}{s}{s}, {s}\nrows {d}: with seat stats {d}, comp_stats lines placed {d}\n", .{
        cand.name, if (permute != 0) ", PERMUTED profiles" else "", if (shuffle != 0) ", SHUFFLED traits" else "", snap, d.rows.len, with_stats, placed.seats,
    });
    if (with_stats == 0) return error.NoSeatStats;
    try w.print("fold bounds {any}, dev cut {d}, test cut {d}\n", .{ c.bounds[0..5], c.dev, c.test_ });
    try w.flush();

    var windows: [harness.folds + 1]Window = undefined;
    for (1..harness.folds + 1) |k| {
        const f = c.fold(k);
        windows[k - 1] = .{ .label = try std.fmt.allocPrint(arena, "fold {d}", .{k}), .before = f.lo, .lo = f.lo, .hi = f.hi };
    }
    windows[harness.folds] = .{ .label = "dev-val", .before = c.dev, .lo = c.dev, .hi = c.test_ };

    var pooled: Scores = .{};
    defer pooled.deinit(gpa);
    var gains: [harness.folds + 1]Gain = undefined;
    var final_clear: Clear = .{};
    var rep: Replication = .{};

    for (windows, 0..) |win, wi| {
        const fit_cfg: comps.Fit = .{ .c = c, .before = win.before };
        var p = try comps.buildProfiles(gpa, d, extra, fit_cfg, permute);
        defer p.deinit(gpa);
        // Fold 3 also scores the replication window: everything up to the dev cut
        const replicate = wi == 2;
        const blue = try ratingsBlue(gpa, d, players, c, win.before, if (replicate) c.dev else win.hi);
        defer gpa.free(blue);

        var fit_games: std.ArrayList(u32) = .empty;
        defer fit_games.deinit(gpa);
        var score_games: std.ArrayList(u32) = .empty;
        defer score_games.deinit(gpa);
        var rep_games: std.ArrayList(u32) = .empty;
        defer rep_games.deinit(gpa);
        for (d.games, 0..) |g, gi| {
            if (std.math.isNan(blue[gi])) continue;
            if (fit_cfg.has(g)) try fit_games.append(gpa, @intCast(gi));
            if (g.start >= win.lo and g.start < win.hi) try score_games.append(gpa, @intCast(gi));
            if (replicate and g.start >= win.lo and g.start < c.dev) try rep_games.append(gpa, @intCast(gi));
        }
        var fit_u: Units = .{};
        defer fit_u.deinit(gpa);
        try unitsOf(gpa, d, &p, fit_games.items, blue, &fit_u);
        var score_u: Units = .{};
        defer score_u.deinit(gpa);
        try unitsOf(gpa, d, &p, score_games.items, blue, &score_u);
        const seat_scale = scaleOf(fit_u.seats.items);
        const team_scale = scaleOf(fit_u.teams.items);
        for ([_]*Units{ &fit_u, &score_u }) |u| {
            standardise(u.seats.items, seat_scale);
            standardise(u.teams.items, team_scale);
        }
        if (shuffle != 0) {
            try shuffleTraits(gpa, &fit_u, shuffle);
            try shuffleTraits(gpa, &score_u, shuffle +% 1);
        }

        var model = try fitModel(gpa, &fit_u);
        defer model.deinit(gpa);
        var sc: Scores = .{};
        defer sc.deinit(gpa);
        try scoreGames(gpa, &model, &score_u, &sc);
        gains[wi] = gainOf(sc.base.items, sc.full.items);
        const team_gain = gainOf(sc.base.items, sc.team.items);
        const seat_gain = gainOf(sc.team.items, sc.full.items);
        const cc = try countClear(gpa, &model);
        try w.print("{s}: fit {d} games, scored {d}; log loss vs ratings {d:.5} ± {d:.5} (team terms {d:.5} ± {d:.5}, then champion terms {d:.5} ± {d:.5}); clear {d} of {d}, BH {d}\n", .{
            win.label,      fit_games.items.len, score_games.items.len, gains[wi].mean, gains[wi].half,
            team_gain.mean, team_gain.half,      seat_gain.mean,        seat_gain.half, cc.clear,
            cc.tests,       cc.bh,
        });
        try w.flush();
        if (wi < harness.folds) {
            try pooled.base.appendSlice(gpa, sc.base.items);
            try pooled.team.appendSlice(gpa, sc.team.items);
            try pooled.full.appendSlice(gpa, sc.full.items);
        }
        if (replicate) {
            rep = try replicateOn(gpa, d, &p, &model, cc, rep_games.items, blue, seat_scale, team_scale, shuffle);
            try w.print("replication: {d} deviations clear before bounds[2], same sign on the newer dev games ({d} games) {d}, mean signed z {d:.2}; BH passes {d}, same sign {d}\n", .{
                rep.clear, rep.games, rep.agree, if (rep.clear > 0) rep.z_sum / @as(f64, @floatFromInt(rep.clear)) else 0, rep.bh, rep.bh_agree,
            });
        }
        if (wi == harness.folds) {
            final_clear = cc;
            try writeOutputs(gpa, arena, io, d, &model, &p, seat_scale, &names, &score_u, cc);
        }
    }

    const all = gainOf(pooled.base.items, pooled.full.items);
    const team_all = gainOf(pooled.base.items, pooled.team.items);
    const seat_all = gainOf(pooled.team.items, pooled.full.items);
    var better: usize = 0;
    for (gains[0..harness.folds]) |g| better += @intFromBool(g.mean < 0);
    const dv = gains[harness.folds];
    try w.print("folds pooled: {d:.5} ± {d:.5} nats/game over {d} games (team terms {d:.5} ± {d:.5}, champion terms {d:.5} ± {d:.5}), better in {d} of {d}; dev-val {d:.5} ± {d:.5}\n", .{
        all.mean, all.half, all.n, team_all.mean, team_all.half, seat_all.mean, seat_all.half, better, harness.folds, dv.mean, dv.half,
    });
    try w.print("RESULT champcomp folds={d:.5}±{d:.5} better={d}/{d} devval={d:.5}±{d:.5} clear={d}/{d} bh={d} replicated={d}/{d} bh_replicated={d}/{d}{s}{s}\n", .{
        all.mean,          all.half,                              better,                                harness.folds, dv.mean,   dv.half,
        final_clear.clear, final_clear.tests,                     final_clear.bh,                        rep.agree,     rep.clear, rep.bh_agree,
        rep.bh,            if (permute != 0) " PERMUTED" else "", if (shuffle != 0) " SHUFFLED" else "",
    });
    try w.flush();
    return 0;
}

/// Raw per-cell refits on the replication games, against the model's clear deviations
fn replicateOn(
    gpa: Allocator,
    d: *const rows.Data,
    p: *const comps.Profiles,
    m: *const Model,
    cc: Clear,
    games: []const u32,
    blue: []const f64,
    seat_scale: Scale,
    team_scale: Scale,
    shuffle: u64,
) !Replication {
    var u: Units = .{};
    defer u.deinit(gpa);
    try unitsOf(gpa, d, p, games, blue, &u);
    standardise(u.seats.items, seat_scale);
    standardise(u.teams.items, team_scale);
    if (shuffle != 0) try shuffleTraits(gpa, &u, shuffle +% 2);
    const extra = try gpa.alloc(f64, u.seats.items.len);
    defer gpa.free(extra);
    for (extra, 0..) |*e, i| e.* = m.teamTerm(&u.teams.items[i / 5].x);
    var grp = try groupByCell(gpa, u.seats.items);
    defer grp.deinit(gpa);
    const ests = try gpa.alloc(Est, grp.cells.len);
    defer gpa.free(ests);
    for (ests, 0..) |*e, gi| e.* = try fitCell(gpa, u.seats.items, grp.of(gi), extra);
    const rf = roleFit(grp.cells, ests);
    var r: Replication = .{ .games = games.len };
    for (grp.cells, ests) |cell, re| {
        if (!re.ok()) continue;
        const ci = m.index.get(cell) orelse continue;
        const role: usize = @intCast(cell & 7);
        for (0..nf) |f| {
            const dev = re.beta[f] - rf.m[role][f];
            if (bhPass(m, cc, ci, f)) {
                r.bh += 1;
                if (std.math.sign(dev) == std.math.sign(rawZ(m, ci, f))) r.bh_agree += 1;
            }
            const pz = zOf(m.post[ci][f]);
            if (@abs(pz) < clear_z) continue;
            r.clear += 1;
            r.z_sum += std.math.sign(pz) * dev / re.se[f];
            if (std.math.sign(dev) == std.math.sign(pz)) r.agree += 1;
        }
    }
    return r;
}

const Row = struct { ci: u32, f: u8, z: f64 };

fn writeOutputs(
    gpa: Allocator,
    arena: Allocator,
    io: Io,
    d: *const rows.Data,
    m: *const Model,
    p: *const comps.Profiles,
    sc: Scale,
    names: *const std.AutoHashMapUnmanaged(u32, []const u8),
    scored: *const Units,
    cc: Clear,
) !void {
    const cwd = Io.Dir.cwd();
    const nameOf = struct {
        fn f(n: *const std.AutoHashMapUnmanaged(u32, []const u8), id: u32) []const u8 {
            return n.get(id) orelse "?";
        }
    }.f;
    var fbuf: [32]u8 = undefined;

    // Every cell and feature
    {
        var file = try cwd.createFile(io, "champcomp.tsv", .{});
        defer file.close(io);
        var b: [64 * 1024]u8 = undefined;
        var fw = file.writer(io, &b);
        const o = &fw.interface;
        try o.writeAll("champion\trole\tgames\tfeature\traw_pp\tse_pp\trole_mean_pp\traw_z\tbh\tdeviation_pp\tdeviation_sd_pp\tz\tcentre\n");
        for (m.cells, m.ests, m.post, 0..) |cell, e, post, ci| {
            if (e.n == 0) continue;
            const role: usize = @intCast(cell & 7);
            const ok = e.ok();
            for (0..nf) |f| {
                try o.print("{s}\t{s}\t{d}\t{s}\t{d:.3}\t{d:.3}\t{d:.3}\t{d:.2}\t{d}\t{d:.3}\t{d:.3}\t{d:.2}\t{d:.4}\n", .{
                    nameOf(names, @intCast(cell >> 3)),        role_names[role],            e.n,                            featureName(&fbuf, f),
                    e.beta[f] * pp_per_logit,                  e.se[f] * pp_per_logit,      m.rf.m[role][f] * pp_per_logit, if (ok) rawZ(m, ci, f) else nan,
                    @intFromBool(ok and bhPass(m, cc, ci, f)), post[f].mean * pp_per_logit, post[f].sd * pp_per_logit,      zOf(post[f]),
                    e.mean_x[f],
                });
            }
        }
        try o.flush();
    }
    // Role means (one champion-role's slope on average, team effect included) and spreads
    {
        var file = try cwd.createFile(io, "roles.tsv", .{});
        defer file.close(io);
        var b: [16 * 1024]u8 = undefined;
        var fw = file.writer(io, &b);
        const o = &fw.interface;
        try o.writeAll("role\tfeature\tcells\tmean_pp\tmean_ci_pp\ttau_pp\n");
        for (0..5) |role| for (0..nf) |f| {
            try o.print("{s}\t{s}\t{d}\t{d:.3}\t{d:.3}\t{d:.3}\n", .{
                role_names[role],               featureName(&fbuf, f),                    m.rf.cells[role],
                m.rf.m[role][f] * pp_per_logit, 1.96 * m.rf.m_se[role][f] * pp_per_logit, @sqrt(m.rf.tau2[role][f]) * pp_per_logit,
            });
        };
        try o.flush();
    }
    // Team terms (enemy's five, own five)
    {
        var file = try cwd.createFile(io, "team.tsv", .{});
        defer file.close(io);
        var b: [4096]u8 = undefined;
        var fw = file.writer(io, &b);
        const o = &fw.interface;
        try o.writeAll("feature\teffect_pp\tci_pp\tteams\n");
        for (0..nf) |f| {
            var nb: [32]u8 = undefined;
            const name = std.fmt.bufPrint(&nb, "{s}:{s}", .{ if (f < nt) "enemy" else "own", trait_names[f % nt] }) catch "?";
            try o.print("{s}\t{d:.3}\t{d:.3}\t{d}\n", .{ name, m.team.beta[f] * pp_per_logit, 1.96 * m.team.se[f] * pp_per_logit, m.team.n });
        }
        try o.flush();
    }
    // Seat values and the seat features' scale: any comp's breakdown from these and
    // champcomp.tsv
    {
        var file = try cwd.createFile(io, "profiles.tsv", .{});
        defer file.close(io);
        var b: [64 * 1024]u8 = undefined;
        var fw = file.writer(io, &b);
        const o = &fw.interface;
        try o.writeAll("# seat feature scale: feature, mean, sd of the raw set traits (AP share: the set's magic damage over all its damage)\n");
        for (0..nf) |f| try o.print("# {s}\t{d:.5}\t{d:.5}\n", .{ featureName(&fbuf, f), sc.mean[f], sc.sd[f] });
        try o.writeAll("champion\trole\tmagic_dpm\tdpm");
        for (trait_names[1..]) |t| try o.print("\t{s}", .{t});
        try o.writeAll("\n");
        var it = p.raw.iterator();
        while (it.next()) |e| {
            const role: usize = @intCast(e.key_ptr.* & 7);
            const id: u32 = @intCast(e.key_ptr.* >> 3);
            const s = seatOf(p, id, role);
            try o.print("{s}\t{s}\t{d:.2}\t{d:.2}", .{ nameOf(names, id), role_names[role], s.magic, s.dmg });
            for (s.v[1..]) |v| try o.print("\t{d:.4}", .{v});
            try o.writeAll("\n");
        }
        try o.flush();
    }

    // Clear deviations, strongest first
    var clear: std.ArrayList(Row) = .empty;
    defer clear.deinit(gpa);
    for (m.ests, m.post, 0..) |e, post, ci| {
        if (!e.ok()) continue;
        for (0..nf) |f| {
            const z = zOf(post[f]);
            if (@abs(z) >= clear_z) try clear.append(gpa, .{ .ci = @intCast(ci), .f = @intCast(f), .z = z });
        }
    }
    std.mem.sort(Row, clear.items, {}, struct {
        fn lt(_: void, a: Row, b: Row) bool {
            return @abs(a.z) > @abs(b.z);
        }
    }.lt);

    for ([_]struct { []const u8, usize, []const u8 }{
        .{ "enemy", 0, "Win into an enemy team with more of a trait, against the role's average champion" },
        .{ "ally", nt, "Win beside allies with more of a trait, against the role's average champion" },
    }) |side| {
        const path = try std.fmt.allocPrint(arena, "effects-champcomp-{s}.tsv", .{side[0]});
        var file = try cwd.createFile(io, path, .{});
        defer file.close(io);
        var b: [16 * 1024]u8 = undefined;
        var fw = file.writer(io, &b);
        const o = &fw.interface;
        try o.print("# {s} | pp per sd of the trait | the champion gains more than its role's average as the trait rises\n", .{side[2]});
        var n: usize = 0;
        for (clear.items) |r| {
            if (r.f < side[1] or r.f >= side[1] + nt or n >= 40) continue;
            const cell = m.cells[r.ci];
            const pf = m.post[r.ci][r.f];
            try o.print("{s} {s}: {s}\t{d:.2}\t{d:.2}\t{d}\n", .{
                nameOf(names, @intCast(cell >> 3)), role_names[cell & 7],        trait_words[r.f % nt],
                pf.mean * pp_per_logit,             1.96 * pf.sd * pp_per_logit, m.ests[r.ci].n,
            });
            n += 1;
        }
        try o.flush();
    }

    // Examples: for the clearest cells, the scored game where its own term is largest,
    // split by feature
    {
        var file = try cwd.createFile(io, "examples.tsv", .{});
        defer file.close(io);
        var b: [64 * 1024]u8 = undefined;
        var fw = file.writer(io, &b);
        const o = &fw.interface;
        try o.writeAll("champion\trole\tallies\tenemies\tterm_pp\tparts_pp (largest first)\n");
        var done: std.AutoHashMapUnmanaged(u32, void) = .empty;
        defer done.deinit(gpa);
        const seats = scored.seats.items;
        for (clear.items) |r| {
            if (done.count() >= 15) break;
            if (done.contains(r.ci)) continue;
            try done.put(gpa, r.ci, {});
            const cell = m.cells[r.ci];
            var best: ?usize = null;
            var best_t: f64 = 0;
            for (seats, 0..) |u, ui| if (u.cell == cell) {
                const t = m.seatTerm(cell, &u.x, null);
                if (best == null or @abs(t) > @abs(best_t)) {
                    best = ui;
                    best_t = t;
                }
            };
            const ui = best orelse continue;
            const u = seats[ui];
            var parts: [nf]f64 = undefined;
            _ = m.seatTerm(cell, &u.x, &parts);
            const g = d.games[u.game];
            const side: usize = (ui % 10) / 5;
            const role: usize = @intCast(cell & 7);
            try o.print("{s}\t{s}\t", .{ nameOf(names, @intCast(cell >> 3)), role_names[role] });
            var first = true;
            for (g.teams[side], 0..) |ch, rr| if (rr != role) {
                try o.print("{s}{s}", .{ if (first) "" else ", ", nameOf(names, ch) });
                first = false;
            };
            try o.writeAll("\t");
            for (g.teams[1 - side], 0..) |ch, rr| try o.print("{s}{s}", .{ if (rr == 0) "" else ", ", nameOf(names, ch) });
            try o.print("\t{d:.2}\t", .{best_t * pp_per_logit});
            var order: [nf]u8 = undefined;
            for (&order, 0..) |*x, k| x.* = @intCast(k);
            std.mem.sort(u8, &order, &parts, struct {
                fn lt(ps: *const [nf]f64, a: u8, bb: u8) bool {
                    return @abs(ps[a]) > @abs(ps[bb]);
                }
            }.lt);
            for (order[0..4], 0..) |f, k| {
                try o.print("{s}{s} {d:.2}", .{ if (k == 0) "" else ", ", featureName(&fbuf, f), parts[f] * pp_per_logit });
            }
            try o.writeAll("\n");
        }
        try o.flush();
    }

    // Plain findings
    {
        var file = try cwd.createFile(io, "findings.tsv", .{});
        defer file.close(io);
        var b: [16 * 1024]u8 = undefined;
        var fw = file.writer(io, &b);
        const o = &fw.interface;
        try o.print("{d} of {d} champion-role and trait effects differ clearly (99%) from their role's average after shrinking; {d} pass a 5% false discovery rate unshrunk.\n", .{ cc.clear, cc.tests, cc.bh });
        for (clear.items[0..@min(clear.items.len, 10)]) |r| {
            const cell = m.cells[r.ci];
            const pf = m.post[r.ci][r.f];
            try o.print("{s} {s} wins {d:.1} pp {s} than its role's average per sd of {s} {s} (± {d:.1}, {d} games).\n", .{
                nameOf(names, @intCast(cell >> 3)),                  role_names[cell & 7],
                @abs(pf.mean) * pp_per_logit,                        if (pf.mean > 0) "more" else "less",
                if (r.f < nt) "the enemy team's" else "its allies'", trait_words[r.f % nt],
                1.96 * pf.sd * pp_per_logit,                         m.ests[r.ci].n,
            });
        }
        try o.flush();
    }
}

const testing = std.testing;

test "a planted champion's deviation comes back; a shared slope stays a role mean" {
    const gpa = testing.allocator;
    var rng: std.Random.DefaultPrng = .init(7);
    const r = rng.random();
    const n_games = 6000;
    var u: Units = .{};
    defer u.deinit(gpa);
    const melee = @backingInt(Trait.melee);
    const cc = @backingInt(Trait.cc);
    for (0..n_games) |gi| {
        const off = 0.2 * r.floatNorm(f64);
        // Enemy traits of each team, shared by its seats
        var enemy: [2][nf]f32 = undefined;
        for (&enemy) |*e| for (e) |*v| {
            v.* = @floatCast(r.floatNorm(f64));
        };
        // Champion 1 (role 1) gains 0.3 logit per sd of enemy melee; every jungler 0.1
        // per sd of enemy CC (a team-wide slope: role means, not deviations)
        var z: [2]f64 = .{ off, -off };
        var champs: [2][5]u32 = undefined;
        for (0..2) |s| for (0..5) |role| {
            champs[s][role] = @intCast(1 + r.uintLessThan(u32, 4) + 10 * role);
            if (role == 1 and champs[s][role] == 11) z[s] += 0.3 * @as(f64, enemy[s][melee]);
            if (role == 1) z[s] += 0.1 * @as(f64, enemy[s][cc]);
        };
        const blue_won = r.float(f64) < sigmoid(z[0] - z[1]);
        for (0..2) |s| {
            const y: f32 = if (blue_won == (s == 0)) 1 else 0;
            const o: f32 = @floatCast(if (s == 0) off else -off);
            try u.teams.append(gpa, .{ .game = @intCast(gi), .cell = 0, .y = y, .off = o, .x = enemy[s] });
            for (0..5) |role| try u.seats.append(gpa, .{
                .game = @intCast(gi),
                .cell = comps.cellKey(champs[s][role], role),
                .y = y,
                .off = o,
                .x = enemy[s],
            });
        }
    }
    var m = try fitModel(gpa, &u);
    defer m.deinit(gpa);
    const planted = m.index.get(comps.cellKey(11, 1)).?;
    const p = m.post[planted][melee];
    try testing.expect(p.mean > 0.1 and @abs(zOf(p)) >= 2);
    // A champion with nothing planted shows no clear deviation on melee
    const other = m.index.get(comps.cellKey(12, 1)).?;
    try testing.expect(@abs(zOf(m.post[other][melee])) < clear_z);
    // The team-wide CC slope reaches the team terms, not the jungle deviations
    try testing.expect(m.team.beta[cc] > 0.05);
    for (1..5) |ch| {
        const ci = m.index.get(comps.cellKey(@intCast(ch + 10), 1)).?;
        try testing.expect(@abs(zOf(m.post[ci][cc])) < clear_z);
    }
}

test "traits of a set" {
    var s: [2]Seat = .{
        .{ .magic = 300, .dmg = 400, .v = @splat(1) },
        .{ .magic = 100, .dmg = 600, .v = @splat(-0.5) },
    };
    const t = traitsOf(&s);
    try testing.expectApproxEqAbs(0.4, t[@backingInt(Trait.ap_share)], 1e-12);
    try testing.expectApproxEqAbs(0.5, t[@backingInt(Trait.melee)], 1e-12);
    s[0].dmg = 0;
    s[1].dmg = 0;
    try testing.expectApproxEqAbs(0.5, traitsOf(&s)[@backingInt(Trait.ap_share)], 1e-12);
}
