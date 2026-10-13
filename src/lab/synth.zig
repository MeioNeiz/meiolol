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
//!   counters  every lane matchup's own effect, sd `counter_sd`, antisymmetric
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
        if (s.pair == 0) return error.BadPlantSpec;
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
        for (0..5) |r| {
            const x = g.teams[0][r];
            const y = g.teams[1][r];
            if (x == y) continue;
            const r3: u3 = @intCast(r);
            if (r3 == matchup[0].role) {
                if (x == matchup[0].champion and y == matchup[1].champion) ctr += 1;
                if (y == matchup[0].champion and x == matchup[1].champion) ctr -= 1;
            }
            if (spec.counter_sd != 0) {
                const sign: f64 = if (x < y) 1 else -1;
                ctrs += sign * hnorm(spec.seed, Stream.counter, pairKey(key(@min(x, y), r), key(@max(x, y), r)));
            }
        }
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

test "plant spec and argument parse" {
    const s = try Spec.parse("seed=7,synergy=2.5,mix=-3,pair=2");
    try std.testing.expectEqual(@as(u64, 7), s.seed);
    try std.testing.expectEqual(@as(f64, 2.5), s.synergy);
    try std.testing.expectEqual(@as(f64, -3), s.mix);
    try std.testing.expectEqual(@as(u32, 2), s.pair);
    try std.testing.expectEqual(@as(f64, 2.5), s.champ);
    try std.testing.expectError(error.BadPlantSpec, Spec.parse("synergy"));
    try std.testing.expectError(error.BadPlantSpec, Spec.parse("synrgy=1"));
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
