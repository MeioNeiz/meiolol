//! `meiolol-lab champgroups SNAP --aa FILE [--shuffle-own SEED]`: which kinds of champion
//! do better or worse into which kinds of enemy team (docs/model.md "Kit groups and a
//! property scan"). Built with -Dcand=src/lab/cand/win-draft: the shipped model is the
//! offset. Dev games only: profiles and the offset from games before bounds[2] ("older"),
//! scored on those (in-sample) and on the newer dev games [bounds[2], D).
//!
//! Enemy traits per seat: the enemy five's summed role z of every profile stat and of
//! aa_build (FILE: champion, role, completed crit or attack-speed items held at the end,
//! deploy/aa-build.sh), then champcomp's set traits (AP share, melee, composites). Per
//! champion-role and trait, one logistic step from the offset on that trait alone. Kit
//! groups (declared in `groups`): weighted mean of their cells' slopes less the rest of
//! each role. Scan: weighted slope of every cell's deviation on its own z of every stat,
//! found on older games, replicated on newer. --shuffle-own shuffles cells' own profile
//! vectors within role (a control for the scan). Writes groups.tsv, members.tsv and
//! scan.tsv in the working directory; last stdout line RESULT

const std = @import("std");
const rows = @import("rows.zig");
const harness = @import("harness.zig");
const compstats = @import("compstats.zig");
const comps = @import("comps.zig");
const champcomp = @import("champcomp.zig");
const synth = @import("synth.zig");
const cand = @import("cand");

const Io = std.Io;
const Allocator = std.mem.Allocator;
const nv = comps.nv;
/// champcomp's set traits but its last, aa (summed as an own stat here already)
const nt = champcomp.nt - 1;
comptime {
    std.debug.assert(@backingInt(champcomp.Trait.aa) == nt);
}

pub const usage =
    \\  champgroups SNAP --aa FILE [--shuffle-own SEED]
    \\                                  kit groups and own x enemy trait scan, dev only,
    \\                                  built with -Dcand=src/lab/cand/win-draft
    \\                                  (lab/champgroups.zig)
    \\
;

/// Own stats: every profile stat, then aa_build
const n_own = nv + 1;
/// Enemy traits: summed role z of the own stats, champcomp's set traits, then the carry
/// traits: the strongest single seat's magic damage and auto-attack build, and the
/// five's total magic damage (a share averages one big AP carry with four AD picks)
const n_carry = 3;
const n_en = n_own + nt + n_carry;
const carry_names = [n_carry][]const u8{ "carry:ap_max", "carry:ap_total", "carry:aa_max" };
const aa_index = nv;
const min_games = 300;
const role_names = [_][]const u8{ "top", "jungle", "middle", "bottom", "support" };
const bh_q = 0.05;
const pp = synth.pp_per_logit;

/// family 0: the 13 declared first; 1: follow-ups (carry traits), their own BH
const Group = struct { label: []const u8, champions: []const []const u8, trait: []const u8, sign: f64, family: u1 = 0 };

/// Declared 2026-10-18 before any run (docs/model.md); trait names as traitName gives them
const groups = [_]Group{
    .{ .label = "G1 auto-attack punishers", .champions = &.{ "Rammus", "Jax", "Shen", "Teemo", "Fiora", "Malphite" }, .trait = "aa_build", .sign = 1 },
    .{ .label = "G2 self-heal", .champions = &.{ "Aatrox", "Vladimir", "Dr. Mundo", "Warwick", "Sylas", "Swain", "Fiddlesticks", "Soraka", "Yuumi" }, .trait = "antiheal", .sign = -1 },
    .{ .label = "G3 CC answers", .champions = &.{ "Olaf", "Gangplank", "Sivir", "Morgana", "Nocturne", "Malzahar", "Fizz" }, .trait = "set:cc", .sign = 1 },
    .{ .label = "G4 lethality assassins", .champions = &.{ "Zed", "Talon", "Kha'Zix", "Rengar", "Qiyana", "Naafiri" }, .trait = "set:tank", .sign = -1 },
    .{ .label = "G5 true and %HP damage", .champions = &.{ "Vayne", "Fiora", "Gwen", "Kog'Maw", "Vel'Koz", "Brand", "Lillia" }, .trait = "set:tank", .sign = 1 },
    .{ .label = "G6 MR kits, spell shields", .champions = &.{ "Galio", "Kassadin", "Sivir", "Malzahar", "Morgana" }, .trait = "set:ap_share", .sign = 1 },
    .{ .label = "G7 stealth", .champions = &.{ "Evelynn", "Twitch", "Shaco", "Akali", "Kha'Zix", "Rengar", "Pyke" }, .trait = "control_pm", .sign = -1 },
    .{ .label = "G8 long-range poke", .champions = &.{ "Xerath", "Ziggs", "Vel'Koz", "Lux", "Jayce", "Varus" }, .trait = "set:engage", .sign = -1 },
    .{ .label = "G9 dash stoppers, disengage", .champions = &.{ "Poppy", "Janna", "Gragas" }, .trait = "set:dive", .sign = 1 },
    .{ .label = "G10 hyper-scalers", .champions = &.{ "Kayle", "Kassadin", "Veigar", "Smolder", "Vayne", "Kog'Maw" }, .trait = "set:early", .sign = -1 },
    .{ .label = "G11 armour kits into AP", .champions = &.{ "Rammus", "Malphite", "Braum", "Poppy" }, .trait = "set:ap_share", .sign = -1 },
    .{ .label = "G12 armour kits into armour pen", .champions = &.{ "Rammus", "Malphite", "Braum", "Poppy", "Ornn" }, .trait = "armour_pen", .sign = -1 },
    .{ .label = "G13 juggernauts into range", .champions = &.{ "Darius", "Garen", "Mordekaiser", "Nasus", "Illaoi", "Sion", "Dr. Mundo", "Trundle", "Volibear" }, .trait = "range", .sign = -1 },
    // Declared 18 Oct ~02:30 BST after the first runs (Jacob: a share is too broad)
    .{ .label = "F1 armour kits into the top AP threat", .champions = &.{ "Rammus", "Malphite", "Braum", "Poppy" }, .trait = "carry:ap_max", .sign = -1, .family = 1 },
    .{ .label = "F2 armour kits into total magic damage", .champions = &.{ "Rammus", "Malphite", "Braum", "Poppy" }, .trait = "carry:ap_total", .sign = -1, .family = 1 },
    .{ .label = "F3 MR kits into the top AP threat", .champions = &.{ "Galio", "Kassadin", "Sivir", "Malzahar", "Morgana" }, .trait = "carry:ap_max", .sign = 1, .family = 1 },
    .{ .label = "F4 MR kits into total magic damage", .champions = &.{ "Galio", "Kassadin", "Sivir", "Malzahar", "Morgana" }, .trait = "carry:ap_total", .sign = 1, .family = 1 },
    .{ .label = "F5 auto-attack punishers into the top auto-attacker", .champions = &.{ "Rammus", "Jax", "Shen", "Teemo", "Fiora", "Malphite" }, .trait = "carry:aa_max", .sign = 1, .family = 1 },
};

fn ownName(i: usize) []const u8 {
    return if (i < nv) @typeInfo(comps.V).@"enum".field_names[i] else "aa_build";
}

fn traitName(buf: []u8, i: usize) []const u8 {
    if (i < n_own) return ownName(i);
    if (i >= n_own + nt) return carry_names[i - n_own - nt];
    return std.fmt.bufPrint(buf, "set:{s}", .{@typeInfo(champcomp.Trait).@"enum".field_names[i - n_own]}) catch "?";
}

/// Sums for one cell, trait and window: one logistic step on the centred trait
const Acc = struct {
    n: f64 = 0,
    x: f64 = 0,
    w: f64 = 0,
    wx: f64 = 0,
    wxx: f64 = 0,
    r: f64 = 0,
    xr: f64 = 0,

    fn add(a: *Acc, x: f64, w: f64, r: f64) void {
        a.n += 1;
        a.x += x;
        a.w += w;
        a.wx += w * x;
        a.wxx += w * x * x;
        a.r += r;
        a.xr += x * r;
    }

    fn plus(a: Acc, b: Acc) Acc {
        return .{ .n = a.n + b.n, .x = a.x + b.x, .w = a.w + b.w, .wx = a.wx + b.wx, .wxx = a.wxx + b.wxx, .r = a.r + b.r, .xr = a.xr + b.xr };
    }

    /// Slope and se in logit per unit of x; nan when too few games
    fn slope(a: Acc) [2]f64 {
        if (a.n < min_games) return .{ std.math.nan(f64), std.math.nan(f64) };
        const m = a.x / a.n;
        const h = a.wxx - 2 * m * a.wx + m * m * a.w;
        if (h <= 0) return .{ std.math.nan(f64), std.math.nan(f64) };
        return .{ (a.xr - m * a.r) / h, 1 / @sqrt(h) };
    }
};

/// Slope on x with z held fixed (both centred): wxz = sum w x z over the same seats
fn slope2(a: Acc, b: Acc, wxz: f64) [2]f64 {
    if (a.n < min_games) return .{ std.math.nan(f64), std.math.nan(f64) };
    const mx = a.x / a.n;
    const mz = b.x / b.n;
    const hxx = a.wxx - 2 * mx * a.wx + mx * mx * a.w;
    const hzz = b.wxx - 2 * mz * b.wx + mz * mz * b.w;
    const hxz = wxz - mz * a.wx - mx * b.wx + mx * mz * a.w;
    const det = hxx * hzz - hxz * hxz;
    if (det <= 0) return .{ std.math.nan(f64), std.math.nan(f64) };
    const gx = a.xr - mx * a.r;
    const gz = b.xr - mz * b.r;
    return .{ (hzz * gx - hxz * gz) / det, @sqrt(hzz / det) };
}

/// One window's cell slopes for one trait, with each role's mean and spread
const Fits = struct {
    beta: []f64,
    se: []f64,
    m: [5]f64 = @splat(0),
    tau2: [5]f64 = @splat(0),
};

/// held: the AP share sums and cross sums when the slope holds enemy AP share fixed
fn fitsOf(gpa: Allocator, acc: []const Acc, cells: []const u64, sd: f64, held: ?struct { ap: []const Acc, cross: []const f64 }) !Fits {
    var f: Fits = .{ .beta = try gpa.alloc(f64, cells.len), .se = try gpa.alloc(f64, cells.len) };
    var ws: [5]f64 = @splat(0);
    for (acc, f.beta, f.se, cells, 0..) |a, *b, *s, c, ci| {
        const e = if (held) |h| slope2(a, h.ap[ci], h.cross[ci]) else a.slope();
        b.* = e[0] * sd;
        s.* = e[1] * sd;
        if (std.math.isNan(b.*)) continue;
        const w = 1 / (s.* * s.*);
        f.m[c & 7] += w * b.*;
        ws[c & 7] += w;
    }
    for (&f.m, ws) |*m, w| m.* = if (w > 0) m.* / w else 0;
    // DerSimonian-Laird spread around the role mean, at least 0
    var q: [5]f64 = @splat(0);
    var w2: [5]f64 = @splat(0);
    var k: [5]f64 = @splat(0);
    for (f.beta, f.se, cells) |b, s, c| {
        if (std.math.isNan(b)) continue;
        const w = 1 / (s * s);
        q[c & 7] += w * (b - f.m[c & 7]) * (b - f.m[c & 7]);
        w2[c & 7] += w * w;
        k[c & 7] += 1;
    }
    for (0..5) |r| {
        if (k[r] < 2) continue;
        f.tau2[r] = @max((q[r] - (k[r] - 1)) / (ws[r] - w2[r] / ws[r]), 0);
    }
    return f;
}

const Est = struct { eff: f64 = std.math.nan(f64), se: f64 = std.math.nan(f64), cells: usize = 0 };

fn pOfEst(e: Est) f64 {
    return if (std.math.isNan(e.eff)) 1 else comps.pOf(e.eff / e.se);
}

/// Group: weighted mean over its cells of slope less the mean of its role's other cells
fn groupEffect(f: *const Fits, cells: []const u64, in: []const bool) Est {
    var rest: [5]f64 = @splat(0);
    var rw: [5]f64 = @splat(0);
    for (f.beta, f.se, cells, in) |b, s, c, g| {
        if (g or std.math.isNan(b)) continue;
        rest[c & 7] += b / (s * s);
        rw[c & 7] += 1 / (s * s);
    }
    var sw: f64 = 0;
    var swd: f64 = 0;
    var n: usize = 0;
    for (f.beta, f.se, cells, in) |b, s, c, g| {
        if (!g or std.math.isNan(b) or rw[c & 7] == 0) continue;
        const w = 1 / (s * s + f.tau2[c & 7]);
        sw += w;
        swd += w * (b - rest[c & 7] / rw[c & 7]);
        n += 1;
    }
    if (sw == 0) return .{};
    return .{ .eff = swd / sw, .se = 1 / @sqrt(sw), .cells = n };
}

/// Scan: weighted slope of cells' deviations on their own z (centred within role)
fn scanEffect(f: *const Fits, cells: []const u64, own: []const [n_own]f64, v: usize) Est {
    var xm: [5]f64 = @splat(0);
    var xw: [5]f64 = @splat(0);
    for (f.beta, f.se, cells, own) |b, s, c, o| {
        if (std.math.isNan(b)) continue;
        const w = 1 / (s * s + f.tau2[c & 7]);
        xm[c & 7] += w * o[v];
        xw[c & 7] += w;
    }
    var sxy: f64 = 0;
    var sxx: f64 = 0;
    var n: usize = 0;
    for (f.beta, f.se, cells, own) |b, s, c, o| {
        if (std.math.isNan(b)) continue;
        const w = 1 / (s * s + f.tau2[c & 7]);
        const x = o[v] - xm[c & 7] / xw[c & 7];
        sxy += w * x * (b - f.m[c & 7]);
        sxx += w * x * x;
        n += 1;
    }
    if (sxx == 0) return .{};
    return .{ .eff = sxy / sxx, .se = 1 / @sqrt(sxx), .cells = n };
}

pub fn main(gpa: Allocator, arena: Allocator, io: Io, argv: []const []const u8) !u8 {
    if (argv.len < 1) {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    }
    if (!@hasDecl(cand, "name") or !std.mem.eql(u8, cand.name, "win-draft")) {
        std.debug.print("champgroups: build with -Dcand=src/lab/cand/win-draft (the shipped model is the offset)\n", .{});
        return 2;
    }
    const snap = argv[0];
    var aa_path: ?[]const u8 = null;
    var shuffle: u64 = 0;
    var i: usize = 1;
    while (i < argv.len) : (i += 1) {
        if (std.mem.eql(u8, argv[i], "--aa") and i + 1 < argv.len) {
            i += 1;
            aa_path = argv[i];
        } else if (std.mem.eql(u8, argv[i], "--shuffle-own") and i + 1 < argv.len) {
            i += 1;
            shuffle = try std.fmt.parseInt(u64, argv[i], 10);
        } else {
            std.debug.print("usage:\n{s}", .{usage});
            return 2;
        }
    }
    var aa = try champcomp.loadAa(gpa, io, aa_path orelse {
        std.debug.print("champgroups: --aa FILE is required (deploy/aa-build.sh)\n", .{});
        return 2;
    });
    defer aa.deinit(gpa);

    var buf: [4096]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &buf);
    const w = &stdout.interface;

    const data_path = if (try synth.parseArg(snap)) |pa| pa.path else snap;
    var legendaries = try rows.loadLegendaries(gpa, io, snap);
    defer legendaries.deinit(gpa);
    var data = try rows.load(gpa, snap, &legendaries);
    defer data.deinit();
    const d = &data;
    const players = try harness.gamePlayers(gpa, d);
    defer gpa.free(players);
    const c = try harness.cuts(gpa, d);
    const names = try champcomp.loadNames(gpa, arena, data_path);
    const extra = try gpa.alloc(?compstats.Seat, d.rows.len);
    defer gpa.free(extra);
    const team_obj = try gpa.alloc(?[2]compstats.Team, d.games.len);
    defer gpa.free(team_obj);
    _ = try comps.loadExtra(gpa, io, d, data_path, extra, team_obj);

    const split = c.bounds[2];
    const fit_cfg: comps.Fit = .{ .c = c, .before = split };
    var p = try comps.buildProfiles(gpa, d, extra, fit_cfg, 0);
    defer p.deinit(gpa);
    // champcomp's fold 3 window: one cached offset serves both
    const offsets = try champcomp.Offsets.init(gpa, io, snap, data_path, d);
    const blue = try offsets.get(gpa, io, d, players, c, split, c.dev);
    defer gpa.free(blue);
    try w.print("# champgroups, offset win-draft{s}, {s}\nsplit {d}, dev cut {d}\n", .{ if (shuffle != 0) ", SHUFFLED own profiles" else "", snap, split, c.dev });
    try w.flush();

    // aa_build's role z over older seats; a champion-role without a line is its role's mean
    var aa_m: [5]f64 = @splat(0);
    var aa_q: [5]f64 = @splat(0);
    var aa_n: [5]f64 = @splat(0);
    for (d.games, 0..) |g, gi| {
        if (!fit_cfg.has(g) or std.math.isNan(blue[gi])) continue;
        for (g.teams) |t| for (t, 0..) |ch, r| {
            const v = aa.get(comps.cellKey(ch, r)) orelse continue;
            aa_m[r] += v;
            aa_q[r] += v * v;
            aa_n[r] += 1;
        };
    }
    var aa_sd: [5]f64 = undefined;
    for (&aa_m, aa_q, aa_n, &aa_sd) |*m, q, n, *sd| {
        m.* /= @max(n, 1);
        sd.* = @sqrt(@max(q / @max(n, 1) - m.* * m.*, 1e-12));
    }
    const ownOf = struct {
        fn f(pr: *const comps.Profiles, a: *const std.AutoHashMapUnmanaged(u64, f64), am: [5]f64, asd: [5]f64, ch: u32, r: usize) [n_own]f64 {
            var o: [n_own]f64 = undefined;
            @memcpy(o[0..nv], &pr.z(r, pr.raw_of(ch, r)));
            o[aa_index] = ((a.get(comps.cellKey(ch, r)) orelse am[r]) - am[r]) / asd[r];
            return o;
        }
    }.f;

    // Cells: every champion-role seen in a scored game
    var index: std.AutoHashMapUnmanaged(u64, u32) = .empty;
    defer index.deinit(gpa);
    var cells: std.ArrayList(u64) = .empty;
    defer cells.deinit(gpa);
    const Win = enum { older, newer };
    const windowOf = struct {
        fn f(g: rows.Game, cut: harness.Cuts, s: i64, fc: comps.Fit) ?Win {
            if (fc.has(g)) return .older;
            if (!g.is_test and harness.played(g) and g.start >= s and g.start < cut.dev) return .newer;
            return null;
        }
    }.f;
    for (d.games, 0..) |g, gi| {
        if (std.math.isNan(blue[gi]) or windowOf(g, c, split, fit_cfg) == null) continue;
        for (g.teams) |t| for (t, 0..) |ch, r| {
            const k = comps.cellKey(ch, r);
            const e = try index.getOrPut(gpa, k);
            if (!e.found_existing) {
                e.value_ptr.* = @intCast(cells.items.len);
                try cells.append(gpa, k);
            }
        };
    }
    const nc = cells.items.len;
    const own = try gpa.alloc([n_own]f64, nc);
    defer gpa.free(own);
    for (own, cells.items) |*o, k| o.* = ownOf(&p, &aa, aa_m, aa_sd, @intCast(k >> 3), @intCast(k & 7));

    // One pass: per window, cell and trait, the sums; traits standardised over older seats
    const acc = try gpa.alloc(Acc, 2 * nc * n_en);
    defer gpa.free(acc);
    @memset(acc, .{});
    // sum w x_t x_ap per window, cell and trait: for the slopes with AP share held fixed
    const ap_t = n_own + @backingInt(champcomp.Trait.ap_share);
    const cross = try gpa.alloc(f64, 2 * nc * n_en);
    defer gpa.free(cross);
    @memset(cross, 0);
    var xs: [n_en]f64 = @splat(0);
    var xq: [n_en]f64 = @splat(0);
    var xn: f64 = 0;
    for (d.games, 0..) |g, gi| {
        if (std.math.isNan(blue[gi])) continue;
        const win = windowOf(g, c, split, fit_cfg) orelse continue;
        var tr: [2][n_en]f64 = undefined;
        for (g.teams, 0..) |t, s| {
            var seats: [5]champcomp.Seat = undefined;
            tr[s][0..n_own].* = @splat(0);
            for (t, 0..) |ch, r| {
                seats[r] = champcomp.seatOf(&p, ch, r);
                for (ownOf(&p, &aa, aa_m, aa_sd, ch, r), 0..) |v, j| tr[s][j] += v;
            }
            @memcpy(tr[s][n_own .. n_own + nt], champcomp.traitsOf(&seats)[0..nt]);
            var ap_max: f64 = 0;
            var ap_total: f64 = 0;
            var aa_max: f64 = 0;
            for (t, seats, 0..) |ch, st, r| {
                ap_max = @max(ap_max, st.magic);
                ap_total += st.magic;
                aa_max = @max(aa_max, aa.get(comps.cellKey(ch, r)) orelse aa_m[r]);
            }
            tr[s][n_own + nt ..].* = .{ ap_max, ap_total, aa_max };
        }
        const lb = @log(blue[gi] / (1 - blue[gi]));
        for (g.teams, 0..) |t, s| {
            const off = if (s == 0) lb else -lb;
            const q = 1 / (1 + @exp(-off));
            const y: f64 = if (g.winner == s) 1 else 0;
            const x = &tr[1 - s];
            if (win == .older) {
                for (x, &xs, &xq) |v, *a, *b| {
                    a.* += v;
                    b.* += v * v;
                }
                xn += 1;
            }
            for (t, 0..) |ch, r| {
                const ci = index.get(comps.cellKey(ch, r)).?;
                const base = (@as(usize, @backingInt(win)) * nc + ci) * n_en;
                for (x, 0..) |v, j| {
                    acc[base + j].add(v, q * (1 - q), y - q);
                    cross[base + j] += q * (1 - q) * v * x[ap_t];
                }
            }
        }
    }
    var sd: [n_en]f64 = undefined;
    for (&sd, xs, xq) |*s, a, b| {
        const m = a / xn;
        s.* = @sqrt(@max(b / xn - m * m, 1e-12));
    }

    if (shuffle != 0) {
        var rng: std.Random.DefaultPrng = .init(shuffle);
        for (0..5) |r| {
            var idx: std.ArrayList(usize) = .empty;
            defer idx.deinit(gpa);
            for (cells.items, 0..) |k, ci| if ((k & 7) == r) try idx.append(gpa, ci);
            const vals = try gpa.alloc([n_own]f64, idx.items.len);
            defer gpa.free(vals);
            for (vals, idx.items) |*v, ci| v.* = own[ci];
            rng.random().shuffle([n_own]f64, vals);
            for (vals, idx.items) |v, ci| own[ci] = v;
        }
    }

    // Fits per window (older, newer, all) and trait
    const n_win = 3;
    var fits: [n_win][n_en]Fits = undefined;
    // Post hoc (18 Oct, after the first run): each trait with enemy AP share held fixed, all
    // dev games
    var held: [n_en]Fits = undefined;
    const tmp = try gpa.alloc(Acc, nc);
    defer gpa.free(tmp);
    const tmp_ap = try gpa.alloc(Acc, nc);
    defer gpa.free(tmp_ap);
    const tmp_x = try gpa.alloc(f64, nc);
    defer gpa.free(tmp_x);
    for (0..n_win) |wi| for (0..n_en) |t| {
        for (tmp, tmp_ap, tmp_x, 0..) |*a, *b, *x, ci| {
            const o = (0 * nc + ci) * n_en;
            const n = (1 * nc + ci) * n_en;
            a.* = switch (wi) {
                0 => acc[o + t],
                1 => acc[n + t],
                else => acc[o + t].plus(acc[n + t]),
            };
            b.* = acc[o + ap_t].plus(acc[n + ap_t]);
            x.* = cross[o + t] + cross[n + t];
        }
        fits[wi][t] = try fitsOf(arena, tmp, cells.items, sd[t], null);
        if (wi == 2 and t != ap_t) held[t] = try fitsOf(arena, tmp, cells.items, sd[t], .{ .ap = tmp_ap, .cross = tmp_x });
    };

    var tb: [32]u8 = undefined;
    const traitIndex = struct {
        fn f(name: []const u8) ?usize {
            var b: [32]u8 = undefined;
            for (0..n_en) |t| if (std.mem.eql(u8, traitName(&b, t), name)) return t;
            return null;
        }
    }.f;
    var ids: std.StringHashMapUnmanaged(u32) = .empty;
    defer ids.deinit(gpa);
    var nit = names.iterator();
    while (nit.next()) |e| try ids.put(gpa, e.value_ptr.*, e.key_ptr.*);

    // Groups
    const cwd = Io.Dir.cwd();
    var gout: std.Io.Writer.Allocating = .init(arena);
    var mout: std.Io.Writer.Allocating = .init(arena);
    try gout.writer.print("group\ttrait\tsign\tcells\tall_pp\tall_ci_pp\tp\tbh\tdetected\tolder_pp\tolder_ci_pp\tnewer_pp\tnewer_ci_pp\tap_held_pp\tap_held_ci_pp\n", .{});
    try mout.writer.print("group\tchampion\trole\tgames\tdeviation_pp\tci_pp\tap_held_pp\tap_held_ci_pp\n", .{});
    var g_est: [groups.len][n_win]Est = undefined;
    var g_held: [groups.len]Est = @splat(.{});
    var g_p: [groups.len]f64 = undefined;
    var g_t: [groups.len]usize = undefined;
    const in = try gpa.alloc(bool, nc);
    defer gpa.free(in);
    for (groups, 0..) |grp, gi| {
        g_t[gi] = traitIndex(grp.trait) orelse {
            std.debug.print("champgroups: {s}: no trait {s}\n", .{ grp.label, grp.trait });
            return 2;
        };
        var want: std.AutoHashMapUnmanaged(u32, void) = .empty;
        defer want.deinit(gpa);
        for (grp.champions) |name| try want.put(gpa, ids.get(name) orelse {
            std.debug.print("champgroups: {s}: no champion {s}\n", .{ grp.label, name });
            return 2;
        }, {});
        for (in, cells.items) |*x, k| x.* = want.contains(@intCast(k >> 3));
        for (0..n_win) |wi| g_est[gi][wi] = groupEffect(&fits[wi][g_t[gi]], cells.items, in);
        if (g_t[gi] != ap_t) g_held[gi] = groupEffect(&held[g_t[gi]], cells.items, in);
        g_p[gi] = pOfEst(g_est[gi][2]);
        const f = &fits[2][g_t[gi]];
        for (cells.items, in, 0..) |k, x, ci| {
            if (!x or std.math.isNan(f.beta[ci])) continue;
            const a = acc[ci * n_en + g_t[gi]].plus(acc[(nc + ci) * n_en + g_t[gi]]);
            const hd: [2]f64 = if (g_t[gi] != ap_t) .{ (held[g_t[gi]].beta[ci] - held[g_t[gi]].m[k & 7]) * pp, 1.96 * held[g_t[gi]].se[ci] * pp } else .{ std.math.nan(f64), std.math.nan(f64) };
            try mout.writer.print("{s}\t{s}\t{s}\t{d}\t{d:.2}\t{d:.2}\t{d:.2}\t{d:.2}\n", .{ grp.label, names.get(@intCast(k >> 3)) orelse "?", role_names[k & 7], @as(u64, @intFromFloat(a.n)), (f.beta[ci] - f.m[k & 7]) * pp, 1.96 * f.se[ci] * pp, hd[0], hd[1] });
        }
    }
    var g_bh: [2]f64 = undefined;
    for (&g_bh, 0..) |*b, fam| {
        var fp: std.ArrayList(f64) = .empty;
        defer fp.deinit(gpa);
        for (groups, g_p) |grp, pv| if (grp.family == fam) try fp.append(gpa, pv);
        b.* = try comps.bhThreshold(gpa, fp.items, bh_q);
    }
    var detected: usize = 0;
    var followups: usize = 0;
    var det_names: std.ArrayList(u8) = .empty;
    for (groups, 0..) |grp, gi| {
        const e = g_est[gi];
        const bh = g_bh[grp.family] > 0 and g_p[gi] <= g_bh[grp.family];
        const det = bh and std.math.sign(e[2].eff) == grp.sign;
        if (det and grp.family == 1) followups += 1;
        if (det and grp.family == 0) {
            detected += 1;
            try det_names.print(arena, "{s}{s}", .{ if (det_names.items.len > 0) "," else "", grp.label[0..std.mem.indexOfScalar(u8, grp.label, ' ').?] });
        }
        try gout.writer.print("{s}\t{s}\t{s}\t{d}\t{d:.3}\t{d:.3}\t{e:.2}\t{}\t{}\t{d:.3}\t{d:.3}\t{d:.3}\t{d:.3}\t{d:.3}\t{d:.3}\n", .{
            grp.label,           grp.trait,           if (grp.sign > 0) "+" else "-", e[2].cells,
            e[2].eff * pp,       1.96 * e[2].se * pp, g_p[gi],                        bh,
            det,                 e[0].eff * pp,       1.96 * e[0].se * pp,            e[1].eff * pp,
            1.96 * e[1].se * pp, g_held[gi].eff * pp, 1.96 * g_held[gi].se * pp,
        });
        try w.print("{s} into {s}: {d:.2} ± {d:.2} pp per sd ({d} cells; older {d:.2}, newer {d:.2}), p {e:.1}{s}; AP share held {d:.2} ± {d:.2}\n", .{
            grp.label, grp.trait, e[2].eff * pp, 1.96 * e[2].se * pp, e[2].cells, e[0].eff * pp, e[1].eff * pp, g_p[gi], if (det) ", DETECTED" else "", g_held[gi].eff * pp, 1.96 * g_held[gi].se * pp,
        });
    }
    try cwd.writeFile(io, .{ .sub_path = "groups.tsv", .data = gout.written() });
    try cwd.writeFile(io, .{ .sub_path = "members.tsv", .data = mout.written() });

    // Scan: discovery on older, replication on newer
    const Pair = struct { v: u16, t: u16, old: Est, new: Est, all: Est, p: f64 };
    const pairs = try gpa.alloc(Pair, n_own * n_en);
    defer gpa.free(pairs);
    const ps = try gpa.alloc(f64, pairs.len);
    defer gpa.free(ps);
    for (0..n_own) |v| for (0..n_en) |t| {
        const k = v * n_en + t;
        pairs[k] = .{
            .v = @intCast(v),
            .t = @intCast(t),
            .old = scanEffect(&fits[0][t], cells.items, own, v),
            .new = scanEffect(&fits[1][t], cells.items, own, v),
            .all = scanEffect(&fits[2][t], cells.items, own, v),
            .p = undefined,
        };
        pairs[k].p = pOfEst(pairs[k].old);
        ps[k] = pairs[k].p;
    };
    const s_bh = try comps.bhThreshold(gpa, ps, bh_q);
    std.mem.sort(Pair, pairs, {}, struct {
        fn lt(_: void, a: Pair, b: Pair) bool {
            return a.p < b.p;
        }
    }.lt);
    var found: usize = 0;
    var replicated: usize = 0;
    var sout: std.Io.Writer.Allocating = .init(arena);
    try sout.writer.print("own\tenemy\told_pp\told_ci_pp\tp_old\tbh\tnew_pp\tnew_ci_pp\treplicated\tall_pp\tall_ci_pp\n", .{});
    for (pairs) |q| {
        const bh = s_bh > 0 and q.p <= s_bh;
        const rep = bh and !std.math.isNan(q.new.eff) and std.math.sign(q.new.eff) == std.math.sign(q.old.eff) and @abs(q.new.eff / q.new.se) >= 1.645;
        found += @intFromBool(bh);
        replicated += @intFromBool(rep);
        try sout.writer.print("{s}\t{s}\t{d:.3}\t{d:.3}\t{e:.2}\t{}\t{d:.3}\t{d:.3}\t{}\t{d:.3}\t{d:.3}\n", .{
            ownName(q.v),         traitName(&tb, q.t), q.old.eff * pp,       1.96 * q.old.se * pp, q.p,
            bh,                   q.new.eff * pp,      1.96 * q.new.se * pp, rep,                  q.all.eff * pp,
            1.96 * q.all.se * pp,
        });
    }
    try cwd.writeFile(io, .{ .sub_path = "scan.tsv", .data = sout.written() });
    try w.print("scan: {d} pairs, {d} found on older games (BH 5%), {d} replicated on newer\n", .{ pairs.len, found, replicated });
    var n_first: usize = 0;
    for (groups) |grp| n_first += @intFromBool(grp.family == 0);
    try w.print("RESULT champgroups groups_detected={d}/{d} [{s}] followups_detected={d}/{d} scan_found={d}/{d} scan_replicated={d}{s}\n", .{
        detected, n_first, det_names.items, followups, groups.len - n_first, found, pairs.len, replicated, if (shuffle != 0) " SHUFFLED" else "",
    });
    try w.flush();
    return 0;
}

test "slope with a second trait held fixed" {
    // y depends on x only; z is x plus noise, so x's slope survives holding z and z's goes
    var rng: std.Random.DefaultPrng = .init(7);
    var ax: Acc = .{};
    var az: Acc = .{};
    var wxz: f64 = 0;
    for (0..20000) |_| {
        const x = rng.random().floatNorm(f64);
        const z = x + rng.random().floatNorm(f64);
        const q = 0.5;
        const y: f64 = if (rng.random().float(f64) < 1 / (1 + @exp(-0.4 * x))) 1 else 0;
        ax.add(x, q * (1 - q), y - q);
        az.add(z, q * (1 - q), y - q);
        wxz += q * (1 - q) * x * z;
    }
    try std.testing.expectApproxEqAbs(0.4, slope2(ax, az, wxz)[0], 0.08);
    try std.testing.expectApproxEqAbs(0.4, ax.slope()[0], 0.08);
    try std.testing.expectApproxEqAbs(0.0, slope2(az, ax, wxz)[0], 0.08);
}
