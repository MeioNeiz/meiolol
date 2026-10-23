//! `meiolol-lab champcomp SNAP`: which champions do better or worse into which enemy comps,
//! and beside which allies (docs/model.md "Champions into comps"). Built with
//! -Dcand=src/lab/cand/win-ratings: its predictions are the offset, as comps'.
//!
//! Traits of a set of seats, from comps' champion-role profiles (fit games only, z within
//! role): AP share of damage, melee count, CC, engage, dive, tank, sustain, early power,
//! auto-attack build (--aa FILE, deploy/aa-build.sh: z within role over fit seats; 0
//! without the file, so the trait drops out). A team sees the enemy's five and its own five (team terms, fitted once over teams); a
//! seat sees the enemy's five and its four allies (18 features, standardised on the fit
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
//! --only FEATURE (e.g. enemy:ap_share) zeroes every other feature: that trait's slope
//! alone, not holding the other 17 fixed. --groups (needs --aa): kit groups (kit_groups,
//! champgroups' detected six) as group-level predictors of their members' deviations on
//! the group's enemy trait: a cell's deviation shrinks towards the sum of its groups'
//! coefficients times its centred memberships, not towards 0 (one weighted regression of
//! the cells' raw deviations per feature, pooled over roles, spread re-estimated around
//! it, twice: the two-stage form of the multilevel fit); scored against the plain terms
//! paired, on every game and on games with a member; leave-one-member-out on the
//! replication window. --group-shuffle SEED: memberships shuffled within role (a
//! control). Up to 277661c, --kit-prior did the same with one covariate, armour lean.
//! Writes champcomp.tsv, roles.tsv, team.tsv, profiles.tsv, examples.tsv, preds.tsv,
//! effects-champcomp-*.tsv and findings.tsv in the working directory; last stdout line
//! RESULT

const std = @import("std");
const api = @import("api");
const cand = @import("cand");
const rows = @import("rows.zig");
const harness = @import("harness.zig");
const compstats = @import("compstats.zig");
const comps = @import("comps.zig");
const synth = @import("synth.zig");
const snapcache = @import("snapcache.zig");
const par = @import("../par.zig");

const Io = std.Io;
const Allocator = std.mem.Allocator;
const vi = comps.vi;

pub const usage =
    \\  champcomp SNAP [--permute-profiles SEED] [--shuffle-traits SEED] [--export DIR]
    \\                [--only FEATURE] [--aa FILE] [--groups | --group-shuffle SEED]
    \\                                  champions into comps, dev only, built with
    \\                                  -Dcand=src/lab/cand/win-ratings (or win-comp, an
    \\                                  offset with the damage mix, or win-draft, the
    \\                                  shipped model): per champion-role,
    \\                                  win against the enemy team's and its allies'
    \\                                  traits beyond ratings and its role's average,
    \\                                  shrunk, on comps' folds and dev-val
    \\                                  (lab/champcomp.zig); SNAP may be plant:SPEC:PATH
    \\                                  (champ_melee, cell); --export writes
    \\                                  DIR/draft-comp.json from the dev-val fit for the
    \\                                  admin Draft tester (offset win-draft); --only
    \\                                  enemy:ap_share fits that feature alone;
    \\                                  --aa FILE: the auto-attack trait (deploy/
    \\                                  aa-build.sh); --groups: deviations shrink
    \\                                  towards their kit groups', paired against
    \\                                  the plain terms
    \\
;

/// aa last: champgroups takes the others (it has aa_build as an own stat already)
pub const Trait = enum { ap_share, melee, cc, engage, dive, tank, sustain, early, aa };
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
    "auto-attack build",
};

/// A kit group: champions (any role) whose deviation on one enemy trait is guessed
/// together
pub const KitGroup = struct { label: []const u8, words: []const u8, trait: Trait, champions: []const []const u8 };

/// champgroups' detected six (docs/model.md "Kit groups and a property scan"), on the
/// enemy trait each was declared on. G1 without Fiora: post hoc, she went the other way
pub const kit_groups = [_]KitGroup{
    .{ .label = "G1", .words = "auto-attack punishers", .trait = .aa, .champions = &.{ "Rammus", "Jax", "Shen", "Teemo", "Malphite" } },
    .{ .label = "G3", .words = "CC answers", .trait = .cc, .champions = &.{ "Olaf", "Gangplank", "Sivir", "Morgana", "Nocturne", "Malzahar", "Fizz" } },
    .{ .label = "G4", .words = "lethality assassins", .trait = .tank, .champions = &.{ "Zed", "Talon", "Kha'Zix", "Rengar", "Qiyana", "Naafiri" } },
    .{ .label = "G5", .words = "true and %HP damage dealers", .trait = .tank, .champions = &.{ "Vayne", "Fiora", "Gwen", "Kog'Maw", "Vel'Koz", "Brand", "Lillia" } },
    .{ .label = "G6", .words = "magic resist kits", .trait = .ap_share, .champions = &.{ "Galio", "Kassadin", "Sivir", "Malzahar", "Morgana" } },
    .{ .label = "G11", .words = "armour kits", .trait = .ap_share, .champions = &.{ "Rammus", "Malphite", "Braum", "Poppy" } },
};
const ng = kit_groups.len;

/// The enemy feature a group's coefficient is on
fn groupFeature(g: usize) usize {
    return @backingInt(kit_groups[g].trait);
}

/// Per champion-role: bit g set when the champion is in kit group g
pub const Members = std.AutoHashMapUnmanaged(u64, u32);

/// Raw auto-attack build per champion-role (deploy/aa-build.sh) and its role mean and sd
/// over fit seats; a champion-role without a line is its role's mean
pub const Aa = struct {
    raw: *const std.AutoHashMapUnmanaged(u64, f64),
    mean: [5]f64 = @splat(0),
    sd: [5]f64 = @splat(1),

    fn z(a: *const Aa, champion: u32, role: usize) f64 {
        const v = a.raw.get(comps.cellKey(champion, role)) orelse return 0;
        return (v - a.mean[role]) / a.sd[role];
    }
};

/// FILE: header line, then champion id, role index, aa_build
pub fn loadAa(gpa: Allocator, io: Io, path: []const u8) !std.AutoHashMapUnmanaged(u64, f64) {
    const text = try Io.Dir.cwd().readFileAlloc(io, path, gpa, .unlimited);
    defer gpa.free(text);
    var out: std.AutoHashMapUnmanaged(u64, f64) = .empty;
    errdefer out.deinit(gpa);
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    _ = lines.next();
    while (lines.next()) |line| {
        var it = std.mem.tokenizeScalar(u8, line, '\t');
        const c = try std.fmt.parseInt(u32, it.next() orelse return error.BadAaFile, 10);
        const r = try std.fmt.parseInt(usize, it.next() orelse return error.BadAaFile, 10);
        const v = try std.fmt.parseFloat(f64, it.next() orelse return error.BadAaFile);
        try out.put(gpa, comps.cellKey(c, r), v);
    }
    return out;
}

/// aa's role mean and sd over the given games' seats (as champgroups')
fn aaOf(raw: *const std.AutoHashMapUnmanaged(u64, f64), d: *const rows.Data, games: []const u32) Aa {
    var a: Aa = .{ .raw = raw };
    var q: [5]f64 = @splat(0);
    var n: [5]f64 = @splat(0);
    for (games) |gi| for (d.games[gi].teams) |t| for (t, 0..) |ch, r| {
        const v = raw.get(comps.cellKey(ch, r)) orelse continue;
        a.mean[r] += v;
        q[r] += v * v;
        n[r] += 1;
    };
    for (&a.mean, &a.sd, q, n) |*m, *sd, qq, nn| {
        m.* /= @max(nn, 1);
        sd.* = @sqrt(@max(qq / @max(nn, 1) - m.* * m.*, 1e-12));
    }
    return a;
}

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

/// seatOf with the auto-attack build (0 without aa)
fn seatWith(p: *const comps.Profiles, aa: ?*const Aa, champion: u32, role: usize) Seat {
    var s = seatOf(p, champion, role);
    if (aa) |a| s.v[@backingInt(Trait.aa)] = a.z(champion, role);
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

/// A seat's 18 raw features in its game: enemy team, then its four allies
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

/// A team's 18 raw features: enemy team, then its own five
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

const logit = @import("nn").logit;
const sigmoid = @import("nn").sigmoid;

/// Ratings' chance for blue in every game with start < hi (not test, played), fitted on
/// the dev games before `before`; NaN elsewhere. As compcheck.offset: the same seeds, the
/// same query
pub fn ratingsBlue(gpa: Allocator, d: *const rows.Data, players: []const harness.Players, c: harness.Cuts, before: i64, hi: i64) ![]f64 {
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

/// ratingsBlue per window through snapcache (offsets-BEFORE-HI), keyed by this binary,
/// the snapshot argument (plant: specs too) and the game count: champcomp's controls and
/// champgroups (fold 3's window) refit the same offsets, 15-40 s each
pub const Offsets = struct {
    data_path: []const u8,
    key: u64,

    pub fn init(gpa: Allocator, io: Io, snap: []const u8, data_path: []const u8, d: *const rows.Data) !Offsets {
        var h: std.hash.Wyhash = .init(try snapcache.exeHash(gpa, io));
        h.update(snap);
        h.update(std.mem.asBytes(&d.games.len));
        return .{ .data_path = data_path, .key = h.final() };
    }

    pub fn get(o: *const Offsets, gpa: Allocator, io: Io, d: *const rows.Data, players: []const harness.Players, c: harness.Cuts, before: i64, hi: i64) ![]f64 {
        var nb: [64]u8 = undefined;
        const name = try std.mem.print(&nb, "offsets-{d}-{d}", .{ before, hi });
        const out = try gpa.alloc(f64, d.games.len);
        errdefer gpa.free(out);
        const io_ = struct {
            fn read(v: []f64, r: *Io.Reader) !void {
                try r.readSliceAll(std.mem.sliceAsBytes(v));
            }
            fn write(v: []const f64, w: *Io.Writer) !void {
                try w.writeAll(std.mem.sliceAsBytes(v));
            }
        };
        if (try snapcache.load(gpa, io, o.data_path, name, o.key, out, io_.read)) return out;
        const blue = try ratingsBlue(gpa, d, players, c, before, hi);
        defer gpa.free(blue);
        @memcpy(out, blue);
        snapcache.save(gpa, io, o.data_path, name, o.key, @as([]const f64, out), io_.write);
        return out;
    }
};

fn included(g: rows.Game, hi: i64) bool {
    return !g.is_test and harness.played(g) and g.start < hi;
}

fn toF32(x: [nf]f64) [nf]f32 {
    var out: [nf]f32 = undefined;
    for (&out, x) |*a, b| a.* = @floatCast(b);
    return out;
}

/// Units of the given games, raw features (not yet standardised)
fn unitsOf(gpa: Allocator, d: *const rows.Data, p: *const comps.Profiles, aa: ?*const Aa, games: []const u32, blue: []const f64, out: *Units) !void {
    for (games) |gi| {
        const g = d.games[gi];
        var seats: [2][5]Seat = undefined;
        for (g.teams, 0..) |t, s| for (t, 0..) |ch, r| {
            seats[s][r] = seatWith(p, aa, ch, r);
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

/// Every feature but f set to 0 (they then fit to 0 with a huge se and drop out)
fn keepOnly(u: *Units, f: usize) void {
    for ([_][]Unit{ u.seats.items, u.teams.items }) |list| for (list) |*x| {
        for (&x.x, 0..) |*v, j| if (j != f) {
            v.* = 0;
        };
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
    /// --groups: each kit group's coefficient (logit per sd on its feature: a member's
    /// deviation beyond a non-member's), their covariance, and each role's
    /// precision-weighted member share. Memberships are centred on the share, so a role's
    /// deviations still average 0 and nothing moves into the team terms; 0 otherwise
    gamma: [ng]f64 = @splat(0),
    cov: [ng][ng]f64 = @splat(@splat(0)),
    share: [5][ng]f64 = @splat(@splat(0)),

    /// Group g's centred membership for a cell of role with mask
    fn centred(rf: *const RoleFit, role: usize, g: usize, mask: u32) f64 {
        const in: f64 = @floatFromInt((mask >> @intCast(g)) & 1);
        return in - rf.share[role][g];
    }

    /// Group g's part of a cell's expected deviation
    pub fn part(rf: *const RoleFit, role: usize, g: usize, mask: u32) f64 {
        return rf.gamma[g] * rf.centred(role, g, mask);
    }

    /// A cell's expected deviation from its role's mean on feature f, and that guess's
    /// variance
    fn target(rf: *const RoleFit, role: usize, f: usize, mask: u32) [2]f64 {
        var t: f64 = 0;
        var v: f64 = 0;
        for (0..ng) |a| {
            if (groupFeature(a) != f) continue;
            const za = rf.centred(role, a, mask);
            t += rf.gamma[a] * za;
            for (0..ng) |b| if (groupFeature(b) == f) {
                v += za * rf.centred(role, b, mask) * rf.cov[a][b];
            };
        }
        return .{ t, v };
    }
};

/// members: per cell its kit group mask (--groups), else null
pub fn roleFit(cells: []const u64, ests: []const Est, members: ?[]const u32) RoleFit {
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
    spreadOf(&rf, cells, ests, members, wsum);
    const mm = members orelse return rf;
    for (0..ng) |g| {
        const f = groupFeature(g);
        for (cells, ests, mm) |c, e, mask| {
            if (!e.ok() or (mask >> @intCast(g)) & 1 == 0) continue;
            rf.share[c & 7][g] += 1 / (e.se[f] * e.se[f]);
        }
        for (0..5) |role| if (wsum[role][f] > 0) {
            rf.share[role][g] /= wsum[role][f];
        };
    }
    // The coefficients' weights depend on the spread left around them: twice
    for (0..2) |_| {
        groupFit(&rf, cells, ests, mm, null);
        spreadOf(&rf, cells, ests, members, wsum);
    }
    return rf;
}

/// Weighted least squares of the cells' raw deviations on their centred memberships, per
/// feature over every role, weights 1 / (se^2 + tau^2); skip leaves one cell out
fn groupFit(rf: *RoleFit, cells: []const u64, ests: []const Est, members: []const u32, skip: ?usize) void {
    var a: [ng][ng]f64 = @splat(@splat(0));
    var b: [ng]f64 = @splat(0);
    for (cells, ests, members, 0..) |c, e, mask, ci| {
        if (!e.ok()) continue;
        if (skip) |s| if (s == ci) continue;
        const role: usize = @intCast(c & 7);
        for (0..ng) |g| {
            const f = groupFeature(g);
            const w = 1 / (e.se[f] * e.se[f] + rf.tau2[role][f]);
            const zg = rf.centred(role, g, mask);
            b[g] += w * zg * (e.beta[f] - rf.m[role][f]);
            for (0..ng) |h| if (groupFeature(h) == f) {
                a[g][h] += w * zg * rf.centred(role, h, mask);
            };
        }
    }
    rf.cov = invertSmall(a);
    for (&rf.gamma, rf.cov) |*gm, row| {
        var s: f64 = 0;
        for (row, b) |x, y| s += x * y;
        gm.* = s;
    }
}

/// Inverse of a symmetric positive semi-definite matrix (Gauss-Jordan, no pivoting); a
/// group with no weight (no fitted cells) gets zero rows and columns
fn invertSmall(a_in: [ng][ng]f64) [ng][ng]f64 {
    var a = a_in;
    var inv: [ng][ng]f64 = @splat(@splat(0));
    var empty: [ng]bool = undefined;
    for (0..ng) |g| {
        empty[g] = !(a[g][g] > 0);
        if (empty[g]) {
            for (0..ng) |h| {
                a[g][h] = 0;
                a[h][g] = 0;
            }
            a[g][g] = 1;
        }
        inv[g][g] = 1;
    }
    for (0..ng) |col| {
        const piv = a[col][col];
        for (0..ng) |j| {
            a[col][j] /= piv;
            inv[col][j] /= piv;
        }
        for (0..ng) |row| {
            const k = a[row][col];
            if (row == col or k == 0) continue;
            for (0..ng) |j| {
                a[row][j] -= k * a[col][j];
                inv[row][j] -= k * inv[col][j];
            }
        }
    }
    for (0..ng) |g| if (empty[g]) for (0..ng) |h| {
        inv[g][h] = 0;
        inv[h][g] = 0;
    };
    return inv;
}

/// DerSimonian-Laird spread of each role and feature's deviations around their target
fn spreadOf(rf: *RoleFit, cells: []const u64, ests: []const Est, members: ?[]const u32, wsum: [5][nf]f64) void {
    var q: [5][nf]f64 = @splat(@splat(0));
    var w2sum: [5][nf]f64 = @splat(@splat(0));
    for (cells, ests, 0..) |c, e, ci| {
        if (!e.ok()) continue;
        const role: usize = @intCast(c & 7);
        for (0..nf) |f| {
            const w = 1 / (e.se[f] * e.se[f]);
            const t = rf.target(role, f, if (members) |mm| mm[ci] else 0)[0];
            const dlt = e.beta[f] - rf.m[role][f] - t;
            q[role][f] += w * dlt * dlt;
            w2sum[role][f] += w * w;
        }
    }
    rf.tau2 = @splat(@splat(0));
    for (0..5) |role| for (0..nf) |f| {
        const k: f64 = @floatFromInt(rf.cells[role]);
        if (k < 2) continue;
        // No spread unless Q shows one: a positive estimate by chance let noise through
        // on planted data with none (champion terms 0.00017 nats/game worse)
        if (q[role][f] <= chi2Quantile(k - 1, heterogeneity_z)) continue;
        const denom = wsum[role][f] - w2sum[role][f] / wsum[role][f];
        rf.tau2[role][f] = @max((q[role][f] - (k - 1)) / denom, 0);
    };
}

/// One-sided normal quantile of the heterogeneity test (1%)
const heterogeneity_z = 2.326;

/// Chi-squared quantile with df degrees of freedom at normal quantile z (Wilson-Hilferty)
fn chi2Quantile(df: f64, z: f64) f64 {
    const a = 2 / (9 * df);
    const t = 1 - a + z * @sqrt(a);
    return df * t * t * t;
}

/// Posterior deviation of one cell and feature from its role's mean (logit per sd), sd;
/// group: its kit groups' part (the prior's mean), own_sd: the sd of the rest given it
pub const Post = struct { mean: f64 = 0, sd: f64 = 0, group: f64 = 0, own_sd: f64 = 0 };

/// mask: the cell's kit groups (--groups; else 0)
pub fn posterior(rf: *const RoleFit, role: usize, e: Est, f: usize, mask: u32) Post {
    if (!e.ok()) return .{};
    const t2 = rf.tau2[role][f];
    const s2 = e.se[f] * e.se[f] + rf.m_se[role][f] * rf.m_se[role][f];
    if (t2 + s2 == 0) return .{};
    const b = t2 / (t2 + s2);
    const t = rf.target(role, f, mask);
    return .{ .mean = t[0] + b * (e.beta[f] - rf.m[role][f] - t[0]), .sd = @sqrt(b * s2 + (1 - b) * (1 - b) * t[1]), .group = t[0], .own_sd = @sqrt(b * s2) };
}

/// A fitted model: team terms, and per cell the posterior deviations and centres
pub const Model = struct {
    team: Est,
    cells: []u64,
    ests: []Est,
    rf: RoleFit,
    post: [][nf]Post,
    /// Per cell: its kit group mask with --groups, else 0
    members: []u32,
    index: std.AutoHashMapUnmanaged(u64, u32) = .empty,

    pub fn deinit(m: *Model, gpa: Allocator) void {
        gpa.free(m.cells);
        gpa.free(m.ests);
        gpa.free(m.post);
        gpa.free(m.members);
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

/// Each profiled champion-role's kit groups (ids: each group's champion ids); seed
/// nonzero shuffles the masks among a role's champion-roles (a control)
fn membersOf(gpa: Allocator, p: *const comps.Profiles, ids: *const [ng][]const u32, seed: u64, out: *Members) !void {
    var keys: std.ArrayList(u64) = .empty;
    defer keys.deinit(gpa);
    var it = p.raw.keyIterator();
    while (it.next()) |k| try keys.append(gpa, k.*);
    std.mem.sort(u64, keys.items, {}, std.sort.asc(u64));
    var rng: std.Random.DefaultPrng = .init(seed);
    for (0..5) |role| {
        var masks: std.ArrayList(u32) = .empty;
        defer masks.deinit(gpa);
        var mine: std.ArrayList(u64) = .empty;
        defer mine.deinit(gpa);
        for (keys.items) |k| if ((k & 7) == role) {
            var mask: u32 = 0;
            for (ids, 0..) |list, g| {
                if (std.mem.findScalar(u32, list, @intCast(k >> 3)) != null) mask |= @as(u32, 1) << @intCast(g);
            }
            try mine.append(gpa, k);
            try masks.append(gpa, mask);
        };
        if (seed != 0) rng.random().shuffle(u32, masks.items);
        for (mine.items, masks.items) |k, v| if (v != 0) try out.put(gpa, k, v);
    }
}

/// Team terms over every team, then two passes of per-cell fits and deviation shrinkage
/// on the seats (ten a game, in step with the teams, two a game); members: --groups
pub fn fitModel(gpa: Allocator, u: *const Units, members: ?*const Members) !Model {
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
        .members = try gpa.alloc(u32, grp.cells.len),
    };
    errdefer m.deinit(gpa);
    for (m.cells, m.members, 0..) |c, *k, i| {
        try m.index.put(gpa, c, @intCast(i));
        k.* = if (members) |x| x.get(c) orelse 0 else 0;
    }
    const extra = try gpa.alloc(f64, seats.len);
    defer gpa.free(extra);
    for (0..passes) |pass| {
        for (extra, 0..) |*e, i| e.* = m.teamTerm(&teams[i / 5].x);
        if (pass > 0) addOtherSeats(&m, seats, extra);
        for (m.ests, 0..) |*e, ci| e.* = try fitCell(gpa, seats, grp.of(ci), extra);
        m.rf = roleFit(m.cells, m.ests, if (members != null) m.members else null);
        for (m.cells, m.ests, m.post, m.members) |c, e, *p, k| {
            for (0..nf) |f| p[f] = posterior(&m.rf, @intCast(c & 7), e, f, k);
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

/// DIR/preds.tsv rows (netcheck's shape): blue's chance from the offset, + team terms, + all
fn writePreds(w: *Io.Writer, d: *const rows.Data, m: *const Model, u: *const Units, block: []const u8) !void {
    for (0..u.teams.items.len / 2) |k| {
        const t = u.teams.items[2 * k];
        const z0: f64 = t.off;
        try w.print("{s}\t{s}\t{d}\t{d:.6}\t{d:.6}\t{d:.6}\n", .{
            block,                                  d.games[t.game].match_id,                t.y, sigmoid(z0),
            sigmoid(z0 + blueExtra(m, u, k, true)), sigmoid(z0 + blueExtra(m, u, k, false)),
        });
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

/// The champion's own part over its sd: a group part is tested by its coefficient (in a
/// role with no spread a non-member's small centring term would otherwise be as clear as
/// its group)
fn zOf(p: Post) f64 {
    return if (p.own_sd > 0) (p.mean - p.group) / p.own_sd else 0;
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
    return std.mem.print(buf, "{s}:{s}", .{ if (f < nt) "enemy" else "ally", trait_names[f % nt] }) catch "?";
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
    /// --groups, leave one member out: per group, over its member cells fitted on both
    loo: [ng]Loo = @splat(.{}),
};

/// d: a member's raw deviation on the newer games; t: its group's guess fitted without it
/// on the older ones; v = d's se^2 + the older fit's spread
const Loo = struct {
    n: usize = 0,
    /// |d - t| < |d|
    closer: usize = 0,
    /// sum ((d - t)^2 - d^2) / v: below 0 when the guess beats the role's mean
    sse: f64 = 0,
    /// sum t d / v and sum t^2 / v: d's slope on t is td / tt with se 1 / sqrt(tt)
    td: f64 = 0,
    tt: f64 = 0,

    fn plus(a: Loo, b: Loo) Loo {
        return .{ .n = a.n + b.n, .closer = a.closer + b.closer, .sse = a.sse + b.sse, .td = a.td + b.td, .tt = a.tt + b.tt };
    }
};

/// Windows fitted at once: each holds its fit units and profiles (~2 GB) beside the
/// shared rows (~6 GB); the gpu-box's WSL has 24 GB
const max_windows = 3;
/// Fold 3 also scores the replication window: everything up to the dev cut
const replicate_window = 2;

/// One window's fit and scores, from WinJob.run; main reports them in window order
const WinOut = struct {
    p: ?comps.Profiles = null,
    model: ?Model = null,
    score_u: Units = .{},
    seat_scale: Scale = undefined,
    sc: Scores = .{},
    /// --groups: the plain terms' scores on the same games, which scored games have a
    /// member in either team, and the plain terms' spread
    psc: Scores = .{},
    member_game: std.ArrayList(bool) = .empty,
    plain_tau2: [5][nf]f64 = @splat(@splat(0)),
    aa: ?Aa = null,
    cc: Clear = .{},
    rep: Replication = .{},
    fit_n: usize = 0,
    score_n: usize = 0,

    fn deinit(o: *WinOut, gpa: Allocator) void {
        if (o.p) |*p| p.deinit(gpa);
        if (o.model) |*m| m.deinit(gpa);
        o.score_u.deinit(gpa);
        o.sc.deinit(gpa);
        o.psc.deinit(gpa);
        o.member_game.deinit(gpa);
    }
};

const WinJob = struct {
    gpa: Allocator,
    io: Io,
    d: *const rows.Data,
    extra: []const ?compstats.Seat,
    players: []const harness.Players,
    c: harness.Cuts,
    offsets: *const Offsets,
    windows: []const Window,
    outs: []WinOut,
    permute: u64,
    shuffle: u64,
    only: ?usize,
    aa_raw: ?*const std.AutoHashMapUnmanaged(u64, f64),
    /// --groups: each kit group's champion ids
    groups: ?*const [ng][]const u32,
    group_shuffle: u64,

    fn run(j: *const WinJob, wi: usize) !void {
        const gpa = j.gpa;
        const d = j.d;
        const c = j.c;
        const win = j.windows[wi];
        const o = &j.outs[wi];
        const fit_cfg: comps.Fit = .{ .c = c, .before = win.before };
        o.p = try comps.buildProfiles(gpa, d, j.extra, fit_cfg, j.permute);
        const p = &o.p.?;
        const replicate = wi == replicate_window;
        const blue = try j.offsets.get(gpa, j.io, d, j.players, c, win.before, if (replicate) c.dev else win.hi);
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
        o.fit_n = fit_games.items.len;
        o.score_n = score_games.items.len;
        if (j.aa_raw) |r| o.aa = aaOf(r, d, fit_games.items);
        const aa = if (o.aa) |*a| a else null;
        var fit_u: Units = .{};
        defer fit_u.deinit(gpa);
        try unitsOf(gpa, d, p, aa, fit_games.items, blue, &fit_u);
        try unitsOf(gpa, d, p, aa, score_games.items, blue, &o.score_u);
        o.seat_scale = scaleOf(fit_u.seats.items);
        const team_scale = scaleOf(fit_u.teams.items);
        for ([_]*Units{ &fit_u, &o.score_u }) |u| {
            standardise(u.seats.items, o.seat_scale);
            standardise(u.teams.items, team_scale);
        }
        if (j.shuffle != 0) {
            try shuffleTraits(gpa, &fit_u, j.shuffle);
            try shuffleTraits(gpa, &o.score_u, j.shuffle +% 1);
        }
        if (j.only) |f| for ([_]*Units{ &fit_u, &o.score_u }) |u| keepOnly(u, f);

        var members: Members = .empty;
        defer members.deinit(gpa);
        if (j.groups) |ids| try membersOf(gpa, p, ids, j.group_shuffle, &members);
        o.model = try fitModel(gpa, &fit_u, if (j.groups != null) &members else null);
        const model = &o.model.?;
        try scoreGames(gpa, model, &o.score_u, &o.sc);
        if (j.groups != null) {
            var plain = try fitModel(gpa, &fit_u, null);
            defer plain.deinit(gpa);
            try scoreGames(gpa, &plain, &o.score_u, &o.psc);
            o.plain_tau2 = plain.rf.tau2;
            const seats = o.score_u.seats.items;
            for (0..seats.len / 10) |k| {
                const any = for (seats[10 * k ..][0..10]) |st| {
                    if (members.contains(st.cell)) break true;
                } else false;
                try o.member_game.append(gpa, any);
            }
        }
        o.cc = try countClear(gpa, model);
        if (replicate) o.rep = try replicateOn(gpa, d, p, aa, model, o.cc, rep_games.items, blue, o.seat_scale, team_scale, j.shuffle, j.only, j.groups != null);
    }
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
    var export_dir: ?[]const u8 = null;
    var only: ?usize = null;
    var aa_path: ?[]const u8 = null;
    var groups_on = false;
    var group_shuffle: u64 = 0;
    var i: usize = 1;
    while (i < argv.len) : (i += 1) {
        const a = argv[i];
        if (std.mem.eql(u8, a, "--permute-profiles") and i + 1 < argv.len) {
            i += 1;
            permute = try std.fmt.parseInt(u64, argv[i], 10);
        } else if (std.mem.eql(u8, a, "--shuffle-traits") and i + 1 < argv.len) {
            i += 1;
            shuffle = try std.fmt.parseInt(u64, argv[i], 10);
        } else if (std.mem.eql(u8, a, "--export") and i + 1 < argv.len) {
            i += 1;
            export_dir = argv[i];
        } else if (std.mem.eql(u8, a, "--aa") and i + 1 < argv.len) {
            i += 1;
            aa_path = argv[i];
        } else if (std.mem.eql(u8, a, "--groups")) {
            groups_on = true;
        } else if (std.mem.eql(u8, a, "--group-shuffle") and i + 1 < argv.len) {
            i += 1;
            groups_on = true;
            group_shuffle = try std.fmt.parseInt(u64, argv[i], 10);
        } else if (std.mem.eql(u8, a, "--only") and i + 1 < argv.len) {
            i += 1;
            var fb: [32]u8 = undefined;
            only = for (0..nf) |f| {
                if (std.mem.eql(u8, featureName(&fb, f), argv[i])) break f;
            } else {
                std.debug.print("champcomp --only: no feature {s}\n", .{argv[i]});
                return 2;
            };
        } else {
            std.debug.print("usage:\n{s}", .{usage});
            return 2;
        }
    }
    const data_path = if (try synth.parseArg(snap)) |pa| pa.path else snap;
    // The tester lays these terms on the shipped model, so they must be fitted beyond it
    if (export_dir != null and (permute != 0 or shuffle != 0 or only != null or group_shuffle != 0 or !std.mem.eql(u8, cand.name, "win-draft"))) {
        std.debug.print("champcomp --export: build with -Dcand=src/lab/cand/win-draft, no controls\n", .{});
        return 2;
    }
    if (groups_on and aa_path == null) {
        std.debug.print("champcomp --groups: needs --aa FILE (G1 is on the auto-attack trait)\n", .{});
        return 2;
    }
    var aa_raw: std.AutoHashMapUnmanaged(u64, f64) = if (aa_path) |ap| try loadAa(gpa, io, ap) else .empty;
    defer aa_raw.deinit(gpa);

    var buf: [4096]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &buf);
    const w = &stdout.interface;

    var data = try rows.loadSnap(gpa, io, snap);
    defer data.deinit();
    const d = &data;
    const players = try harness.gamePlayers(gpa, d);
    defer gpa.free(players);
    const c = try harness.cuts(gpa, d);
    const names = try rows.loadNames(gpa, arena, data_path);
    const offset_cache = try Offsets.init(gpa, io, snap, data_path, d);
    var group_ids: [ng][]const u32 = undefined;
    for (&group_ids, kit_groups) |*ids, grp| {
        const list = try arena.alloc(u32, grp.champions.len);
        for (list, grp.champions) |*id, want| {
            var it = names.iterator();
            id.* = while (it.next()) |e| {
                if (std.mem.eql(u8, e.value_ptr.*, want)) break e.key_ptr.*;
            } else {
                std.debug.print("champcomp: {s}: no champion {s}\n", .{ grp.label, want });
                return 2;
            };
        }
        ids.* = list;
    }

    const extra = try gpa.alloc(?compstats.Seat, d.rows.len);
    defer gpa.free(extra);
    const team_obj = try gpa.alloc(?[2]compstats.Team, d.games.len);
    defer gpa.free(team_obj);
    const placed = try comps.loadExtra(gpa, io, d, data_path, extra, team_obj);
    var with_stats: usize = 0;
    for (d.rows) |r| with_stats += @intFromBool(!std.math.isNan(r.stats[0]));
    var ob: [32]u8 = undefined;
    const only_name = if (only) |f| featureName(&ob, f) else "";
    try w.print("# champcomp, offset {s}{s}{s}{s}{s}{s}, {s}\nrows {d}: with seat stats {d}, comp_stats lines placed {d}\n", .{ cand.name, if (permute != 0) ", PERMUTED profiles" else "", if (shuffle != 0) ", SHUFFLED traits" else "", if (only != null) ", ONLY " else "", only_name, if (aa_path == null) ", no aa trait" else if (group_shuffle != 0) ", kit groups SHUFFLED" else if (groups_on) ", kit groups" else "", snap, d.rows.len, with_stats, placed.seats });
    if (with_stats == 0) return error.NoSeatStats;
    try w.print("fold bounds {any}, dev cut {d}, test cut {d}\n", .{ c.bounds[0..5], c.dev, c.test_ });
    try w.flush();

    var windows: [harness.folds + 1]Window = undefined;
    for (1..harness.folds + 1) |k| {
        const f = c.fold(k);
        windows[k - 1] = .{ .label = try arena.print("fold {d}", .{k}), .before = f.lo, .lo = f.lo, .hi = f.hi };
    }
    windows[harness.folds] = .{ .label = "dev-val", .before = c.dev, .lo = c.dev, .hi = c.test_ };

    var pooled: Scores = .{};
    defer pooled.deinit(gpa);
    var gains: [harness.folds + 1]Gain = undefined;
    // --groups against the plain terms on the same games: every game, games with a member
    var group_gains: [harness.folds + 1][2]Gain = undefined;
    var pooled_plain: [2]std.ArrayList(f64) = @splat(.empty);
    var pooled_groups: [2]std.ArrayList(f64) = @splat(.empty);
    defer for ([_]*[2]std.ArrayList(f64){ &pooled_plain, &pooled_groups }) |l| for (l) |*x| x.deinit(gpa);
    var final_clear: Clear = .{};
    var rep: Replication = .{};

    var preds_file = try Io.Dir.cwd().createFile(io, "preds.tsv", .{});
    defer preds_file.close(io);
    var pbuf: [64 * 1024]u8 = undefined;
    var pw = preds_file.writer(io, &pbuf);
    try pw.interface.writeAll("fold\tmatch_id\ty\tcand\tteam\tfull\n");

    var outs: [harness.folds + 1]WinOut = @splat(.{});
    defer for (&outs) |*o| o.deinit(gpa);
    const job: WinJob = .{
        .gpa = gpa,
        .io = io,
        .d = d,
        .extra = extra,
        .players = players,
        .c = c,
        .offsets = &offset_cache,
        .windows = &windows,
        .outs = &outs,
        .permute = permute,
        .shuffle = shuffle,
        .only = only,
        .aa_raw = if (aa_path != null) &aa_raw else null,
        .groups = if (groups_on) &group_ids else null,
        .group_shuffle = group_shuffle,
    };
    try par.forEachUpTo(io, windows.len, max_windows, &job, WinJob.run);

    for (windows, &outs, 0..) |win, *o, wi| {
        const model = &o.model.?;
        var lb: [8]u8 = undefined;
        const block = if (wi == harness.folds) "dev" else try std.mem.print(&lb, "{d}", .{wi + 1});
        try writePreds(&pw.interface, d, model, &o.score_u, block);
        if (groups_on) {
            var mp: std.ArrayList(f64) = .empty;
            defer mp.deinit(gpa);
            var mg: std.ArrayList(f64) = .empty;
            defer mg.deinit(gpa);
            for (o.psc.full.items, o.sc.full.items, o.member_game.items) |a, b, in| if (in) {
                try mp.append(gpa, a);
                try mg.append(gpa, b);
            };
            group_gains[wi] = .{ gainOf(o.psc.full.items, o.sc.full.items), gainOf(mp.items, mg.items) };
            if (wi < harness.folds) {
                try pooled_plain[0].appendSlice(gpa, o.psc.full.items);
                try pooled_groups[0].appendSlice(gpa, o.sc.full.items);
                try pooled_plain[1].appendSlice(gpa, mp.items);
                try pooled_groups[1].appendSlice(gpa, mg.items);
            }
            const gg = group_gains[wi];
            try w.print("{s}: groups vs plain terms {d:.5} ± {d:.5}, games with a member {d:.5} ± {d:.5} ({d} games); pp per sd:", .{ win.label, gg[0].mean, gg[0].half, gg[1].mean, gg[1].half, gg[1].n });
            for (kit_groups, 0..) |grp, g| try w.print(" {s} {d:.2} ± {d:.2}", .{ grp.label, model.rf.gamma[g] * pp_per_logit, 1.96 * @sqrt(model.rf.cov[g][g]) * pp_per_logit });
            try w.writeAll("\n");
        }
        gains[wi] = gainOf(o.sc.base.items, o.sc.full.items);
        const team_gain = gainOf(o.sc.base.items, o.sc.team.items);
        const seat_gain = gainOf(o.sc.team.items, o.sc.full.items);
        const cc = o.cc;
        try w.print("{s}: fit {d} games, scored {d}; log loss vs ratings {d:.5} ± {d:.5} (team terms {d:.5} ± {d:.5}, then champion terms {d:.5} ± {d:.5}); clear {d} of {d}, BH {d}\n", .{
            win.label,      o.fit_n,        o.score_n,      gains[wi].mean, gains[wi].half,
            team_gain.mean, team_gain.half, seat_gain.mean, seat_gain.half, cc.clear,
            cc.tests,       cc.bh,
        });
        try w.flush();
        if (wi < harness.folds) {
            try pooled.base.appendSlice(gpa, o.sc.base.items);
            try pooled.team.appendSlice(gpa, o.sc.team.items);
            try pooled.full.appendSlice(gpa, o.sc.full.items);
        }
        if (wi == replicate_window) {
            rep = o.rep;
            try w.print("replication: {d} deviations clear before bounds[2], same sign on the newer dev games ({d} games) {d}, mean signed z {d:.2}; BH passes {d}, same sign {d}\n", .{
                rep.clear, rep.games, rep.agree, if (rep.clear > 0) rep.z_sum / @as(f64, @floatFromInt(rep.clear)) else 0, rep.bh, rep.bh_agree,
            });
        }
        if (wi == harness.folds) {
            final_clear = cc;
            const p = &o.p.?;
            const aa = if (o.aa) |*a| a else null;
            try writeOutputs(gpa, arena, io, d, model, p, aa, o.seat_scale, &names, &o.score_u, cc);
            if (export_dir) |dir| {
                var better: u32 = 0;
                for (gains[0..harness.folds]) |g| better += @intFromBool(g.mean < 0);
                const meta: ExportMeta = .{
                    .snapshot = std.fs.path.basename(data_path),
                    .fit_games = @intCast(o.fit_n),
                    .folds = gainOf(pooled.base.items, pooled.full.items),
                    .better = better,
                    .devval = gains[wi],
                    .clear = cc.clear,
                    .tests = cc.tests,
                    .bh = cc.bh,
                };
                try writeExport(arena, io, d, model, p, aa, o.seat_scale, &o.score_u, meta, groups_on, dir);
                try w.print("wrote {s}/draft-comp.json\n", .{dir});
            }
        }
    }

    try pw.interface.flush();
    const all = gainOf(pooled.base.items, pooled.full.items);
    const team_all = gainOf(pooled.base.items, pooled.team.items);
    const seat_all = gainOf(pooled.team.items, pooled.full.items);
    var better: usize = 0;
    for (gains[0..harness.folds]) |g| better += @intFromBool(g.mean < 0);
    const dv = gains[harness.folds];
    try w.print("folds pooled: {d:.5} ± {d:.5} nats/game over {d} games (team terms {d:.5} ± {d:.5}, champion terms {d:.5} ± {d:.5}), better in {d} of {d}; dev-val {d:.5} ± {d:.5}\n", .{
        all.mean, all.half, all.n, team_all.mean, team_all.half, seat_all.mean, seat_all.half, better, harness.folds, dv.mean, dv.half,
    });
    var group_buf: [320]u8 = undefined;
    var group_text: []const u8 = "";
    if (groups_on) {
        var pooled_g: [2]Gain = undefined;
        var gb: [2]usize = .{ 0, 0 };
        for (0..2) |k| {
            pooled_g[k] = gainOf(pooled_plain[k].items, pooled_groups[k].items);
            for (group_gains[0..harness.folds]) |g| gb[k] += @intFromBool(g[k].mean < 0);
            const gd = group_gains[harness.folds][k];
            try w.print("groups vs plain terms, {s}, folds pooled: {d:.5} ± {d:.5} nats/game over {d} games, better in {d} of {d}; dev-val {d:.5} ± {d:.5}\n", .{
                if (k == 0) "every game" else "games with a member", pooled_g[k].mean, pooled_g[k].half, pooled_g[k].n, gb[k], harness.folds, gd.mean, gd.half,
            });
        }
        const dvm = &outs[harness.folds].model.?;
        for (kit_groups, 0..) |grp, g| {
            const f = groupFeature(g);
            var fb: [32]u8 = undefined;
            try w.print("dev-val {s} {s} into {s}: {d:.2} ± {d:.2} pp per sd; tau pp by role, plain -> groups:", .{ grp.label, grp.words, featureName(&fb, f), dvm.rf.gamma[g] * pp_per_logit, 1.96 * @sqrt(dvm.rf.cov[g][g]) * pp_per_logit });
            for (0..5) |role| try w.print(" {s} {d:.2} -> {d:.2}", .{ role_names[role], @sqrt(outs[harness.folds].plain_tau2[role][f]) * pp_per_logit, @sqrt(dvm.rf.tau2[role][f]) * pp_per_logit });
            try w.writeAll("\n");
        }
        var all_loo: Loo = .{};
        for (kit_groups, rep.loo) |grp, l| {
            all_loo = all_loo.plus(l);
            try w.print("leave one member out ({s}): {d} members, closer than the role mean {d}, sse {d:.2}, newer deviation per guess {d:.2} ± {d:.2}\n", .{ grp.label, l.n, l.closer, l.sse, if (l.tt > 0) l.td / l.tt else nan, if (l.tt > 0) 1.96 / @sqrt(l.tt) else nan });
        }
        const slope = if (all_loo.tt > 0) all_loo.td / all_loo.tt else nan;
        const slope_se = if (all_loo.tt > 0) 1 / @sqrt(all_loo.tt) else nan;
        try w.print("leave one member out, all: {d} members, closer {d}, sse {d:.2}, slope {d:.2} ± {d:.2}\n", .{ all_loo.n, all_loo.closer, all_loo.sse, slope, 1.96 * slope_se });
        group_text = try std.mem.print(&group_buf, " groups={d:.5}±{d:.5} groups_better={d}/{d} member_games={d:.5}±{d:.5} member_better={d}/{d} member_devval={d:.5}±{d:.5} loo_sse={d:.2} loo_slope={d:.2}±{d:.2} loo_closer={d}/{d}{s}", .{
            pooled_g[0].mean,                   pooled_g[0].half,                   gb[0],       harness.folds, pooled_g[1].mean, pooled_g[1].half, gb[1],     harness.folds,
            group_gains[harness.folds][1].mean, group_gains[harness.folds][1].half, all_loo.sse, slope,         1.96 * slope_se,  all_loo.closer,   all_loo.n, if (group_shuffle != 0) " GROUP-SHUFFLED" else "",
        });
    }
    try w.print("RESULT champcomp folds={d:.5}±{d:.5} better={d}/{d} devval={d:.5}±{d:.5} clear={d}/{d} bh={d} replicated={d}/{d} bh_replicated={d}/{d}{s}{s}{s}\n", .{
        all.mean,          all.half,                              better,                                harness.folds, dv.mean,   dv.half,
        final_clear.clear, final_clear.tests,                     final_clear.bh,                        rep.agree,     rep.clear, rep.bh_agree,
        rep.bh,            if (permute != 0) " PERMUTED" else "", if (shuffle != 0) " SHUFFLED" else "", group_text,
    });
    try w.flush();
    return 0;
}

const ExportMeta = struct {
    snapshot: []const u8,
    fit_games: u32,
    folds: Gain,
    better: u32,
    devval: Gain,
    clear: usize,
    tests: usize,
    bh: usize,
};

/// draft-comp.json (format meiolol-champcomp, docs/model.md "Draft model file"): what the
/// admin Draft tester needs to add each seat's term to the shipped model and split it by
/// trait. A seat's term on its team's logit is sum_f dev[f] * ((x[f] - mean[f]) / sd[f] -
/// centre[f]), x its 18 raw features (traitsOf the enemy's five, then of its four allies)
/// from seat values; an empty slot or a champion-role with no profile is its role's seat.
/// Team terms are left out (folds: -0.00001 ± 0.00005). Cells with every deviation 0 too
fn writeExport(
    arena: Allocator,
    io: Io,
    d: *const rows.Data,
    m: *const Model,
    p: *const comps.Profiles,
    aa: ?*const Aa,
    sc: Scale,
    scored: *const Units,
    meta: ExportMeta,
    groups_on: bool,
    dir: []const u8,
) !void {
    const Feature = struct { name: []const u8, label: []const u8, mean: f64, sd: f64 };
    const CellOut = struct {
        champion: u32,
        role: u8,
        games: u32,
        centre: [nf]f64,
        dev: [nf]f64,
        sd: [nf]f64,
        /// Features whose own part is clear (zOf at or above clear_z); u32, as
        /// JSON writes a u8 slice as a string
        clear: []const u32,
        /// --groups: the part of dev its kit groups predict (group.part summed per
        /// feature, centred memberships, so a non-member's is small and the other way),
        /// and the groups it is in; dev - group is the champion's own part
        group: [nf]f64,
        member: []const u32,
    };
    const GroupOut = struct { label: []const u8, words: []const u8, feature: usize, gamma: f64, sd: f64, members: u32 };
    const Ref = struct { label: []const u8, teams: [2][5]u32, blue: f64 };
    const SeatRow = [2 + 1 + nt]f64;
    var features: [nf]Feature = undefined;
    for (&features, 0..) |*f, fi| {
        const label = try arena.print("{s} {s}", .{ if (fi < nt) "enemy" else "allies'", trait_words[fi % nt] });
        f.* = .{ .name = try arena.dupe(u8, featureName(try arena.alloc(u8, 32), fi)), .label = label, .mean = sc.mean[fi], .sd = sc.sd[fi] };
    }
    // [champion, role, magic, dmg, v[1..]]: v[0] (AP share) is the set's, not a seat's
    var seats: std.ArrayList(SeatRow) = .empty;
    var it = p.raw.iterator();
    while (it.next()) |e| {
        const role: usize = @intCast(e.key_ptr.* & 7);
        const id: u32 = @intCast(e.key_ptr.* >> 3);
        const st = seatWith(p, aa, id, role);
        var row: SeatRow = undefined;
        row[0] = @floatFromInt(id);
        row[1] = @floatFromInt(role);
        row[2] = st.magic;
        row[3] = st.dmg;
        @memcpy(row[4..], st.v[1..]);
        try seats.append(arena, row);
    }
    var role_seats: [5][1 + nt]f64 = undefined;
    for (&role_seats, 0..) |*row, r| {
        // No champion has id 0: raw_of falls back to the role's
        const st = seatOf(p, 0, r);
        row[0] = st.magic;
        row[1] = st.dmg;
        @memcpy(row[2..], st.v[1..]);
    }
    var cells: std.ArrayList(CellOut) = .empty;
    var groups: [ng]GroupOut = undefined;
    for (&groups, kit_groups, 0..) |*g, grp, gi| g.* = .{ .label = grp.label, .words = grp.words, .feature = groupFeature(gi), .gamma = m.rf.gamma[gi], .sd = @sqrt(m.rf.cov[gi][gi]), .members = 0 };
    for (m.cells, m.ests, m.post, m.members) |cell, e, post, mask| {
        if (!e.ok()) continue;
        var any = false;
        const role: usize = @intCast(cell & 7);
        var out: CellOut = .{ .champion = @intCast(cell >> 3), .role = @intCast(cell & 7), .games = e.n, .centre = e.mean_x, .dev = undefined, .sd = undefined, .clear = &.{}, .group = undefined, .member = &.{} };
        var clear: std.ArrayList(u32) = .empty;
        for (post, 0..) |q, f| {
            out.dev[f] = q.mean;
            out.sd[f] = q.sd;
            out.group[f] = m.rf.target(role, f, mask)[0];
            any = any or q.mean != 0;
            if (@abs(zOf(q)) >= clear_z) try clear.append(arena, @intCast(f));
        }
        out.clear = clear.items;
        var member: std.ArrayList(u32) = .empty;
        for (0..ng) |g| if ((mask >> @intCast(g)) & 1 == 1) {
            try member.append(arena, @intCast(g));
            groups[g].members += 1;
        };
        out.member = member.items;
        if (any) try cells.append(arena, out);
    }
    // Real scored games: blue's comp part, sum of blue's seat terms minus red's
    var refs: std.ArrayList(Ref) = .empty;
    for (0..@min(scored.teams.items.len / 2, 6)) |k| {
        var blue: f64 = 0;
        for (0..10) |j| {
            const st = scored.seats.items[10 * k + j];
            const t = m.seatTerm(st.cell, &st.x, null);
            blue += if (j < 5) t else -t;
        }
        try refs.append(arena, .{ .label = "dev-val game", .teams = d.games[scored.teams.items[2 * k].game].teams, .blue = blue });
    }
    const File = struct {
        format: []const u8 = "meiolol-champcomp",
        version: u32 = 2,
        meta: struct {
            snapshot: []const u8,
            offset: []const u8 = "win-draft",
            fit_games: u32,
            what: []const u8 = "champion-role deviations from their role's average slope on the enemy's and allies' traits, beyond the shipped model, shrunk; dev games, no test look",
            folds: Gain,
            better: u32,
            devval: Gain,
            clear: usize,
            tests: usize,
            bh: usize,
        },
        roles: []const []const u8 = &role_names,
        traits: []const []const u8,
        features: []const Feature,
        seats: []const SeatRow,
        role_seats: []const [1 + nt]f64,
        cells: []const CellOut,
        /// --groups: the kit groups (gamma, sd: logit per sd of the enemy feature, a
        /// member's deviation beyond a non-member's); empty without
        groups: []const GroupOut,
        refs: []const Ref,
    };
    const file: File = .{
        .meta = .{ .snapshot = meta.snapshot, .fit_games = meta.fit_games, .folds = meta.folds, .better = meta.better, .devval = meta.devval, .clear = meta.clear, .tests = meta.tests, .bh = meta.bh },
        .traits = &trait_words,
        .features = &features,
        .seats = seats.items,
        .role_seats = &role_seats,
        .cells = cells.items,
        .groups = if (groups_on) &groups else &.{},
        .refs = refs.items,
    };
    try Io.Dir.cwd().createDirPath(io, dir);
    const json = try std.json.Stringify.valueAlloc(arena, file, .{});
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fs.path.join(arena, &.{ dir, "draft-comp.json" }), .data = json });
}

/// Raw per-cell refits on the replication games, against the model's clear deviations
fn replicateOn(
    gpa: Allocator,
    d: *const rows.Data,
    p: *const comps.Profiles,
    aa: ?*const Aa,
    m: *const Model,
    cc: Clear,
    games: []const u32,
    blue: []const f64,
    seat_scale: Scale,
    team_scale: Scale,
    shuffle: u64,
    only: ?usize,
    groups_on: bool,
) !Replication {
    var u: Units = .{};
    defer u.deinit(gpa);
    try unitsOf(gpa, d, p, aa, games, blue, &u);
    standardise(u.seats.items, seat_scale);
    standardise(u.teams.items, team_scale);
    if (shuffle != 0) try shuffleTraits(gpa, &u, shuffle +% 2);
    if (only) |f| keepOnly(&u, f);
    const extra = try gpa.alloc(f64, u.seats.items.len);
    defer gpa.free(extra);
    for (extra, 0..) |*e, i| e.* = m.teamTerm(&u.teams.items[i / 5].x);
    var grp = try groupByCell(gpa, u.seats.items);
    defer grp.deinit(gpa);
    const ests = try gpa.alloc(Est, grp.cells.len);
    defer gpa.free(ests);
    for (ests, 0..) |*e, gi| e.* = try fitCell(gpa, u.seats.items, grp.of(gi), extra);
    const rf = roleFit(grp.cells, ests, null);
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
        const mask = m.members[ci];
        if (!groups_on or mask == 0 or !m.ests[ci].ok()) continue;
        var without = m.rf;
        groupFit(&without, m.cells, m.ests, m.members, ci);
        for (0..ng) |g| {
            if ((mask >> @intCast(g)) & 1 == 0) continue;
            const f = groupFeature(g);
            const t = without.target(role, f, mask)[0];
            const dev = re.beta[f] - rf.m[role][f];
            const v = re.se[f] * re.se[f] + m.rf.tau2[role][f];
            const l = &r.loo[g];
            l.n += 1;
            l.closer += @intFromBool(@abs(dev - t) < @abs(dev));
            l.sse += ((dev - t) * (dev - t) - dev * dev) / v;
            l.td += t * dev / v;
            l.tt += t * t / v;
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
    aa: ?*const Aa,
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
        try o.writeAll("champion\trole\tgames\tfeature\traw_pp\tse_pp\trole_mean_pp\traw_z\tbh\tdeviation_pp\tdeviation_sd_pp\tz\tcentre\tgroup_pp\n");
        for (m.cells, m.ests, m.post, 0..) |cell, e, post, ci| {
            if (e.n == 0) continue;
            const role: usize = @intCast(cell & 7);
            const ok = e.ok();
            for (0..nf) |f| {
                try o.print("{s}\t{s}\t{d}\t{s}\t{d:.3}\t{d:.3}\t{d:.3}\t{d:.2}\t{d}\t{d:.3}\t{d:.3}\t{d:.2}\t{d:.4}\t{d:.3}\n", .{
                    nameOf(names, @intCast(cell >> 3)),        role_names[role],                                      e.n,                            featureName(&fbuf, f),
                    e.beta[f] * pp_per_logit,                  e.se[f] * pp_per_logit,                                m.rf.m[role][f] * pp_per_logit, if (ok) rawZ(m, ci, f) else nan,
                    @intFromBool(ok and bhPass(m, cc, ci, f)), post[f].mean * pp_per_logit,                           post[f].sd * pp_per_logit,      zOf(post[f]),
                    e.mean_x[f],                               m.rf.target(role, f, m.members[ci])[0] * pp_per_logit,
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
            const name = std.mem.print(&nb, "{s}:{s}", .{ if (f < nt) "enemy" else "own", trait_names[f % nt] }) catch "?";
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
            const s = seatWith(p, aa, id, role);
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
        const path = try arena.print("effects-champcomp-{s}.tsv", .{side[0]});
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
    var m = try fitModel(gpa, &u, null);
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

test "kit groups: members shrink towards their group, not the role mean" {
    // 40 jungle cells, 8 in G1 with an aa slope 0.05 above the rest, no other spread; one
    // member with a huge se ends at its group's guess, not at the role mean
    const f = groupFeature(0);
    var cells: [40]u64 = undefined;
    var ests: [40]Est = undefined;
    var members: [40]u32 = undefined;
    for (&cells, &ests, &members, 0..) |*c, *e, *k, i| {
        c.* = comps.cellKey(@intCast(i + 1), 1);
        k.* = @intFromBool(i < 8);
        e.* = .{ .n = 1000, .beta = @splat(0), .se = @splat(0.01) };
        e.beta[f] = 0.02 + 0.05 * @as(f64, @floatFromInt(k.*));
    }
    ests[7].se[f] = 10;
    ests[7].beta[f] = -1;
    const rf = roleFit(&cells, &ests, &members);
    try testing.expectApproxEqAbs(0.05, rf.gamma[0], 1e-6);
    for (1..ng) |g| try testing.expectEqual(0, rf.gamma[g]);
    const p = posterior(&rf, 1, ests[7], f, members[7]);
    try testing.expectApproxEqAbs(rf.part(1, 0, members[7]), p.mean, 1e-4);
    try testing.expectApproxEqAbs(0.05 * (1 - rf.share[1][0]), p.mean, 1e-4);
    // Centred: the role's deviations still average 0, so nothing moves into team terms
    var s: f64 = 0;
    for (ests, members) |e, k| s += rf.target(1, f, k)[0] / (e.se[f] * e.se[f]);
    try testing.expectApproxEqAbs(0, s, 1e-6);
    // Features with no group keep their plain posterior
    try testing.expectEqual(0, rf.target(1, 0, members[0])[0]);
    // Without groups the same cell stays at its role's mean
    const plain = roleFit(&cells, &ests, null);
    try testing.expectApproxEqAbs(0, posterior(&plain, 1, ests[7], f, 0).mean, 1e-3);
}

test "a planted kit group comes back through the whole fit" {
    const gpa = testing.allocator;
    var rng: std.Random.DefaultPrng = .init(11);
    const r = rng.random();
    var u: Units = .{};
    defer u.deinit(gpa);
    const f = groupFeature(0);
    for (0..6000) |gi| {
        const off = 0.2 * r.floatNorm(f64);
        var enemy: [2][nf]f32 = undefined;
        for (&enemy) |*e| for (e) |*v| {
            v.* = @floatCast(r.floatNorm(f64));
        };
        // Junglers 11 and 12 (G1) gain 0.3 logit per sd of the enemy's aa, 13 and 14 not
        var z: [2]f64 = .{ off, -off };
        var champs: [2][5]u32 = undefined;
        for (0..2) |s| for (0..5) |role| {
            champs[s][role] = @intCast(1 + r.uintLessThan(u32, 4) + 10 * role);
            if (champs[s][role] == 11 or champs[s][role] == 12) z[s] += 0.3 * @as(f64, enemy[s][f]);
        };
        const blue_won = r.float(f64) < sigmoid(z[0] - z[1]);
        for (0..2) |s| {
            const y: f32 = if (blue_won == (s == 0)) 1 else 0;
            const o: f32 = @floatCast(if (s == 0) off else -off);
            try u.teams.append(gpa, .{ .game = @intCast(gi), .cell = 0, .y = y, .off = o, .x = enemy[s] });
            for (0..5) |role| try u.seats.append(gpa, .{ .game = @intCast(gi), .cell = comps.cellKey(champs[s][role], role), .y = y, .off = o, .x = enemy[s] });
        }
    }
    var members: Members = .empty;
    defer members.deinit(gpa);
    try members.put(gpa, comps.cellKey(11, 1), 1);
    try members.put(gpa, comps.cellKey(12, 1), 1);
    var m = try fitModel(gpa, &u, &members);
    defer m.deinit(gpa);
    const ci = 1.96 * @sqrt(m.rf.cov[0][0]);
    try testing.expect(@abs(m.rf.gamma[0] - 0.3) < @max(ci, 0.1));
    // A member's deviation is its group part plus its own, and the members' own parts
    // average out
    var own: f64 = 0;
    for ([_]u32{ 11, 12 }) |ch| {
        const c = m.index.get(comps.cellKey(ch, 1)).?;
        const grp = m.rf.target(1, f, m.members[c])[0];
        try testing.expect(grp > 0.1);
        own += m.post[c][f].mean - grp;
    }
    try testing.expect(@abs(own / 2) < 0.1);
}
