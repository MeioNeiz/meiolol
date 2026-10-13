//! Planted effects (docs/model.md "Model tests"): winners re-drawn from a known logit, so
//! a model's recovered effects can be checked against the truth, and its "not detected"
//! read against what it could have detected. Any command's SNAP may be
//! `plant:SPEC:PATH`: rows.load loads PATH as usual and relabels it here, so real drafts,
//! game counts, folds, seat stats and experience stay, only who won changes. SPEC is
//! comma-separated key=value, sizes in win pp at 50% (logit = pp / 25, as effect tables
//! report), e.g. `plant:seed=2,synergy=2,mix=-3:$HOME/ml/snaps/snap-20261012T2055Z`.
//! Blue's logit, each a Term:
//!   base      side + champion-role strengths, blue minus red (normal, sd `champ`)
//!   synergy   when one team has the `pair`-th most common ally pair of two roles
//!   counter   the `pair`-th most common lane matchup (same role, two champions): to the
//!             lower champion id
//!   pairs     every ally pair's own effect, normal with sd `pair_sd` (role-pair blocks)
//!   counters  every lane matchup's own effect (same role, and bottom and support
//!             crossed), sd `counter_sd`, antisymmetric; `lanes` 1 same role only, 2
//!             bottom and support crossed only
//!   mix       per sd of win-comp's mix form (f - 0.5)^2, blue minus red; f the team's
//!             damage-weighted magic share from champion-role profiles over all rows
//!   skill     per player per log1p(earlier games on the champion), blue minus red
//! Experience wins (champ_wins, wins_before) stay the real ones: noise to the truth

const std = @import("std");
const core = @import("core");
const rows = @import("rows.zig");
const seatstats = @import("seatstats.zig");

const log = std.log.scoped(.plant);

pub const prefix = "plant:";

/// Win pp at 50% per logit unit
pub const pp_per_logit: f64 = 25.0;

pub const Spec = struct {
    seed: u64 = 1,
    champ: f64 = 2.5,
    side: f64 = 0,
    synergy: f64 = 0,
    counter: f64 = 0,
    /// Which ally pair and lane matchup, by games holding it: 1 the most common
    pair: u32 = 1,
    pair_sd: f64 = 0,
    counter_sd: f64 = 0,
    /// Which matchups counter_sd covers: 0 all, 1 same role, 2 bottom and support crossed
    lanes: u32 = 0,
    mix: f64 = 0,
    skill: f64 = 0,

    pub fn parse(text: []const u8) !Spec {
        var s: Spec = .{};
        var it = std.mem.tokenizeScalar(u8, text, ',');
        const info = @typeInfo(Spec).@"struct";
        while (it.next()) |kv| {
            const eq = std.mem.indexOfScalar(u8, kv, '=') orelse return error.BadPlantSpec;
            var found = false;
            inline for (info.field_names, info.field_types) |name, T| {
                if (std.mem.eql(u8, kv[0..eq], name)) {
                    @field(s, name) = switch (T) {
                        f64 => try std.fmt.parseFloat(f64, kv[eq + 1 ..]),
                        else => try std.fmt.parseInt(T, kv[eq + 1 ..], 10),
                    };
                    found = true;
                }
            }
            if (!found) return error.BadPlantSpec;
        }
        if (s.pair == 0 or s.lanes > 2) return error.BadPlantSpec;
        return s;
    }
};

pub const Arg = struct { spec: Spec, path: []const u8 };

/// `plant:SPEC:PATH`, or null for a plain snapshot path
pub fn parseArg(snap: []const u8) !?Arg {
    if (!std.mem.startsWith(u8, snap, prefix)) return null;
    const rest = snap[prefix.len..];
    const colon = std.mem.indexOfScalar(u8, rest, ':') orelse return error.BadPlantSpec;
    return .{ .spec = try Spec.parse(rest[0..colon]), .path = rest[colon + 1 ..] };
}

pub const Term = enum { base, synergy, counter, pairs, counters, mix, skill };
pub const n_term = @typeInfo(Term).@"enum".field_names.len;

pub const Slot = struct { champion: u32, role: u3 };

pub const Truth = struct {
    /// Per game, each term's part of blue's logit
    parts: [][n_term]f32,
    /// The planted ally pair (lower role first) and lane matchup (favoured champion
    /// first), games holding each
    pair: [2]Slot,
    pair_games: u32,
    matchup: [2]Slot,
    matchup_games: u32,
    /// sd of the unscaled mix form over games; 0 without seat stats
    mix_sd: f64,

    pub fn logit(t: *const Truth, game: usize) f32 {
        var z: f32 = 0;
        for (t.parts[game]) |x| z += x;
        return z;
    }

    pub fn deinit(t: *Truth, gpa: std.mem.Allocator) void {
        gpa.free(t.parts);
    }
};

fn key(champion: u32, role: usize) u64 {
    return @as(u64, champion) << 3 | role;
}

fn pairKey(a: u64, b: u64) u64 {
    return a << 32 | b;
}

fn unit(seed: u64, stream: u64, k: u64) f64 {
    var h = std.hash.Wyhash.init(seed);
    h.update(std.mem.asBytes(&stream));
    h.update(std.mem.asBytes(&k));
    return (@as(f64, @floatFromInt(h.final() >> 11)) + 0.5) / @as(f64, 1 << 53);
}

/// Standard normal, fixed by (seed, stream, k)
fn hnorm(seed: u64, stream: u64, k: u64) f64 {
    const a = unit(seed, 2 * stream, k);
    const b = unit(seed, 2 * stream + 1, k);
    return @sqrt(-2 * @log(a)) * @cos(2 * std.math.pi * b);
}

const Stream = struct {
    const champ = 1;
    const pair = 2;
    const counter = 3;
    const winner = 4;
};

fn gameKey(g: rows.Game) u64 {
    var h = std.hash.Wyhash.init(0x51a7);
    h.update(g.match_id);
    h.update(std.mem.asBytes(&g.start));
    h.update(std.mem.asBytes(&g.platform));
    return h.final();
}

/// Blue's role against red's: the five lanes, then bottom and support crossed
const lane_pairs = [_][2]usize{ .{ 0, 0 }, .{ 1, 1 }, .{ 2, 2 }, .{ 3, 3 }, .{ 4, 4 }, .{ 3, 4 }, .{ 4, 3 } };

const Count = struct { key: u64, n: u32 };

/// The k-th most common key (1-based), ties to the lower key
fn kth(gpa: std.mem.Allocator, counts: *const std.AutoHashMapUnmanaged(u64, u32), k: u32) !Count {
    var list: std.ArrayList(Count) = .empty;
    defer list.deinit(gpa);
    var it = counts.iterator();
    while (it.next()) |e| try list.append(gpa, .{ .key = e.key_ptr.*, .n = e.value_ptr.* });
    if (list.items.len < k) return error.TooFewPairs;
    std.mem.sort(Count, list.items, {}, struct {
        fn before(_: void, a: Count, b: Count) bool {
            return if (a.n != b.n) a.n > b.n else a.key < b.key;
        }
    }.before);
    return list.items[k - 1];
}

fn slotOf(k: u64) Slot {
    return .{ .champion = @intCast(k >> 3), .role = @intCast(k & 7) };
}

const pseudo = 10;

/// Champion-role profiles for the mix form: magic share of damage dealt and damage per
/// minute, each pulled to the role's mean by `pseudo` games
const Profiles = struct {
    sums: std.AutoHashMapUnmanaged(u64, [4]f64) = .empty,
    role: [5][4]f64 = @splat(@splat(0)),

    fn add(p: *Profiles, gpa: std.mem.Allocator, r: rows.Row) !void {
        const s = &r.stats;
        const dealt = s[@backingInt(seatstats.SeatStat.dmg_phys)] + s[@backingInt(seatstats.SeatStat.dmg_magic)] + s[@backingInt(seatstats.SeatStat.dmg_true)];
        const mins = s[@backingInt(seatstats.SeatStat.minutes)];
        if (!(dealt > 0) or !(mins > 0)) return;
        const v = [4]f64{ s[@backingInt(seatstats.SeatStat.dmg_magic)] / dealt, 1, dealt / mins, 1 };
        const e = try p.sums.getOrPutValue(gpa, key(r.champion, @backingInt(r.role)), @splat(0));
        const ro = &p.role[@backingInt(r.role)];
        for (e.value_ptr, ro, v) |*a, *b, x| {
            a.* += x;
            b.* += x;
        }
    }

    /// Magic share, damage per minute
    fn of(p: *const Profiles, champion: u32, role: usize) [2]f64 {
        const ro = p.role[role];
        const s = p.sums.get(key(champion, role)) orelse @as([4]f64, @splat(0));
        return .{
            (s[0] + pseudo * ro[0] / ro[1]) / (s[1] + pseudo),
            (s[2] + pseudo * ro[2] / ro[3]) / (s[3] + pseudo),
        };
    }
};

pub fn truth(gpa: std.mem.Allocator, d: *const rows.Data, spec: Spec) !Truth {
    const pp = 1.0 / pp_per_logit;
    const parts = try gpa.alloc([n_term]f32, d.games.len);
    errdefer gpa.free(parts);
    @memset(parts, @splat(0));

    var ally: std.AutoHashMapUnmanaged(u64, u32) = .empty;
    defer ally.deinit(gpa);
    var lane: std.AutoHashMapUnmanaged(u64, u32) = .empty;
    defer lane.deinit(gpa);
    for (d.games) |g| {
        for (g.teams) |t| for (0..5) |a| for (a + 1..5) |b| {
            const e = try ally.getOrPutValue(gpa, pairKey(key(t[a], a), key(t[b], b)), 0);
            e.value_ptr.* += 1;
        };
        for (0..5) |r| {
            const x = g.teams[0][r];
            const y = g.teams[1][r];
            if (x == y) continue;
            const e = try lane.getOrPutValue(gpa, pairKey(key(@min(x, y), r), key(@max(x, y), r)), 0);
            e.value_ptr.* += 1;
        }
    }
    const pc = try kth(gpa, &ally, spec.pair);
    const mc = try kth(gpa, &lane, spec.pair);
    const pair = [2]Slot{ slotOf(pc.key >> 32), slotOf(pc.key & 0xffff_ffff) };
    const matchup = [2]Slot{ slotOf(mc.key >> 32), slotOf(mc.key & 0xffff_ffff) };

    // Per game and slot: log1p(games on the champion), magic share, damage per minute
    const skill_x = try gpa.alloc([2][5]f32, d.games.len);
    defer gpa.free(skill_x);
    @memset(skill_x, @splat(@splat(0)));
    var prof: Profiles = .{};
    defer prof.sums.deinit(gpa);
    for (d.rows) |r| {
        skill_x[r.game][r.side][@backingInt(r.role)] = @floatCast(std.math.log1p(@as(f64, @floatFromInt(r.champ_games))));
        try prof.add(gpa, r);
    }
    const have_stats = prof.role[0][1] > 0;
    if (spec.mix != 0 and !have_stats) return error.NoSeatStats;

    var mix_x: []f64 = &.{};
    defer gpa.free(mix_x);
    var mix_sd: f64 = 0;
    if (have_stats) {
        mix_x = try gpa.alloc(f64, d.games.len);
        var s1: f64 = 0;
        var s2: f64 = 0;
        for (d.games, mix_x) |g, *x| {
            var form: [2]f64 = undefined;
            for (g.teams, &form) |t, *f| {
                var num: f64 = 0;
                var den: f64 = 0;
                for (t, 0..) |ch, r| {
                    const p = prof.of(ch, r);
                    num += p[1] * p[0];
                    den += p[1];
                }
                const frac = if (den > 0) num / den else 0.5;
                f.* = (frac - 0.5) * (frac - 0.5);
            }
            x.* = form[0] - form[1];
            s1 += x.*;
            s2 += x.* * x.*;
        }
        const n: f64 = @floatFromInt(@max(d.games.len, 1));
        mix_sd = @sqrt(@max(s2 / n - (s1 / n) * (s1 / n), 0));
    }

    var pair_games: u32 = 0;
    var matchup_games: u32 = 0;
    for (d.games, parts, 0..) |g, *p, gi| {
        var base: f64 = spec.side;
        for (0..5) |r| base += spec.champ * (hnorm(spec.seed, Stream.champ, key(g.teams[0][r], r)) - hnorm(spec.seed, Stream.champ, key(g.teams[1][r], r)));
        p[@backingInt(Term.base)] = @floatCast(base * pp);

        var syn: f64 = 0;
        var pairs: f64 = 0;
        for (g.teams, [2]f64{ 1, -1 }) |t, sign| {
            if (t[pair[0].role] == pair[0].champion and t[pair[1].role] == pair[1].champion) {
                syn += sign;
                pair_games += 1;
            }
            if (spec.pair_sd != 0) for (0..5) |a| for (a + 1..5) |b| {
                pairs += sign * hnorm(spec.seed, Stream.pair, pairKey(key(t[a], a), key(t[b], b)));
            };
        }
        p[@backingInt(Term.synergy)] = @floatCast(spec.synergy * syn * pp);
        p[@backingInt(Term.pairs)] = @floatCast(spec.pair_sd * pairs * pp);

        var ctr: f64 = 0;
        var ctrs: f64 = 0;
        const blue = g.teams[0][matchup[0].role];
        const red = g.teams[1][matchup[0].role];
        if (blue == matchup[0].champion and red == matchup[1].champion) ctr = 1;
        if (red == matchup[0].champion and blue == matchup[1].champion) ctr = -1;
        if (spec.counter_sd != 0) for (lane_pairs) |lp| {
            const crossed = lp[0] != lp[1];
            if ((spec.lanes == 1 and crossed) or (spec.lanes == 2 and !crossed)) continue;
            const kb = key(g.teams[0][lp[0]], lp[0]);
            const kr = key(g.teams[1][lp[1]], lp[1]);
            if (kb == kr) continue;
            const sign: f64 = if (kb < kr) 1 else -1;
            ctrs += sign * hnorm(spec.seed, Stream.counter, pairKey(@min(kb, kr), @max(kb, kr)));
        };
        if (ctr != 0) matchup_games += 1;
        p[@backingInt(Term.counter)] = @floatCast(spec.counter * ctr * pp);
        p[@backingInt(Term.counters)] = @floatCast(spec.counter_sd * ctrs * pp);

        if (mix_sd > 0) p[@backingInt(Term.mix)] = @floatCast(spec.mix * mix_x[gi] / mix_sd * pp);
        var sk: f64 = 0;
        for (skill_x[gi][0], skill_x[gi][1]) |b, rd| sk += b - rd;
        p[@backingInt(Term.skill)] = @floatCast(spec.skill * sk * pp);
    }
    return .{
        .parts = parts,
        .pair = pair,
        .pair_games = pair_games,
        .matchup = matchup,
        .matchup_games = matchup_games,
        .mix_sd = mix_sd,
    };
}

pub fn sigmoid(z: f64) f64 {
    return 1 / (1 + @exp(-z));
}

/// Draws every game's winner from the truth (seeded by spec.seed and the game, so the
/// same spec gives the same winners at any load order) and sets the rows' win outcome
pub fn relabel(d: *rows.Data, t: *const Truth, seed: u64) void {
    for (d.games, 0..) |*g, gi| {
        const p = sigmoid(t.logit(gi));
        g.winner = if (unit(seed, Stream.winner, gameKey(g.*)) < p) 0 else 1;
    }
    for (d.rows) |*r| r.y[@backingInt(rows.Outcome.win)] = @floatFromInt(@intFromBool(r.side == d.games[r.game].winner));
}

/// rows.load's hook: relabels a loaded snapshot by the spec
pub fn plant(gpa: std.mem.Allocator, d: *rows.Data, spec: Spec) !void {
    var t = try truth(gpa, d, spec);
    defer t.deinit(gpa);
    relabel(d, &t, spec.seed);
    var blue: usize = 0;
    for (d.games) |g| blue += @intFromBool(g.winner == 0);
    log.info("planted on {d} games (blue won {d}): pair #{d} {t} + #{d} {t} in {d} team-games, matchup #{d} over #{d} {t} in {d} games, mix sd {d:.5}", .{
        d.games.len,           blue,                                               t.pair[0].champion, @as(core.Role, @fromBackingInt(t.pair[0].role)),
        t.pair[1].champion,    @as(core.Role, @fromBackingInt(t.pair[1].role)),    t.pair_games,       t.matchup[0].champion,
        t.matchup[1].champion, @as(core.Role, @fromBackingInt(t.matchup[0].role)), t.matchup_games,    t.mix_sd,
    });
}

/// Fully synthetic games for tests, no snapshot: n games a minute apart, the newest
/// fifteenth EUW1 test games (platform 0), the rest over 3 platforms. 30 champions per role
/// (id % 5 its role, popularity falling as 1/rank), 1 in 8 picks a flex champion from
/// another role; seat stats from a magic share and damage per minute per champion plus
/// noise; earlier games on the champion log-uniform 0-54. Winners from `spec`
pub fn draft(gpa: std.mem.Allocator, n: usize, spec: Spec) !rows.Data {
    var data: rows.Data = .{ .arena = .init(gpa), .games = &.{}, .rows = &.{} };
    errdefer data.deinit();
    const a = data.arena.allocator();
    var prng: std.Random.DefaultPrng = .init(spec.seed ^ 0xd4af7);
    const rnd = prng.random();
    const per_role = 30;
    var weights: [per_role]f64 = undefined;
    for (&weights, 0..) |*w, i| w.* = 1 / @as(f64, @floatFromInt(i + 1));

    const games = try a.alloc(rows.Game, n);
    const out = try a.alloc(rows.Row, 10 * n);
    const n_test = n / 15;
    for (games, 0..) |*g, gi| {
        var teams: [2][5]u32 = undefined;
        var used: [10]u32 = @splat(0);
        for (0..10) |slot| {
            const role = slot % 5;
            const ch: u32 = while (true) {
                const own = if (rnd.uintLessThan(u8, 8) == 0) (role + 1 + rnd.uintLessThan(usize, 4)) % 5 else role;
                const c: u32 = @intCast(1 + own + 5 * rnd.weightedIndex(f64, &weights));
                if (std.mem.indexOfScalar(u32, &used, c) == null) break c;
            };
            used[slot] = ch;
            teams[slot / 5][role] = ch;
        }
        g.* = .{
            .match_id = try std.fmt.allocPrint(a, "SYN_{d}", .{gi}),
            .start = @intCast(gi * 60_000),
            .patch = 16020,
            .platform = if (gi >= n - n_test) 0 else @intCast(gi % 3),
            .is_test = gi >= n - n_test,
            .teams = teams,
            .winner = 0,
            .timeline15 = true,
            .duration_s = 1800,
        };
        for (0..10) |slot| {
            const side: u1 = @intCast(slot / 5);
            const ch = teams[side][slot % 5];
            var st = seatstats.unknown;
            const share = std.math.clamp(0.5 + 0.25 * hnorm(spec.seed, 9, ch) + 0.08 * rnd.floatNorm(f64), 0.02, 0.98);
            const dpm = 700 * @exp(0.3 * hnorm(spec.seed, 10, ch) + 0.2 * rnd.floatNorm(f64));
            st[@backingInt(seatstats.SeatStat.minutes)] = 30;
            st[@backingInt(seatstats.SeatStat.dmg_magic)] = @floatCast(30 * dpm * share);
            st[@backingInt(seatstats.SeatStat.dmg_phys)] = @floatCast(30 * dpm * (1 - share));
            st[@backingInt(seatstats.SeatStat.dmg_true)] = 0;
            const champ_games: u16 = @intFromFloat(@exp(rnd.float(f64) * 4) - 1);
            out[gi * 10 + slot] = .{
                .game = @intCast(gi),
                .slot = @intCast(slot),
                .side = side,
                .role = @fromBackingInt(@as(u3, @intCast(slot % 5))),
                .champion = ch,
                .y = @splat(std.math.nan(f32)),
                .champ_games = champ_games,
                .games_before = champ_games + rnd.uintLessThan(u16, 100),
                .stats = st,
            };
        }
    }
    data.games = games;
    data.rows = out;
    var t = try truth(gpa, &data, spec);
    defer t.deinit(gpa);
    relabel(&data, &t, spec.seed);
    return data;
}

pub const Fit = struct {
    w: []f64,
    /// Standard errors from the inverse Hessian at the fit
    se: []f64,

    pub fn deinit(f: *Fit, gpa: std.mem.Allocator) void {
        gpa.free(f.w);
        gpa.free(f.se);
    }
};

/// Unpenalised logistic regression by Newton's method; x is n rows of k features,
/// row-major (add a constant column for an intercept)
pub fn logistic(gpa: std.mem.Allocator, x: []const f64, y: []const f64, k: usize) !Fit {
    const w = try gpa.alloc(f64, k);
    errdefer gpa.free(w);
    @memset(w, 0);
    const g = try gpa.alloc(f64, k);
    defer gpa.free(g);
    const h = try gpa.alloc(f64, k * k);
    defer gpa.free(h);
    const inv = try gpa.alloc(f64, k * k);
    errdefer gpa.free(inv);
    for (0..100) |_| {
        @memset(g, 0);
        @memset(h, 0);
        for (y, 0..) |yi, i| {
            const row = x[i * k ..][0..k];
            var z: f64 = 0;
            for (row, w) |a, b| z += a * b;
            const p = sigmoid(z);
            for (0..k) |a| {
                g[a] += (p - yi) * row[a];
                for (0..k) |b| h[a * k + b] += p * (1 - p) * row[a] * row[b];
            }
        }
        try invert(h, inv, k);
        var step: f64 = 0;
        for (0..k) |a| {
            var s: f64 = 0;
            for (0..k) |b| s += inv[a * k + b] * g[b];
            w[a] -= s;
            step = @max(step, @abs(s));
        }
        if (step < 1e-9) break;
    }
    const se = try gpa.alloc(f64, k);
    for (se, 0..) |*s, a| s.* = @sqrt(inv[a * k + a]);
    gpa.free(inv);
    return .{ .w = w, .se = se };
}

/// Gauss-Jordan with partial pivoting; m is destroyed
fn invert(m: []f64, inv: []f64, k: usize) !void {
    @memset(inv, 0);
    for (0..k) |i| inv[i * k + i] = 1;
    for (0..k) |c| {
        var piv = c;
        for (c + 1..k) |r| if (@abs(m[r * k + c]) > @abs(m[piv * k + c])) {
            piv = r;
        };
        if (m[piv * k + c] == 0) return error.Singular;
        for (0..k) |j| {
            std.mem.swap(f64, &m[c * k + j], &m[piv * k + j]);
            std.mem.swap(f64, &inv[c * k + j], &inv[piv * k + j]);
        }
        const d = m[c * k + c];
        for (0..k) |j| {
            m[c * k + j] /= d;
            inv[c * k + j] /= d;
        }
        for (0..k) |r| if (r != c) {
            const f = m[r * k + c];
            if (f == 0) continue;
            for (0..k) |j| {
                m[r * k + j] -= f * m[c * k + j];
                inv[r * k + j] -= f * inv[c * k + j];
            }
        };
    }
}

/// Smallest true effect (logit) a two-sided 5% test finds with 80% power, for a binary
/// feature present (+1 or -1 for blue) in `games` games near 50%: se = 2 / sqrt(games)
pub fn mdeLogit(games: f64) f64 {
    return (1.96 + 0.84) * 2 / @sqrt(games);
}

pub const usage =
    \\  plant-score plant:SPEC:SNAP PREDS.tsv [REF_COL]
    \\                                  per-game win predictions (netcheck's preds.tsv,
    \\                                  games-*.tsv) against the planted truth
    \\                                  (lab/synth.zig): log loss vs REF_COL (default cand
    \\                                  or the first) and vs the truth; per planted term
    \\                                  the share of it each model's logit carries
    \\
;

const skip_cols = [_][]const u8{ "fold", "block", "match_id", "platform", "y", "slot", "outcome" };

const Col = struct { name: []const u8, at: usize, p: std.ArrayList(f64) = .empty };

/// Rows of a preds file joined to the planted games, dev and folds apart
const Group = struct {
    name: []const u8,
    games: std.ArrayList(u32) = .empty,
    y: std.ArrayList(f64) = .empty,
    cols: []Col,
};

pub fn main(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: std.Io, argv: []const []const u8) !u8 {
    if (argv.len < 2) {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    }
    const arg = try parseArg(argv[0]) orelse {
        std.debug.print("plant-score: SNAP must be plant:SPEC:PATH\n", .{});
        return 2;
    };
    const empty: std.AutoHashMapUnmanaged(u64, void) = .empty;
    var d = try rows.load(gpa, argv[0], &empty);
    defer d.deinit();
    var t = try truth(gpa, &d, arg.spec);
    defer t.deinit(gpa);

    var index: std.StringHashMapUnmanaged(u32) = .empty;
    for (d.games, 0..) |g, gi| try index.put(arena, g.match_id, @intCast(gi));

    const text = try std.Io.Dir.cwd().readFileAlloc(io, argv[1], arena, .limited(1 << 31));
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    var head = std.mem.splitScalar(u8, lines.next() orelse return error.EmptyPreds, '\t');
    var names: std.ArrayList([]const u8) = .empty;
    while (head.next()) |h| try names.append(arena, h);
    const find = struct {
        fn f(ns: []const []const u8, n: []const u8) ?usize {
            for (ns, 0..) |x, i| if (std.mem.eql(u8, x, n)) return i;
            return null;
        }
    }.f;
    const at_id = find(names.items, "match_id") orelse return error.NoMatchId;
    const at_y = find(names.items, "y") orelse return error.NoY;
    const at_group = find(names.items, "fold") orelse find(names.items, "block");
    const at_outcome = find(names.items, "outcome");

    var groups: [2]Group = undefined;
    for (&groups, [_][]const u8{ "dev", "folds" }) |*g, n| {
        var cols: std.ArrayList(Col) = .empty;
        for (names.items, 0..) |nm, i| {
            for (skip_cols) |sc| {
                if (std.mem.eql(u8, nm, sc)) break;
            } else try cols.append(arena, .{ .name = nm, .at = i });
        }
        g.* = .{ .name = n, .cols = cols.items };
    }
    var unknown: usize = 0;
    var flipped: usize = 0;
    var kept: usize = 0;
    var fields: std.ArrayList([]const u8) = .empty;
    while (lines.next()) |line| {
        fields.clearRetainingCapacity();
        var it = std.mem.splitScalar(u8, line, '\t');
        while (it.next()) |f| try fields.append(arena, f);
        if (fields.items.len != names.items.len) return error.RaggedPreds;
        if (at_outcome) |o| if (!std.mem.eql(u8, fields.items[o], "win")) continue;
        const gi = index.get(fields.items[at_id]) orelse {
            unknown += 1;
            continue;
        };
        const y = try std.fmt.parseFloat(f64, fields.items[at_y]);
        // Blue's outcome and chance, as netcheck writes them; anything else is another
        // spec's or snapshot's file
        if ((y > 0.5) != (d.games[gi].winner == 0)) flipped += 1;
        const dev = if (at_group) |a| std.mem.eql(u8, fields.items[a], "dev") else true;
        const g = &groups[if (dev) 0 else 1];
        try g.games.append(arena, gi);
        try g.y.append(arena, y);
        for (g.cols) |*c| try c.p.append(arena, try std.fmt.parseFloat(f64, fields.items[c.at]));
        kept += 1;
    }
    if (unknown > 0 or flipped > 0 or kept == 0) {
        std.debug.print("plant-score: {d} rows kept, {d} match ids not in the snapshot, {d} outcomes unlike the planted winner: preds from another spec or snapshot?\n", .{ kept, unknown, flipped });
        return 1;
    }

    var buf: [8192]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &buf);
    const w = &stdout.interface;
    try w.print("# plant-score {s}\n\nspec: {s}\npair #{d} {t} + #{d} {t}: {d} team-games; matchup #{d} over #{d} {t}: {d} games; mix sd {d:.5}\n", .{
        argv[1],               argv[0],                                            t.pair[0].champion, @as(core.Role, @fromBackingInt(t.pair[0].role)),
        t.pair[1].champion,    @as(core.Role, @fromBackingInt(t.pair[1].role)),    t.pair_games,       t.matchup[0].champion,
        t.matchup[1].champion, @as(core.Role, @fromBackingInt(t.matchup[0].role)), t.matchup_games,    t.mix_sd,
    });
    var planted: std.ArrayList(Term) = .empty;
    for (std.enums.values(Term)[1..]) |term| {
        for (d.games, 0..) |_, gi| if (t.parts[gi][@backingInt(term)] != 0) {
            try planted.append(arena, term);
            break;
        };
    }
    for (&groups) |*g| {
        if (g.games.items.len == 0) continue;
        try scoreGroup(gpa, arena, w, &t, g, planted.items, if (argv.len >= 3) argv[2] else "cand");
    }
    try w.flush();
    return 0;
}

fn loss(y: f64, p: f64) f64 {
    const q = std.math.clamp(p, 1e-6, 1 - 1e-6);
    return -(y * @log(q) + (1 - y) * @log(1 - q));
}

fn plus(x: f64) []const u8 {
    return if (x >= 0) "+" else "";
}

fn logitOf(p: f64) f64 {
    const q = std.math.clamp(p, 1e-6, 1 - 1e-6);
    return @log(q / (1 - q));
}

/// Mean of a - b per game and its standard error (games are independent rows)
fn paired(a: []const f64, b: []const f64) [2]f64 {
    var m: f64 = 0;
    var m2: f64 = 0;
    for (a, b) |x, y| {
        m += x - y;
        m2 += (x - y) * (x - y);
    }
    const n: f64 = @floatFromInt(a.len);
    m /= n;
    return .{ m, @sqrt(@max(m2 / n - m * m, 0) / n) };
}

fn scoreGroup(gpa: std.mem.Allocator, arena: std.mem.Allocator, w: *std.Io.Writer, t: *const Truth, g: *const Group, planted: []const Term, ref_name: []const u8) !void {
    const n = g.games.items.len;
    const ys = g.y.items;
    var ref: *const Col = &g.cols[0];
    for (g.cols) |*c| if (std.mem.eql(u8, c.name, ref_name)) {
        ref = c;
    };
    // The truth, and the truth without the planted terms (what champion strengths alone give)
    const truth_l = try arena.alloc(f64, n);
    const base_l = try arena.alloc(f64, n);
    const base_z = try arena.alloc(f64, n);
    for (g.games.items, ys, truth_l, base_l, base_z) |gi, y, *tl, *bl, *bz| {
        tl.* = loss(y, sigmoid(t.logit(gi)));
        bz.* = t.parts[gi][@backingInt(Term.base)];
        bl.* = loss(y, sigmoid(bz.*));
    }
    const ref_l = try arena.alloc(f64, n);
    for (ref_l, ys, ref.p.items) |*l, y, p| l.* = loss(y, p);
    var mean_ref: f64 = 0;
    for (ref_l) |l| mean_ref += l;
    mean_ref /= @floatFromInt(n);

    try w.print("\n## {s}: {d} games; log loss vs {s} ({d:.5}), negative is better; captured = slope of the model's logit on each truth part (1 all of it, 0 none), 95% robust\n\n", .{ g.name, n, ref.name, mean_ref });
    try w.writeAll("| model | log loss | vs ref | base slope |");
    for (planted) |term| try w.print(" {t} captured |", .{term});
    try w.writeAll("\n| --- | --- | --- | --- |");
    for (planted) |_| try w.writeAll(" --- |");
    try w.writeAll("\n");

    const k = planted.len + 2;
    const x = try arena.alloc(f64, n * k);
    for (g.games.items, 0..) |gi, i| {
        x[i * k] = base_z[i];
        for (planted, 1..) |term, j| x[i * k + j] = t.parts[gi][@backingInt(term)];
        x[i * k + k - 1] = 1;
    }
    const z = try arena.alloc(f64, n);
    const l = try arena.alloc(f64, n);
    for (g.cols) |*c| {
        var mean: f64 = 0;
        for (l, z, ys, c.p.items) |*li, *zi, y, p| {
            li.* = loss(y, p);
            zi.* = logitOf(p);
            mean += li.*;
        }
        mean /= @floatFromInt(n);
        const gain = paired(l, ref_l);
        const fit = try ols(gpa, x, z, k);
        defer gpa.free(fit);
        try w.print("| {s} | {d:.5} | {s}{d:.5} ± {d:.5} | {d:.2} ± {d:.2} |", .{ c.name, mean, plus(gain[0]), gain[0], 1.96 * gain[1], fit[0], 1.96 * fit[k] });
        for (1..planted.len + 1) |j| try w.print(" {d:.2} ± {d:.2} |", .{ fit[j], 1.96 * fit[k + j] });
        try w.writeAll("\n");
    }
    var tm: f64 = 0;
    for (truth_l) |v| tm += v;
    const tg = paired(truth_l, ref_l);
    const bg = paired(base_l, ref_l);
    const pg = paired(truth_l, base_l);
    try w.print("| truth | {d:.5} | {s}{d:.5} ± {d:.5} | |\n| truth without plants | | {s}{d:.5} ± {d:.5} | |\n\nThe plants are worth {s}{d:.5} ± {d:.5} nats/game to an oracle on these games\n", .{
        tm / @as(f64, @floatFromInt(n)), plus(tg[0]), tg[0], 1.96 * tg[1], plus(bg[0]), bg[0], 1.96 * bg[1], plus(pg[0]), pg[0], 1.96 * pg[1],
    });
}

/// Least squares of z on x (n rows of k), coefficients then their HC0 robust standard
/// errors (2k values)
fn ols(gpa: std.mem.Allocator, x: []const f64, z: []const f64, k: usize) ![]f64 {
    const xtx = try gpa.alloc(f64, k * k);
    defer gpa.free(xtx);
    const inv = try gpa.alloc(f64, k * k);
    defer gpa.free(inv);
    const xtz = try gpa.alloc(f64, k);
    defer gpa.free(xtz);
    @memset(xtx, 0);
    @memset(xtz, 0);
    for (z, 0..) |zi, i| {
        const row = x[i * k ..][0..k];
        for (0..k) |a| {
            xtz[a] += row[a] * zi;
            for (0..k) |b| xtx[a * k + b] += row[a] * row[b];
        }
    }
    // A planted term absent from these games leaves a zero column: hold its slope at 0
    for (0..k) |a| if (xtx[a * k + a] == 0) {
        xtx[a * k + a] = 1;
    };
    try invert(xtx, inv, k);
    const out = try gpa.alloc(f64, 2 * k);
    @memset(out, 0);
    for (0..k) |a| for (0..k) |b| {
        out[a] += inv[a * k + b] * xtz[b];
    };
    const meat = try gpa.alloc(f64, k * k);
    defer gpa.free(meat);
    @memset(meat, 0);
    for (z, 0..) |zi, i| {
        const row = x[i * k ..][0..k];
        var e = zi;
        for (row, out[0..k]) |a, b| e -= a * b;
        for (0..k) |a| for (0..k) |b| {
            meat[a * k + b] += e * e * row[a] * row[b];
        };
    }
    for (0..k) |a| {
        var v: f64 = 0;
        for (0..k) |b| for (0..k) |c| {
            v += inv[a * k + b] * meat[b * k + c] * inv[c * k + a];
        };
        out[k + a] = @sqrt(@max(v, 0));
    }
    return out;
}

test "plant spec and argument parse" {
    const s = try Spec.parse("seed=7,synergy=2.5,mix=-3,pair=2");
    try std.testing.expectEqual(@as(u64, 7), s.seed);
    try std.testing.expectEqual(@as(f64, 2.5), s.synergy);
    try std.testing.expectEqual(@as(f64, -3), s.mix);
    try std.testing.expectEqual(@as(u32, 2), s.pair);
    try std.testing.expectEqual(@as(f64, 2.5), s.champ);
    try std.testing.expectError(error.BadPlantSpec, Spec.parse("synergy"));
    try std.testing.expectError(error.BadPlantSpec, Spec.parse("synrgy=1"));
    try std.testing.expectEqual(@as(u32, 2), (try Spec.parse("counter_sd=2,lanes=2")).lanes);
    try std.testing.expectError(error.BadPlantSpec, Spec.parse("lanes=3"));
    const a = (try parseArg("plant:skill=1:/home/x/snap")).?;
    try std.testing.expectEqualStrings("/home/x/snap", a.path);
    try std.testing.expectEqual(@as(f64, 1), a.spec.skill);
    try std.testing.expect(try parseArg("/home/x/snap") == null);
}

/// Columns: each planted term's part (scaled to logit 1 per unit of spec) and a constant
fn design(gpa: std.mem.Allocator, t: *const Truth, terms: []const Term) ![]f64 {
    const k = terms.len + 1;
    const x = try gpa.alloc(f64, t.parts.len * k);
    for (t.parts, 0..) |p, i| {
        for (terms, 0..) |term, j| x[i * k + j] = p[@backingInt(term)];
        x[i * k + terms.len] = 1;
    }
    return x;
}

fn blueWins(gpa: std.mem.Allocator, d: *const rows.Data) ![]f64 {
    const y = try gpa.alloc(f64, d.games.len);
    for (d.games, y) |g, *v| v.* = @floatFromInt(@intFromBool(g.winner == 0));
    return y;
}

test "winners follow the planted logit: each term comes back at its size" {
    const gpa = std.testing.allocator;
    const spec: Spec = .{ .seed = 3, .synergy = 10, .counter = 10, .mix = -8, .skill = 3, .pair_sd = 2, .counter_sd = 2 };
    var d = try draft(gpa, 30_000, spec);
    defer d.deinit();
    var t = try truth(gpa, &d, spec);
    defer t.deinit(gpa);
    try std.testing.expect(t.pair_games > 500 and t.matchup_games > 100);
    const terms = std.enums.values(Term);
    const x = try design(gpa, &t, terms);
    defer gpa.free(x);
    const y = try blueWins(gpa, &d);
    defer gpa.free(y);
    var f = try logistic(gpa, x, y, terms.len + 1);
    defer f.deinit(gpa);
    // Every coefficient is 1 (the truth's own scale), the intercept 0
    for (f.w[0..terms.len], f.se[0..terms.len]) |w, se| try std.testing.expect(@abs(w - 1) < 3.5 * se);
    try std.testing.expect(@abs(f.w[terms.len]) < 3.5 * f.se[terms.len]);
}

test "nothing planted: the terms' features carry no signal" {
    const gpa = std.testing.allocator;
    const none: Spec = .{ .seed = 5 };
    var d = try draft(gpa, 30_000, none);
    defer d.deinit();
    // Features at unit size, labels from the plain spec
    var t = try truth(gpa, &d, .{ .seed = 5, .champ = 0, .synergy = 25, .counter = 25, .mix = 25, .skill = 25, .pair_sd = 25, .counter_sd = 25 });
    defer t.deinit(gpa);
    var base = try truth(gpa, &d, none);
    defer base.deinit(gpa);
    for (t.parts, base.parts) |*p, b| p[@backingInt(Term.base)] = b[@backingInt(Term.base)];
    const terms = std.enums.values(Term);
    const x = try design(gpa, &t, terms);
    defer gpa.free(x);
    const y = try blueWins(gpa, &d);
    defer gpa.free(y);
    var f = try logistic(gpa, x, y, terms.len + 1);
    defer f.deinit(gpa);
    try std.testing.expect(@abs(f.w[0] - 1) < 3.5 * f.se[0]);
    for (f.w[1..terms.len], f.se[1..terms.len]) |w, se| try std.testing.expect(@abs(w) < 3.5 * se);
}

test "same seed, same winners; another seed, others" {
    const gpa = std.testing.allocator;
    var a = try draft(gpa, 2000, .{ .seed = 1, .synergy = 4 });
    defer a.deinit();
    var b = try draft(gpa, 2000, .{ .seed = 1, .synergy = 4 });
    defer b.deinit();
    var t = try truth(gpa, &a, .{ .seed = 2, .synergy = 4 });
    defer t.deinit(gpa);
    relabel(&b, &t, 2);
    var same: usize = 0;
    for (a.games, b.games) |x, y| same += @intFromBool(x.winner == y.winner);
    // Different strengths and draws: about half agree
    try std.testing.expect(same > 800 and same < 1200);
    var c = try draft(gpa, 2000, .{ .seed = 1, .synergy = 4 });
    defer c.deinit();
    for (a.games, c.games) |x, y| try std.testing.expectEqual(x.winner, y.winner);
    for (c.rows) |r| try std.testing.expectEqual(@as(f32, @floatFromInt(@intFromBool(r.side == c.games[r.game].winner))), r.y[@backingInt(rows.Outcome.win)]);
}

test "captured share: a model carrying half a planted term reads 0.5" {
    const gpa = std.testing.allocator;
    const spec: Spec = .{ .seed = 4, .synergy = 10, .skill = 3 };
    var d = try draft(gpa, 5000, spec);
    defer d.deinit();
    var t = try truth(gpa, &d, spec);
    defer t.deinit(gpa);
    const terms = [_]Term{ .base, .synergy, .skill };
    const x = try design(gpa, &t, &terms);
    defer gpa.free(x);
    var prng: std.Random.DefaultPrng = .init(1);
    const z = try gpa.alloc(f64, d.games.len);
    defer gpa.free(z);
    for (z, t.parts) |*v, p| v.* = 0.9 * p[@backingInt(Term.base)] + 0.5 * p[@backingInt(Term.synergy)] + 0.05 * prng.random().floatNorm(f64);
    const fit = try ols(gpa, x, z, terms.len + 1);
    defer gpa.free(fit);
    const k = terms.len + 1;
    try std.testing.expectApproxEqAbs(@as(f64, 0.9), fit[0], 3 * fit[k]);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), fit[1], 3 * fit[k + 1]);
    try std.testing.expectApproxEqAbs(@as(f64, 0), fit[2], 3 * fit[k + 2]);
    try std.testing.expect(fit[k + 1] < 0.05);
}
