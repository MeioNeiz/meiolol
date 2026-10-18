//! netcheck's `set` net (docs/model.md "Neural draft models"): DeepSets over each team on
//! win-comp's champion-role profiles, residual on the candidate's logit.
//! Slot input x = [profile z (12); role one-hot (5); champion-role embedding (--emb, with
//! --ids 1)]; u = ReLU(W1 x + b1) (phi units); team vector t = mean of its 5 u;
//! f(own, other) = w . ReLU(V [t_own; t_other] + c) (rho units; t_own alone with --cross 0);
//! logit = (f(blue, red) - f(red, blue)) / 2 + c[platform] + a * offset. w starts at 0,
//! so the net starts as the candidate, and early stopping also scores that start: 0
//! epochs (the candidate alone) when no step beats it on validation.
//! Profiles as win-comp's: 12 end-of-game stats per seat (per minute where a rate), the
//! won and lost halves' means per champion-role each shrunk to the role mean by 20
//! pseudo-rows, averaged; z within role weighted by seats; unknown champion-role 0. Built
//! from the fit games only (inner games while tuning); a fit game sees its slots'
//! profiles without its own row (leave-one-out), scored and validation games the full ones

const std = @import("std");
const rows = @import("rows.zig");
const seatstats = @import("seatstats.zig");
const winnet = @import("winnet.zig");
const gates = @import("gates.zig");
const cand = @import("cand");

const Io = std.Io;
const NetGame = winnet.NetGame;

pub const Config = struct {
    /// Per-slot units: the team vector's width
    phi: u32 = 16,
    /// Hidden units on the team vectors
    rho: u32 = 16,
    /// rho sees the enemy team's vector too (cross-team terms)
    cross: bool = true,
    /// A champion-role embedding (opts.emb wide) beside the profile
    ids: bool = false,
    control: Control = .none,
    /// Write the net's inputs per block (first seed): dumpPart
    dump: bool = false,
};

/// Null controls (a gain under either means a leak or a gain from something else):
/// shuffle: the fit games' results permuted (seeded) for both the profiles' halves and
/// the net's labels, offsets as they are (run with --fix-offset 1): gain ~0 or below;
/// permute: each champion-role gets another of its role's profile: no profile content
pub const Control = enum { none, shuffle, permute };

/// Parses a set-only option; false when `k` isn't one
pub fn parseOption(c: *Config, k: []const u8, v: []const u8) !bool {
    if (std.mem.eql(u8, k, "--phi")) {
        c.phi = try std.fmt.parseInt(u32, v, 10);
    } else if (std.mem.eql(u8, k, "--rho")) {
        c.rho = try std.fmt.parseInt(u32, v, 10);
    } else if (std.mem.eql(u8, k, "--cross")) {
        c.cross = (try std.fmt.parseInt(u1, v, 10)) == 1;
    } else if (std.mem.eql(u8, k, "--ids")) {
        c.ids = (try std.fmt.parseInt(u1, v, 10)) == 1;
    } else if (std.mem.eql(u8, k, "--control")) {
        c.control = std.meta.stringToEnum(Control, v) orelse return error.UnknownControl;
    } else if (std.mem.eql(u8, k, "--dump")) {
        c.dump = (try std.fmt.parseInt(u1, v, 10)) == 1;
    } else return false;
    if (c.phi == 0 or c.rho == 0) return error.BadValue;
    return true;
}

const Feature = enum { magic, true_dmg, dmg, tank, taken, armour, cc, immob, ally, heal, range, buildings };
pub const n_prof = std.enums.values(Feature).len;
const pseudo = 20;

fn stat(s: *const seatstats.Stats, x: seatstats.SeatStat) f32 {
    return s[@backingInt(x)];
}

/// One seat's value of a profile feature, NaN when unknown (win-comp's rowValue)
fn rowValue(f: Feature, s: *const seatstats.Stats) f32 {
    const nan = std.math.nan(f32);
    const mins = stat(s, .minutes);
    const per: f32 = if (mins > 0) 1 / mins else nan;
    const dealt = stat(s, .dmg_phys) + stat(s, .dmg_magic) + stat(s, .dmg_true);
    const taken = stat(s, .taken_phys) + stat(s, .taken_magic) + stat(s, .taken_true);
    const mitigated = stat(s, .mitigated);
    const share = struct {
        fn of(x: f32, total: f32) f32 {
            return if (total > 0) x / total else std.math.nan(f32);
        }
    }.of;
    return switch (f) {
        .magic => share(stat(s, .dmg_magic), dealt),
        .true_dmg => share(stat(s, .dmg_true), dealt),
        .dmg => dealt * per,
        .tank => share(mitigated, mitigated + taken),
        .taken => taken * per,
        .armour => stat(s, .armor_end) - stat(s, .mr_end),
        .cc => stat(s, .cc_time) * per,
        .immob => stat(s, .immobilisations) * per,
        .ally => (stat(s, .heal_allies) + stat(s, .shield_allies)) * per,
        // heal is Riot's totalHeal, teammates included
        .heal => blk: {
            const own = stat(s, .heal) - stat(s, .heal_allies);
            break :blk if (std.math.isNan(own)) nan else @max(own, 0) * per;
        },
        .range => stat(s, .attack_range),
        .buildings => stat(s, .dmg_buildings) * per,
    };
}

fn rowValues(s: *const seatstats.Stats) [n_prof]f32 {
    var out: [n_prof]f32 = undefined;
    for (std.enums.values(Feature), &out) |f, *o| {
        const v = rowValue(f, s);
        o.* = if (std.math.isInf(v)) std.math.nan(f32) else v;
    }
    return out;
}

fn key(champion: u32, role: usize) u64 {
    return (@as(u64, champion) << 3) | role;
}

/// Row index per (game, side * 5 + role); maxInt when missing
fn seatRows(gpa: std.mem.Allocator, d: *const rows.Data) ![]u32 {
    const seat = try gpa.alloc(u32, d.games.len * 10);
    @memset(seat, std.math.maxInt(u32));
    for (d.rows, 0..) |r, i| seat[@as(usize, r.game) * 10 + @as(usize, r.side) * 5 + @backingInt(r.role)] = @intCast(i);
    return seat;
}

const win = @backingInt(rows.Outcome.win);

/// Per champion-role: the halves' sums and counts per feature, seats seen; role means and
/// the z scale per role and feature
const Profiles = struct {
    index: std.AutoHashMapUnmanaged(u64, u32) = .empty,
    /// [champion-role][half][feature]: sum, count
    acc: [][2][n_prof][2]f64 = &.{},
    seen: []f64 = &.{},
    role_mean: [5][n_prof]f64 = @splat(@splat(0)),
    z_mean: [5][n_prof]f64 = @splat(@splat(0)),
    z_sd: [5][n_prof]f64 = @splat(@splat(0)),
    /// Blue won, per data game index, in place of the real result (Control.shuffle)
    won: ?[]const u1 = null,
    /// Profile id read for each id (Control.permute)
    perm: ?[]u32 = null,

    fn rowY(p: *const Profiles, r: *const rows.Row) f32 {
        const won = p.won orelse return r.y[win];
        return @floatFromInt(@intFromBool(won[r.game] == 1 - @as(u1, r.side)));
    }

    fn build(gpa: std.mem.Allocator, d: *const rows.Data, seat: []const u32, games: []const u32, won: ?[]const u1) !Profiles {
        var p: Profiles = .{ .won = won };
        errdefer p.deinit(gpa);
        for (games) |gi| for (0..10) |s| {
            const ri = seat[@as(usize, gi) * 10 + s];
            if (ri == std.math.maxInt(u32)) continue;
            const r = d.rows[ri];
            const e = try p.index.getOrPut(gpa, key(r.champion, s % 5));
            if (!e.found_existing) e.value_ptr.* = p.index.count() - 1;
        };
        const n = p.index.count();
        p.acc = try gpa.alloc([2][n_prof][2]f64, n);
        @memset(p.acc, @splat(@splat(@splat(0))));
        p.seen = try gpa.alloc(f64, n);
        @memset(p.seen, 0);
        var role_acc: [5][n_prof][2]f64 = @splat(@splat(@splat(0)));
        for (games) |gi| for (0..10) |s| {
            const ri = seat[@as(usize, gi) * 10 + s];
            if (ri == std.math.maxInt(u32)) continue;
            const r = &d.rows[ri];
            const y = p.rowY(r);
            if (std.math.isNan(y)) continue;
            const id = p.index.get(key(r.champion, s % 5)).?;
            p.seen[id] += 1;
            const half: usize = @intFromBool(y > 0.5);
            for (rowValues(&r.stats), 0..) |v, f| {
                if (std.math.isNan(v)) continue;
                p.acc[id][half][f][0] += v;
                p.acc[id][half][f][1] += 1;
                role_acc[s % 5][f][0] += v;
                role_acc[s % 5][f][1] += 1;
            }
        };
        for (&p.role_mean, role_acc) |*m, ra| for (m, ra) |*x, a| {
            x.* = if (a[1] > 0) a[0] / a[1] else 0;
        };
        var sums: [5][n_prof][3]f64 = @splat(@splat(@splat(0)));
        var it = p.index.iterator();
        while (it.next()) |e| {
            const id = e.value_ptr.*;
            const role: usize = @intCast(e.key_ptr.* & 7);
            const wt = p.seen[id];
            for (0..n_prof) |f| {
                const v = p.raw(id, role, f, null);
                sums[role][f][0] += wt;
                sums[role][f][1] += wt * v;
                sums[role][f][2] += wt * v * v;
            }
        }
        for (0..5) |role| for (0..n_prof) |f| {
            const s = sums[role][f];
            if (s[0] == 0) continue;
            const mean = s[1] / s[0];
            const sd = @sqrt(@max(s[2] / s[0] - mean * mean, 0));
            if (sd < 1e-9 * @max(@abs(mean), 1)) continue;
            p.z_mean[role][f] = mean;
            p.z_sd[role][f] = sd;
        };
        return p;
    }

    fn deinit(p: *Profiles, gpa: std.mem.Allocator) void {
        p.index.deinit(gpa);
        gpa.free(p.acc);
        gpa.free(p.seen);
        if (p.perm) |x| gpa.free(x);
    }

    /// Control.permute: each id reads a random other id of its role (seeded)
    fn permute(p: *Profiles, gpa: std.mem.Allocator, seed: u32) !void {
        const perm = try gpa.alloc(u32, p.index.count());
        p.perm = perm;
        var by_role: [5]std.ArrayList(u32) = @splat(.empty);
        defer for (&by_role) |*b| b.deinit(gpa);
        // Sorted keys, so the permutation doesn't depend on hash order
        var keys: std.ArrayList(u64) = .empty;
        defer keys.deinit(gpa);
        var it = p.index.keyIterator();
        while (it.next()) |k| try keys.append(gpa, k.*);
        std.mem.sort(u64, keys.items, {}, std.sort.asc(u64));
        for (keys.items) |k| try by_role[k & 7].append(gpa, p.index.get(k).?);
        var rng: std.Random.DefaultPrng = .init(0x9e37 +% seed);
        for (by_role) |b| {
            const to = try gpa.dupe(u32, b.items);
            defer gpa.free(to);
            rng.random().shuffle(u32, to);
            for (b.items, to) |from, x| perm[from] = x;
        }
    }

    /// The shrunk outcome-balanced mean; without: leave out that seat's own values
    fn raw(p: *const Profiles, id: u32, role: usize, f: usize, without: ?*const Without) f64 {
        var out: f64 = 0;
        for (0..2) |half| {
            var s = p.acc[id][half][f][0];
            var n = p.acc[id][half][f][1];
            if (without) |w| if (w.half == half and !std.math.isNan(w.v[f])) {
                s -= w.v[f];
                n -= 1;
            };
            out += 0.5 * (s + pseudo * p.role_mean[role][f]) / (n + pseudo);
        }
        return out;
    }

    /// A seat's z profile; loo: without its own row (a fit game)
    fn z(p: *const Profiles, r: *const rows.Row, role: usize, loo: bool, out: *[n_prof]f32) void {
        const own_id = p.index.get(key(r.champion, role)) orelse {
            out.* = @splat(0);
            return;
        };
        // Another champion-role's profile never holds this row
        const id = if (p.perm) |x| x[own_id] else own_id;
        const y = p.rowY(r);
        const own: Without = .{ .half = @intFromBool(y > 0.5), .v = rowValues(&r.stats) };
        const without: ?*const Without = if (loo and id == own_id and !std.math.isNan(y)) &own else null;
        for (out, 0..) |*o, f| {
            const sd = p.z_sd[role][f];
            const v = p.raw(id, role, f, without);
            o.* = if (sd > 0) @floatCast((v - p.z_mean[role][f]) / sd) else 0;
        }
    }
};

const Without = struct { half: usize, v: [n_prof]f32 };

/// One game for the net: netcheck's ids, platform, label and offset, plus each slot's z
/// profile
pub const SetGame = struct {
    g: NetGame,
    z: [10][n_prof]f32,
};

/// Blue won per data game index: the fit games' results in a seeded random order (other
/// games keep theirs; only fit games are read)
fn shuffledResults(gpa: std.mem.Allocator, d: *const rows.Data, fit_games: []const u32, seed: u32) ![]u1 {
    const won = try gpa.alloc(u1, d.games.len);
    for (won, d.games) |*w, g| w.* = 1 - g.winner;
    const ys = try gpa.alloc(u1, fit_games.len);
    defer gpa.free(ys);
    for (ys, fit_games) |*y, gi| y.* = won[gi];
    var rng: std.Random.DefaultPrng = .init(0x5f1e +% seed);
    rng.random().shuffle(u1, ys);
    for (ys, fit_games) |y, gi| won[gi] = y;
    return won;
}

/// Each of `games` with its slots' profiles from `p`; loo for the games `p` was built on
fn setGames(gpa: std.mem.Allocator, d: *const rows.Data, seat: []const u32, p: *const Profiles, games: []const u32, nets: []const NetGame, loo: bool) ![]SetGame {
    const out = try gpa.alloc(SetGame, games.len);
    for (out, games, nets) |*o, gi, g| {
        o.g = g;
        if (p.won) |w| o.g.y = @floatFromInt(w[gi]);
        for (&o.z, 0..) |*z, s| {
            const ri = seat[@as(usize, gi) * 10 + s];
            if (ri == std.math.maxInt(u32)) z.* = @splat(0) else p.z(&d.rows[ri], s % 5, loo, z);
        }
    }
    return out;
}

/// Flat parameters: platform intercepts, the offset's weight, phi and rho biases (no
/// decay); champion-role embeddings (emb_wd); W1 (phi x in), V (rho x rin), w (wd)
const Layout = struct {
    phi: usize,
    rho: usize,
    emb: usize,
    in: usize,
    rin: usize,
    cross: bool,
    c: usize,
    a: usize,
    b1: usize,
    cb: usize,
    e: usize,
    w1: usize,
    v: usize,
    out: usize,
    len: usize,

    fn init(cfg: Config, emb: usize, n_ids: usize) Layout {
        var l: Layout = undefined;
        l.phi = cfg.phi;
        l.rho = cfg.rho;
        l.emb = if (cfg.ids) emb else 0;
        l.in = n_prof + 5 + l.emb;
        l.cross = cfg.cross;
        l.rin = if (cfg.cross) 2 * l.phi else l.phi;
        l.c = 0;
        l.a = winnet.n_platforms;
        l.b1 = l.a + 1;
        l.cb = l.b1 + l.phi;
        l.e = l.cb + l.rho;
        l.w1 = l.e + n_ids * l.emb;
        l.v = l.w1 + l.phi * l.in;
        l.out = l.v + l.rho * l.rin;
        l.len = l.out + l.rho;
        return l;
    }
};

const Net = struct {
    l: Layout,
    p: []f32,

    fn init(gpa: std.mem.Allocator, l: Layout, rnd: std.Random) !Net {
        const p = try gpa.alloc(f32, l.len);
        @memset(p, 0);
        p[l.a] = 1;
        for (p[l.e..l.w1]) |*x| x.* = (rnd.float(f32) * 2 - 1) * 0.1;
        const b1 = @sqrt(6.0 / @as(f32, @floatFromInt(l.in)));
        for (p[l.w1..l.v]) |*x| x.* = (rnd.float(f32) * 2 - 1) * b1;
        const bv = @sqrt(6.0 / @as(f32, @floatFromInt(l.rin)));
        for (p[l.v..l.out]) |*x| x.* = (rnd.float(f32) * 2 - 1) * bv;
        // w stays 0: the net starts as the offset
        return .{ .l = l, .p = p };
    }
};

/// One game's activations: slot inputs and units, team vectors, rho's inputs and
/// hidden units (after ReLU and dropout) per side order; then gradient scratch
const Work = struct {
    buf: []f32,
    x: []f32,
    u: []f32,
    t: []f32,
    rin: []f32,
    hid: []f32,
    dt: []f32,
    din: []f32,
    du: []f32,

    fn init(gpa: std.mem.Allocator, l: Layout) !Work {
        const sizes = [_]usize{ 10 * l.in, 10 * l.phi, 2 * l.phi, 2 * l.rin, 2 * l.rho, 2 * l.phi, l.rin, l.phi };
        var total: usize = 0;
        for (sizes) |s| total += s;
        const buf = try gpa.alloc(f32, total);
        var at: usize = 0;
        var parts: [sizes.len][]f32 = undefined;
        for (sizes, &parts) |s, *p| {
            p.* = buf[at..][0..s];
            at += s;
        }
        return .{ .buf = buf, .x = parts[0], .u = parts[1], .t = parts[2], .rin = parts[3], .hid = parts[4], .dt = parts[5], .din = parts[6], .du = parts[7] };
    }

    fn deinit(w: *const Work, gpa: std.mem.Allocator) void {
        gpa.free(w.buf);
    }
};

const dot = winnet.dot;
const axpy = winnet.axpy;
const sigmoid = winnet.sigmoid;

/// f per side order (0: blue's view, 1: red's); with rnd, rho's units drop at 1 - keep
fn forward(n: *const Net, g: *const SetGame, w: *const Work, keep: f32, rnd: ?std.Random) [2]f32 {
    const l = n.l;
    const p = n.p;
    for (0..10) |s| {
        const x = w.x[s * l.in ..][0..l.in];
        @memcpy(x[0..n_prof], &g.z[s]);
        @memset(x[n_prof..][0..5], 0);
        x[n_prof + s % 5] = 1;
        if (l.emb > 0) @memcpy(x[n_prof + 5 ..], p[l.e + g.g.ids[s] * l.emb ..][0..l.emb]);
        const u = w.u[s * l.phi ..][0..l.phi];
        for (u, 0..) |*o, j| o.* = @max(0, p[l.b1 + j] + dot(p[l.w1 + j * l.in ..][0..l.in], x));
    }
    for (0..2) |side| {
        const t = w.t[side * l.phi ..][0..l.phi];
        @memset(t, 0);
        for (0..5) |r| axpy(t, 0.2, w.u[(side * 5 + r) * l.phi ..][0..l.phi]);
    }
    var f: [2]f32 = undefined;
    for (0..2) |o| {
        const rin = w.rin[o * l.rin ..][0..l.rin];
        @memcpy(rin[0..l.phi], w.t[o * l.phi ..][0..l.phi]);
        if (l.cross) @memcpy(rin[l.phi..], w.t[(1 - o) * l.phi ..][0..l.phi]);
        const hid = w.hid[o * l.rho ..][0..l.rho];
        for (hid, 0..) |*h, j| {
            const z = p[l.cb + j] + dot(p[l.v + j * l.rin ..][0..l.rin], rin);
            const kept = if (rnd) |rr| rr.float(f32) < keep else true;
            h.* = if (z > 0 and kept) (if (rnd != null) z / keep else z) else 0;
        }
        f[o] = dot(p[l.out..l.len], hid);
    }
    return f;
}

fn gameLogit(n: *const Net, g: *const SetGame, f: [2]f32) f32 {
    return (f[0] - f[1]) / 2 + n.p[n.l.c + g.g.platform] + n.p[n.l.a] * g.g.off;
}

/// Adds dl (d loss / d logit)'s gradient to gr, from forward's activations in w
fn backward(n: *const Net, g: *const SetGame, w: *const Work, dl: f32, keep: f32, gr: []f32) void {
    const l = n.l;
    const p = n.p;
    gr[l.c + g.g.platform] += dl;
    gr[l.a] += dl * g.g.off;
    @memset(w.dt, 0);
    for (0..2) |o| {
        const df: f32 = if (o == 0) dl / 2 else -dl / 2;
        const rin = w.rin[o * l.rin ..][0..l.rin];
        const hid = w.hid[o * l.rho ..][0..l.rho];
        axpy(gr[l.out..l.len], df, hid);
        @memset(w.din, 0);
        for (hid, 0..) |h, j| {
            if (h == 0) continue;
            const dz = df * p[l.out + j] / keep;
            gr[l.cb + j] += dz;
            axpy(gr[l.v + j * l.rin ..][0..l.rin], dz, rin);
            axpy(w.din, dz, p[l.v + j * l.rin ..][0..l.rin]);
        }
        axpy(w.dt[o * l.phi ..][0..l.phi], 1, w.din[0..l.phi]);
        if (l.cross) axpy(w.dt[(1 - o) * l.phi ..][0..l.phi], 1, w.din[l.phi..]);
    }
    for (0..10) |s| {
        const x = w.x[s * l.in ..][0..l.in];
        const u = w.u[s * l.phi ..][0..l.phi];
        const dt = w.dt[(s / 5) * l.phi ..][0..l.phi];
        for (u, dt, 0..) |uj, d, j| {
            if (uj <= 0) continue;
            const dz = 0.2 * d;
            gr[l.b1 + j] += dz;
            axpy(gr[l.w1 + j * l.in ..][0..l.in], dz, x);
            if (l.emb > 0) axpy(gr[l.e + g.g.ids[s] * l.emb ..][0..l.emb], dz, p[l.w1 + j * l.in + n_prof + 5 ..][0..l.emb]);
        }
    }
}

fn predict(n: *const Net, games: []const SetGame, w: *const Work, out: []f32) void {
    for (games, out) |*g, *o| o.* = sigmoid(gameLogit(n, g, forward(n, g, w, 1, null)));
}

fn meanLoss(n: *const Net, games: []const SetGame, w: *const Work) f64 {
    var s: f64 = 0;
    for (games) |*g| s += winnet.loss1(g.g.y, sigmoid(gameLogit(n, g, forward(n, g, w, 1, null))));
    return s / @as(f64, @floatFromInt(@max(games.len, 1)));
}

/// The offset alone's loss: a fresh net's reference, since it starts as the offset
fn offsetLoss(games: []const SetGame) f64 {
    var s: f64 = 0;
    for (games) |*g| s += winnet.loss1(g.g.y, sigmoid(g.g.off));
    return s / @as(f64, @floatFromInt(@max(games.len, 1)));
}

const Trained = struct { net: Net, steps: u64, epochs: f64, val_loss: f64 };

/// AdamW over shuffled batches for at most max_steps, as netcheck's small net; with val,
/// also scored before the first step, so 0 steps (the offset alone) can win
fn train(gpa: std.mem.Allocator, opts: winnet.Options, seed: u32, n_ids: u32, set: []const SetGame, val: ?[]const SetGame, max_steps: u64) !Trained {
    var rng: std.Random.DefaultPrng = .init(seed);
    const rnd = rng.random();
    const l: Layout = .init(opts.set, opts.emb, n_ids);
    var n = try Net.init(gpa, l, rnd);
    errdefer gpa.free(n.p);
    const w: Work = try .init(gpa, l);
    defer w.deinit(gpa);
    const scratch = try gpa.alloc(f32, 4 * l.len);
    defer gpa.free(scratch);
    const gr = scratch[0..l.len];
    const m1 = scratch[l.len..][0..l.len];
    const m2 = scratch[2 * l.len ..][0..l.len];
    const best = scratch[3 * l.len ..][0..l.len];
    @memset(m1, 0);
    @memset(m2, 0);
    const order = try gpa.alloc(u32, set.len);
    defer gpa.free(order);
    for (order, 0..) |*o, i| o.* = @intCast(i);
    const keep = 1 - opts.dropout;
    const drop: ?std.Random = if (opts.dropout > 0) rnd else null;
    const emb_wd = opts.emb_wd orelse opts.wd;
    const per_epoch = winnet.stepsPerEpoch(set.len, opts.batch);
    const eval_every = @max(1, per_epoch / @max(opts.evals, 1));

    var best_loss = std.math.inf(f64);
    if (val) |v| {
        best_loss = meanLoss(&n, v, &w);
        gates.initLoss("setnet", best_loss, offsetLoss(v));
    }
    @memcpy(best, n.p);
    var best_step: u64 = 0;
    var since_best: u32 = 0;
    var step: u64 = 0;
    var at: usize = order.len;
    while (step < max_steps) {
        if (at >= order.len) {
            rnd.shuffle(u32, order);
            at = 0;
        }
        const part = order[at..@min(at + opts.batch, order.len)];
        at += part.len;
        @memset(gr, 0);
        const count: f32 = @floatFromInt(part.len);
        for (part) |gi| {
            const g = &set[gi];
            const f = forward(&n, g, &w, keep, drop);
            backward(&n, g, &w, (sigmoid(gameLogit(&n, g, f)) - g.g.y) / count, keep, gr);
        }
        if (opts.clip > 0) {
            var norm: f32 = 0;
            for (gr) |x| norm += x * x;
            norm = @sqrt(norm);
            if (norm > opts.clip) for (gr) |*x| {
                x.* *= opts.clip / norm;
            };
        }
        step += 1;
        const c1 = 1 - std.math.pow(f32, 0.9, @floatFromInt(step));
        const c2 = 1 - std.math.pow(f32, 0.999, @floatFromInt(step));
        for (n.p, gr, m1, m2, 0..) |*x, g, *s1, *s2, i| {
            s1.* = 0.9 * s1.* + 0.1 * g;
            s2.* = 0.999 * s2.* + 0.001 * g * g;
            if (i == l.a and opts.fix_offset) continue;
            const decay: f32 = if (i < l.e) 0 else if (i < l.w1) emb_wd * x.* else opts.wd * x.*;
            x.* -= opts.lr * ((s1.* / c1) / (@sqrt(s2.* / c2) + 1e-8) + decay);
        }
        const v = val orelse continue;
        if (step % eval_every != 0 and step != max_steps) continue;
        const loss = meanLoss(&n, v, &w);
        if (loss < best_loss - 1e-7) {
            best_loss = loss;
            best_step = step;
            since_best = 0;
            @memcpy(best, n.p);
        } else {
            since_best += 1;
            if (since_best >= opts.patience) break;
        }
    }
    if (val == null) best_step = step else @memcpy(n.p, best);
    const epochs = @as(f64, @floatFromInt(best_step)) / @as(f64, @floatFromInt(per_epoch));
    return .{ .net = n, .steps = best_step, .epochs = epochs, .val_loss = best_loss };
}

/// netcheck's fit for one seed: tune on the inner games (early stopping on val), refit on
/// all fit games for a tenth more epochs (none when the start won), score
pub fn fit(gpa: std.mem.Allocator, io: Io, opts: winnet.Options, seed: u32, s: winnet.Sets) !winnet.Fitted {
    const t0 = Io.Clock.awake.now(io);
    const d = s.d;
    const seat = try seatRows(gpa, d);
    defer gpa.free(seat);
    const cfg = opts.set;
    const won: ?[]u1 = if (cfg.control == .shuffle) try shuffledResults(gpa, d, s.idx.fit, seed) else null;
    defer if (won) |x| gpa.free(x);
    var p_inner: Profiles = try .build(gpa, d, seat, s.idx.inner, won);
    defer p_inner.deinit(gpa);
    if (cfg.control == .permute) try p_inner.permute(gpa, seed);
    const inner = try setGames(gpa, d, seat, &p_inner, s.idx.inner, s.inner, true);
    defer gpa.free(inner);
    const val = try setGames(gpa, d, seat, &p_inner, s.idx.val, s.val, false);
    defer gpa.free(val);
    const dumping = cfg.dump and seed == opts.seeds[0];
    if (dumping) {
        try dumpPart(gpa, io, opts.out, s.block, "inner", d, s.idx.inner, inner);
        try dumpPart(gpa, io, opts.out, s.block, "val", d, s.idx.val, val);
    }
    const tuned = try train(gpa, opts, seed, s.n_inner, inner, val, opts.max_epochs * winnet.stepsPerEpoch(inner.len, opts.batch));
    gpa.free(tuned.net.p);

    var p_all: Profiles = try .build(gpa, d, seat, s.idx.fit, won);
    defer p_all.deinit(gpa);
    if (cfg.control == .permute) try p_all.permute(gpa, seed);
    const all = try setGames(gpa, d, seat, &p_all, s.idx.fit, s.fit, true);
    defer gpa.free(all);
    const scored = try setGames(gpa, d, seat, &p_all, s.idx.scored, s.scored, false);
    defer gpa.free(scored);
    if (dumping) {
        try dumpPart(gpa, io, opts.out, s.block, "fit", d, s.idx.fit, all);
        try dumpPart(gpa, io, opts.out, s.block, "scored", d, s.idx.scored, scored);
    }
    const steps = if (tuned.steps == 0) 0 else winnet.refitSteps(tuned.epochs, all.len, opts.batch);
    const full = try train(gpa, opts, seed, s.n_all, all, null, steps);
    defer gpa.free(full.net.p);
    const w: Work = try .init(gpa, full.net.l);
    defer w.deinit(gpa);
    const pred = try gpa.alloc(f32, scored.len);
    predict(&full.net, scored, &w, pred);
    std.debug.print("netcheck: seed {d}: set net {d:.2} epochs, offset weight {d:.3}\n", .{ seed, tuned.epochs, full.net.p[full.net.l.a] });
    if (opts.export_net and s.block == .dev) try writeExport(gpa, io, opts, seed, &full.net, &p_all, s, scored, &w);
    return .{ .pred = pred, .epochs = tuned.epochs, .val_loss = tuned.val_loss, .seconds = winnet.secondsSince(io, t0) };
}

/// --export 1: one seed's dev fit as DIR/setnet-s<seed>.json (format meiolol-setnet,
/// version 1). A game's logit is gameLogit over forward: params are the flat Layout
/// (offsets in `layout`); a slot's input is its champion-role's z profile (zeros when
/// not in `profiles`), the role one-hot and, with emb > 0, the embedding row of its
/// vocab id (`ids`, else the role's 0..4). `refs`: the first scored games' inputs and
/// logits, for a reader to check itself against
fn writeExport(gpa: std.mem.Allocator, io: Io, opts: winnet.Options, seed: u32, n: *const Net, p: *const Profiles, s: winnet.Sets, scored: []const SetGame, w: *const Work) !void {
    var arena_state = std.heap.ArenaAllocator.init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const Id = struct { champion: u32, role: u8, id: u32 };
    const Prof = struct { champion: u32, role: u8, z: [n_prof]f32 };
    const Ref = struct { teams: [2][5]u32, platform: u8, offset: f32, logit: f32 };
    var ids: std.ArrayList(Id) = .empty;
    var vit = s.vocab_all.map.iterator();
    while (vit.next()) |e| try ids.append(arena, .{ .champion = @intCast(e.key_ptr.* >> 3), .role = @intCast(e.key_ptr.* & 7), .id = e.value_ptr.* });
    std.mem.sort(Id, ids.items, {}, struct {
        fn lt(_: void, a: Id, b: Id) bool {
            return a.id < b.id;
        }
    }.lt);
    var profs: std.ArrayList(Prof) = .empty;
    var pit = p.index.iterator();
    while (pit.next()) |e| {
        const role: usize = @intCast(e.key_ptr.* & 7);
        var z: [n_prof]f32 = undefined;
        for (&z, 0..) |*o, f| {
            const sd = p.z_sd[role][f];
            o.* = if (sd > 0) @floatCast((p.raw(e.value_ptr.*, role, f, null) - p.z_mean[role][f]) / sd) else 0;
        }
        try profs.append(arena, .{ .champion = @intCast(e.key_ptr.* >> 3), .role = @intCast(role), .z = z });
    }
    std.mem.sort(Prof, profs.items, {}, struct {
        fn lt(_: void, a: Prof, b: Prof) bool {
            return a.champion * 8 + a.role < b.champion * 8 + b.role;
        }
    }.lt);
    const n_refs = @min(scored.len, 200);
    const refs = try arena.alloc(Ref, n_refs);
    for (refs, scored[0..n_refs], s.idx.scored[0..n_refs]) |*r, *g, gi| {
        r.* = .{ .teams = s.d.games[gi].teams, .platform = g.g.platform, .offset = g.g.off, .logit = gameLogit(n, g, forward(n, g, w, 1, null)) };
    }
    const l = n.l;
    const file = .{
        .format = "meiolol-setnet",
        .version = 1,
        .candidate = if (@hasDecl(cand, "name")) cand.name else "cand",
        .seed = seed,
        .fit_games = s.idx.fit.len,
        .phi = l.phi,
        .rho = l.rho,
        .emb = l.emb,
        .cross = l.cross,
        .n_prof = n_prof,
        .features = std.enums.values(Feature),
        .layout = .{ .in = l.in, .rin = l.rin, .c = l.c, .a = l.a, .b1 = l.b1, .cb = l.cb, .e = l.e, .w1 = l.w1, .v = l.v, .out = l.out, .len = l.len },
        .params = n.p,
        .ids = ids.items,
        .profiles = profs.items,
        .refs = refs,
    };
    const json = try std.json.Stringify.valueAlloc(arena, file, .{});
    const name = try std.fmt.allocPrint(arena, "setnet-s{d}.json", .{seed});
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fs.path.join(arena, &.{ opts.out, name }), .data = json });
}

/// --dump 1 (meiolol-58's PyTorch cross-check): one set of a block as the net sees it.
/// DIR/set-<block>-<part>.f32: games x 10 slots (blue by role, then red) x n_prof z,
/// little-endian f32 (leave-one-out for inner and fit); .tsv: match_id, platform index,
/// y (blue won, as trained on), offset (the candidate's blue logit), the 10 vocab ids
/// (champion-role with min_games fit games, else the role's 0..4; inner and val use the
/// inner games' vocab), same order
fn dumpPart(gpa: std.mem.Allocator, io: Io, out: []const u8, block: winnet.Block, part: []const u8, d: *const rows.Data, games: []const u32, set: []const SetGame) !void {
    var dir = try Io.Dir.cwd().openDir(io, out, .{});
    defer dir.close(io);
    var buf: [64 * 1024]u8 = undefined;
    const bin = try std.fmt.allocPrint(gpa, "set-{s}-{s}.f32", .{ @tagName(block), part });
    defer gpa.free(bin);
    var bf = try dir.createFile(io, bin, .{});
    defer bf.close(io);
    var bw = bf.writer(io, &buf);
    for (set) |*g| try bw.interface.writeAll(std.mem.sliceAsBytes(&g.z));
    try bw.interface.flush();
    const tsv = try std.fmt.allocPrint(gpa, "set-{s}-{s}.tsv", .{ @tagName(block), part });
    defer gpa.free(tsv);
    var tf = try dir.createFile(io, tsv, .{});
    defer tf.close(io);
    var tw = tf.writer(io, &buf);
    const w = &tw.interface;
    try w.writeAll("match_id\tplatform\ty\toff");
    for (0..10) |slot| try w.print("\tid{d}", .{slot});
    try w.writeAll("\n");
    for (games, set) |gi, *g| {
        try w.print("{s}\t{d}\t{d}\t{d:.6}", .{ d.games[gi].match_id, g.g.platform, g.g.y, g.g.off });
        for (g.g.ids) |id| try w.print("\t{d}", .{id});
        try w.writeAll("\n");
    }
    try w.flush();
}

/// Training-health entry (lab/health.zig): netcheck's default options with `cfg`, fitted
/// on `set` for `steps` (0: at init) without early stopping; blue's chance per `scored`
/// game into pred. Returns the parameters (caller frees)
pub fn healthFit(gpa: std.mem.Allocator, cfg: Config, seed: u32, n_ids: u32, set: []const SetGame, steps: u64, scored: []const SetGame, pred: []f32) ![]f32 {
    var opts: winnet.Options = .{ .net = .set };
    opts.set = cfg;
    const t = try train(gpa, opts, seed, n_ids, set, null, steps);
    errdefer gpa.free(t.net.p);
    const w: Work = try .init(gpa, t.net.l);
    defer w.deinit(gpa);
    predict(&t.net, scored, &w, pred);
    return t.net.p;
}

const testing = std.testing;

fn testGame(r: std.Random, n_ids: u32) SetGame {
    var g: SetGame = .{ .g = .{ .ids = undefined, .platform = r.uintLessThan(u8, 3), .y = 0, .off = 0 }, .z = undefined };
    for (&g.g.ids, 0..) |*id, s| id.* = 5 + 5 * r.uintLessThan(u32, (n_ids - 5) / 5) + @as(u32, @intCast(s % 5));
    for (&g.z) |*z| for (z) |*x| {
        x.* = r.floatNorm(f32);
    };
    return g;
}

test "set net: gradient matches finite differences" {
    const gpa = testing.allocator;
    for ([_]Config{ .{ .phi = 6, .rho = 5 }, .{ .phi = 4, .rho = 3, .cross = false, .ids = true } }) |cfg| {
        const n_ids = 30;
        const l: Layout = .init(cfg, 3, n_ids);
        var rng: std.Random.DefaultPrng = .init(7);
        const r = rng.random();
        var n = try Net.init(gpa, l, r);
        defer gpa.free(n.p);
        for (n.p[l.out..l.len]) |*x| x.* = r.floatNorm(f32);
        n.p[l.a] = 0.8;
        const w: Work = try .init(gpa, l);
        defer w.deinit(gpa);
        var g = testGame(r, n_ids);
        g.g.y = 1;
        g.g.off = 0.4;
        const gr = try gpa.alloc(f32, l.len);
        defer gpa.free(gr);
        @memset(gr, 0);
        const f = forward(&n, &g, &w, 1, null);
        backward(&n, &g, &w, sigmoid(gameLogit(&n, &g, f)) - g.g.y, 1, gr);
        var checks: std.ArrayList(usize) = .empty;
        defer checks.deinit(gpa);
        try checks.appendSlice(gpa, &.{ l.c + g.g.platform, l.a, l.b1 + 1, l.cb + 2, l.w1 + 3, l.w1 + l.in + 7, l.v + 1, l.v + l.rin + 2, l.out + 1 });
        if (l.emb > 0) try checks.append(gpa, l.e + g.g.ids[2] * l.emb + 1);
        for (checks.items) |i| {
            const old = n.p[i];
            n.p[i] = old + 1e-3;
            const up = meanLoss(&n, (&g)[0..1], &w);
            n.p[i] = old - 1e-3;
            const down = meanLoss(&n, (&g)[0..1], &w);
            n.p[i] = old;
            try testing.expectApproxEqAbs((up - down) / 2e-3, gr[i], 2e-3);
        }
    }
}

test "set net: starts at the offset, antisymmetric, learns a lopsided-team effect" {
    const gpa = testing.allocator;
    var rng: std.Random.DefaultPrng = .init(11);
    const r = rng.random();
    const n_ids = 30;
    // A team whose feature-0 sum is far from 0 (lopsided) loses
    const games = try gpa.alloc(SetGame, 6000);
    defer gpa.free(games);
    for (games) |*g| {
        g.* = testGame(r, n_ids);
        g.g.platform = 0;
        var q: [2]f32 = @splat(0);
        for (0..10) |s| q[s / 5] += g.z[s][0];
        const edge = -(q[0] * q[0] - q[1] * q[1]) / 5;
        g.g.y = if (r.float(f32) < sigmoid(edge)) 1 else 0;
    }
    const set = games[0..5000];
    const val = games[5000..];
    var opts: winnet.Options = .{ .net = .set, .dropout = 0, .wd = 0, .lr = 3e-3, .batch = 64, .clip = 0, .evals = 2, .patience = 4, .max_epochs = 15 };
    opts.set = .{ .phi = 8, .rho = 8 };

    const t0 = try train(gpa, opts, 1, n_ids, set, null, 0);
    defer gpa.free(t0.net.p);
    const w: Work = try .init(gpa, t0.net.l);
    defer w.deinit(gpa);
    var a = games[0];
    a.g.off = 0.7;
    var p: [2]f32 = undefined;
    predict(&t0.net, (&a)[0..1], &w, p[0..1]);
    try testing.expectApproxEqAbs(sigmoid(0.7), p[0], 1e-6);

    const t = try train(gpa, opts, 1, n_ids, set, val, opts.max_epochs * winnet.stepsPerEpoch(set.len, opts.batch));
    defer gpa.free(t.net.p);
    try testing.expect(t.steps > 0);
    try testing.expect(t.val_loss < @log(2.0) - 0.05);
    // Swapping the teams (and the offset's sign) flips everything but blue's intercept
    var b = a;
    for (0..5) |i| {
        std.mem.swap(u32, &b.g.ids[i], &b.g.ids[i + 5]);
        std.mem.swap([n_prof]f32, &b.z[i], &b.z[i + 5]);
    }
    b.g.off = -a.g.off;
    predict(&t.net, &.{ a, b }, &w, &p);
    try testing.expectApproxEqAbs(2 * t.net.p[t.net.l.c], winnet.logit(p[0]) + winnet.logit(p[1]), 1e-4);
    // Lopsided blue (feature 0 high in every slot) into a balanced red
    var c = a;
    c.g.off = 0;
    for (0..10) |s| c.z[s] = @splat(0);
    for (0..5) |s| c.z[s][0] = 1.5;
    predict(&t.net, (&c)[0..1], &w, p[0..1]);
    try testing.expect(p[0] < 0.25);
}

test "profiles: shrunk halves, z in role, leave-one-out" {
    const gpa = testing.allocator;
    var games: [4]rows.Game = undefined;
    var rs: [40]rows.Row = undefined;
    for (&games, 0..) |*g, gi| {
        g.* = .{ .match_id = "", .start = @intCast(gi), .patch = 0, .platform = 0, .is_test = false, .teams = @splat(@splat(0)), .winner = @intCast(gi % 2) };
        for (0..10) |s| {
            const side: u1 = @intCast(s / 5);
            var st = seatstats.unknown;
            st[@backingInt(seatstats.SeatStat.minutes)] = 10;
            st[@backingInt(seatstats.SeatStat.attack_range)] = @floatFromInt(100 * (s % 5) + 10 * gi + side);
            var y: [rows.outcome_count]f32 = @splat(std.math.nan(f32));
            y[win] = if (side == g.winner) 1 else 0;
            // Champion 1 + side in every role: two champion-roles per role
            rs[gi * 10 + s] = .{ .game = @intCast(gi), .slot = @intCast(s), .side = side, .role = @fromBackingInt(@intCast(s % 5)), .champion = 1 + @as(u32, side), .y = y, .stats = st };
        }
    }
    const d: rows.Data = .{ .arena = .init(gpa), .games = &games, .rows = &rs };
    const seat = try seatRows(gpa, &d);
    defer gpa.free(seat);
    var p: Profiles = try .build(gpa, &d, seat, &.{ 0, 1, 2, 3 }, null);
    defer p.deinit(gpa);
    const f = @backingInt(Feature.range);
    // Mid (role 2), champion 1 (blue): ranges 200, 210, 220, 230; blue won games 0, 2
    const id = p.index.get(key(1, 2)).?;
    const rm = p.role_mean[2][f];
    try testing.expectApproxEqAbs(@as(f64, 215.5), rm, 1e-9);
    const won = (200 + 220 + pseudo * rm) / (2 + pseudo);
    const lost = (210 + 230 + pseudo * rm) / (2 + pseudo);
    try testing.expectApproxEqAbs(0.5 * (won + lost), p.raw(id, 2, f, null), 1e-9);
    var z: [n_prof]f32 = undefined;
    var z_loo: [n_prof]f32 = undefined;
    p.z(&rs[0 * 10 + 2], 2, false, &z);
    p.z(&rs[0 * 10 + 2], 2, true, &z_loo);
    // Two champion-roles per role, equal seats: z = -1 and +1
    try testing.expectApproxEqAbs(@as(f32, -1), z[f], 1e-4);
    const won_loo = (220 + pseudo * rm) / (1 + pseudo);
    const want = (0.5 * (won_loo + lost) - p.z_mean[2][f]) / p.z_sd[2][f];
    try testing.expectApproxEqAbs(@as(f32, @floatCast(want)), z_loo[f], 1e-4);
    // Unknown stats give z 0 (no spread)
    try testing.expectEqual(@as(f32, 0), z[@backingInt(Feature.magic)]);

    // permute: a permutation within each role; a row reading another profile isn't left out
    try p.permute(gpa, 3);
    var hit: [10]bool = @splat(false);
    var it = p.index.iterator();
    while (it.next()) |e| {
        const to = p.perm.?[e.value_ptr.*];
        hit[to] = true;
        var kt = p.index.iterator();
        while (kt.next()) |x| if (x.value_ptr.* == to) try testing.expectEqual(e.key_ptr.* & 7, x.key_ptr.* & 7);
    }
    for (hit) |h| try testing.expect(h);
    p.z(&rs[0 * 10 + 2], 2, true, &z_loo);
    if (p.perm.?[id] != id) try testing.expectApproxEqAbs(@as(f32, 1), z_loo[f], 1e-4);

    // shuffle: results from `won`
    const shuffled: [4]u1 = .{ 1, 1, 0, 0 };
    var q: Profiles = try .build(gpa, &d, seat, &.{ 0, 1, 2, 3 }, &shuffled);
    defer q.deinit(gpa);
    const qid = q.index.get(key(1, 2)).?;
    try testing.expectApproxEqAbs(@as(f64, 200 + 210), q.acc[qid][1][f][0], 1e-9);
    try testing.expectApproxEqAbs(@as(f64, 220 + 230), q.acc[qid][0][f][0], 1e-9);
}

test "dump: the net's inputs per game, z as f32 and a tsv line each" {
    const gpa = testing.allocator;
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir = try std.fmt.allocPrint(gpa, ".zig-cache/tmp/{s}", .{&tmp.sub_path});
    defer gpa.free(dir);
    var games: [2]rows.Game = undefined;
    for (&games, 0..) |*g, i| g.* = .{ .match_id = if (i == 0) "EUW1_1" else "EUW1_2", .start = 0, .patch = 0, .platform = 0, .is_test = false, .teams = @splat(@splat(0)), .winner = 0 };
    const d: rows.Data = .{ .arena = .init(gpa), .games = &games, .rows = &.{} };
    var rng: std.Random.DefaultPrng = .init(2);
    var set: [2]SetGame = .{ testGame(rng.random(), 30), testGame(rng.random(), 30) };
    set[1].g.y = 1;
    set[1].g.off = -0.25;
    try dumpPart(gpa, io, dir, .f3, "scored", &d, &.{ 1, 0 }, &set);
    const bin = try tmp.dir.readFileAlloc(io, "set-f3-scored.f32", gpa, .limited(1 << 20));
    defer gpa.free(bin);
    try testing.expectEqual(2 * 10 * n_prof * 4, bin.len);
    try testing.expectEqualSlices(u8, std.mem.sliceAsBytes(&set[1].z), bin[10 * n_prof * 4 ..]);
    const tsv = try tmp.dir.readFileAlloc(io, "set-f3-scored.tsv", gpa, .limited(1 << 20));
    defer gpa.free(tsv);
    var lines = std.mem.tokenizeScalar(u8, tsv, '\n');
    _ = lines.next();
    try testing.expect(std.mem.startsWith(u8, lines.next().?, "EUW1_2\t"));
    try testing.expect(std.mem.startsWith(u8, lines.next().?, "EUW1_1\t"));
    try testing.expect(lines.next() == null);
}
